from __future__ import annotations

from collections.abc import Iterable

import math
import pulp

from .data_models import (
    ArcType,
    FixedFactorDefaults,
    NetworkData,
    NetworkNode,
    ObjectiveWeights,
    RoutingResult,
    Shipment,
    TransferArcTemplate,
    TransportArcTemplate,
    VariableFactorDefaults,
    _TimedArc,
)


########################################
#   TimeExpandedFreightRoutingModel    #
########################################
class TimeExpandedNetwork:
    """Builds and stores the time-expanded representation of a multimodal network."""

    def __init__(
        self,
        network_data: NetworkData,
        planning_days: int,
        shipments: Iterable[Shipment],
        default_fixed_costs: FixedFactorDefaults | None = None,
        default_fixed_emissions: FixedFactorDefaults | None = None,
        default_variable_factors: VariableFactorDefaults | None = None,
    ):
        if not isinstance(planning_days, int) or planning_days <= 0:
            raise ValueError("planning_days must be a positive integer.")

        self.network_data = network_data
        self.planning_days = planning_days
        self.max_time_min = planning_days * 24 * 60
        self.shipments = list(shipments)
        self.default_fixed_costs = (
            default_fixed_costs or network_data.default_fixed_costs
        )
        self.default_fixed_emissions = (
            default_fixed_emissions or network_data.default_fixed_emissions
        )
        self.default_variable_factors = (
            default_variable_factors or network_data.default_variable_factors
        )

        # Initialize event times for all (hub, mode) pairs
        self.event_times: dict[tuple[str, str], set[int]] = {}
        for hub in self.network_data.hubs.values():
            for mode in hub.supported_modes:
                self.event_times[(hub.id, mode)] = {0, self.max_time_min}

        self.transport_arcs: list[_TimedArc] = []
        self.transfer_arcs: list[_TimedArc] = []
        self.waiting_arcs: list[_TimedArc] = []
        self.all_arcs: list[_TimedArc] = []
        self.nodes: set[NetworkNode] = set()

        self._build()

    @staticmethod
    def build(
        network_data: NetworkData,
        planning_days: int,
        shipments: Iterable[Shipment],
        default_fixed_costs: FixedFactorDefaults | None = None,
        default_fixed_emissions: FixedFactorDefaults | None = None,
        default_variable_factors: VariableFactorDefaults | None = None,
    ) -> "TimeExpandedNetwork":
        """Build reusable lookup indexes from the loaded network data and returns the built network."""
        return TimeExpandedNetwork(
            network_data=network_data,
            planning_days=planning_days,
            shipments=shipments,
            default_fixed_costs=default_fixed_costs,
            default_fixed_emissions=default_fixed_emissions,
            default_variable_factors=default_variable_factors,
        )

    def _get_fixed_cost(self, arc: _TimedArc) -> float:
        if arc.fixed_cost is not None:
            return arc.fixed_cost
        if arc.arc_type == ArcType.TRANSPORT:
            return self.default_fixed_costs.transport.get(arc.mode, 0.0)
        elif arc.arc_type == ArcType.TRANSFER:
            return self.default_fixed_costs.transfer
        return self.default_fixed_costs.waiting

    def _get_fixed_emissions(self, arc: _TimedArc) -> float:
        if arc.fixed_emissions is not None:
            return arc.fixed_emissions
        if arc.arc_type == ArcType.TRANSPORT:
            return self.default_fixed_emissions.transport.get(arc.mode, 0.0)
        elif arc.arc_type == ArcType.TRANSFER:
            return self.default_fixed_emissions.transfer
        return self.default_fixed_emissions.waiting

    @staticmethod
    def objective_weights_for(
        shipment: Shipment, fallback: ObjectiveWeights
    ) -> ObjectiveWeights:
        """Resolve and normalize one shipment's objective weights."""
        return (shipment.objective_weights or fallback).normalized()

    @staticmethod
    def _required_vehicles(arc: _TimedArc, weight: float) -> int:
        return max(1, math.ceil(weight / max(arc.capacity, 1e-9)))

    def estimate_normalization_bounds(
        self, shipment: Shipment | None = None
    ) -> dict[str, tuple[float, float]]:
        """Return analytical normalization bounds for one shipment.

        Passing a shipment yields the bounds used by both the mathematical model
        and the heuristics.  The no-argument form is retained for callers that
        need aggregate reporting bounds.
        """
        if shipment is None:
            if not self.shipments:
                return {
                    "cost": (0.0, 1.0),
                    "time": (0.0, 1.0),
                    "emissions": (0.0, 1.0),
                }
            if len(self.shipments) == 1:
                shipment = self.shipments[0]
            else:
                shipment_bounds = [
                    self.estimate_normalization_bounds(item) for item in self.shipments
                ]
                return {
                    criterion: (
                        sum(bounds[criterion][0] for bounds in shipment_bounds),
                        sum(bounds[criterion][1] for bounds in shipment_bounds),
                    )
                    for criterion in ("cost", "time", "emissions")
                }

        return self._analytical_normalization_bounds(shipment)

    def normalization_ranges(self, shipment: Shipment) -> dict[str, float]:
        """Return protected normalization denominators for one shipment."""
        bounds = self.estimate_normalization_bounds(shipment)
        return {
            criterion: max(upper - lower, 1e-9)
            for criterion, (lower, upper) in bounds.items()
        }

    def shared_fixed_objective_coefficients(
        self,
        shipments: Iterable[Shipment],
        fallback: ObjectiveWeights,
    ) -> tuple[float, float]:
        """Return common cost/emissions coefficients for shared vehicle impacts."""
        shipment_list = list(shipments)
        if not shipment_list:
            return 0.0, 0.0
        cost_coefficients = []
        emissions_coefficients = []
        for shipment in shipment_list:
            weights = self.objective_weights_for(shipment, fallback)
            ranges = self.normalization_ranges(shipment)
            cost_coefficients.append(weights.cost / ranges["cost"])
            emissions_coefficients.append(weights.emissions / ranges["emissions"])
        return (
            sum(cost_coefficients) / len(cost_coefficients),
            sum(emissions_coefficients) / len(emissions_coefficients),
        )

    def _analytical_normalization_bounds(
        self, shipment: Shipment
    ) -> dict[str, tuple[float, float]]:
        """Estimate shipment scales without traversing the expanded graph."""
        available_time = float(
            max(0, min(shipment.deadline, self.max_time_min) - shipment.start_time)
        )
        aerial_distance = self._aerial_distance_km(shipment)

        cost_rates = tuple(
            factor.cost_per_ton_km for factor in self.network_data.mode_factors.values()
        )
        emissions_rates = tuple(
            factor.emissions_kg_per_ton_km
            for factor in self.network_data.mode_factors.values()
        )
        templates = self.network_data.arc_templates
        transport_templates = tuple(
            template
            for template in templates
            if isinstance(template, TransportArcTemplate)
        )
        max_speed = max(
            1e-9,
            max(
                (
                    template.distance / template.duration_min
                    for template in transport_templates
                ),
                default=1.0,
            ),
        )
        min_duration = min(
            (float(template.duration_min) for template in templates), default=30.0
        )
        min_cost_rate = min(cost_rates, default=0.0)
        max_cost_rate = max(cost_rates, default=0.0)
        min_emissions_rate = min(emissions_rates, default=0.0)
        max_emissions_rate = max(emissions_rates, default=0.0)

        fixed_costs = (
            *self.default_fixed_costs.transport.values(),
            self.default_fixed_costs.transfer,
            self.default_fixed_costs.waiting,
            *(
                template.fixed_cost
                for template in templates
                if template.fixed_cost is not None
            ),
        )
        fixed_emissions = (
            *self.default_fixed_emissions.transport.values(),
            self.default_fixed_emissions.transfer,
            self.default_fixed_emissions.waiting,
            *(
                template.fixed_emissions
                for template in templates
                if template.fixed_emissions is not None
            ),
        )
        smallest_capacity = min(self.network_data.capacities.values(), default=1.0)
        max_required_vehicles = max(1, math.ceil(shipment.weight / smallest_capacity))
        max_fixed_cost = max(fixed_costs, default=0.0) * max_required_vehicles
        max_fixed_emissions = max(fixed_emissions, default=0.0) * max_required_vehicles

        min_time = aerial_distance / max_speed
        max_time = available_time
        max_distance = max_speed * available_time
        max_segments = max(1.0, available_time / min_duration)

        min_cost = aerial_distance * min_cost_rate * shipment.weight
        max_cost = (
            max_distance * max_cost_rate * shipment.weight
            + max_segments * max_fixed_cost
        )
        min_emissions = aerial_distance * min_emissions_rate * shipment.weight
        max_emissions = (
            max_distance * max_emissions_rate * shipment.weight
            + max_segments * max_fixed_emissions
        )

        if max_cost <= min_cost:
            max_cost = min_cost + 1.0
        if max_time <= min_time:
            max_time = min_time + 1.0
        if max_emissions <= min_emissions:
            max_emissions = min_emissions + 1.0

        return {
            "cost": (min_cost, max_cost),
            "time": (min_time, max_time),
            "emissions": (min_emissions, max_emissions),
        }

    def _aerial_distance_km(self, shipment: Shipment) -> float:
        """Return the geodetic distance between a shipment's endpoints."""
        start = self.network_data.hubs.get(shipment.start_hub)
        end = self.network_data.hubs.get(shipment.end_hub)
        if (
            start is None
            or end is None
            or start.latitude is None
            or start.longitude is None
            or end.latitude is None
            or end.longitude is None
        ):
            return 0.0

        lat1 = math.radians(start.latitude)
        lat2 = math.radians(end.latitude)
        delta_lat = math.radians(end.latitude - start.latitude)
        delta_lon = math.radians(end.longitude - start.longitude)
        haversine = (
            math.sin(delta_lat / 2.0) ** 2
            + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2.0) ** 2
        )
        central_angle = 2.0 * math.atan2(
            math.sqrt(haversine), math.sqrt(1.0 - haversine)
        )
        return 6371.0 * central_angle

    def _build(self) -> None:
        # Populate event times based on templates
        for template in self.network_data.arc_templates:
            if isinstance(template, TransportArcTemplate):
                for day in range(self.planning_days):
                    for departure_min in template.departure_minutes:
                        start_min = day * 24 * 60 + departure_min
                        arrival_min = start_min + template.duration_min
                        if arrival_min <= self.max_time_min:
                            self.event_times[(template.from_hub, template.mode)].add(
                                start_min
                            )
                            self.event_times[(template.to_hub, template.mode)].add(
                                arrival_min
                            )
            elif isinstance(template, TransferArcTemplate):
                for day in range(self.planning_days):
                    for departure_min in template.departure_minutes:
                        start_min = day * 24 * 60 + departure_min
                        arrival_min = start_min + template.duration_min
                        if arrival_min <= self.max_time_min:
                            self.event_times[
                                (template.from_hub, template.from_mode)
                            ].add(start_min)
                            self.event_times[(template.from_hub, template.to_mode)].add(
                                arrival_min
                            )

        # Dynamic adjustments if shipments are provided
        if self.shipments:
            for s in self.shipments:
                for mode in self.network_data.hubs[s.start_hub].supported_modes:
                    if s.start_time <= self.max_time_min:
                        self.event_times[(s.start_hub, mode)].add(s.start_time)
                for mode in self.network_data.hubs[s.end_hub].supported_modes:
                    if s.deadline <= self.max_time_min:
                        self.event_times[(s.end_hub, mode)].add(s.deadline)

        # Convert event times to sorted lists
        event_times_list = {k: sorted(list(v)) for k, v in self.event_times.items()}

        # 1. Transport Arcs
        for template in self.network_data.arc_templates:
            if isinstance(template, TransportArcTemplate):
                for day in range(self.planning_days):
                    for departure_min in template.departure_minutes:
                        start_min = day * 24 * 60 + departure_min
                        arrival_min = start_min + template.duration_min

                        if arrival_min > self.max_time_min:
                            continue

                        cost = template.cost
                        if cost is None:
                            factor = self.network_data.mode_factors.get(template.mode)
                            if not factor:
                                raise ValueError(
                                    f"Missing mode factor for mode: {template.mode}"
                                )
                            cost = template.distance * factor.cost_per_ton_km

                        emissions = template.emissions
                        if emissions is None:
                            factor = self.network_data.mode_factors.get(template.mode)
                            if not factor:
                                raise ValueError(
                                    f"Missing mode factor for mode: {template.mode}"
                                )
                            emissions = (
                                template.distance * factor.emissions_kg_per_ton_km
                            )

                        transport_capacity = (
                            template.capacity
                            if template.capacity is not None
                            else self.network_data.capacities[template.mode]
                        )

                        self.transport_arcs.append(
                            _TimedArc(
                                from_node=NetworkNode(
                                    template.from_hub, template.mode, start_min
                                ),
                                to_node=NetworkNode(
                                    template.to_hub, template.mode, arrival_min
                                ),
                                mode=template.mode,
                                arc_type=ArcType.TRANSPORT,
                                departure_min=start_min,
                                arrival_min=arrival_min,
                                cost=cost,
                                emissions=emissions,
                                capacity=transport_capacity,
                                distance=template.distance,
                                max_vehicles=template.max_vehicles,
                                fixed_cost=template.fixed_cost,
                                fixed_emissions=template.fixed_emissions,
                            )
                        )

        # 2. Transfer Arcs
        for template in self.network_data.arc_templates:
            if isinstance(template, TransferArcTemplate):
                for day in range(self.planning_days):
                    for departure_min in template.departure_minutes:
                        start_min = day * 24 * 60 + departure_min
                        arrival_min = start_min + template.duration_min

                        if arrival_min > self.max_time_min:
                            continue

                        cost = template.transfer_cost_per_ton
                        if cost is None:
                            cost = self.default_variable_factors.transfer_cost_per_ton

                        emissions = template.transfer_emissions_per_ton
                        if emissions is None:
                            emissions = (
                                self.default_variable_factors.transfer_emissions_per_ton
                            )

                        transfer_capacity = (
                            template.capacity
                            if template.capacity is not None
                            else self.network_data.capacities["transfer"]
                        )

                        self.transfer_arcs.append(
                            _TimedArc(
                                from_node=NetworkNode(
                                    template.hub, template.from_mode, start_min
                                ),
                                to_node=NetworkNode(
                                    template.hub, template.to_mode, arrival_min
                                ),
                                mode=f"{template.from_mode}->{template.to_mode}",
                                arc_type=ArcType.TRANSFER,
                                departure_min=start_min,
                                arrival_min=arrival_min,
                                cost=cost,
                                emissions=emissions,
                                capacity=transfer_capacity,
                                distance=0.0,
                                max_vehicles=template.max_vehicles,
                                fixed_cost=template.fixed_cost,
                                fixed_emissions=template.fixed_emissions,
                            )
                        )

        # 3. Waiting Arcs
        for (hub_id, mode), times in event_times_list.items():
            for i in range(len(times) - 1):
                start_min = times[i]
                arrival_min = times[i + 1]
                duration_hours = (arrival_min - start_min) / 60.0

                hub = self.network_data.hubs[hub_id]
                waiting_cost_per_hour = (
                    hub.waiting_cost_per_hour
                    if hub.waiting_cost_per_hour is not None
                    else self.default_variable_factors.waiting_cost_per_hour
                )
                waiting_emissions_per_hour = (
                    hub.waiting_emissions_per_hour
                    if hub.waiting_emissions_per_hour is not None
                    else self.default_variable_factors.waiting_emissions_per_hour
                )
                cost = duration_hours * waiting_cost_per_hour
                emissions = duration_hours * waiting_emissions_per_hour

                self.waiting_arcs.append(
                    _TimedArc(
                        from_node=NetworkNode(hub_id, mode, start_min),
                        to_node=NetworkNode(hub_id, mode, arrival_min),
                        mode=mode,
                        arc_type=ArcType.WAITING,
                        departure_min=start_min,
                        arrival_min=arrival_min,
                        cost=cost,
                        emissions=emissions,
                        capacity=self.network_data.capacities["waiting"],
                        max_vehicles=None,
                        fixed_cost=None,
                        fixed_emissions=None,
                    )
                )

        self.all_arcs = self.transport_arcs + self.transfer_arcs + self.waiting_arcs

        # Collect all unique NetworkNode objects from the arcs
        self.nodes = set()
        for arc in self.all_arcs:
            self.nodes.add(arc.from_node)
            self.nodes.add(arc.to_node)

    def summary(self) -> None:
        """Print an overview of the generated time-expanded network."""
        print("==============================")
        print("Summary TimeExpandedNetwork:")
        print(f"planning_days={self.planning_days}")
        print(f"planning_horizon_min={self.max_time_min}")
        print(f"shipments={len(self.shipments)}")
        print(f"nodes={len(self.nodes)}")
        print(f"arcs={len(self.all_arcs)}")
        print(f"  - transport_arcs={len(self.transport_arcs)}")
        print(f"  - transfer_arcs={len(self.transfer_arcs)}")
        print(f"  - waiting_arcs={len(self.waiting_arcs)}")
        print("==============================")


class TimeExpandedFreightRoutingModel:
    """Build and solve routing models on a multimodal freight network."""

    def __init__(
        self,
        objective_weights: ObjectiveWeights | None = None,
    ):
        self.objective_weights = objective_weights or ObjectiveWeights()

    def solve(
        self,
        network: TimeExpandedNetwork,
        time_limit_sec: float | None = None,
        show_progress: bool = False,
    ) -> RoutingResult:
        """Solve the routing problem for the shipments built into the network.

        Args:
            network: The pre-built time-expanded network.
            time_limit_sec: Optional solver time limit in seconds.
            show_progress: Whether to display the HiGHS solver log.
        """
        return self._solve(
            network,
            time_limit_sec=time_limit_sec,
            show_progress=show_progress,
        )

    def _solve(
        self,
        network: TimeExpandedNetwork,
        time_limit_sec: float | None = None,
        show_progress: bool = False,
    ) -> RoutingResult:
        """Solve the routing problem with an optional solver time limit."""
        shipments = tuple(network.shipments)
        if not shipments:
            raise ValueError("shipments must not be empty.")

        self.network = network
        self.network_data = network.network_data
        self.default_fixed_costs = network.default_fixed_costs
        self.default_fixed_emissions = network.default_fixed_emissions
        self.default_variable_factors = network.default_variable_factors
        self.all_arcs = network.all_arcs
        self.nodes = network.nodes
        self.transport_arcs = network.transport_arcs
        self.transfer_arcs = network.transfer_arcs
        self.waiting_arcs = network.waiting_arcs
        self.planning_days = network.planning_days

        self._validate_shipments(shipments)

        ########################################
        #           setup lp problem           #
        ########################################
        self.prob = pulp.LpProblem(
            "Time_Expanded_Routing_Consolidation", pulp.LpMinimize
        )

        arc_indices = list(range(len(self.all_arcs)))
        shipment_indices = list(range(len(shipments)))
        price_limited_indices = [
            k for k, shipment in enumerate(shipments) if shipment.max_price is not None
        ]
        has_total_budget = all(shipment.max_price is not None for shipment in shipments)

        # Decision variables: use_arc[(i, k)] = 1 if shipment k uses arc i
        self.use_arc = pulp.LpVariable.dicts(
            "UseArc",
            [(i, k) for i in arc_indices for k in shipment_indices],
            cat=pulp.LpBinary,
        )

        # Slack variables for soft constraints (infeasibility diagnostics)
        self.slack_deadline = pulp.LpVariable.dicts(
            "SlackDeadline",
            shipment_indices,
            lowBound=0,
            cat=pulp.LpContinuous,
        )
        self.slack_price = pulp.LpVariable.dicts(
            "SlackPrice",
            price_limited_indices,
            lowBound=0,
            cat=pulp.LpContinuous,
        )
        self.slack_emissions = pulp.LpVariable.dicts(
            "SlackEmissions",
            shipment_indices,
            lowBound=0,
            cat=pulp.LpContinuous,
        )
        self.slack_total_budget = (
            pulp.LpVariable(
                "SlackTotalBudget",
                lowBound=0,
                cat=pulp.LpContinuous,
            )
            if has_total_budget
            else None
        )

        # Dynamic vehicle count variables
        self.vehicle_count = {}
        for i, arc in enumerate(self.all_arcs):
            if arc.max_vehicles is not None:
                up_bound = arc.max_vehicles
                cat = pulp.LpInteger
            elif arc.arc_type == ArcType.TRANSPORT and arc.mode == "road":
                up_bound = None
                cat = pulp.LpInteger
            else:
                up_bound = 1
                cat = pulp.LpBinary

            self.vehicle_count[i] = pulp.LpVariable(
                f"VehicleCount_{i}",
                lowBound=0,
                upBound=up_bound,
                cat=cat,
            )

        ########################################
        #      formulate objective function    #
        ########################################
        # Cost Component (Fixed + Variable)
        fixed_cost = pulp.lpSum(
            self.network._get_fixed_cost(self.all_arcs[i]) * self.vehicle_count[i]
            for i in range(len(self.all_arcs))
        )
        var_cost = pulp.lpSum(
            self.use_arc[(i, k)] * arc.cost * shipment.weight
            for i, arc in enumerate(self.all_arcs)
            for k, shipment in enumerate(shipments)
        )
        total_cost = fixed_cost + var_cost

        # Shared fixed emissions component
        fixed_emissions = pulp.lpSum(
            self.network._get_fixed_emissions(self.all_arcs[i]) * self.vehicle_count[i]
            for i in range(len(self.all_arcs))
        )

        # Shipment-specific min-max scales.  The exact model and heuristics both
        # obtain these values from TimeExpandedNetwork, preventing scale drift.
        bounds_by_shipment = [
            self.network.estimate_normalization_bounds(shipment)
            for shipment in shipments
        ]
        weights_by_shipment = [
            self.network.objective_weights_for(shipment, self.objective_weights)
            for shipment in shipments
        ]
        cost_ranges = [
            max(bounds["cost"][1] - bounds["cost"][0], 1e-9)
            for bounds in bounds_by_shipment
        ]
        time_ranges = [
            max(bounds["time"][1] - bounds["time"][0], 1e-9)
            for bounds in bounds_by_shipment
        ]
        emissions_ranges = [
            max(bounds["emissions"][1] - bounds["emissions"][0], 1e-9)
            for bounds in bounds_by_shipment
        ]

        variable_cost_by_shipment = [
            pulp.lpSum(
                self.use_arc[(i, k)] * arc.cost * shipments[k].weight
                for i, arc in enumerate(self.all_arcs)
            )
            for k in shipment_indices
        ]
        time_by_shipment = [
            pulp.lpSum(
                self.use_arc[(i, k)] * arc.duration_min
                for i, arc in enumerate(self.all_arcs)
            )
            for k in shipment_indices
        ]
        variable_emissions_by_shipment = [
            pulp.lpSum(
                self.use_arc[(i, k)] * arc.emissions * shipments[k].weight
                for i, arc in enumerate(self.all_arcs)
            )
            for k in shipment_indices
        ]

        # Fixed vehicle impacts are shared by consolidated shipments.  Their
        # coefficient is the mean shipment preference; for one shipment this
        # reduces exactly to that shipment's normalized objective.
        (
            fixed_cost_coefficient,
            fixed_emissions_coefficient,
        ) = self.network.shared_fixed_objective_coefficients(
            shipments, self.objective_weights
        )

        routing_objective = (
            fixed_cost_coefficient * fixed_cost
            + fixed_emissions_coefficient * fixed_emissions
            + pulp.lpSum(
                weights_by_shipment[k].cost
                * (variable_cost_by_shipment[k] - bounds_by_shipment[k]["cost"][0])
                / cost_ranges[k]
                + weights_by_shipment[k].time
                * (time_by_shipment[k] - bounds_by_shipment[k]["time"][0])
                / time_ranges[k]
                + weights_by_shipment[k].emissions
                * (
                    variable_emissions_by_shipment[k]
                    - bounds_by_shipment[k]["emissions"][0]
                )
                / emissions_ranges[k]
                for k in shipment_indices
            )
        )

        # Normalize soft-constraint violations to the same dimensionless scales
        # as the routing objective.
        total_budget_violation = (
            self.slack_total_budget / sum(cost_ranges)
            if self.slack_total_budget is not None
            else 0.0
        )
        normalized_constraint_violation = (
            pulp.lpSum(
                self.slack_deadline[k] / time_ranges[k] for k in shipment_indices
            )
            + pulp.lpSum(
                self.slack_price[k] / cost_ranges[k] for k in price_limited_indices
            )
            + pulp.lpSum(
                self.slack_emissions[k] / emissions_ranges[k]
                for k in shipment_indices
                if shipments[k].max_emissions is not None
            )
            + total_budget_violation
        )

        soft_constraint_penalty = 100.0
        self.prob += (
            routing_objective
            + soft_constraint_penalty * normalized_constraint_violation
        )

        ########################################
        #        formulate constraints         #
        ########################################

        ########################################
        #     flow conservation constraints    #
        ########################################
        incoming_by_node: dict[NetworkNode, list[int]] = {}
        outgoing_by_node: dict[NetworkNode, list[int]] = {}
        for i, arc in enumerate(self.all_arcs):
            outgoing_by_node.setdefault(arc.from_node, []).append(i)
            incoming_by_node.setdefault(arc.to_node, []).append(i)

        for k, shipment in enumerate(shipments):
            start_nodes = {
                node
                for node in self.nodes
                if node.hub_id == shipment.start_hub
                and node.time_min == shipment.start_time
            }
            end_nodes = {node for node in self.nodes if node.hub_id == shipment.end_hub}

            # Must depart start nodes exactly once
            self.prob += (
                pulp.lpSum(
                    self.use_arc[(i, k)]
                    for node in start_nodes
                    for i in outgoing_by_node.get(node, [])
                )
                == 1
            )

            # Must arrive at end nodes exactly once
            self.prob += (
                pulp.lpSum(
                    self.use_arc[(i, k)]
                    for node in end_nodes
                    for i in incoming_by_node.get(node, [])
                )
                == 1
            )

            # Soft deadline constraint
            self.prob += (
                pulp.lpSum(
                    node.time_min * self.use_arc[(i, k)]
                    for node in end_nodes
                    for i in incoming_by_node.get(node, [])
                )
                - self.slack_deadline[k]
                <= shipment.deadline
            )

            # Intermediate node flow conservation
            intermediate_nodes = self.nodes - start_nodes - end_nodes
            for node in intermediate_nodes:
                self.prob += pulp.lpSum(
                    self.use_arc[(i, k)] for i in incoming_by_node.get(node, [])
                ) == pulp.lpSum(
                    self.use_arc[(i, k)] for i in outgoing_by_node.get(node, [])
                )

        ########################################
        #  capacity & activation constraints   #
        ########################################
        for i, arc in enumerate(self.all_arcs):
            self.prob += (
                pulp.lpSum(
                    shipments[k].weight * self.use_arc[(i, k)] for k in shipment_indices
                )
                <= arc.capacity * self.vehicle_count[i]
            )

            # Bounding count to usage
            if arc.arc_type == ArcType.TRANSPORT and arc.mode == "road":
                total_weight = sum(s.weight for s in shipments)
                max_road_vehicles = max(1, int(total_weight / arc.capacity) + 1)
                self.prob += self.vehicle_count[i] <= max_road_vehicles * pulp.lpSum(
                    self.use_arc[(i, k)] for k in shipment_indices
                )
            else:
                self.prob += self.vehicle_count[i] <= pulp.lpSum(
                    self.use_arc[(i, k)] for k in shipment_indices
                )

        ########################################
        #   budget and emission constraints    #
        ########################################
        for k, shipment in enumerate(shipments):
            if shipment.max_price is not None:
                # Soft price budget constraint
                self.prob += (
                    pulp.lpSum(
                        self.use_arc[(i, k)] * arc.cost * shipment.weight
                        for i, arc in enumerate(self.all_arcs)
                    )
                    - self.slack_price[k]
                    <= shipment.max_price
                )

            if shipment.max_emissions is not None:
                # Soft emissions budget constraint
                self.prob += (
                    pulp.lpSum(
                        self.use_arc[(i, k)] * arc.emissions * shipment.weight
                        for i, arc in enumerate(self.all_arcs)
                    )
                    - self.slack_emissions[k]
                    <= shipment.max_emissions
                )

        # Shared fixed costs cannot be assigned unambiguously when only some
        # shipments have price limits. Apply the combined budget only if every
        # shipment defines one.
        if self.slack_total_budget is not None:
            total_budget = sum(
                shipment.max_price
                for shipment in shipments
                if shipment.max_price is not None
            )
            self.prob += total_cost - self.slack_total_budget <= total_budget

        ########################################
        #           solver execution           #
        ########################################
        highs_py = pulp.HiGHS(
            msg=show_progress,
            timeLimit=time_limit_sec,
        )
        status = self.prob.solve(highs_py)

        self.status = pulp.LpStatus[status]
        self.objective_value = pulp.value(self.prob.objective)
        diagnostics = []
        is_optimal = self.status == "Optimal"

        if self.status == "Optimal":
            # Check for soft constraint violations
            for k, shipment in enumerate(shipments):
                slack_dl = pulp.value(self.slack_deadline[k])
                slack_pr = (
                    pulp.value(self.slack_price[k])
                    if shipment.max_price is not None
                    else 0.0
                )
                slack_em = (
                    pulp.value(self.slack_emissions[k])
                    if shipment.max_emissions is not None
                    else 0.0
                )

                if slack_dl and slack_dl > 1e-3:
                    diagnostics.append(
                        f"Shipment '{shipment.id}': Deadline is too tight. "
                        f"Requires an extra {slack_dl:.1f} minutes to route successfully."
                    )
                    is_optimal = False
                if slack_pr and slack_pr > 1e-3:
                    diagnostics.append(
                        f"Shipment '{shipment.id}': Budget is too low. "
                        f"Requires an extra {slack_pr:.2f} EUR to cover costs."
                    )
                    is_optimal = False
                if slack_em and slack_em > 1e-3:
                    diagnostics.append(
                        f"Shipment '{shipment.id}': Emissions limit is too restrictive. "
                        f"Requires an additional {slack_em:.1f} kg CO2 allowance."
                    )
                    is_optimal = False

            slack_tot = (
                pulp.value(self.slack_total_budget)
                if self.slack_total_budget is not None
                else 0.0
            )
            if slack_tot and slack_tot > 1e-3:
                diagnostics.append(
                    f"Global: Combined price budget is too low. "
                    f"Requires an extra {slack_tot:.2f} EUR to cover overall costs."
                )
                is_optimal = False

            if diagnostics:
                print("--- INFEASIBILITY DIAGNOSTIC REPORT ---")
                for msg in diagnostics:
                    print(f"❌ {msg}")

            # filter decision variables using a > 0.5 threshold
            # to remain robust against small floating-point solver tolerances.
            self.total_fixed_cost = sum(
                self.network._get_fixed_cost(arc) * pulp.value(self.vehicle_count[i])
                for i, arc in enumerate(self.all_arcs)
                if pulp.value(self.vehicle_count[i]) > 0.5
            )
            self.total_fixed_emissions = sum(
                self.network._get_fixed_emissions(arc)
                * pulp.value(self.vehicle_count[i])
                for i, arc in enumerate(self.all_arcs)
                if pulp.value(self.vehicle_count[i]) > 0.5
            )
            self.total_variable_cost = sum(
                arc.cost * shipment.weight * pulp.value(self.use_arc[(i, k)])
                for i, arc in enumerate(self.all_arcs)
                for k, shipment in enumerate(shipments)
                if pulp.value(self.use_arc[(i, k)]) > 0.5
            )
            self.total_variable_emissions = sum(
                arc.emissions * shipment.weight * pulp.value(self.use_arc[(i, k)])
                for i, arc in enumerate(self.all_arcs)
                for k, shipment in enumerate(shipments)
                if pulp.value(self.use_arc[(i, k)]) > 0.5
            )
            self.total_cost = self.total_fixed_cost + self.total_variable_cost
            self.total_emissions = (
                self.total_fixed_emissions + self.total_variable_emissions
            )
            self.total_time = sum(
                arc.duration_min * pulp.value(self.use_arc[(i, k)])
                for i, arc in enumerate(self.all_arcs)
                for k in range(len(shipments))
                if pulp.value(self.use_arc[(i, k)]) > 0.5
            )

            # Store shipment routes
            self.shipment_routes = {}
            for k, shipment in enumerate(shipments):
                chosen_arcs = [
                    self.all_arcs[i]
                    for i in range(len(self.all_arcs))
                    if pulp.value(self.use_arc[(i, k)]) > 0.5
                ]
                chosen_arcs.sort(key=lambda a: a.departure_min)
                self.shipment_routes[shipment.id] = chosen_arcs
        else:
            self.total_fixed_cost = 0.0
            self.total_fixed_emissions = 0.0
            self.total_variable_cost = 0.0
            self.total_variable_emissions = 0.0
            self.total_cost = 0.0
            self.total_emissions = 0.0
            self.total_time = 0.0
            self.shipment_routes = {}

        return RoutingResult(
            status=self.status,
            is_optimal=is_optimal,
            total_cost=self.total_cost,
            total_emissions=self.total_emissions,
            total_time=self.total_time,
            shipment_routes={k: tuple(v) for k, v in self.shipment_routes.items()},
            objective_value=self.objective_value,
            total_fixed_cost=self.total_fixed_cost,
            total_variable_cost=self.total_variable_cost,
            total_fixed_emissions=self.total_fixed_emissions,
            total_variable_emissions=self.total_variable_emissions,
            diagnostics=tuple(diagnostics),
        )

    def _validate_shipments(self, shipments: tuple[Shipment, ...]) -> None:
        for shipment in shipments:
            if shipment.start_hub not in self.network_data.hubs:
                raise ValueError(
                    f"{shipment.id}: unknown start_hub {shipment.start_hub!r}."
                )
            if shipment.end_hub not in self.network_data.hubs:
                raise ValueError(
                    f"{shipment.id}: unknown end_hub {shipment.end_hub!r}."
                )

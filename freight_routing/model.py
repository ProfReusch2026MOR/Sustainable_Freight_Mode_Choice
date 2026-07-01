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

        self._build(self.shipments)

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

    def estimate_normalization_bounds(
        self, shipments: Iterable[Shipment]
    ) -> dict[str, tuple[float, float]]:
        total_weight = sum(s.weight for s in shipments)

        # Aerial distance (geodetic start-to-end distance) is always needed for minimum bounds
        max_aerial_dist = 0.0
        for s in shipments:
            start_hub = self.network_data.hubs.get(s.start_hub)
            end_hub = self.network_data.hubs.get(s.end_hub)
            if (
                start_hub
                and end_hub
                and start_hub.latitude is not None
                and start_hub.longitude is not None
                and end_hub.latitude is not None
                and end_hub.longitude is not None
            ):
                # Haversine formula to calculate aerial distance in km
                lat1, lon1 = start_hub.latitude, start_hub.longitude
                lat2, lon2 = end_hub.latitude, end_hub.longitude

                phi1 = math.radians(lat1)
                phi2 = math.radians(lat2)
                delta_phi = math.radians(lat2 - lat1)
                delta_lambda = math.radians(lon2 - lon1)

                a = (
                    math.sin(delta_phi / 2.0) ** 2
                    + math.cos(phi1)
                    * math.cos(phi2)
                    * math.sin(delta_lambda / 2.0) ** 2
                )
                c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
                dist_km = 6371.0 * c

                if dist_km > max_aerial_dist:
                    max_aerial_dist = dist_km

        # Global mode factors loop (needed for minimum and maximum bounds)
        min_cost_per_ton_km = float("inf")
        max_cost_per_ton_km = 0.0
        min_emissions_kg_per_ton_km = float("inf")
        max_emissions_kg_per_ton_km = 0.0

        for factor in self.network_data.mode_factors.values():
            if factor.cost_per_ton_km > max_cost_per_ton_km:
                max_cost_per_ton_km = factor.cost_per_ton_km
            if factor.cost_per_ton_km < min_cost_per_ton_km:
                min_cost_per_ton_km = factor.cost_per_ton_km
            if factor.emissions_kg_per_ton_km > max_emissions_kg_per_ton_km:
                max_emissions_kg_per_ton_km = factor.emissions_kg_per_ton_km
            if factor.emissions_kg_per_ton_km < min_emissions_kg_per_ton_km:
                min_emissions_kg_per_ton_km = factor.emissions_kg_per_ton_km

        if min_cost_per_ton_km == float("inf"):
            min_cost_per_ton_km = 0.0
        if min_emissions_kg_per_ton_km == float("inf"):
            min_emissions_kg_per_ton_km = 0.0

        # Calculate minimum bounds using max speed
        max_speed = 0.0
        for template in self.network_data.arc_templates:
            if isinstance(template, TransportArcTemplate) and template.duration_min > 0:
                speed = template.distance / template.duration_min
                if speed > max_speed:
                    max_speed = speed
        if max_speed == 0.0:
            max_speed = 1.0

        min_time = max_aerial_dist / max_speed
        min_cost = max_aerial_dist * min_cost_per_ton_km * total_weight
        min_eco = max_aerial_dist * min_emissions_kg_per_ton_km * total_weight

        max_time = float(self.max_time_min)

        # Calculate maximum bounds using the analytical template estimation
        min_duration = float("inf")
        max_fixed_cost_single = 0.0
        max_fixed_emissions_single = 0.0

        for template in self.network_data.arc_templates:
            if isinstance(template, TransportArcTemplate):
                if template.duration_min > 0 and template.duration_min < min_duration:
                    min_duration = template.duration_min

            fc = template.fixed_cost
            if fc is None:
                if isinstance(template, TransportArcTemplate):
                    fc = self.default_fixed_costs.transport.get(template.mode, 0.0)
                elif isinstance(template, TransferArcTemplate):
                    fc = self.default_fixed_costs.transfer
            if fc is not None and fc > max_fixed_cost_single:
                max_fixed_cost_single = fc

            fe = template.fixed_emissions
            if fe is None:
                if isinstance(template, TransportArcTemplate):
                    fe = self.default_fixed_emissions.transport.get(template.mode, 0.0)
                elif isinstance(template, TransferArcTemplate):
                    fe = self.default_fixed_emissions.transfer
            if fe is not None and fe > max_fixed_emissions_single:
                max_fixed_emissions_single = fe

        if min_duration == float("inf") or min_duration <= 0:
            min_duration = 30.0

        max_segments = max(1.0, max_time / min_duration)
        max_dist = max_speed * max_time

        max_var_cost = max_dist * max_cost_per_ton_km * total_weight
        max_fixed_cost_est = max_segments * max_fixed_cost_single + (
            self.default_fixed_costs.waiting * len(self.event_times)
        )
        max_cost = max_var_cost + max_fixed_cost_est

        max_var_eco = max_dist * max_emissions_kg_per_ton_km * total_weight
        max_fixed_eco_est = max_segments * max_fixed_emissions_single + (
            self.default_fixed_emissions.waiting * len(self.event_times)
        )
        max_eco = max_var_eco + max_fixed_eco_est

        # Division by zero/negative range protection
        if max_cost <= min_cost:
            max_cost = min_cost + 1.0
        if max_time <= min_time:
            max_time = min_time + 1.0
        if max_eco <= min_eco:
            max_eco = min_eco + 1.0

        return {
            "cost": (min_cost, max_cost),
            "time": (min_time, max_time),
            "emissions": (min_eco, max_eco),
        }

    def _build(self, shipments: Iterable[Shipment] | None = None) -> None:
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
        if shipments:
            for s in shipments:
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
    ) -> RoutingResult:
        """Solve the routing problem for the shipments built into the network."""
        return self._solve(network, time_limit_sec=time_limit_sec)

    def _solve(
        self,
        network: TimeExpandedNetwork,
        time_limit_sec: float | None = None,
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
            shipment_indices,
            lowBound=0,
            cat=pulp.LpContinuous,
        )
        self.slack_emissions = pulp.LpVariable.dicts(
            "SlackEmissions",
            shipment_indices,
            lowBound=0,
            cat=pulp.LpContinuous,
        )
        self.slack_total_budget = pulp.LpVariable(
            "SlackTotalBudget",
            lowBound=0,
            cat=pulp.LpContinuous,
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

        # Time Component
        total_time = pulp.lpSum(
            self.use_arc[(i, k)] * arc.duration_min
            for i, arc in enumerate(self.all_arcs)
            for k in range(len(shipments))
        )

        # Emissions Component (Fixed + Variable)
        fixed_emissions = pulp.lpSum(
            self.network._get_fixed_emissions(self.all_arcs[i]) * self.vehicle_count[i]
            for i in range(len(self.all_arcs))
        )
        var_emissions = pulp.lpSum(
            self.use_arc[(i, k)] * arc.emissions * shipment.weight
            for i, arc in enumerate(self.all_arcs)
            for k, shipment in enumerate(shipments)
        )
        total_emissions = fixed_emissions + var_emissions

        # Combined Weighted Objective Function (Min-Max scaled dynamically)
        bounds = self.network.estimate_normalization_bounds(shipments)
        c_min, c_max = bounds["cost"]
        t_min, t_max = bounds["time"]
        e_min, e_max = bounds["emissions"]

        # Dynamic penalty factor Big-M for soft constraints
        penalty_m = max(c_max, t_max, e_max, 1000.0) * 100.0

        self.prob += (
            self.objective_weights.cost * ((total_cost - c_min) / (c_max - c_min))
            + self.objective_weights.time * ((total_time - t_min) / (t_max - t_min))
            + self.objective_weights.emissions
            * ((total_emissions - e_min) / (e_max - e_min))
            + penalty_m * pulp.lpSum(self.slack_deadline[k] for k in shipment_indices)
            + penalty_m * pulp.lpSum(self.slack_price[k] for k in shipment_indices)
            + penalty_m
            * pulp.lpSum(
                self.slack_emissions[k]
                for k in shipment_indices
                if shipments[k].max_emissions is not None
            )
            + penalty_m * self.slack_total_budget
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

        # Soft total combined budget limit across all shipments (including fixed costs)
        total_budget = sum(shipment.max_price for shipment in shipments)
        self.prob += total_cost - self.slack_total_budget <= total_budget

        ########################################
        #           solver execution           #
        ########################################
        highs_py = pulp.HiGHS(msg=False, timeLimit=time_limit_sec)
        status = self.prob.solve(highs_py)

        self.status = pulp.LpStatus[status]
        self.objective_value = pulp.value(self.prob.objective)
        diagnostics = []
        is_optimal = self.status == "Optimal"

        if self.status == "Optimal":
            # Check for soft constraint violations
            for k, shipment in enumerate(shipments):
                slack_dl = pulp.value(self.slack_deadline[k])
                slack_pr = pulp.value(self.slack_price[k])
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

            slack_tot = pulp.value(self.slack_total_budget)
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

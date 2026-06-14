from __future__ import annotations

from collections.abc import Iterable
from typing import Any

import pulp

from .data_models import (
    ArcType,
    FixedFactorDefaults,
    Hub,
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

MAX_EST_COST = 5000.0
MAX_EST_TIME = 2880.0
MAX_EST_ECO = 1000.0


########################################
#   TimeExpandedFreightRoutingModel    #
########################################
class TimeExpandedFreightRoutingModel:
    """Build and solve routing models on a multimodal freight network."""

    def __init__(
        self,
        network_data: NetworkData,
        objective_weights: ObjectiveWeights | None = None,
        default_fixed_costs: FixedFactorDefaults | None = None,
        default_fixed_emissions: FixedFactorDefaults | None = None,
        default_variable_factors: VariableFactorDefaults | None = None,
    ):
        self.network_data = network_data
        self.objective_weights = objective_weights or ObjectiveWeights()
        self.default_fixed_costs = (
            default_fixed_costs or network_data.default_fixed_costs
        )
        self.default_fixed_emissions = (
            default_fixed_emissions or network_data.default_fixed_emissions
        )
        self.default_variable_factors = (
            default_variable_factors or network_data.default_variable_factors
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

    def build(
        self, planning_days: int, shipments: Iterable[Shipment] | None = None
    ) -> None:
        """Build reusable lookup indexes from the loaded network data."""

        if not isinstance(planning_days, int) or planning_days <= 0:
            raise ValueError("planning_days must be a positive integer.")
        self.planning_days = planning_days
        self.max_time_min = planning_days * 24 * 60

        # 1. Initialize event times for all (hub, mode) pairs
        self.event_times: dict[tuple[str, str], set[int]] = {}
        for hub in self.network_data.hubs.values():
            for mode in hub.supported_modes:
                self.event_times[(hub.id, mode)] = {0, self.max_time_min}

        self.transport_arcs: list[_TimedArc] = []
        self.transfer_arcs: list[_TimedArc] = []

        def add_event(hub_id: str, mode: str, time_min: int) -> None:
            key = (hub_id, mode)
            if key in self.event_times:
                if 0 <= time_min <= self.max_time_min:
                    self.event_times[key].add(time_min)

        # Add shipment start times and deadlines as events
        if shipments is not None:
            for shipment in shipments:
                start_hub = self.network_data.hubs.get(shipment.start_hub)
                if start_hub:
                    for mode in start_hub.supported_modes:
                        add_event(shipment.start_hub, mode, shipment.start_time)
                end_hub = self.network_data.hubs.get(shipment.end_hub)
                if end_hub:
                    for mode in end_hub.supported_modes:
                        add_event(shipment.end_hub, mode, shipment.deadline)

        # 2. Generate Transport Arcs
        for template in self.network_data.arc_templates:
            if isinstance(template, TransportArcTemplate):
                for day in range(planning_days):
                    for dep_min in template.departure_minutes:
                        start_min = day * 24 * 60 + dep_min
                        arrival_min = start_min + template.duration_min
                        if arrival_min <= self.max_time_min:
                            add_event(template.from_hub, template.mode, start_min)
                            add_event(template.to_hub, template.mode, arrival_min)

                            cost = template.cost
                            if cost is None:
                                factor = self.network_data.mode_factors.get(
                                    template.mode
                                )
                                if not factor:
                                    raise ValueError(
                                        f"Missing mode factor for mode: {template.mode}"
                                    )
                                cost = template.distance * factor.cost_per_ton_km

                            emissions = template.emissions
                            if emissions is None:
                                factor = self.network_data.mode_factors.get(
                                    template.mode
                                )
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
                                    max_vehicles=template.max_vehicles,
                                    fixed_cost=template.fixed_cost,
                                    fixed_emissions=template.fixed_emissions,
                                )
                            )

            elif isinstance(template, TransferArcTemplate):
                # 3. Generate Transfer Arcs
                for day in range(planning_days):
                    for dep_min in template.departure_minutes:
                        start_min = day * 24 * 60 + dep_min
                        arrival_min = start_min + template.duration_min
                        if arrival_min <= self.max_time_min:
                            add_event(template.hub, template.from_mode, start_min)
                            add_event(template.hub, template.to_mode, arrival_min)

                            transfer_cost_per_ton = (
                                template.transfer_cost_per_ton
                                if template.transfer_cost_per_ton is not None
                                else self.default_variable_factors.transfer_cost_per_ton
                            )
                            transfer_emissions_per_ton = (
                                template.transfer_emissions_per_ton
                                if template.transfer_emissions_per_ton is not None
                                else self.default_variable_factors.transfer_emissions_per_ton
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
                                    cost=transfer_cost_per_ton,
                                    emissions=transfer_emissions_per_ton,
                                    capacity=transfer_capacity,
                                    max_vehicles=template.max_vehicles,
                                    fixed_cost=template.fixed_cost,
                                    fixed_emissions=template.fixed_emissions,
                                )
                            )

        # 4. Generate Waiting Arcs
        self.waiting_arcs: list[_TimedArc] = []
        for (hub_id, mode), times in self.event_times.items():
            sorted_times = sorted(times)
            for start_min, arrival_min in zip(sorted_times, sorted_times[1:]):
                duration = arrival_min - start_min
                if duration <= 0:
                    continue
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
                cost = waiting_cost_per_hour * (duration / 60)
                emissions = waiting_emissions_per_hour * (duration / 60)

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

    def solve(self, shipments: Iterable[Shipment]) -> RoutingResult:
        """Solve the routing problem for explicitly provided shipments."""
        shipments = tuple(shipments)
        if not shipments:
            raise ValueError("shipments must not be empty.")
        self._validate_shipments(shipments)

        # Rebuild network if needed to ensure shipment start/deadline nodes exist
        rebuild_needed = False
        if not hasattr(self, "planning_days"):
            rebuild_needed = True
            planning_days = 1
        else:
            planning_days = self.planning_days
            for s in shipments:
                start_key = (
                    s.start_hub,
                    next(iter(self.network_data.hubs[s.start_hub].supported_modes)),
                )
                if (
                    start_key not in self.event_times
                    or s.start_time not in self.event_times[start_key]
                ):
                    rebuild_needed = True
                    break

        if rebuild_needed:
            self.build(planning_days, shipments)

        # 1. Setup LP problem
        self.prob = pulp.LpProblem(
            "Time_Expanded_Routing_Consolidation", pulp.LpMinimize
        )

        arc_indices = list(range(len(self.all_arcs)))
        shipment_indices = list(range(len(shipments)))

        # 2. Decision variables: use_arc[(i, k)] = 1 if shipment k uses arc i
        self.use_arc = pulp.LpVariable.dicts(
            "UseArc",
            [(i, k) for i in arc_indices for k in shipment_indices],
            cat=pulp.LpBinary,
        )

        # 3. Dynamic vehicle count variables
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

        # 4. Formulate Objective Function
        # Cost Component (Fixed + Variable)
        fixed_cost = pulp.lpSum(
            self._get_fixed_cost(self.all_arcs[i]) * self.vehicle_count[i]
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
            self._get_fixed_emissions(self.all_arcs[i]) * self.vehicle_count[i]
            for i in range(len(self.all_arcs))
        )
        var_emissions = pulp.lpSum(
            self.use_arc[(i, k)] * arc.emissions * shipment.weight
            for i, arc in enumerate(self.all_arcs)
            for k, shipment in enumerate(shipments)
        )
        total_emissions = fixed_emissions + var_emissions

        # Combined Weighted Objective Function
        self.prob += (
            self.objective_weights.cost * (total_cost / MAX_EST_COST)
            + self.objective_weights.time * (total_time / MAX_EST_TIME)
            + self.objective_weights.emissions * (total_emissions / MAX_EST_ECO)
        )

        # 5. Formulate Constraints

        # 5.1 Flow Conservation Constraints
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

            # Deadline constraint
            self.prob += (
                pulp.lpSum(
                    node.time_min * self.use_arc[(i, k)]
                    for node in end_nodes
                    for i in incoming_by_node.get(node, [])
                )
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

        # 5.2 Capacity & Activation Constraints
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

        # 5.3 Shipment Budget and Emissions Constraints
        for k, shipment in enumerate(shipments):
            self.prob += (
                pulp.lpSum(
                    self.use_arc[(i, k)] * arc.cost * shipment.weight
                    for i, arc in enumerate(self.all_arcs)
                )
                <= shipment.max_price
            )

            if shipment.max_emissions is not None:
                self.prob += (
                    pulp.lpSum(
                        self.use_arc[(i, k)] * arc.emissions * shipment.weight
                        for i, arc in enumerate(self.all_arcs)
                    )
                    <= shipment.max_emissions
                )

        # Total combined budget limit across all shipments (including fixed costs)
        total_budget = sum(shipment.max_price for shipment in shipments)
        self.prob += total_cost <= total_budget

        # 6. Solver execution
        # use highspy if available, otherwise highs CLI
        highs_py = pulp.HiGHS(msg=False)
        status = self.prob.solve(highs_py)

        self.status = pulp.LpStatus[status]
        if self.status == "Optimal":
            # filter decision variables using a > 0.5 threshold
            # to remain robust against small floating-point solver tolerances.
            self.total_fixed_cost = sum(
                self._get_fixed_cost(arc) * pulp.value(self.vehicle_count[i])
                for i, arc in enumerate(self.all_arcs)
                if pulp.value(self.vehicle_count[i]) > 0.5
            )
            self.total_fixed_emissions = sum(
                self._get_fixed_emissions(arc) * pulp.value(self.vehicle_count[i])
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
            is_optimal=(self.status == "Optimal"),
            total_cost=self.total_cost,
            total_emissions=self.total_emissions,
            total_time=self.total_time,
            shipment_routes={k: tuple(v) for k, v in self.shipment_routes.items()},
            total_fixed_cost=self.total_fixed_cost,
            total_variable_cost=self.total_variable_cost,
            total_fixed_emissions=self.total_fixed_emissions,
            total_variable_emissions=self.total_variable_emissions,
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

    def summary(self) -> None:
        """Print an overview of the generated time-expanded network."""
        if not hasattr(self, "all_arcs"):
            raise ValueError(
                "Model has not been built yet. Call build(planning_days) first."
            )

        print("==============================")
        print("Summary TimeExpandedFreightRoutingModel:")
        print(f"planning_days={self.planning_days}")
        print(f"planning_horizon_min={self.max_time_min}")
        print(f"nodes={len(self.nodes)}")
        print(f"arcs={len(self.all_arcs)}")
        print(f"  - transport_arcs={len(self.transport_arcs)}")
        print(f"  - transfer_arcs={len(self.transfer_arcs)}")
        print(f"  - waiting_arcs={len(self.waiting_arcs)}")
        print("==============================")

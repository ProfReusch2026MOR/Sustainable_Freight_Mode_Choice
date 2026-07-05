from __future__ import annotations

import heapq
import math
import random
from collections import defaultdict
from dataclasses import dataclass

from freight_routing.data_models import (
    ArcType,
    NetworkData,
    NetworkNode,
    ObjectiveWeights,
    RoutingResult,
    Shipment,
    TransportArcTemplate,
    _TimedArc,
)
from freight_routing.model import TimeExpandedNetwork


@dataclass
class _NetworkIndex:
    outgoing: dict[NetworkNode, list[_TimedArc]]
    arc_to_index: dict[_TimedArc, int]
    nodes_by_hub_time: dict[tuple[str, int], list[NetworkNode]]
    nodes_by_hub: dict[str, list[NetworkNode]]


@dataclass
class _CapacityState:
    active_vehicles: list[int]
    remaining_capacity: list[float]


@dataclass
class _NormalizationContext:
    bounds: dict[str, dict[str, tuple[float, float]]]
    ranges: dict[str, dict[str, float]]
    fixed_cost_coefficient: float
    fixed_emissions_coefficient: float


class DijkstraRouter:
    def __init__(self, objective_weights: ObjectiveWeights):
        self.objective_weights = objective_weights
        self._cached_network: TimeExpandedNetwork | None = None
        self._network_index: _NetworkIndex | None = None
        self._apsp_network_data: NetworkData | None = None
        self._min_time_matrix: dict[str, dict[str, float]] = {}
        self._min_cost_matrix: dict[str, dict[str, float]] = {}
        self._min_emissions_matrix: dict[str, dict[str, float]] = {}
        self._node_to_id: dict[NetworkNode, int] = {}
        self._arc_capacity: list[float] = []
        self._arc_fixed_cost: list[float] = []
        self._arc_fixed_emissions: list[float] = []
        self._arc_vehicle_limit: list[float] = []

    def _normalization_context(
        self,
        network: TimeExpandedNetwork,
        shipments: list[Shipment],
    ) -> _NormalizationContext:
        bounds_by_shipment = {
            shipment.id: network.estimate_normalization_bounds(shipment)
            for shipment in shipments
        }
        ranges_by_shipment = {
            shipment.id: network.normalization_ranges(shipment)
            for shipment in shipments
        }
        fixed_cost_coefficient, fixed_emissions_coefficient = (
            network.shared_fixed_objective_coefficients(
                shipments, self.objective_weights
            )
        )
        return _NormalizationContext(
            bounds=bounds_by_shipment,
            ranges=ranges_by_shipment,
            fixed_cost_coefficient=fixed_cost_coefficient,
            fixed_emissions_coefficient=fixed_emissions_coefficient,
        )

    def _get_network_index(self, network: TimeExpandedNetwork) -> _NetworkIndex:
        if self._cached_network is not network or self._network_index is None:
            self._node_to_id = {node: i for i, node in enumerate(network.nodes)}

            # Precompute static arc attributes
            self._arc_capacity = [arc.capacity for arc in network.all_arcs]
            self._arc_fixed_cost = [
                network._get_fixed_cost(arc) for arc in network.all_arcs
            ]
            self._arc_fixed_emissions = [
                network._get_fixed_emissions(arc) for arc in network.all_arcs
            ]
            self._arc_vehicle_limit = [
                self._vehicle_limit(arc) for arc in network.all_arcs
            ]

            outgoing = defaultdict(list)
            arc_to_index = {}
            for index, arc in enumerate(network.all_arcs):
                outgoing[arc.from_node].append(arc)
                arc_to_index[arc] = index

            nodes_by_hub_time = defaultdict(list)
            nodes_by_hub = defaultdict(list)
            for node in network.nodes:
                nodes_by_hub_time[(node.hub_id, node.time_min)].append(node)
                nodes_by_hub[node.hub_id].append(node)

            self._cached_network = network
            self._network_index = _NetworkIndex(
                outgoing=dict(outgoing),
                arc_to_index=arc_to_index,
                nodes_by_hub_time=dict(nodes_by_hub_time),
                nodes_by_hub=dict(nodes_by_hub),
            )
        return self._network_index

    def _run_static_backward_dijkstra(
        self, end_hub: str, rev_graph: dict[str, list[tuple[str, float]]]
    ) -> dict[str, float]:
        distance = {end_hub: 0.0}
        queue = [(0.0, end_hub)]
        while queue:
            current_distance, hub = heapq.heappop(queue)
            if current_distance > distance.get(hub, math.inf):
                continue
            for previous_hub, score in rev_graph.get(hub, []):
                candidate = current_distance + score
                if candidate >= distance.get(previous_hub, math.inf):
                    continue
                distance[previous_hub] = candidate
                heapq.heappush(queue, (candidate, previous_hub))
        return distance

    def _precompute_apsp(self, network: TimeExpandedNetwork) -> None:
        network_data = network.network_data
        if self._apsp_network_data is network_data:
            return

        self._min_time_matrix.clear()
        self._min_cost_matrix.clear()
        self._min_emissions_matrix.clear()

        time_rev_graph = defaultdict(list)
        cost_rev_graph = defaultdict(list)
        emissions_rev_graph = defaultdict(list)

        for template in network_data.arc_templates:
            if not isinstance(template, TransportArcTemplate):
                continue
            factor = network_data.mode_factors[template.mode]
            cost = (
                template.cost
                if template.cost is not None
                else template.distance * factor.cost_per_ton_km
            )
            emissions = (
                template.emissions
                if template.emissions is not None
                else template.distance * factor.emissions_kg_per_ton_km
            )

            time_rev_graph[template.to_hub].append(
                (template.from_hub, float(template.duration_min))
            )
            cost_rev_graph[template.to_hub].append((template.from_hub, float(cost)))
            emissions_rev_graph[template.to_hub].append(
                (template.from_hub, float(emissions))
            )

        for hub_id in network_data.hubs:
            self._min_time_matrix[hub_id] = self._run_static_backward_dijkstra(
                hub_id, time_rev_graph
            )
            self._min_cost_matrix[hub_id] = self._run_static_backward_dijkstra(
                hub_id, cost_rev_graph
            )
            self._min_emissions_matrix[hub_id] = self._run_static_backward_dijkstra(
                hub_id, emissions_rev_graph
            )

        self._apsp_network_data = network_data

    def _min_time_by_hub(
        self,
        network: TimeExpandedNetwork,
        shipment: Shipment,
    ) -> dict[str, float]:
        self._precompute_apsp(network)
        return self._min_time_matrix[shipment.end_hub]

    def _find_shortest_path(
        self,
        network: TimeExpandedNetwork,
        shipment: Shipment,
        capacity: _CapacityState,
        normalization: _NormalizationContext,
    ) -> list[_TimedArc] | None:
        """Find the lowest-scoring feasible route for one shipment."""
        index = self._get_network_index(network)
        start_nodes = sorted(
            index.nodes_by_hub_time.get((shipment.start_hub, shipment.start_time), []),
            key=lambda node: node.mode,
        )
        end_nodes = {
            node
            for node in index.nodes_by_hub.get(shipment.end_hub, [])
            if node.time_min <= shipment.deadline
        }
        if not start_nodes or not end_nodes:
            return None

        ranges = normalization.ranges[shipment.id]
        weights = network.objective_weights_for(shipment, self.objective_weights)
        heuristic = self._heuristic_by_hub(
            network=network,
            shipment=shipment,
            weights=weights,
            ranges=ranges,
        )
        min_time = self._min_time_by_hub(network, shipment)

        # Corridor pruning threshold
        min_time_direct = min_time.get(shipment.start_hub, math.inf)
        corridor_threshold = math.inf
        if not math.isinf(min_time_direct):
            corridor_threshold = max(2.5 * min_time_direct, min_time_direct + 2880)

        def estimate(node: NetworkNode) -> float:
            if heuristic is None:
                return 0.0
            return heuristic.get(node.hub_id, math.inf)

        node_to_id = self._node_to_id
        num_nodes = len(network.nodes)
        queue: list[tuple[float, float, int, NetworkNode]] = []
        distance: list[float] = [math.inf] * num_nodes
        parent: dict[NetworkNode, tuple[NetworkNode | None, _TimedArc | None]] = {}
        counter = 0
        best_feasible_score = math.inf
        best_end_node = None

        for node in start_nodes:
            estimate_to_goal = estimate(node)
            if math.isinf(estimate_to_goal):
                continue

            min_time_to_end = min_time.get(node.hub_id, math.inf)
            if node.time_min + min_time_to_end > shipment.deadline:
                continue

            min_time_from_start = self._min_time_matrix.get(node.hub_id, {}).get(
                shipment.start_hub, math.inf
            )
            if min_time_from_start + min_time_to_end > corridor_threshold:
                continue

            distance[node_to_id[node]] = 0.0
            parent[node] = (None, None)
            heapq.heappush(queue, (estimate_to_goal, 0.0, counter, node))
            counter += 1

        while queue:
            priority, current_distance, _, node = heapq.heappop(queue)
            if priority >= best_feasible_score:
                if best_end_node is not None:
                    return self._reconstruct_route(best_end_node, parent)
                break
            if current_distance > distance[node_to_id[node]]:
                continue
            if node in end_nodes:
                return self._reconstruct_route(node, parent)

            for arc in index.outgoing.get(node, []):
                next_node = arc.to_node

                min_time_to_end = min_time.get(next_node.hub_id, math.inf)
                if next_node.time_min + min_time_to_end > shipment.deadline:
                    continue

                min_time_from_start = self._min_time_matrix.get(
                    next_node.hub_id, {}
                ).get(shipment.start_hub, math.inf)
                if min_time_from_start + min_time_to_end > corridor_threshold:
                    continue

                estimate_to_goal = estimate(next_node)
                if math.isinf(estimate_to_goal):
                    continue

                arc_score = self._arc_score(
                    network=network,
                    arc=arc,
                    arc_index=index.arc_to_index[arc],
                    shipment=shipment,
                    capacity=capacity,
                    normalization=normalization,
                    weights=weights,
                    ranges=ranges,
                )
                if arc_score is None:
                    continue

                candidate = current_distance + arc_score
                v_id = node_to_id[next_node]
                if candidate >= distance[v_id]:
                    continue

                if next_node in end_nodes:
                    if candidate < best_feasible_score:
                        best_feasible_score = candidate
                        best_end_node = next_node

                distance[v_id] = candidate
                parent[next_node] = (node, arc)
                heapq.heappush(
                    queue,
                    (candidate + estimate_to_goal, candidate, counter, next_node),
                )
                counter += 1

        return None

    def _heuristic_by_hub(
        self,
        network: TimeExpandedNetwork,
        shipment: Shipment,
        weights: ObjectiveWeights,
        ranges: dict[str, float],
    ) -> dict[str, float] | None:
        return None

    def _arc_score(
        self,
        network: TimeExpandedNetwork,
        arc: _TimedArc,
        arc_index: int,
        shipment: Shipment,
        capacity: _CapacityState,
        normalization: _NormalizationContext,
        weights: ObjectiveWeights,
        ranges: dict[str, float],
    ) -> float | None:
        remaining_cap = capacity.remaining_capacity[arc_index]
        weight = shipment.weight

        if remaining_cap >= weight:
            needed = 0
        else:
            needed = math.ceil(
                (weight - remaining_cap) / max(self._arc_capacity[arc_index], 1e-9)
            )

        if (
            capacity.active_vehicles[arc_index] + needed
            > self._arc_vehicle_limit[arc_index]
        ):
            return None

        fixed_cost = self._arc_fixed_cost[arc_index] * needed
        fixed_emissions = self._arc_fixed_emissions[arc_index] * needed
        return (
            normalization.fixed_cost_coefficient * fixed_cost
            + weights.cost * arc.cost * weight / ranges["cost"]
            + weights.time * arc.duration_min / ranges["time"]
            + normalization.fixed_emissions_coefficient * fixed_emissions
            + weights.emissions * arc.emissions * weight / ranges["emissions"]
        )

    @staticmethod
    def _vehicle_limit(arc: _TimedArc) -> float:
        if arc.max_vehicles is not None:
            return float(arc.max_vehicles)
        if arc.arc_type == ArcType.TRANSPORT and arc.mode == "road":
            return math.inf
        return 1.0

    @staticmethod
    def _additional_vehicles(
        arc: _TimedArc, shipment_weight: float, remaining_capacity: float
    ) -> int:
        if remaining_capacity >= shipment_weight:
            return 0
        return math.ceil(
            (shipment_weight - remaining_capacity) / max(arc.capacity, 1e-9)
        )

    @staticmethod
    def _empty_capacity_state(network: TimeExpandedNetwork) -> _CapacityState:
        arc_count = len(network.all_arcs)
        return _CapacityState(
            active_vehicles=[0] * arc_count,
            remaining_capacity=[0.0] * arc_count,
        )

    def _reserve_route(
        self,
        network: TimeExpandedNetwork,
        route: tuple[_TimedArc, ...] | list[_TimedArc],
        shipment: Shipment,
        capacity: _CapacityState,
    ) -> None:
        arc_to_index = self._get_network_index(network).arc_to_index
        for arc in route:
            arc_index = arc_to_index[arc]
            needed = self._additional_vehicles(
                arc, shipment.weight, capacity.remaining_capacity[arc_index]
            )
            capacity.active_vehicles[arc_index] += needed
            capacity.remaining_capacity[arc_index] += needed * arc.capacity
            capacity.remaining_capacity[arc_index] -= shipment.weight

    @staticmethod
    def _reconstruct_route(
        end_node: NetworkNode,
        parent: dict[NetworkNode, tuple[NetworkNode | None, _TimedArc | None]],
    ) -> list[_TimedArc]:
        route = []
        node = end_node
        while True:
            previous, arc = parent[node]
            if previous is None:
                break
            if arc is not None:
                route.append(arc)
            node = previous
        route.reverse()
        return route

    def solve(
        self,
        network: TimeExpandedNetwork,
    ) -> RoutingResult:
        """Solve one shipment with this router's shortest-path algorithm.

        Args:
            network: The pre-built TimeExpandedNetwork instance.

        Returns:
            A RoutingResult containing the optimal path and objective metrics.
        """
        if len(network.shipments) != 1:
            raise ValueError("solve() requires a network with exactly one shipment.")
        shipment = network.shipments[0]

        normalization = self._normalization_context(network, [shipment])
        bounds = normalization.bounds[shipment.id]
        ranges = normalization.ranges[shipment.id]
        route_arcs = self._find_shortest_path(
            network=network,
            shipment=shipment,
            capacity=self._empty_capacity_state(network),
            normalization=normalization,
        )

        if route_arcs is None:
            return RoutingResult(
                status="Infeasible",
                is_optimal=False,
                objective_value=None,
                total_cost=0.0,
                total_emissions=0.0,
                total_time=0.0,
                shipment_routes={},
                diagnostics=(
                    "No feasible path exists between source and destination within deadline.",
                ),
            )

        # Compute final metrics
        total_fixed_cost = sum(
            network._get_fixed_cost(arc)
            * network._required_vehicles(arc, shipment.weight)
            for arc in route_arcs
        )
        total_var_cost = sum(arc.cost * shipment.weight for arc in route_arcs)
        total_cost = total_fixed_cost + total_var_cost

        total_fixed_emissions = sum(
            network._get_fixed_emissions(arc)
            * network._required_vehicles(arc, shipment.weight)
            for arc in route_arcs
        )
        total_var_emissions = sum(arc.emissions * shipment.weight for arc in route_arcs)
        total_emissions = total_fixed_emissions + total_var_emissions

        total_time = sum(arc.duration_min for arc in route_arcs)

        # Objective value (exact weighted combination)
        cost_scaled = (total_cost - bounds["cost"][0]) / ranges["cost"]
        time_scaled = (total_time - bounds["time"][0]) / ranges["time"]
        emissions_scaled = (total_emissions - bounds["emissions"][0]) / ranges[
            "emissions"
        ]
        weights = network.objective_weights_for(shipment, self.objective_weights)
        objective_value = (
            weights.cost * cost_scaled
            + weights.time * time_scaled
            + weights.emissions * emissions_scaled
        )

        return RoutingResult(
            status="Optimal",
            is_optimal=True,
            objective_value=objective_value,
            total_cost=total_cost,
            total_emissions=total_emissions,
            total_time=total_time,
            shipment_routes={shipment.id: tuple(route_arcs)},
            total_fixed_cost=total_fixed_cost,
            total_variable_cost=total_var_cost,
            total_fixed_emissions=total_fixed_emissions,
            total_variable_emissions=total_var_emissions,
        )

    def solve_multiple(
        self,
        network: TimeExpandedNetwork,
        show_progress: bool = False,
        progress_callback=None,
    ) -> RoutingResult:
        """Construct a feasible multi-shipment solution sequentially.

        Args:
            network: The pre-built TimeExpandedNetwork instance.
            show_progress: Optionally show a progress bar.
            progress_callback: Optional callback progress_callback(current, total, msg)

        Returns:
            A RoutingResult containing the consolidated routes and objective metrics.
        """
        shipments = network.shipments
        if not shipments:
            raise ValueError("solve_multiple() requires at least one shipment.")

        normalization = self._normalization_context(network, shipments)

        # Sort shipments by weight descending (heaviest first)
        sorted_shipments = sorted(shipments, key=lambda s: s.weight, reverse=True)

        # Track active vehicles and remaining capacities on each time-expanded arc
        capacity = self._empty_capacity_state(network)

        shipment_routes = {}
        diagnostics = []

        # Route each shipment sequentially
        shipment_iterable = sorted_shipments
        if show_progress:
            from tqdm import tqdm

            shipment_iterable = tqdm(sorted_shipments, desc="Routing shipments")

        for idx, shipment in enumerate(shipment_iterable):
            if progress_callback:
                progress_callback(
                    idx,
                    len(sorted_shipments),
                    f"Routing shipment '{shipment.id}' ({idx + 1}/{len(sorted_shipments)})",
                )
            route_arcs = self._find_shortest_path(
                network=network,
                shipment=shipment,
                capacity=capacity,
                normalization=normalization,
            )

            if route_arcs is None:
                diagnostics.append(f"Shipment {shipment.id}: No feasible path found.")
                continue

            self._reserve_route(network, route_arcs, shipment, capacity)
            shipment_routes[shipment.id] = tuple(route_arcs)

        return self._build_combined_result(
            network=network,
            shipment_routes=shipment_routes,
            active_vehicles=capacity.active_vehicles,
            shipments=shipments,
            normalization=normalization,
            diagnostics=diagnostics,
        )

    def optimize_multiple(
        self,
        initial_result: RoutingResult,
        network: TimeExpandedNetwork,
        iterations: int = 20,
        ruin_fraction: float = 0.2,
        seed: int | None = None,
        show_progress: bool = False,
        progress_callback=None,
    ) -> RoutingResult:
        """Optimizes an initial RoutingResult for multiple shipments using Ruin-and-Recreate (LNS).

        Args:
            initial_result: The initial RoutingResult to optimize.
            network: The pre-built TimeExpandedNetwork instance.
            iterations: Number of LNS iterations.
            ruin_fraction: Fraction of shipments to remove and reroute in each iteration.
            seed: Optional random seed for reproducibility.
            show_progress: Optionally show a progress bar.
            progress_callback: Optional callback progress_callback(current, total, msg)

        Returns:
            An optimized RoutingResult.
        """
        if iterations < 0:
            raise ValueError("iterations must not be negative.")
        if not 0.0 < ruin_fraction <= 1.0:
            raise ValueError("ruin_fraction must be in the interval (0, 1].")
        if initial_result.status == "Infeasible" or not initial_result.shipment_routes:
            return initial_result

        shipments = network.shipments
        normalization = self._normalization_context(network, shipments)
        rng = random.Random(seed)

        best_result = initial_result
        best_routes = dict(initial_result.shipment_routes)
        best_obj = (
            initial_result.objective_value
            if initial_result.objective_value is not None
            else math.inf
        )

        shipment_by_id = {s.id: s for s in shipments}
        num_to_ruin = max(1, int(len(shipments) * ruin_fraction))

        iterator = range(iterations)
        if show_progress:
            from tqdm import tqdm

            iterator = tqdm(iterator, desc="Optimizing routes (LNS)")

        for step in iterator:
            if progress_callback:
                progress_callback(
                    step, iterations, f"LNS Iteration {step + 1}/{iterations}"
                )
            # Choose shipments to ruin (remove)
            ruined_ids = rng.sample(
                list(best_routes.keys()), min(num_to_ruin, len(best_routes))
            )
            remaining_ids = [
                s_id for s_id in best_routes.keys() if s_id not in ruined_ids
            ]

            # Rebuild network state from remaining shipments' routes
            capacity = self._empty_capacity_state(network)

            for s_id in remaining_ids:
                shipment = shipment_by_id[s_id]
                self._reserve_route(network, best_routes[s_id], shipment, capacity)

            # Re-route the ruined shipments sequentially
            candidate_routes = {s_id: best_routes[s_id] for s_id in remaining_ids}
            ruined_shipments = [shipment_by_id[s_id] for s_id in ruined_ids]

            # Sort ruined shipments by weight descending
            ruined_shipments.sort(key=lambda s: s.weight, reverse=True)

            diagnostics = []
            routing_failed = False

            for shipment in ruined_shipments:
                route_arcs = self._find_shortest_path(
                    network=network,
                    shipment=shipment,
                    capacity=capacity,
                    normalization=normalization,
                )

                if route_arcs is None:
                    routing_failed = True
                    break

                self._reserve_route(network, route_arcs, shipment, capacity)
                candidate_routes[shipment.id] = tuple(route_arcs)

            if routing_failed:
                continue

            # Evaluate candidate solution
            candidate_result = self._build_combined_result(
                network=network,
                shipment_routes=candidate_routes,
                active_vehicles=capacity.active_vehicles,
                shipments=shipments,
                normalization=normalization,
                diagnostics=diagnostics,
            )

            # Accept if it covers at least as many shipments and has lower objective value
            if (
                len(candidate_routes) >= len(best_routes)
                and candidate_result.objective_value is not None
                and candidate_result.objective_value < best_obj
            ):
                best_result = candidate_result
                best_routes = candidate_routes
                best_obj = candidate_result.objective_value

        return best_result

    def _build_combined_result(
        self,
        network: TimeExpandedNetwork,
        shipment_routes: dict[str, tuple[_TimedArc, ...]],
        active_vehicles: list[int],
        shipments: list[Shipment],
        normalization: _NormalizationContext,
        diagnostics: list[str],
    ) -> RoutingResult:
        # Ensure diagnostics contains entries for all unrouted shipments
        for shipment in shipments:
            if shipment.id not in shipment_routes:
                msg = f"Shipment {shipment.id}: No feasible path found."
                if msg not in diagnostics:
                    diagnostics.append(msg)

        if not shipment_routes:
            return RoutingResult(
                status="Infeasible",
                is_optimal=False,
                objective_value=None,
                total_cost=0.0,
                total_emissions=0.0,
                total_time=0.0,
                shipment_routes={},
                diagnostics=tuple(diagnostics),
            )

        # Compute total fixed costs based on activated vehicles
        total_fixed_cost = sum(
            network._get_fixed_cost(arc) * active_vehicles[idx]
            for idx, arc in enumerate(network.all_arcs)
        )
        routed_shipments = [
            shipment for shipment in shipments if shipment.id in shipment_routes
        ]
        variable_cost_by_shipment = {
            shipment.id: sum(
                arc.cost * shipment.weight for arc in shipment_routes[shipment.id]
            )
            for shipment in routed_shipments
        }
        total_var_cost = sum(variable_cost_by_shipment.values())

        total_cost = total_fixed_cost + total_var_cost

        # Emissions
        total_fixed_emissions = sum(
            network._get_fixed_emissions(arc) * active_vehicles[idx]
            for idx, arc in enumerate(network.all_arcs)
        )
        variable_emissions_by_shipment = {
            shipment.id: sum(
                arc.emissions * shipment.weight for arc in shipment_routes[shipment.id]
            )
            for shipment in routed_shipments
        }
        total_var_emissions = sum(variable_emissions_by_shipment.values())

        total_emissions = total_fixed_emissions + total_var_emissions

        # Time is the sum of durations of all routes
        time_by_shipment = {
            shipment.id: sum(arc.duration_min for arc in shipment_routes[shipment.id])
            for shipment in routed_shipments
        }
        total_time = sum(time_by_shipment.values())

        # Objective value
        objective_value = (
            normalization.fixed_cost_coefficient * total_fixed_cost
            + normalization.fixed_emissions_coefficient * total_fixed_emissions
        )
        for shipment in routed_shipments:
            bounds = normalization.bounds[shipment.id]
            ranges = normalization.ranges[shipment.id]
            weights = network.objective_weights_for(shipment, self.objective_weights)
            objective_value += (
                weights.cost
                * (variable_cost_by_shipment[shipment.id] - bounds["cost"][0])
                / ranges["cost"]
                + weights.time
                * (time_by_shipment[shipment.id] - bounds["time"][0])
                / ranges["time"]
                + weights.emissions
                * (variable_emissions_by_shipment[shipment.id] - bounds["emissions"][0])
                / ranges["emissions"]
            )

        return RoutingResult(
            status="Feasible",
            is_optimal=False,
            objective_value=objective_value,
            total_cost=total_cost,
            total_emissions=total_emissions,
            total_time=total_time,
            shipment_routes=shipment_routes,
            total_fixed_cost=total_fixed_cost,
            total_variable_cost=total_var_cost,
            total_fixed_emissions=total_fixed_emissions,
            total_variable_emissions=total_var_emissions,
            diagnostics=tuple(diagnostics),
        )


class AStarRouter(DijkstraRouter):
    def __init__(self, objective_weights: ObjectiveWeights):
        super().__init__(objective_weights)
        self._heuristic_cache: dict[tuple, dict[str, float]] = {}
        self._heuristic_network_data: NetworkData | None = None

    def _heuristic_by_hub(
        self,
        network: TimeExpandedNetwork,
        shipment: Shipment,
        weights: ObjectiveWeights,
        ranges: dict[str, float],
    ) -> dict[str, float]:
        self._precompute_apsp(network)

        network_data = network.network_data
        if self._heuristic_network_data is not network_data:
            self._heuristic_cache.clear()
            self._heuristic_network_data = network_data

        cache_key = (
            shipment.end_hub,
            shipment.weight,
            weights.cost,
            weights.time,
            weights.emissions,
            ranges["cost"],
            ranges["time"],
            ranges["emissions"],
        )
        cached = self._heuristic_cache.get(cache_key)
        if cached is not None:
            return cached

        reverse_graph: dict[str, list[tuple[str, float]]] = defaultdict(list)
        for template in network_data.arc_templates:
            if not isinstance(template, TransportArcTemplate):
                continue
            factor = network_data.mode_factors[template.mode]
            cost = (
                template.cost
                if template.cost is not None
                else template.distance * factor.cost_per_ton_km
            )
            emissions = (
                template.emissions
                if template.emissions is not None
                else template.distance * factor.emissions_kg_per_ton_km
            )
            score = (
                weights.cost * cost * shipment.weight / ranges["cost"]
                + weights.time * template.duration_min / ranges["time"]
                + weights.emissions * emissions * shipment.weight / ranges["emissions"]
            )
            reverse_graph[template.to_hub].append((template.from_hub, score))

        distance = {shipment.end_hub: 0.0}
        queue = [(0.0, shipment.end_hub)]
        while queue:
            current_distance, hub = heapq.heappop(queue)
            if current_distance > distance.get(hub, math.inf):
                continue
            for previous_hub, score in reverse_graph.get(hub, []):
                candidate = current_distance + score
                if candidate >= distance.get(previous_hub, math.inf):
                    continue
                distance[previous_hub] = candidate
                heapq.heappush(queue, (candidate, previous_hub))

        self._heuristic_cache[cache_key] = distance
        return distance

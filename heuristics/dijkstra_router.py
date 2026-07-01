from __future__ import annotations

import heapq
import math
from collections import defaultdict

from freight_routing.data_models import (
    Shipment,
    ObjectiveWeights,
    RoutingResult,
    ArcType,
)
from freight_routing.model import TimeExpandedNetwork


class DijkstraRouter:
    def __init__(self, objective_weights: ObjectiveWeights):
        self.objective_weights = objective_weights

    def _find_shortest_path(
        self,
        network: TimeExpandedNetwork,
        shipment: Shipment,
        remaining_capacity: list[float] | None,
        active_vehicles: list[int] | None,
        arc_to_index: dict,
        adj: dict,
        c_diff: float,
        t_diff: float,
        e_diff: float,
    ) -> list | None:
        """Helper to run Dijkstra shortest-path search for a single shipment.

        Args:
            network: The time-expanded network.
            shipment: The shipment to route.
            remaining_capacity: List of remaining capacities per arc index (None if infinite/single routing).
            active_vehicles: List of active vehicle counts per arc index (None if infinite/single routing).
            arc_to_index: Mapping from arc objects to list index.
            adj: Adjacency list of outgoing arcs.
            c_diff, t_diff, e_diff: Normalization denominators.

        Returns:
            A list of Arc objects forming the path, or None if infeasible.
        """
        if remaining_capacity is None:
            remaining_capacity = [0.0] * len(network.all_arcs)
        if active_vehicles is None:
            active_vehicles = [0] * len(network.all_arcs)

        # Identify start and end nodes in the time-expanded graph
        start_nodes = {
            node
            for node in network.nodes
            if node.hub_id == shipment.start_hub
            and node.time_min == shipment.start_time
        }
        end_nodes = {
            node
            for node in network.nodes
            if node.hub_id == shipment.end_hub and node.time_min <= shipment.deadline
        }

        if not start_nodes or not end_nodes:
            return None

        # Define virtual Source and Sink states
        SOURCE = "SOURCE"
        SINK = "SINK"

        # Dijkstra states and priority queue setup
        counter = 0
        pq = [(0.0, counter, SOURCE)]
        dist = {SOURCE: 0.0}
        parent_arc = {}  # maps node -> (parent_node, arc)

        # Run Dijkstra shortest-path search
        while pq:
            d, _, u = heapq.heappop(pq)

            if d > dist.get(u, math.inf):
                continue

            if u == SINK:
                break

            # Transition from virtual SOURCE to actual time-expanded start nodes (cost = 0)
            if u == SOURCE:
                for v in start_nodes:
                    if 0.0 < dist.get(v, math.inf):
                        dist[v] = 0.0
                        parent_arc[v] = (SOURCE, None)
                        counter += 1
                        heapq.heappush(pq, (0.0, counter, v))
                continue

            # Transition from time-expanded end nodes to virtual SINK (cost = 0)
            if u in end_nodes:
                if d < dist.get(SINK, math.inf):
                    dist[SINK] = d
                    parent_arc[SINK] = (u, None)
                    counter += 1
                    heapq.heappush(pq, (d, counter, SINK))

            # Traverse normal outgoing edges
            for arc in adj.get(u, []):
                v = arc.to_node

                # Dynamically compute scaled arc score
                idx = arc_to_index[arc]
                if remaining_capacity[idx] >= shipment.weight:
                    needed = 0
                else:
                    needed = math.ceil(
                        (shipment.weight - remaining_capacity[idx])
                        / max(arc.capacity, 1e-9)
                    )

                # Enforce vehicle count bounds
                limit = arc.max_vehicles
                if limit is None:
                    if arc.arc_type == ArcType.TRANSPORT and arc.mode == "road":
                        limit = math.inf
                    else:
                        limit = 1

                if active_vehicles[idx] + needed > limit:
                    continue  # Exceeds the vehicle limit for this arc!

                if needed == 0:
                    c_fixed = 0.0
                    e_fixed = 0.0
                else:
                    c_fixed = network._get_fixed_cost(arc) * needed
                    e_fixed = network._get_fixed_emissions(arc) * needed

                c_var = arc.cost * shipment.weight
                c_total = c_fixed + c_var
                cost_scaled = c_total / c_diff

                t_total = arc.duration_min
                time_scaled = t_total / t_diff

                e_var = arc.emissions * shipment.weight
                e_total = e_fixed + e_var
                emissions_scaled = e_total / e_diff

                score = (
                    self.objective_weights.cost * cost_scaled
                    + self.objective_weights.time * time_scaled
                    + self.objective_weights.emissions * emissions_scaled
                )
                new_d = d + score

                if new_d < dist.get(v, math.inf):
                    dist[v] = new_d
                    parent_arc[v] = (u, arc)
                    counter += 1
                    heapq.heappush(pq, (new_d, counter, v))

        # Reconstruct route if a valid path was found
        if SINK not in parent_arc:
            return None

        route_arcs = []
        curr = SINK
        while curr != SOURCE:
            prev, arc = parent_arc[curr]
            if arc is not None:
                route_arcs.append(arc)
            curr = prev

        route_arcs.reverse()
        return route_arcs

    def solve(
        self,
        network: TimeExpandedNetwork,
    ) -> RoutingResult:
        """Solves the routing problem for a single shipment using Dijkstra's algorithm.

        Args:
            network: The pre-built TimeExpandedNetwork instance.

        Returns:
            A RoutingResult containing the optimal path and objective metrics.
        """
        shipment = network.shipments[0]

        # 2. Extract bounds for normalization
        bounds = network.estimate_normalization_bounds([shipment])
        c_min, c_max = bounds["cost"]
        t_min, t_max = bounds["time"]
        e_min, e_max = bounds["emissions"]

        c_diff = max(c_max - c_min, 1e-9)
        t_diff = max(t_max - t_min, 1e-9)
        e_diff = max(e_max - e_min, 1e-9)

        # 3. Adjacency list and index mapping
        adj = defaultdict(list)
        arc_to_index = {}
        for idx, arc in enumerate(network.all_arcs):
            adj[arc.from_node].append(arc)
            arc_to_index[arc] = idx

        # 4. Run Dijkstra helper
        route_arcs = self._find_shortest_path(
            network=network,
            shipment=shipment,
            remaining_capacity=None,
            active_vehicles=None,
            arc_to_index=arc_to_index,
            adj=adj,
            c_diff=c_diff,
            t_diff=t_diff,
            e_diff=e_diff,
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

        # 5. Compute final metrics
        total_fixed_cost = sum(network._get_fixed_cost(arc) for arc in route_arcs)
        total_var_cost = sum(arc.cost * shipment.weight for arc in route_arcs)
        total_cost = total_fixed_cost + total_var_cost

        total_fixed_emissions = sum(
            network._get_fixed_emissions(arc) for arc in route_arcs
        )
        total_var_emissions = sum(arc.emissions * shipment.weight for arc in route_arcs)
        total_emissions = total_fixed_emissions + total_var_emissions

        total_time = sum(arc.duration_min for arc in route_arcs)

        # Objective value (exact weighted combination)
        cost_scaled = (total_cost - c_min) / c_diff
        time_scaled = (total_time - t_min) / t_diff
        emissions_scaled = (total_emissions - e_min) / e_diff
        objective_value = (
            self.objective_weights.cost * cost_scaled
            + self.objective_weights.time * time_scaled
            + self.objective_weights.emissions * emissions_scaled
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
    ) -> RoutingResult:
        """Solves the routing problem for multiple shipments sequentially.

        Args:
            network: The pre-built TimeExpandedNetwork instance.
            show_progress: Optionally show a progress bar.

        Returns:
            A RoutingResult containing the consolidated routes and objective metrics.
        """
        shipments = network.shipments

        # 2. Extract bounds for normalization using all shipments
        bounds = network.estimate_normalization_bounds(shipments)
        c_min, c_max = bounds["cost"]
        t_min, t_max = bounds["time"]
        e_min, e_max = bounds["emissions"]
        c_diff = max(c_max - c_min, 1e-9)
        t_diff = max(t_max - t_min, 1e-9)
        e_diff = max(e_max - e_min, 1e-9)

        # 3. Adjacency list and indices
        adj = defaultdict(list)
        arc_to_index = {}
        for idx, arc in enumerate(network.all_arcs):
            adj[arc.from_node].append(arc)
            arc_to_index[arc] = idx

        # Sort shipments by weight descending (heaviest first)
        sorted_shipments = sorted(shipments, key=lambda s: s.weight, reverse=True)

        # Track active vehicles and remaining capacities on each time-expanded arc
        active_vehicles = [0] * len(network.all_arcs)
        remaining_capacity = [0.0] * len(network.all_arcs)

        shipment_routes = {}
        diagnostics = []

        # Route each shipment sequentially
        shipment_iterable = sorted_shipments
        if show_progress:
            from tqdm import tqdm

            shipment_iterable = tqdm(sorted_shipments, desc="Routing shipments")

        for shipment in shipment_iterable:
            route_arcs = self._find_shortest_path(
                network=network,
                shipment=shipment,
                remaining_capacity=remaining_capacity,
                active_vehicles=active_vehicles,
                arc_to_index=arc_to_index,
                adj=adj,
                c_diff=c_diff,
                t_diff=t_diff,
                e_diff=e_diff,
            )

            if route_arcs is None:
                diagnostics.append(f"Shipment {shipment.id}: No feasible path found.")
                continue

            # Update active vehicles and remaining capacities
            for arc in route_arcs:
                idx = arc_to_index[arc]
                if remaining_capacity[idx] >= shipment.weight:
                    remaining_capacity[idx] -= shipment.weight
                else:
                    needed = math.ceil(
                        (shipment.weight - remaining_capacity[idx])
                        / max(arc.capacity, 1e-9)
                    )
                    active_vehicles[idx] += needed
                    remaining_capacity[idx] = (
                        remaining_capacity[idx] + needed * arc.capacity
                    ) - shipment.weight

            shipment_routes[shipment.id] = tuple(route_arcs)

        return self._build_combined_result(
            network=network,
            shipment_routes=shipment_routes,
            active_vehicles=active_vehicles,
            shipments=shipments,
            c_min=c_min,
            c_diff=c_diff,
            t_min=t_min,
            t_diff=t_diff,
            e_min=e_min,
            e_diff=e_diff,
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
    ) -> RoutingResult:
        """Optimizes an initial RoutingResult for multiple shipments using Ruin-and-Recreate (LNS).

        Args:
            initial_result: The initial RoutingResult to optimize.
            network: The pre-built TimeExpandedNetwork instance.
            iterations: Number of LNS iterations.
            ruin_fraction: Fraction of shipments to remove and reroute in each iteration.
            seed: Optional random seed for reproducibility.
            show_progress: Optionally show a progress bar.

        Returns:
            An optimized RoutingResult.
        """
        if initial_result.status == "Infeasible" or not initial_result.shipment_routes:
            return initial_result

        import random

        if seed is not None:
            random.seed(seed)

        shipments = network.shipments

        # 2. Extract bounds for normalization
        bounds = network.estimate_normalization_bounds(shipments)
        c_min, c_max = bounds["cost"]
        t_min, t_max = bounds["time"]
        e_min, e_max = bounds["emissions"]
        c_diff = max(c_max - c_min, 1e-9)
        t_diff = max(t_max - t_min, 1e-9)
        e_diff = max(e_max - e_min, 1e-9)

        # 3. Adjacency list and indices
        adj = defaultdict(list)
        arc_to_index = {}
        for idx, arc in enumerate(network.all_arcs):
            adj[arc.from_node].append(arc)
            arc_to_index[arc] = idx

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

        for _ in iterator:
            # Choose shipments to ruin (remove)
            ruined_ids = random.sample(
                list(best_routes.keys()), min(num_to_ruin, len(best_routes))
            )
            remaining_ids = [
                s_id for s_id in best_routes.keys() if s_id not in ruined_ids
            ]

            # Rebuild network state from remaining shipments' routes
            active_vehicles = [0] * len(network.all_arcs)
            remaining_capacity = [0.0] * len(network.all_arcs)

            for s_id in remaining_ids:
                shipment = shipment_by_id[s_id]
                for arc in best_routes[s_id]:
                    idx = arc_to_index[arc]
                    if remaining_capacity[idx] >= shipment.weight:
                        remaining_capacity[idx] -= shipment.weight
                    else:
                        needed = math.ceil(
                            (shipment.weight - remaining_capacity[idx])
                            / max(arc.capacity, 1e-9)
                        )
                        active_vehicles[idx] += needed
                        remaining_capacity[idx] = (
                            remaining_capacity[idx] + needed * arc.capacity
                        ) - shipment.weight

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
                    remaining_capacity=remaining_capacity,
                    active_vehicles=active_vehicles,
                    arc_to_index=arc_to_index,
                    adj=adj,
                    c_diff=c_diff,
                    t_diff=t_diff,
                    e_diff=e_diff,
                )

                if route_arcs is None:
                    routing_failed = True
                    break

                # Update state
                for arc in route_arcs:
                    idx = arc_to_index[arc]
                    if remaining_capacity[idx] >= shipment.weight:
                        remaining_capacity[idx] -= shipment.weight
                    else:
                        needed = math.ceil(
                            (shipment.weight - remaining_capacity[idx])
                            / max(arc.capacity, 1e-9)
                        )
                        active_vehicles[idx] += needed
                        remaining_capacity[idx] = (
                            remaining_capacity[idx] + needed * arc.capacity
                        ) - shipment.weight

                candidate_routes[shipment.id] = tuple(route_arcs)

            if routing_failed:
                continue

            # Evaluate candidate solution
            candidate_result = self._build_combined_result(
                network=network,
                shipment_routes=candidate_routes,
                active_vehicles=active_vehicles,
                shipments=shipments,
                c_min=c_min,
                c_diff=c_diff,
                t_min=t_min,
                t_diff=t_diff,
                e_min=e_min,
                e_diff=e_diff,
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
        shipment_routes: dict[str, tuple],
        active_vehicles: list[int],
        shipments: list[Shipment],
        c_min: float,
        c_diff: float,
        t_min: float,
        t_diff: float,
        e_min: float,
        e_diff: float,
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
        total_var_cost = 0.0
        for shipment in shipments:
            if shipment.id in shipment_routes:
                total_var_cost += sum(
                    arc.cost * shipment.weight for arc in shipment_routes[shipment.id]
                )

        total_cost = total_fixed_cost + total_var_cost

        # Emissions
        total_fixed_emissions = sum(
            network._get_fixed_emissions(arc) * active_vehicles[idx]
            for idx, arc in enumerate(network.all_arcs)
        )
        total_var_emissions = 0.0
        for shipment in shipments:
            if shipment.id in shipment_routes:
                total_var_emissions += sum(
                    arc.emissions * shipment.weight
                    for arc in shipment_routes[shipment.id]
                )

        total_emissions = total_fixed_emissions + total_var_emissions

        # Time is the sum of durations of all routes
        total_time = sum(
            sum(arc.duration_min for arc in shipment_routes[s_id])
            for s_id in shipment_routes
        )

        # Objective value
        cost_scaled = (total_cost - c_min) / c_diff
        time_scaled = (total_time - t_min) / t_diff
        emissions_scaled = (total_emissions - e_min) / e_diff
        objective_value = (
            self.objective_weights.cost * cost_scaled
            + self.objective_weights.time * time_scaled
            + self.objective_weights.emissions * emissions_scaled
        )

        status = "Optimal" if len(shipment_routes) == len(shipments) else "Feasible"

        return RoutingResult(
            status=status,
            is_optimal=(status == "Optimal"),
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

from __future__ import annotations

import heapq
import math
from collections import defaultdict

from freight_routing.data_models import (
    NetworkData,
    Shipment,
    ObjectiveWeights,
    RoutingResult,
    ArcType,
)
from freight_routing.model import TimeExpandedFreightRoutingModel


class DijkstraRouter:
    def __init__(self, network_data: NetworkData, objective_weights: ObjectiveWeights):
        self.network_data = network_data
        self.objective_weights = objective_weights

    def solve(self, shipment: Shipment, planning_days: int = 7) -> RoutingResult:
        """Solves the routing problem for a single shipment using Dijkstra's algorithm.

        Args:
            shipment: The shipment to route.
            planning_days: The planning horizon in days.

        Returns:
            A RoutingResult containing the optimal path and objective metrics.
        """
        # Build the time-expanded graph using the model class
        model = TimeExpandedFreightRoutingModel(
            self.network_data, objective_weights=self.objective_weights
        )
        model.build(planning_days=planning_days, shipments=[shipment])

        # 2. Extract bounds for normalization
        bounds = model.estimate_normalization_bounds([shipment])
        c_min, c_max = bounds["cost"]
        t_min, t_max = bounds["time"]
        e_min, e_max = bounds["emissions"]

        # Divide-by-zero protection
        c_diff = max(c_max - c_min, 1e-9)
        t_diff = max(t_max - t_min, 1e-9)
        e_diff = max(e_max - e_min, 1e-9)

        # Identify start and end nodes in the time-expanded graph
        start_nodes = {
            node
            for node in model.nodes
            if node.hub_id == shipment.start_hub
            and node.time_min == shipment.start_time
        }
        end_nodes = {
            node
            for node in model.nodes
            if node.hub_id == shipment.end_hub and node.time_min <= shipment.deadline
        }

        if not start_nodes or not end_nodes:
            return RoutingResult(
                status="Infeasible",
                is_optimal=False,
                objective_value=None,
                total_cost=0.0,
                total_emissions=0.0,
                total_time=0.0,
                shipment_routes={},
                diagnostics=(
                    "No start or end nodes found in the time-expanded network.",
                ),
            )

        # Build adjacency list of outgoing arcs for each node
        adj = defaultdict(list)
        for arc in model.all_arcs:
            adj[arc.from_node].append(arc)

        # Define virtual Source and Sink states
        SOURCE = "SOURCE"
        SINK = "SINK"

        # Dijkstra states and priority queue setup
        # pq stores: (current_cumulative_score, tie_breaker_counter, current_node)
        counter = 0
        pq = [(0.0, counter, SOURCE)]
        dist = {SOURCE: 0.0}
        parent_arc = {}  # maps node -> (parent_node, arc)

        # Helper to compute normalized score of an arc
        def get_arc_score(arc) -> float:
            # Cost
            c_fixed = model._get_fixed_cost(arc)
            c_var = arc.cost * shipment.weight
            c_total = c_fixed + c_var
            cost_scaled = c_total / c_diff

            # Time
            t_total = arc.duration_min
            time_scaled = t_total / t_diff

            # Emissions
            e_fixed = model._get_fixed_emissions(arc)
            e_var = arc.emissions * shipment.weight
            e_total = e_fixed + e_var
            emissions_scaled = e_total / e_diff

            return (
                self.objective_weights.cost * cost_scaled
                + self.objective_weights.time * time_scaled
                + self.objective_weights.emissions * emissions_scaled
            )

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
                score = get_arc_score(arc)
                new_d = d + score

                if new_d < dist.get(v, math.inf):
                    dist[v] = new_d
                    parent_arc[v] = (u, arc)
                    counter += 1
                    heapq.heappush(pq, (new_d, counter, v))

        # 7. Reconstruct route if a valid path was found
        if SINK not in parent_arc:
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

        route_arcs = []
        curr = SINK
        while curr != SOURCE:
            prev, arc = parent_arc[curr]
            if arc is not None:
                route_arcs.append(arc)
            curr = prev

        route_arcs.reverse()

        # 8. Compute final metrics
        total_fixed_cost = sum(model._get_fixed_cost(arc) for arc in route_arcs)
        total_var_cost = sum(arc.cost * shipment.weight for arc in route_arcs)
        total_cost = total_fixed_cost + total_var_cost

        total_fixed_emissions = sum(
            model._get_fixed_emissions(arc) for arc in route_arcs
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

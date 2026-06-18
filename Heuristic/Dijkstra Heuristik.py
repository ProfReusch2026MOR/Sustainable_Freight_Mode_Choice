"""

Diese Version gibt gezielt vier Routentypen aus:

1. Route nach deiner Praeferenz
2. Kostenminimum
3. Zeitminimum
4. CO2-Minimum

Du musst nur den Bereich USER_INPUT anpassen.
Danach ausfuehren mit:

    python adaptive_multiobjective_astar_4routes.py
"""

from __future__ import annotations

import argparse
import heapq
import json
import math
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional, Any


# ============================================================
# 1) USER_INPUT: HIER AENDERST DU ROUTE UND PRAEFERENZEN
# ============================================================

USER_INPUT = {
    # Pfad zu deiner JSON-Datei
    "input_file": "multimodal_network.json",

    # Start- und Ziel-Hub
    # Beispiele:
    # "BER_3970" = Berlin Terminal
    # "HAM_3971" = Hamburg Terminal
    # "ROT_3146" = Rotterdam Terminal
    # "FRA_3974" = Frankfurt am Main Terminal
    # "NEW_283" = New York City Terminal
    # "SHA_2240" = Shanghai Terminal
    "start_hub": "NEW_283",
    "end_hub": "SHA_2240",

    # Sendungsgewicht in Tonnen
    "shipment_weight_tons": 2.0,

    # ------------------------------------------------------------
    # DEINE INDIVIDUELLE PRAEFERENZ
    # ------------------------------------------------------------
    # Hier bestimmst du, was dir bei der ersten Route wichtig ist.
    #
    # Beispiel:
    # Kosten = 0.20
    # Zeit   = 0.20
    # CO2    = 0.80
    #
    # Die Summe muss nicht genau 1.0 sein.
    # Der Code normalisiert die Werte automatisch.
    "preference_cost": 0.50,
    "preference_time": 0.30,
    "preference_co2": 0.20,

    # Strafwert fuer Verkehrsmittelwechsel.
    # Hoeherer Wert = weniger Wechsel zwischen road, rail, air, ship.
    "preference_mode_change": 0.03,

    # Maximale Anzahl expandierter Zustaende.
    # Wenn keine Route gefunden wird, Wert erhoehen.
    "max_expansions": 200_000,

    # Optional: Verkehrsmittel erlauben.
    # Leere Liste bedeutet: alle Modi erlaubt.
    # Beispiel:
    # "allowed_modes": ["road", "rail", "ship"]
    "allowed_modes": [],

    # Optional: Verkehrsmittel verbieten.
    # Beispiel:
    # "forbidden_modes": ["air"]
    "forbidden_modes": [],

    # Soll eine Liste verfuegbarer Hubs ausgegeben werden?
    "show_available_hubs": False,

    # Suchbegriff fuer Hubs, z.B. "Hamburg", "Berlin", "Rotterdam".
    # Nur relevant, wenn show_available_hubs=True.
    "hub_search_term": "",
}


# ============================================================
# 2) ALGORITHMUS
#    Darunter musst du normalerweise nichts mehr aendern.
# ============================================================

@dataclass(frozen=True)
class Edge:
    source: str
    target: str
    mode: str
    distance_km: float
    duration_min: float
    cost: float
    emissions: float
    arc_id: str


@dataclass
class RouteResult:
    route_type: str
    path: List[str]
    edges: List[Edge]
    total_cost: float
    total_time_min: float
    total_emissions: float
    total_distance_km: float
    score: float
    weights: Dict[str, float]

    def modes(self) -> List[str]:
        return [e.mode for e in self.edges]

    def mode_changes(self) -> int:
        m = self.modes()
        return sum(1 for i in range(1, len(m)) if m[i] != m[i - 1])


def normalize_preferences(cost: float, time: float, co2: float) -> Tuple[float, float, float]:
    total = cost + time + co2
    if total <= 0:
        raise ValueError("Die Summe aus preference_cost, preference_time und preference_co2 muss groesser als 0 sein.")
    return cost / total, time / total, co2 / total


def build_four_weight_sets() -> List[Dict[str, float]]:
    """
    Erstellt genau vier Gewichtungen:
    1. individuelle Praeferenz
    2. Kostenminimum
    3. Zeitminimum
    4. CO2-Minimum
    """
    pc, pt, pe = normalize_preferences(
        float(USER_INPUT["preference_cost"]),
        float(USER_INPUT["preference_time"]),
        float(USER_INPUT["preference_co2"]),
    )

    mode_change = float(USER_INPUT["preference_mode_change"])

    return [
        {
            "name": "Deine Praeferenz",
            "cost": pc,
            "time": pt,
            "emissions": pe,
            "mode_change": mode_change,
        },
        {
            "name": "Kostenminimum",
            "cost": 1.0,
            "time": 0.0,
            "emissions": 0.0,
            "mode_change": mode_change,
        },
        {
            "name": "Zeitminimum",
            "cost": 0.0,
            "time": 1.0,
            "emissions": 0.0,
            "mode_change": mode_change,
        },
        {
            "name": "CO2-Minimum",
            "cost": 0.0,
            "time": 0.0,
            "emissions": 1.0,
            "mode_change": mode_change,
        },
    ]


def list_available_hubs(data: Dict[str, Any], search_term: str = "", limit: int = 80) -> None:
    hubs = data.get("hubs", [])
    term = search_term.lower().strip()

    if term:
        hubs = [
            h for h in hubs
            if term in h.get("name", "").lower() or term in h.get("id", "").lower()
        ]

    print("\nVerfuegbare Hubs")
    print("-" * 70)

    for h in hubs[:limit]:
        modes = ", ".join(h.get("supported_modes", []))
        print(f"{h.get('id')} = {h.get('name')} | Modi: {modes}")

    if len(hubs) > limit:
        print(f"... {len(hubs) - limit} weitere Hubs nicht angezeigt.")


def load_network(
    path: str,
    shipment_weight_tons: float,
    allowed_modes: Optional[List[str]] = None,
    forbidden_modes: Optional[List[str]] = None,
) -> Tuple[Dict[str, Any], Dict[str, List[Edge]]]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    allowed = set(allowed_modes or [])
    forbidden = set(forbidden_modes or [])

    factors = data.get("mode_factors", {})
    graph: Dict[str, List[Edge]] = {}

    # Alle Hubs aufnehmen, auch wenn sie keine ausgehenden Kanten haben.
    for hub in data.get("hubs", []):
        hub_id = hub.get("id")
        if hub_id:
            graph.setdefault(hub_id, [])

    for arc in data.get("arc_templates", []):
        mode = arc.get("mode")

        if mode not in factors:
            continue
        if allowed and mode not in allowed:
            continue
        if mode in forbidden:
            continue

        source = arc.get("from")
        target = arc.get("to")

        if not source or not target:
            continue

        distance = float(arc.get("dist", 0.0))
        duration = float(arc.get("duration_min", 0.0))

        cost = distance * float(factors[mode]["cost_per_ton_km"]) * shipment_weight_tons
        emissions = distance * float(factors[mode]["emissions_kg_per_ton_km"]) * shipment_weight_tons

        edge = Edge(
            source=source,
            target=target,
            mode=mode,
            distance_km=distance,
            duration_min=duration,
            cost=cost,
            emissions=emissions,
            arc_id=arc.get("id", f"{source}_{target}_{mode}"),
        )

        graph.setdefault(source, []).append(edge)
        graph.setdefault(target, [])

    return data, graph


def estimate_scales(graph: Dict[str, List[Edge]]) -> Dict[str, float]:
    """
    Skalen dienen dazu, Kosten, Zeit und CO2 vergleichbar zu machen.
    Ohne Normalisierung wuerde z.B. Kosten wegen groesserer Zahlenwerte dominieren.
    """
    edges = [edge for edge_list in graph.values() for edge in edge_list]

    if not edges:
        return {"cost": 1.0, "time": 1.0, "emissions": 1.0}

    avg_cost = sum(e.cost for e in edges) / len(edges)
    avg_time = sum(e.duration_min for e in edges) / len(edges)
    avg_emissions = sum(e.emissions for e in edges) / len(edges)

    return {
        "cost": max(avg_cost, 1e-9),
        "time": max(avg_time, 1e-9),
        "emissions": max(avg_emissions, 1e-9),
    }


def normalize(value: float, scale: float) -> float:
    if scale <= 0:
        return value
    return value / scale


def edge_score(
    edge: Edge,
    weights: Dict[str, float],
    scales: Dict[str, float],
    previous_mode: Optional[str],
) -> float:
    mode_change_penalty = 1.0 if previous_mode is not None and previous_mode != edge.mode else 0.0

    return (
        weights["cost"] * normalize(edge.cost, scales["cost"])
        + weights["time"] * normalize(edge.duration_min, scales["time"])
        + weights["emissions"] * normalize(edge.emissions, scales["emissions"])
        + weights.get("mode_change", 0.0) * mode_change_penalty
    )


def astar_multimodal(
    graph: Dict[str, List[Edge]],
    start: str,
    goal: str,
    weights: Dict[str, float],
    scales: Dict[str, float],
    max_expansions: int,
) -> Optional[RouteResult]:


    def heuristic(_: str) -> float:
        return 0.0

    start_state = (start, None)

    dist: Dict[Tuple[str, Optional[str]], float] = {start_state: 0.0}
    parent: Dict[Tuple[str, Optional[str]], Tuple[Tuple[str, Optional[str]], Edge]] = {}

    pq: List[Tuple[float, float, str, Optional[str]]] = []
    heapq.heappush(pq, (heuristic(start), 0.0, start, None))

    best_goal_state: Optional[Tuple[str, Optional[str]]] = None
    expansions = 0

    while pq and expansions < max_expansions:
        _, current_g, node, prev_mode = heapq.heappop(pq)
        state = (node, prev_mode)

        if current_g > dist.get(state, math.inf):
            continue

        if node == goal:
            best_goal_state = state
            break

        expansions += 1

        for edge in graph.get(node, []):
            step = edge_score(edge, weights, scales, prev_mode)
            new_state = (edge.target, edge.mode)
            new_g = current_g + step

            if new_g < dist.get(new_state, math.inf):
                dist[new_state] = new_g
                parent[new_state] = (state, edge)

                f = new_g + heuristic(edge.target)
                heapq.heappush(pq, (f, new_g, edge.target, edge.mode))

    if best_goal_state is None:
        return None

    edges: List[Edge] = []
    state = best_goal_state

    while state != start_state:
        previous_state, edge = parent[state]
        edges.append(edge)
        state = previous_state

    edges.reverse()
    path = [start] + [e.target for e in edges]

    return RouteResult(
        route_type=str(weights["name"]),
        path=path,
        edges=edges,
        total_cost=sum(e.cost for e in edges),
        total_time_min=sum(e.duration_min for e in edges),
        total_emissions=sum(e.emissions for e in edges),
        total_distance_km=sum(e.distance_km for e in edges),
        score=dist[best_goal_state],
        weights=weights,
    )


def improve_route_by_shortcuts(
    route: RouteResult,
    graph: Dict[str, List[Edge]],
    weights: Dict[str, float],
    scales: Dict[str, float],
) -> RouteResult:
    """
    Lokale Verbesserung:
    Wenn zwei aufeinanderfolgende Kanten A -> B -> C durch eine direkte
    Kante A -> C mit besserem Score ersetzt werden koennen, wird gekuerzt.
    """
    improved_edges = route.edges[:]
    changed = True

    while changed:
        changed = False
        i = 0

        while i < len(improved_edges) - 1:
            a = improved_edges[i].source
            c = improved_edges[i + 1].target
            prev_mode = improved_edges[i - 1].mode if i > 0 else None

            direct_edges = [e for e in graph.get(a, []) if e.target == c]

            if not direct_edges:
                i += 1
                continue

            old_score = (
                edge_score(improved_edges[i], weights, scales, prev_mode)
                + edge_score(improved_edges[i + 1], weights, scales, improved_edges[i].mode)
            )

            best_direct = min(
                direct_edges,
                key=lambda e: edge_score(e, weights, scales, prev_mode),
            )
            new_score = edge_score(best_direct, weights, scales, prev_mode)

            if new_score < old_score:
                improved_edges[i:i + 2] = [best_direct]
                changed = True
            else:
                i += 1

    path = [improved_edges[0].source] + [e.target for e in improved_edges] if improved_edges else route.path

    return RouteResult(
        route_type=route.route_type,
        path=path,
        edges=improved_edges,
        total_cost=sum(e.cost for e in improved_edges),
        total_time_min=sum(e.duration_min for e in improved_edges),
        total_emissions=sum(e.emissions for e in improved_edges),
        total_distance_km=sum(e.distance_km for e in improved_edges),
        score=sum(
            edge_score(e, weights, scales, improved_edges[i - 1].mode if i > 0 else None)
            for i, e in enumerate(improved_edges)
        ),
        weights=weights,
    )


def calculate_four_routes(
    graph: Dict[str, List[Edge]],
    start: str,
    goal: str,
    max_expansions: int,
) -> List[RouteResult]:
    scales = estimate_scales(graph)
    weight_sets = build_four_weight_sets()

    routes: List[RouteResult] = []

    for weights in weight_sets:
        result = astar_multimodal(
            graph=graph,
            start=start,
            goal=goal,
            weights=weights,
            scales=scales,
            max_expansions=max_expansions,
        )

        if result is not None:
            improved = improve_route_by_shortcuts(result, graph, weights, scales)
            routes.append(improved)

    return routes


def print_route(route: RouteResult, rank: int) -> None:
    print("\n" + "=" * 70)
    print(f"ROUTE {rank}: {route.route_type}")
    print("=" * 70)

    print("Pfad:       " + " -> ".join(route.path))
    print("Modi:       " + " -> ".join(route.modes()))

    print(f"Kosten:     {route.total_cost:,.2f}")
    print(f"Zeit:       {route.total_time_min / 60:,.2f} Stunden")
    print(f"Emissionen: {route.total_emissions:,.2f} kg CO2")
    print(f"Distanz:    {route.total_distance_km:,.2f} km")
    print(f"Wechsel:    {route.mode_changes()}")
    print(f"Score:      {route.score:.4f}")

    print("\nTeilstrecken:")
    for i, edge in enumerate(route.edges, start=1):
        print(
            f"{i:02d}. {edge.source} -> {edge.target} | "
            f"{edge.mode} | "
            f"{edge.distance_km:,.1f} km | "
            f"{edge.duration_min / 60:,.2f} h | "
            f"Kosten {edge.cost:,.2f} | "
            f"CO2 {edge.emissions:,.2f} kg"
        )


def print_comparison_table(routes: List[RouteResult]) -> None:
    print("\n" + "=" * 70)
    print("VERGLEICH DER ROUTEN")
    print("=" * 70)

    header = f"{'Route':<22} {'Kosten':>12} {'Zeit h':>12} {'CO2 kg':>12} {'Distanz':>12} {'Wechsel':>8}"
    print(header)
    print("-" * len(header))

    for route in routes:
        print(
            f"{route.route_type:<22} "
            f"{route.total_cost:>12,.2f} "
            f"{route.total_time_min / 60:>12,.2f} "
            f"{route.total_emissions:>12,.2f} "
            f"{route.total_distance_km:>12,.2f} "
            f"{route.mode_changes():>8}"
        )


def remove_duplicate_routes_keep_type(routes: List[RouteResult]) -> List[RouteResult]:
    """
    Wenn z.B. Kostenminimum und CO2-Minimum dieselbe Route ergeben,
    werden beide trotzdem nicht komplett geloescht.
    Stattdessen bleibt nur eine Ausgabe mit kombiniertem Namen.
    """
    grouped: Dict[Tuple[str, ...], RouteResult] = {}

    for route in routes:
        key = tuple(route.path)

        if key not in grouped:
            grouped[key] = route
        else:
            grouped[key].route_type += " / " + route.route_type

    return list(grouped.values())


def main() -> None:
    parser = argparse.ArgumentParser()

    parser.add_argument("--input", default=None, help="Pfad zur JSON-Datei")
    parser.add_argument("--start", default=None, help="Start-Hub-ID")
    parser.add_argument("--end", default=None, help="Ziel-Hub-ID")
    parser.add_argument("--weight", type=float, default=None, help="Sendungsgewicht in Tonnen")
    parser.add_argument("--max-expansions", type=int, default=None)
    parser.add_argument("--list-hubs", action="store_true", help="Verfuegbare Hubs ausgeben")
    parser.add_argument("--search-hub", default=None, help="Suchbegriff fuer Hubs")

    args = parser.parse_args()

    input_file = args.input or USER_INPUT["input_file"]
    start = args.start or USER_INPUT["start_hub"]
    end = args.end or USER_INPUT["end_hub"]
    shipment_weight = args.weight if args.weight is not None else float(USER_INPUT["shipment_weight_tons"])
    max_expansions = args.max_expansions if args.max_expansions is not None else int(USER_INPUT["max_expansions"])

    data, graph = load_network(
        path=input_file,
        shipment_weight_tons=shipment_weight,
        allowed_modes=USER_INPUT["allowed_modes"],
        forbidden_modes=USER_INPUT["forbidden_modes"],
    )

    if args.list_hubs or USER_INPUT["show_available_hubs"]:
        search_term = args.search_hub if args.search_hub is not None else USER_INPUT["hub_search_term"]
        list_available_hubs(data, search_term=search_term)
        return

    if not start or not end:
        raise ValueError("Bitte start_hub und end_hub im USER_INPUT setzen oder per --start und --end angeben.")

    if start not in graph:
        raise ValueError(f"Start-Hub {start} ist nicht im Graphen enthalten.")

    if end not in graph:
        raise ValueError(f"Ziel-Hub {end} ist nicht im Graphen enthalten.")

    routes = calculate_four_routes(
        graph=graph,
        start=start,
        goal=end,
        max_expansions=max_expansions,
    )

    print("\nDijkstra Heuristik")
    print("=" * 70)
    print(f"Input-Datei:     {input_file}")
    print(f"Start:           {start}")
    print(f"Ziel:            {end}")
    print(f"Gewicht:         {shipment_weight} t")
    print(f"Erlaubte Modi:   {USER_INPUT['allowed_modes'] or 'alle'}")
    print(f"Verbotene Modi:  {USER_INPUT['forbidden_modes'] or 'keine'}")
    print(f"Praeferenz:      Kosten={USER_INPUT['preference_cost']}, "
          f"Zeit={USER_INPUT['preference_time']}, "
          f"CO2={USER_INPUT['preference_co2']}")

    if not routes:
        print("\nKeine Route gefunden.")
        print("Pruefe Start/Ziel, Modi-Filter und max_expansions.")
        return

    # Duplikate zusammenfassen, falls mehrere Ziele dieselbe Route ergeben.
    routes = remove_duplicate_routes_keep_type(routes)

    print_comparison_table(routes)

    for i, route in enumerate(routes, start=1):
        print_route(route, i)


if __name__ == "__main__":
    main()

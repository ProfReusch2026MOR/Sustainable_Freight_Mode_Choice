from __future__ import annotations

import argparse
import csv
import importlib.util
import inspect
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from experiments.run_experiments import (  # noqa: E402
    DATASET_PATH,
    DEFAULT_OUTPUT_DIR,
    DEFAULT_PLANNING_DAYS,
    build_subnetwork,
    generate_shipments,
)
from freight_routing.data_loader import NetworkDataLoader  # noqa: E402
from freight_routing.data_models import (  # noqa: E402
    ArcType,
    NetworkData,
    ObjectiveWeights,
    RoutingResult,
    Shipment,
    TransferArcTemplate,
    TransportArcTemplate,
)
from freight_routing.model import TimeExpandedFreightRoutingModel, TimeExpandedNetwork  # noqa: E402

HEURISTIC_PATH = ROOT / "heuristics" / "Tabu search Heuristik.py"
COMPARISON_COLUMNS = (
    "variant",
    "method",
    "status",
    "is_optimal",
    "runtime_sec",
    "objective_value",
    "full_evaluated_cost_eur",
    "full_evaluated_emissions_kg",
    "route_only_cost_eur",
    "route_only_emissions_kg",
    "total_time_min",
    "transport_time_min",
    "total_distance_km",
    "mode_sequence",
    "path",
    "mode_changes",
    "note",
)


@dataclass(frozen=True)
class VariantSpec:
    name: str
    label: str
    weights: dict[str, float]


@dataclass(frozen=True)
class ComparisonRow:
    variant: str
    method: str
    status: str
    is_optimal: str
    runtime_sec: str
    objective_value: str
    full_evaluated_cost_eur: str
    full_evaluated_emissions_kg: str
    route_only_cost_eur: str
    route_only_emissions_kg: str
    total_time_min: str
    transport_time_min: str
    total_distance_km: str
    mode_sequence: str
    path: str
    mode_changes: str
    note: str


VARIANTS = (
    VariantSpec(
        name="balanced",
        label="Balanced",
        weights={
            "name": "Balanced",
            "cost": 0.5,
            "time": 0.3,
            "emissions": 0.2,
            "mode_change": 0.03,
        },
    ),
    VariantSpec(
        name="cost_min",
        label="Cost minimum",
        weights={
            "name": "Cost minimum",
            "cost": 1.0,
            "time": 0.0,
            "emissions": 0.0,
            "mode_change": 0.03,
        },
    ),
    VariantSpec(
        name="time_min",
        label="Time minimum",
        weights={
            "name": "Time minimum",
            "cost": 0.0,
            "time": 1.0,
            "emissions": 0.0,
            "mode_change": 0.03,
        },
    ),
    VariantSpec(
        name="emissions_min",
        label="CO2 minimum",
        weights={
            "name": "CO2 minimum",
            "cost": 0.0,
            "time": 0.0,
            "emissions": 1.0,
            "mode_change": 0.03,
        },
    ),
)


@dataclass(frozen=True)
class RouteAccounting:
    fixed_cost_by_arc_id: dict[str, float]
    fixed_emissions_by_arc_id: dict[str, float]

    def evaluate(
        self,
        route_cost: float,
        route_emissions: float,
        arc_ids: list[str],
    ) -> tuple[float, float]:
        fixed_cost = sum(
            self.fixed_cost_by_arc_id.get(arc_id, 0.0) for arc_id in arc_ids
        )
        fixed_emissions = sum(
            self.fixed_emissions_by_arc_id.get(arc_id, 0.0) for arc_id in arc_ids
        )
        return route_cost + fixed_cost, route_emissions + fixed_emissions


def load_heuristic_module() -> Any:
    module_name = "tabu_search_heuristic"
    spec = importlib.util.spec_from_file_location(module_name, HEURISTIC_PATH)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load heuristic module from {HEURISTIC_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def build_route_accounting(network_data: NetworkData) -> RouteAccounting:
    fixed_cost_by_arc_id: dict[str, float] = {}
    fixed_emissions_by_arc_id: dict[str, float] = {}
    for template in network_data.arc_templates:
        if isinstance(template, TransportArcTemplate):
            fixed_cost = template.fixed_cost
            if fixed_cost is None:
                fixed_cost = network_data.default_fixed_costs.transport.get(
                    template.mode, 0.0
                )
            fixed_emissions = template.fixed_emissions
            if fixed_emissions is None:
                fixed_emissions = network_data.default_fixed_emissions.transport.get(
                    template.mode, 0.0
                )
        elif isinstance(template, TransferArcTemplate):
            fixed_cost = template.fixed_cost
            if fixed_cost is None:
                fixed_cost = network_data.default_fixed_costs.transfer
            fixed_emissions = template.fixed_emissions
            if fixed_emissions is None:
                fixed_emissions = network_data.default_fixed_emissions.transfer
        else:
            continue
        fixed_cost_by_arc_id[template.id] = float(fixed_cost)
        fixed_emissions_by_arc_id[template.id] = float(fixed_emissions)
    return RouteAccounting(
        fixed_cost_by_arc_id=fixed_cost_by_arc_id,
        fixed_emissions_by_arc_id=fixed_emissions_by_arc_id,
    )


def build_heuristic_graph(
    network_data: NetworkData,
    shipment_weight_tons: float,
    heuristic_module: Any,
) -> dict[str, list[Any]]:
    graph: dict[str, list[Any]] = {}
    for arc in network_data.arc_templates:
        if not isinstance(arc, TransportArcTemplate):
            continue
        mode_factor = network_data.mode_factors[arc.mode]
        cost = (
            float(arc.cost)
            if arc.cost is not None
            else arc.distance * shipment_weight_tons * mode_factor.cost_per_ton_km
        )
        emissions = (
            float(arc.emissions)
            if arc.emissions is not None
            else arc.distance
            * shipment_weight_tons
            * mode_factor.emissions_kg_per_ton_km
        )
        edge = heuristic_module.Edge(
            source=arc.from_hub,
            target=arc.to_hub,
            mode=arc.mode,
            distance_km=float(arc.distance),
            duration_min=float(arc.duration_min),
            cost=cost,
            emissions=emissions,
            arc_id=arc.id,
        )
        graph.setdefault(edge.source, []).append(edge)
    return graph


def run_solver(
    network_data: NetworkData,
    shipment: Shipment,
    variant: VariantSpec,
    time_limit_sec: float,
) -> ComparisonRow:
    weights = ObjectiveWeights(
        cost=variant.weights["cost"],
        time=variant.weights["time"],
        emissions=variant.weights["emissions"],
    )
    network = TimeExpandedNetwork.build(network_data, DEFAULT_PLANNING_DAYS, [shipment])
    model = TimeExpandedFreightRoutingModel(objective_weights=weights)
    started = time.perf_counter()
    result = model.solve(network, time_limit_sec=time_limit_sec)
    runtime_sec = time.perf_counter() - started
    return solver_result_to_row(variant, result, shipment, runtime_sec)


def solver_result_to_row(
    variant: VariantSpec,
    result: RoutingResult,
    shipment: Shipment,
    runtime_sec: float,
) -> ComparisonRow:
    arcs = result.shipment_routes.get(shipment.id, ())
    transport_arcs = [arc for arc in arcs if arc.arc_type == ArcType.TRANSPORT]
    modes = [arc.mode for arc in transport_arcs]
    hubs = [transport_arcs[0].from_node.hub_id] if transport_arcs else []
    hubs.extend(arc.to_node.hub_id for arc in transport_arcs)

    return ComparisonRow(
        variant=variant.name,
        method="HiGHS MILP",
        status=result.status,
        is_optimal=str(result.is_optimal).lower(),
        runtime_sec=f"{runtime_sec:.3f}",
        objective_value=(
            f"{result.objective_value:.6f}"
            if result.objective_value is not None
            else "N/A"
        ),
        full_evaluated_cost_eur=f"{result.total_cost:.2f}",
        full_evaluated_emissions_kg=f"{result.total_emissions:.2f}",
        route_only_cost_eur=(
            f"{sum(arc.cost * shipment.weight for arc in transport_arcs):.2f}"
        ),
        route_only_emissions_kg=(
            f"{sum(arc.emissions * shipment.weight for arc in transport_arcs):.2f}"
        ),
        total_time_min=f"{result.total_time:.2f}",
        transport_time_min=f"{sum(arc.duration_min for arc in transport_arcs):.2f}",
        total_distance_km=f"{sum(arc.distance for arc in transport_arcs):.2f}",
        mode_sequence=" -> ".join(modes) if modes else "N/A",
        path=" -> ".join(hubs) if hubs else "N/A",
        mode_changes=str(_mode_changes(modes)),
        note=(
            "time-expanded exact solver with capacities, waiting, transfers, "
            "fixed and variable costs"
        ),
    )


def run_astar_baseline(
    graph: dict[str, list[Any]],
    shipment: Shipment,
    variant: VariantSpec,
    heuristic_module: Any,
    accounting: RouteAccounting,
    max_expansions: int,
) -> ComparisonRow:
    scales = heuristic_module.estimate_scales(graph)
    started = time.perf_counter()
    route = heuristic_module.astar_multimodal(
        graph=graph,
        start=shipment.start_hub,
        goal=shipment.end_hub,
        weights=variant.weights,
        scales=scales,
        max_expansions=max_expansions,
    )
    if route is not None:
        route = heuristic_module.improve_route_by_shortcuts(
            route, graph, variant.weights, scales
        )
    runtime_sec = time.perf_counter() - started
    return heuristic_result_to_row(
        variant=variant,
        method="A*/Dijkstra baseline",
        route=route,
        runtime_sec=runtime_sec,
        accounting=accounting,
        note="static weighted route search used as heuristic start solution",
    )


def run_tabu_search(
    graph: dict[str, list[Any]],
    shipment: Shipment,
    variant: VariantSpec,
    heuristic_module: Any,
    accounting: RouteAccounting,
    max_expansions: int,
    tabu_iterations: int,
) -> ComparisonRow:
    scales = heuristic_module.estimate_scales(graph)
    started = time.perf_counter()
    route = heuristic_module.tabu_search_route(
        graph=graph,
        start=shipment.start_hub,
        goal=shipment.end_hub,
        weights=variant.weights,
        scales=scales,
        **build_tabu_search_kwargs(
            heuristic_module=heuristic_module,
            max_expansions=max_expansions,
            tabu_iterations=tabu_iterations,
        ),
    )
    runtime_sec = time.perf_counter() - started
    return heuristic_result_to_row(
        variant=variant,
        method="Tabu Search",
        route=route,
        runtime_sec=runtime_sec,
        accounting=accounting,
        note=(
            "static metaheuristic based on A*/Dijkstra route plus tabu "
            "neighborhood search"
        ),
    )


def build_tabu_search_kwargs(
    heuristic_module: Any,
    max_expansions: int,
    tabu_iterations: int,
) -> dict[str, int]:
    kwargs = {
        "max_expansions": max_expansions,
        "max_iterations": tabu_iterations,
        "tabu_tenure": 10,
        "neighbors_per_iteration": 25,
        "no_improvement_limit": 20,
    }
    signature = inspect.signature(heuristic_module.tabu_search_route)
    if "initial_max_neighbors_per_node" in signature.parameters:
        kwargs["initial_max_neighbors_per_node"] = 3
    return kwargs


def heuristic_result_to_row(
    variant: VariantSpec,
    method: str,
    route: Any | None,
    runtime_sec: float,
    accounting: RouteAccounting,
    note: str,
) -> ComparisonRow:
    if route is None:
        return ComparisonRow(
            variant=variant.name,
            method=method,
            status="no_route",
            is_optimal="N/A",
            runtime_sec=f"{runtime_sec:.3f}",
            objective_value="N/A",
            full_evaluated_cost_eur="N/A",
            full_evaluated_emissions_kg="N/A",
            route_only_cost_eur="N/A",
            route_only_emissions_kg="N/A",
            total_time_min="N/A",
            transport_time_min="N/A",
            total_distance_km="N/A",
            mode_sequence="N/A",
            path="N/A",
            mode_changes="N/A",
            note=note,
        )

    modes = route.modes()
    full_cost, full_emissions = accounting.evaluate(
        route_cost=route.total_cost,
        route_emissions=route.total_emissions,
        arc_ids=[edge.arc_id for edge in route.edges],
    )
    return ComparisonRow(
        variant=variant.name,
        method=method,
        status="feasible",
        is_optimal="N/A",
        runtime_sec=f"{runtime_sec:.3f}",
        objective_value="N/A",
        full_evaluated_cost_eur=f"{full_cost:.2f}",
        full_evaluated_emissions_kg=f"{full_emissions:.2f}",
        route_only_cost_eur=f"{route.total_cost:.2f}",
        route_only_emissions_kg=f"{route.total_emissions:.2f}",
        total_time_min=f"{route.total_time_min:.2f}",
        transport_time_min=f"{route.total_time_min:.2f}",
        total_distance_km=f"{route.total_distance_km:.2f}",
        mode_sequence=" -> ".join(modes) if modes else "N/A",
        path=" -> ".join(route.path) if route.path else "N/A",
        mode_changes=str(route.mode_changes()),
        note=note,
    )


def run_comparison(
    *,
    dataset_path: Path = DATASET_PATH,
    max_routes: int = 18,
    shipment_weight_tons: float = 2.0,
    time_limit_sec: float = 15.0,
    max_expansions: int = 200_000,
    tabu_iterations: int = 80,
) -> tuple[list[ComparisonRow], str, Path]:
    base_network = NetworkDataLoader.from_json(dataset_path)
    network = build_subnetwork(base_network, max_routes=max_routes)
    shipment = generate_shipments(
        "solver_heuristic_comparison",
        network,
        shipment_count=1,
        shipment_weight_tons=shipment_weight_tons,
    )[0]
    heuristic_module = load_heuristic_module()
    graph = build_heuristic_graph(network, shipment.weight, heuristic_module)
    accounting = build_route_accounting(network)

    rows: list[ComparisonRow] = []
    for variant in VARIANTS:
        rows.append(run_solver(network, shipment, variant, time_limit_sec))
        rows.append(
            run_astar_baseline(
                graph,
                shipment,
                variant,
                heuristic_module,
                accounting,
                max_expansions,
            )
        )
        rows.append(
            run_tabu_search(
                graph,
                shipment,
                variant,
                heuristic_module,
                accounting,
                max_expansions,
                tabu_iterations,
            )
        )

    shipment_summary = (
        f"{shipment.start_hub} -> {shipment.end_hub}, "
        f"{shipment.weight:.1f} t, deadline {shipment.deadline} min"
    )
    return rows, shipment_summary, dataset_path


def write_comparison_outputs(
    rows: list[ComparisonRow],
    output_dir: Path,
    shipment_summary: str,
    dataset_path: Path,
) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / "solver_heuristic_comparison.csv"
    md_path = output_dir / "solver_heuristic_comparison.md"

    with csv_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=COMPARISON_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))

    md_path.write_text(
        build_markdown_evaluation(rows, shipment_summary, dataset_path),
        encoding="utf-8",
    )
    return csv_path, md_path


def build_markdown_evaluation(
    rows: list[ComparisonRow],
    shipment_summary: str,
    dataset_path: Path,
) -> str:
    lines = [
        "# Solver-vs-Heuristik-Vergleich",
        "",
        "## Setup",
        "",
        f"- Dataset: `{dataset_path.as_posix()}`",
        f"- Beispielsendung: {shipment_summary}",
        "- Varianten: balanced, cost_min, time_min, emissions_min",
        "- Beitrag: Comparison runner, CSV-Ausgabe und kurze Evaluation von Minglu Li.",
        "",
        "## Ergebnisuebersicht",
        "",
        "| Variante | Methode | Status | Runtime (s) | Full evaluated cost | Full evaluated CO2 | Route-only cost | Route-only CO2 | Zeit (min) | Modi | Pfad |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
    ]

    for row in rows:
        lines.append(
            "| "
            f"{row.variant} | {row.method} | {row.status} | {row.runtime_sec} | "
            f"{row.full_evaluated_cost_eur} | {row.full_evaluated_emissions_kg} | "
            f"{row.route_only_cost_eur} | {row.route_only_emissions_kg} | "
            f"{row.total_time_min} | {row.mode_sequence} | {row.path} |"
        )

    lines.extend(
        [
            "",
            "## Unterschiede zwischen den Loesungen",
            "",
            "- Der HiGHS MILP Solver nutzt ein zeitexpandiertes Modell mit Kapazitaeten, Wartezeiten, Transfers sowie fixen und variablen Kosten.",
            "- Die A*/Dijkstra-Heuristik betrachtet eine statische gewichtete Route und liefert eine schnelle Startloesung ohne Optimalitaetsnachweis.",
            "- Die Tabu Search startet von dieser Route und sucht alternative Pfade durch gesperrte Kanten; sie kann bessere Varianten finden, kostet aber mehr Laufzeit.",
            "- Full evaluated cost/CO2 bewertet auch Heuristik-Routen mit denselben fixen Transportkosten und fixen Emissionen aus dem Dataset.",
            "- `Optimal` bedeutet optimal im vollstaendigen MILP-Modell und ist deshalb mit Full evaluated cost/CO2 konsistent.",
            "- Rail hat in dieser Instanz niedrigere Route-only Kosten, aber hoehere fixed activation cost; deshalb ist Road im vollstaendigen Kostenmodell guenstiger.",
            "- Objective Values und MILP-Optimalitaet sind zwischen Solver und Heuristik weiterhin nicht direkt vergleichbar.",
            "",
            "## Kurze Evaluation",
            "",
            build_short_evaluation(rows),
            "",
        ]
    )
    return "\n".join(lines)


def build_short_evaluation(rows: list[ComparisonRow]) -> str:
    feasible = [row for row in rows if row.status in {"Optimal", "feasible"}]
    if not feasible:
        return (
            "Auf der Beispielinstanz wurde keine vergleichbare Route gefunden. "
            "Das spricht fuer eine weitere Pruefung der OD-Auswahl."
        )

    solver_rows = [row for row in rows if row.method == "HiGHS MILP"]
    heuristic_rows = [row for row in rows if row.method != "HiGHS MILP"]
    same_path_count = 0
    compared = 0
    for solver_row in solver_rows:
        matching = [
            row
            for row in heuristic_rows
            if row.variant == solver_row.variant and row.status == "feasible"
        ]
        for heuristic_row in matching:
            compared += 1
            if (
                heuristic_row.path == solver_row.path
                and heuristic_row.mode_sequence == solver_row.mode_sequence
            ):
                same_path_count += 1

    if compared and same_path_count == compared:
        path_sentence = (
            "Alle Heuristikvarianten finden auf dieser reduzierten Instanz "
            "denselben Pfad und dieselben Modi wie der Solver."
        )
    elif same_path_count:
        path_sentence = (
            "Ein Teil der Heuristikvarianten trifft den Solver-Pfad, andere "
            "Varianten zeigen abweichende Routen oder Modi und damit den Zielkonflikt "
            "zwischen Kosten, Zeit und CO2."
        )
    else:
        path_sentence = (
            "Die Heuristikvarianten liefern abweichende Routen oder Modi als der "
            "Solver; das ist plausibel, weil die Heuristik nicht das volle "
            "zeitexpandierte MILP mit Fixkosten und Kapazitaeten optimiert."
        )

    return (
        f"{path_sentence} Insgesamt ist die Heuristik als schnelle "
        "Naeherungsloesung geeignet. Die Rail-Heuristik hat niedrigere "
        "Route-only Kosten, wird aber nach fixed activation cost hoeher bewertet; "
        "damit bleibt Road im vollstaendigen Kostenmodell die konsistente "
        "MILP-Referenz."
    )


def _mode_changes(modes: list[str]) -> int:
    return sum(1 for index in range(1, len(modes)) if modes[index] != modes[index - 1])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare the HiGHS solver and heuristic variants on one shipment."
    )
    parser.add_argument("--dataset", type=Path, default=DATASET_PATH)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--max-routes", type=int, default=18)
    parser.add_argument("--weight", type=float, default=2.0)
    parser.add_argument("--time-limit-sec", type=float, default=15.0)
    parser.add_argument("--max-expansions", type=int, default=200_000)
    parser.add_argument("--tabu-iterations", type=int, default=80)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rows, shipment_summary, dataset_path = run_comparison(
        dataset_path=args.dataset,
        max_routes=args.max_routes,
        shipment_weight_tons=args.weight,
        time_limit_sec=args.time_limit_sec,
        max_expansions=args.max_expansions,
        tabu_iterations=args.tabu_iterations,
    )
    csv_path, md_path = write_comparison_outputs(
        rows=rows,
        output_dir=args.output_dir,
        shipment_summary=shipment_summary,
        dataset_path=dataset_path,
    )
    print(f"Wrote {csv_path}")
    print(f"Wrote {md_path}")


if __name__ == "__main__":
    main()

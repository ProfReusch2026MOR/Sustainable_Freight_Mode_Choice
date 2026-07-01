from __future__ import annotations

import argparse
import csv
import math
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from freight_routing.data_loader import NetworkDataLoader  # noqa: E402
from freight_routing.data_models import (  # noqa: E402
    ArcType,
    NetworkData,
    ObjectiveWeights,
    RoutingResult,
    Shipment,
    TransportArcTemplate,
)
from freight_routing.model import TimeExpandedFreightRoutingModel, TimeExpandedNetwork  # noqa: E402

DATASET_PATH = ROOT / "dataset" / "multimodal_network.json"
DEFAULT_OUTPUT_DIR = ROOT / "experiments" / "results"
DEFAULT_PLANNING_DAYS = 7
MODES = ("road", "rail", "air", "ship")
LAMBDA_VALUES = (0.0, 0.1, 0.5, 1.0, 2.0, 5.0)
COMPUTATIONAL_COLUMNS = (
    "instance",
    "method",
    "shipment_count",
    "route_count",
    "time_limit_sec",
    "status",
    "is_optimal",
    "runtime_sec",
    "objective_value",
    "total_cost_eur",
    "total_emissions_kg",
    "total_time_min",
    "road_share_pct",
    "rail_share_pct",
    "air_share_pct",
    "ship_share_pct",
)
SENSITIVITY_COLUMNS = COMPUTATIONAL_COLUMNS + (
    "lambda",
    "cost_weight",
    "emissions_weight",
    "time_weight",
)


@dataclass(frozen=True)
class InstanceSpec:
    name: str
    max_routes: int
    shipment_count: int
    time_limit_sec: float
    shipment_weight_tons: float | None = None


PROFILES = {
    "smoke": (
        InstanceSpec("smoke_small", max_routes=8, shipment_count=3, time_limit_sec=15),
    ),
    "presentation": (
        InstanceSpec("small", max_routes=10, shipment_count=3, time_limit_sec=15),
        InstanceSpec("medium", max_routes=20, shipment_count=5, time_limit_sec=15),
        InstanceSpec("large", max_routes=30, shipment_count=8, time_limit_sec=20),
    ),
    "modal-shift": (
        InstanceSpec(
            "modal_shift",
            max_routes=10,
            shipment_count=3,
            time_limit_sec=20,
            shipment_weight_tons=8.0,
        ),
    ),
}


def profile_output_paths(
    profile: str,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
) -> dict[str, Path]:
    if profile not in PROFILES:
        raise ValueError(f"Unknown experiment profile: {profile}")
    resolved_output_dir = (
        output_dir / "modal_shift" if profile == "modal-shift" else output_dir
    )
    return {
        "computational_csv": resolved_output_dir / "computational_experiments.csv",
        "sensitivity_csv": resolved_output_dir / "sensitivity_analysis.csv",
        "sensitivity_svg": resolved_output_dir / "sensitivity_cost_emissions.svg",
        "mode_share_svg": resolved_output_dir / "sensitivity_lambda_mode_share.svg",
    }


def lambda_to_weights(lambda_value: float) -> ObjectiveWeights:
    if lambda_value < 0:
        raise ValueError("lambda_value must not be negative.")
    denominator = 1.0 + lambda_value
    return ObjectiveWeights(
        cost=1.0 / denominator,
        time=0.0,
        emissions=lambda_value / denominator,
    )


def mode_share_percentages(
    shipment_routes: dict[str, tuple],
    shipment_weights: dict[str, float],
) -> dict[str, float]:
    ton_km_by_mode = dict.fromkeys(MODES, 0.0)
    for shipment_id, route in shipment_routes.items():
        weight = shipment_weights.get(shipment_id, 0.0)
        for arc in route:
            if arc.arc_type != ArcType.TRANSPORT:
                continue
            if arc.mode not in ton_km_by_mode:
                ton_km_by_mode[arc.mode] = 0.0
            ton_km_by_mode[arc.mode] += arc.distance * weight

    total_ton_km = sum(ton_km_by_mode.values())
    if total_ton_km <= 0:
        return dict.fromkeys(MODES, 0.0)
    return {
        mode: (ton_km_by_mode.get(mode, 0.0) / total_ton_km) * 100.0 for mode in MODES
    }


def result_to_row(
    instance_name: str,
    method: str,
    runtime_sec: float,
    result: RoutingResult,
    mode_shares: dict[str, float],
    shipment_count: int,
) -> dict[str, str]:
    objective_value = (
        "N/A" if result.objective_value is None else f"{result.objective_value:.6f}"
    )
    return {
        "instance": instance_name,
        "method": method,
        "shipment_count": str(shipment_count),
        "status": result.status,
        "is_optimal": str(result.is_optimal),
        "runtime_sec": f"{runtime_sec:.3f}",
        "objective_value": objective_value,
        "total_cost_eur": f"{result.total_cost:.2f}",
        "total_emissions_kg": f"{result.total_emissions:.2f}",
        "total_time_min": f"{result.total_time:.2f}",
        "road_share_pct": f"{mode_shares.get('road', 0.0):.2f}",
        "rail_share_pct": f"{mode_shares.get('rail', 0.0):.2f}",
        "air_share_pct": f"{mode_shares.get('air', 0.0):.2f}",
        "ship_share_pct": f"{mode_shares.get('ship', 0.0):.2f}",
    }


def build_subnetwork(network_data: NetworkData, max_routes: int) -> NetworkData:
    seed_hubs = {
        "BER_3970",
        "HAM_3971",
        "MUE_3972",
        "FRA_3974",
        "STU_3976",
        "DOR_3977",
        "BRE_3979",
        "HAN_3980",
        "LEI_3981",
        "NUE_3983",
        "DRE_3984",
    }
    existing_seeds = seed_hubs.intersection(network_data.hubs)
    selected_hubs = set(existing_seeds)
    selected_arcs: list[TransportArcTemplate] = []
    seen_arc_ids: set[str] = set()
    mode_rank = {"road": 0, "rail": 1, "ship": 2, "air": 3}
    grouped_arcs: dict[tuple[str, str], list[TransportArcTemplate]] = defaultdict(list)
    for arc in network_data.arc_templates:
        if isinstance(arc, TransportArcTemplate):
            grouped_arcs[(arc.from_hub, arc.to_hub)].append(arc)

    ordered_groups = sorted(
        grouped_arcs.items(),
        key=lambda item: (
            0 if item[0][0] in existing_seeds else 1,
            0 if any(0 in arc.departure_minutes for arc in item[1]) else 1,
            -len({arc.mode for arc in item[1]}),
            0 if item[0][1] in existing_seeds else 1,
            item[0][0],
            item[0][1],
        ),
    )

    while len(selected_arcs) < max_routes:
        added = False
        for (from_hub, to_hub), arcs in ordered_groups:
            if from_hub not in selected_hubs and to_hub not in selected_hubs:
                continue
            for arc in sorted(
                arcs, key=lambda item: (mode_rank.get(item.mode, 99), item.id)
            ):
                if arc.id in seen_arc_ids:
                    continue
                selected_arcs.append(arc)
                seen_arc_ids.add(arc.id)
                selected_hubs.add(arc.from_hub)
                selected_hubs.add(arc.to_hub)
                added = True
                if len(selected_arcs) >= max_routes:
                    break
            if len(selected_arcs) >= max_routes:
                break
        if not added:
            break

    return NetworkData(
        hubs={hub_id: network_data.hubs[hub_id] for hub_id in selected_hubs},
        mode_factors=network_data.mode_factors,
        arc_templates=tuple(selected_arcs),
        capacities=network_data.capacities,
        default_fixed_costs=network_data.default_fixed_costs,
        default_fixed_emissions=network_data.default_fixed_emissions,
        default_variable_factors=network_data.default_variable_factors,
    )


def generate_shipments(
    instance_name: str,
    network_data: NetworkData,
    shipment_count: int,
    planning_days: int = DEFAULT_PLANNING_DAYS,
    shipment_weight_tons: float | None = None,
) -> list[Shipment]:
    grouped_arcs: dict[tuple[str, str], list[TransportArcTemplate]] = defaultdict(list)
    for arc in network_data.arc_templates:
        if isinstance(arc, TransportArcTemplate):
            grouped_arcs[(arc.from_hub, arc.to_hub)].append(arc)

    candidate_pairs = [
        (pair, arcs)
        for pair, arcs in grouped_arcs.items()
        if any(0 in arc.departure_minutes for arc in arcs)
    ]
    if not candidate_pairs:
        raise ValueError("Cannot generate shipments without transport arcs at t=0.")
    candidate_pairs.sort(
        key=lambda item: (
            -len({arc.mode for arc in item[1]}),
            item[0][0],
            item[0][1],
        )
    )

    deadline = planning_days * 24 * 60
    shipments = []
    for index in range(shipment_count):
        (start_hub, end_hub), _ = candidate_pairs[index % len(candidate_pairs)]
        weight = (
            shipment_weight_tons
            if shipment_weight_tons is not None
            else 0.5 + (index % 5) * 0.25
        )
        shipments.append(
            Shipment(
                id=f"{instance_name}_shipment_{index + 1}",
                start_hub=start_hub,
                end_hub=end_hub,
                start_time=0,
                deadline=deadline,
                max_price=1_000_000.0,
                max_emissions=1_000_000.0,
                weight=weight,
            )
        )
    return shipments


def solve_instance(
    instance_name: str,
    network_data: NetworkData,
    shipments: list[Shipment],
    weights: ObjectiveWeights,
    time_limit_sec: float,
) -> tuple[RoutingResult, float]:
    network = TimeExpandedNetwork.build(network_data, DEFAULT_PLANNING_DAYS, shipments)
    model = TimeExpandedFreightRoutingModel(objective_weights=weights)
    started = time.perf_counter()
    result = model.solve(network, time_limit_sec=time_limit_sec)
    runtime_sec = time.perf_counter() - started
    return result, runtime_sec


def run_computational_experiments(
    base_network: NetworkData,
    specs: Iterable[InstanceSpec],
) -> list[dict[str, str]]:
    rows = []
    for spec in specs:
        print(
            f"Running {spec.name}: {spec.max_routes} routes, "
            f"{spec.shipment_count} shipments...",
            flush=True,
        )
        network = build_subnetwork(base_network, spec.max_routes)
        shipments = generate_shipments(
            spec.name,
            network,
            spec.shipment_count,
            shipment_weight_tons=spec.shipment_weight_tons,
        )
        shipment_weights = {shipment.id: shipment.weight for shipment in shipments}
        result, runtime_sec = solve_instance(
            spec.name,
            network,
            shipments,
            ObjectiveWeights(),
            spec.time_limit_sec,
        )
        shares = mode_share_percentages(result.shipment_routes, shipment_weights)
        rows.append(
            result_to_row(
                instance_name=spec.name,
                method="HiGHS MILP",
                runtime_sec=runtime_sec,
                result=result,
                mode_shares=shares,
                shipment_count=len(shipments),
            )
            | {
                "route_count": str(len(network.arc_templates)),
                "time_limit_sec": f"{spec.time_limit_sec:.0f}",
            }
        )
    return rows


def run_sensitivity_analysis(
    base_network: NetworkData,
    spec: InstanceSpec,
) -> list[dict[str, str]]:
    network = build_subnetwork(base_network, spec.max_routes)
    shipments = generate_shipments(
        spec.name,
        network,
        spec.shipment_count,
        shipment_weight_tons=spec.shipment_weight_tons,
    )
    shipment_weights = {shipment.id: shipment.weight for shipment in shipments}
    rows = []
    for lambda_value in LAMBDA_VALUES:
        print(
            f"Running sensitivity lambda={lambda_value:g} on {spec.name}...",
            flush=True,
        )
        weights = lambda_to_weights(lambda_value)
        result, runtime_sec = solve_instance(
            spec.name,
            network,
            shipments,
            weights,
            spec.time_limit_sec,
        )
        shares = mode_share_percentages(result.shipment_routes, shipment_weights)
        row = result_to_row(
            instance_name=spec.name,
            method="HiGHS MILP",
            runtime_sec=runtime_sec,
            result=result,
            mode_shares=shares,
            shipment_count=len(shipments),
        )
        row.update(
            {
                "lambda": f"{lambda_value:g}",
                "cost_weight": f"{weights.cost:.6f}",
                "emissions_weight": f"{weights.emissions:.6f}",
                "time_weight": f"{weights.time:.6f}",
                "route_count": str(len(network.arc_templates)),
                "time_limit_sec": f"{spec.time_limit_sec:.0f}",
            }
        )
        rows.append(row)
    return rows


def write_csv(
    path: Path,
    rows: list[dict[str, str]],
    fieldnames: tuple[str, ...] | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if fieldnames is None:
        fieldnames = tuple(sorted({field for row in rows for field in row}))
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _scale(values: list[float], size: int, reverse: bool = False) -> list[float]:
    finite_values = [value for value in values if math.isfinite(value)]
    if not finite_values:
        return [size / 2 for _ in values]
    minimum = min(finite_values)
    maximum = max(finite_values)
    if maximum <= minimum:
        return [size / 2 for _ in values]
    scaled = [((value - minimum) / (maximum - minimum)) * size for value in values]
    if reverse:
        return [size - value for value in scaled]
    return scaled


def _clustered_point_annotations(
    xs: list[float],
    ys: list[float],
    labels: list[str],
) -> str:
    grouped: dict[tuple[float, float], list[str]] = {}
    for x, y, label in zip(xs, ys, labels):
        grouped.setdefault((round(x, 1), round(y, 1)), []).append(label)

    annotations = []
    for (x, y), group_labels in grouped.items():
        annotations.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="#1f77b4" />')
        for index, label in enumerate(group_labels):
            y_offset = -12 + index * 15
            annotations.append(
                f'<text x="{x + 10:.1f}" y="{y + y_offset:.1f}" '
                f'font-size="11" font-family="Arial" '
                f'font-weight="normal">lambda = {label}</text>'
            )
    return "\n".join(annotations)


def write_cost_emissions_svg(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    width, height = 720, 420
    margin = 60
    plot_w, plot_h = width - 2 * margin, height - 2 * margin
    costs = [float(row["total_cost_eur"]) for row in rows]
    emissions = [float(row["total_emissions_kg"]) for row in rows]
    labels = [row["lambda"] for row in rows]
    xs = [margin + value for value in _scale(costs, plot_w)]
    ys = [margin + value for value in _scale(emissions, plot_h, reverse=True)]
    points = " ".join(f"{x:.1f},{y:.1f}" for x, y in zip(xs, ys))
    annotations = _clustered_point_annotations(xs, ys, labels)
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <rect width="100%" height="100%" fill="white"/>
  <text x="{width / 2}" y="28" text-anchor="middle" font-size="18" font-family="Arial" font-weight="normal">Cost-Emission Sensitivity</text>
  <line x1="{margin}" y1="{height - margin}" x2="{width - margin}" y2="{height - margin}" stroke="#333"/>
  <line x1="{margin}" y1="{margin}" x2="{margin}" y2="{height - margin}" stroke="#333"/>
  <text x="{width / 2}" y="{height - 16}" text-anchor="middle" font-size="13" font-family="Arial" font-weight="normal">Total cost (EUR)</text>
  <text x="18" y="{height / 2}" text-anchor="middle" font-size="13" font-family="Arial" font-weight="normal" transform="rotate(-90 18 {height / 2})">Total emissions (kg CO2)</text>
  <polyline points="{points}" fill="none" stroke="#1f77b4" stroke-width="2"/>
  {annotations}
</svg>
"""
    path.write_text(svg, encoding="utf-8")


def write_lambda_mode_share_svg(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    width, height = 720, 420
    margin = 60
    plot_w, plot_h = width - 2 * margin, height - 2 * margin
    lambdas = [float(row["lambda"]) for row in rows]
    road = [float(row["road_share_pct"]) for row in rows]
    rail = [float(row["rail_share_pct"]) for row in rows]
    xs = [margin + value for value in _scale(lambdas, plot_w)]
    road_ys = [margin + value for value in _scale(road, plot_h, reverse=True)]
    rail_ys = [margin + value for value in _scale(rail, plot_h, reverse=True)]
    road_points = " ".join(f"{x:.1f},{y:.1f}" for x, y in zip(xs, road_ys))
    rail_points = " ".join(f"{x:.1f},{y:.1f}" for x, y in zip(xs, rail_ys))
    labels = "\n".join(
        f'<text x="{x:.1f}" y="{height - margin + 18}" text-anchor="middle" font-size="11" font-weight="normal">{label:g}</text>'
        for x, label in zip(xs, lambdas)
    )
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <rect width="100%" height="100%" fill="white"/>
  <text x="{width / 2}" y="28" text-anchor="middle" font-size="18" font-family="Arial" font-weight="normal">Lambda vs. Mode Share</text>
  <line x1="{margin}" y1="{height - margin}" x2="{width - margin}" y2="{height - margin}" stroke="#333"/>
  <line x1="{margin}" y1="{margin}" x2="{margin}" y2="{height - margin}" stroke="#333"/>
  <text x="{width / 2}" y="{height - 16}" text-anchor="middle" font-size="13" font-family="Arial" font-weight="normal">Lambda</text>
  <text x="18" y="{height / 2}" text-anchor="middle" font-size="13" font-family="Arial" font-weight="normal" transform="rotate(-90 18 {height / 2})">Mode share (%)</text>
  <polyline points="{road_points}" fill="none" stroke="#2ca02c" stroke-width="2"/>
  <polyline points="{rail_points}" fill="none" stroke="#d62728" stroke-width="2"/>
  <text x="{width - margin - 120}" y="{margin + 12}" font-size="13" font-weight="normal" fill="#2ca02c">Road share</text>
  <text x="{width - margin - 120}" y="{margin + 32}" font-size="13" font-weight="normal" fill="#d62728">Rail share</text>
  {labels}
</svg>
"""
    path.write_text(svg, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run reproducible computational experiments for the freight routing model."
    )
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILES),
        default="smoke",
        help="Experiment profile to run.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory for generated CSV and SVG outputs.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_paths = profile_output_paths(args.profile, args.output_dir)
    base_network = NetworkDataLoader.from_json(DATASET_PATH)
    specs = PROFILES[args.profile]
    computational_rows = run_computational_experiments(base_network, specs)
    sensitivity_spec = specs[0]
    sensitivity_rows = run_sensitivity_analysis(base_network, sensitivity_spec)

    write_csv(
        output_paths["computational_csv"],
        computational_rows,
        COMPUTATIONAL_COLUMNS,
    )
    write_csv(output_paths["sensitivity_csv"], sensitivity_rows, SENSITIVITY_COLUMNS)
    write_cost_emissions_svg(output_paths["sensitivity_svg"], sensitivity_rows)
    write_lambda_mode_share_svg(output_paths["mode_share_svg"], sensitivity_rows)

    print(f"Wrote {len(computational_rows)} computational rows.")
    print(f"Wrote {len(sensitivity_rows)} sensitivity rows.")
    print(f"Output directory: {output_paths['computational_csv'].parent}")


if __name__ == "__main__":
    main()

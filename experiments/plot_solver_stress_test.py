"""Render the solver stress-test figure from already-computed benchmark data.

This script does not solve or re-run any instance. It only reads two existing
result artifacts and plots them:

- notebooks/results/astar_vs_solver_accuracy.json
  (HiGHS MILP vs. Dijkstra/A* + LNS heuristic, shipment-count sweep on
  dataset/small_network.json, planning_days=15, seeded per size)
- Hard-coded solver-only timings from notebooks/scaling_tests.ipynb
  (dataset/multimodal_network.json, varying planning horizon and shipment
  count; these cells already ran for up to ~84 minutes and are not repeated)

Usage:
    python experiments/plot_solver_stress_test.py
"""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ACCURACY_JSON = PROJECT_ROOT / "notebooks" / "results" / "astar_vs_solver_accuracy.json"
OUTPUT_SVG = PROJECT_ROOT / "documentation" / "assets" / "solver_stress_test.svg"

# Fixed categorical colors (dataviz palette slots 1 and 2, validated CVD-safe).
COLOR_SOLVER = "#2a78d6"  # blue
COLOR_HEURISTIC = "#1baf7a"  # aqua
COLOR_MUTED = "#898781"
COLOR_GRID = "#e1e0d9"
COLOR_INK = "#0b0b0b"

# Solver-only timings already produced in notebooks/scaling_tests.ipynb
# (dataset/multimodal_network.json, 870 hubs / ~36k static arcs).
# Each entry: (label, planning_days, shipment_count, node_count, solve_seconds)
SCALING_TESTS_DATA = [
    ("2d / N=1", 2, 1, 184_112, 58.22),
    ("2d / N=5", 2, 5, 184_112, 307.69),
    ("3d / N=5", 3, 5, 279_907, 613.35),
    ("5d / N=5", 5, 5, 474_155, 5047.75),
]


def load_accuracy_data() -> dict:
    with ACCURACY_JSON.open() as f:
        return json.load(f)


def main() -> None:
    data = load_accuracy_data()
    sizes = data["size"]
    milp_time = data["milp_time"]
    # Heuristic delivered result = greedy construction + LNS improvement.
    heuristic_time = data["opt_time"]

    plt.rcParams["font.family"] = "sans-serif"
    plt.rcParams["font.sans-serif"] = ["Arial", "DejaVu Sans"]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11.5, 4.6))
    fig.patch.set_facecolor("#fcfcfb")

    # --- Panel A: shipment-count stress test -------------------------------
    ax1.set_facecolor("#fcfcfb")
    ax1.plot(
        sizes,
        milp_time,
        color=COLOR_SOLVER,
        linewidth=2,
        marker="o",
        markersize=6,
        label="MILP-Solver (HiGHS)",
    )
    ax1.plot(
        sizes,
        heuristic_time,
        color=COLOR_HEURISTIC,
        linewidth=2,
        marker="o",
        markersize=6,
        label="Heuristik (Greedy + LNS)",
    )
    ax1.set_yscale("log")
    ax1.set_xlabel("Anzahl Sendungen", color=COLOR_INK, fontsize=10)
    ax1.set_ylabel("Laufzeit (s, log-Skala)", color=COLOR_INK, fontsize=10)
    ax1.set_title(
        "Skalierung nach Sendungsanzahl\n(small_network.json, 15 Tage Horizont)",
        fontsize=11,
        color=COLOR_INK,
        pad=10,
    )
    ax1.grid(True, which="both", linestyle=":", linewidth=0.7, color=COLOR_GRID)
    for spine in ("top", "right"):
        ax1.spines[spine].set_visible(False)
    for spine in ("left", "bottom"):
        ax1.spines[spine].set_color(COLOR_MUTED)
    ax1.tick_params(colors=COLOR_MUTED, labelsize=9)

    # Direct end-of-line labels (required: aqua fails the 3:1 contrast check
    # against the light surface, so identity must not rely on color alone).
    ax1.annotate(
        "MILP-Solver",
        xy=(sizes[-1], milp_time[-1]),
        xytext=(4, 2),
        textcoords="offset points",
        color=COLOR_SOLVER,
        fontsize=9,
        fontweight="bold",
    )
    ax1.annotate(
        "Heuristik",
        xy=(sizes[-1], heuristic_time[-1]),
        xytext=(4, -10),
        textcoords="offset points",
        color=COLOR_HEURISTIC,
        fontsize=9,
        fontweight="bold",
    )
    ax1.set_ylim(top=max(milp_time) * 3)

    # --- Panel B: planning-horizon stress test ------------------------------
    ax2.set_facecolor("#fcfcfb")
    labels = [row[0] for row in SCALING_TESTS_DATA]
    solve_seconds = [row[4] for row in SCALING_TESTS_DATA]
    x_positions = range(len(labels))
    ax2.plot(
        x_positions,
        solve_seconds,
        color=COLOR_SOLVER,
        linewidth=2,
        marker="o",
        markersize=7,
    )
    for x, (label, days, n, nodes, seconds) in zip(x_positions, SCALING_TESTS_DATA):
        ax2.annotate(
            f"{seconds / 60:,.1f} min" if seconds >= 60 else f"{seconds:,.0f} s",
            xy=(x, seconds),
            xytext=(0, 9),
            textcoords="offset points",
            ha="center",
            fontsize=8.5,
            color=COLOR_INK,
        )
    ax2.set_yscale("log")
    ax2.set_xticks(list(x_positions))
    ax2.set_xticklabels(labels, fontsize=9, color=COLOR_MUTED)
    ax2.set_xlabel(
        "Planungshorizont / Sendungsanzahl (N)", color=COLOR_INK, fontsize=10
    )
    ax2.set_ylabel("MILP-Laufzeit (s, log-Skala)", color=COLOR_INK, fontsize=10)
    ax2.set_title(
        "Skalierung nach Zeithorizont\n(multimodal_network.json, 870 Hubs)",
        fontsize=11,
        color=COLOR_INK,
        pad=10,
    )
    ax2.grid(
        True, which="both", axis="y", linestyle=":", linewidth=0.7, color=COLOR_GRID
    )
    for spine in ("top", "right"):
        ax2.spines[spine].set_visible(False)
    for spine in ("left", "bottom"):
        ax2.spines[spine].set_color(COLOR_MUTED)
    ax2.tick_params(colors=COLOR_MUTED, labelsize=9)
    ax2.set_xlim(-0.4, len(labels) - 0.6)

    fig.suptitle(
        "Solver-Stresstest: HiGHS MILP vs. Heuristik über zwei Skalierungsachsen",
        fontsize=12.5,
        fontweight="bold",
        color=COLOR_INK,
    )
    fig.tight_layout(rect=(0, 0, 1, 0.93))

    OUTPUT_SVG.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_SVG, format="svg", facecolor=fig.get_facecolor())
    print(f"Wrote {OUTPUT_SVG}")


if __name__ == "__main__":
    main()

from __future__ import annotations

import csv
import tempfile
import unittest
from pathlib import Path

from experiments.compare_solver_heuristic import (
    COMPARISON_COLUMNS,
    VARIANTS,
    ComparisonRow,
    RouteAccounting,
    build_tabu_search_kwargs,
    build_short_evaluation,
    load_heuristic_module,
    write_comparison_outputs,
)


class SolverHeuristicComparisonTests(unittest.TestCase):
    def test_variants_cover_balanced_and_single_objective_weights(self):
        names = {variant.name for variant in VARIANTS}

        self.assertEqual(
            names,
            {"balanced", "cost_min", "time_min", "emissions_min"},
        )

        emissions_variant = next(
            variant for variant in VARIANTS if variant.name == "emissions_min"
        )
        self.assertIn("name", emissions_variant.weights)
        self.assertEqual(emissions_variant.weights["emissions"], 1.0)
        self.assertEqual(emissions_variant.weights["cost"], 0.0)

    def test_write_comparison_outputs_creates_csv_and_german_evaluation(self):
        rows = [
            ComparisonRow(
                variant="balanced",
                method="HiGHS MILP",
                status="Optimal",
                is_optimal="true",
                runtime_sec="0.100",
                objective_value="0.420000",
                full_evaluated_cost_eur="100.00",
                full_evaluated_emissions_kg="50.00",
                route_only_cost_eur="80.00",
                route_only_emissions_kg="30.00",
                total_time_min="120.00",
                transport_time_min="100.00",
                total_distance_km="200.00",
                mode_sequence="road",
                path="A -> B",
                mode_changes="0",
                note="time-expanded exact solver",
            ),
            ComparisonRow(
                variant="balanced",
                method="Tabu Search",
                status="feasible",
                is_optimal="N/A",
                runtime_sec="0.010",
                objective_value="N/A",
                full_evaluated_cost_eur="155.00",
                full_evaluated_emissions_kg="69.00",
                route_only_cost_eur="105.00",
                route_only_emissions_kg="49.00",
                total_time_min="130.00",
                transport_time_min="130.00",
                total_distance_km="210.00",
                mode_sequence="rail",
                path="A -> C -> B",
                mode_changes="0",
                note="static heuristic",
            ),
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            csv_path, md_path = write_comparison_outputs(
                rows=rows,
                output_dir=output_dir,
                shipment_summary="A -> B, 2.0 t",
                dataset_path=Path("dataset/multimodal_network.json"),
            )

            self.assertEqual(csv_path, output_dir / "solver_heuristic_comparison.csv")
            self.assertEqual(md_path, output_dir / "solver_heuristic_comparison.md")

            with csv_path.open(newline="", encoding="utf-8") as csv_file:
                csv_rows = list(csv.DictReader(csv_file))

            self.assertEqual(csv_rows[0]["method"], "HiGHS MILP")
            self.assertEqual(list(csv_rows[0].keys()), list(COMPARISON_COLUMNS))

            markdown = md_path.read_text(encoding="utf-8")
            self.assertIn("Solver-vs-Heuristik-Vergleich", markdown)
            self.assertIn("Unterschiede zwischen den Loesungen", markdown)
            self.assertIn("Kurze Evaluation", markdown)
            self.assertIn("nicht direkt vergleichbar", markdown)
            self.assertIn("Full evaluated cost", markdown)
            self.assertIn("Route-only cost", markdown)
            self.assertIn("fixed activation cost", markdown)
            self.assertIn("Minglu Li", markdown)

    def test_load_heuristic_module_supports_dataclasses_in_spaced_filename(self):
        module = load_heuristic_module()

        self.assertTrue(hasattr(module, "Edge"))
        self.assertTrue(hasattr(module, "tabu_search_route"))

    def test_tabu_search_kwargs_match_current_heuristic_signature(self):
        module = load_heuristic_module()

        kwargs = build_tabu_search_kwargs(
            heuristic_module=module,
            max_expansions=100,
            tabu_iterations=5,
        )

        self.assertIn("initial_max_neighbors_per_node", kwargs)
        self.assertEqual(kwargs["initial_max_neighbors_per_node"], 3)

    def test_short_evaluation_treats_same_hub_path_with_different_modes_as_difference(
        self,
    ):
        rows = [
            ComparisonRow(
                variant="cost_min",
                method="HiGHS MILP",
                status="Optimal",
                is_optimal="true",
                runtime_sec="0.100",
                objective_value="0.420000",
                full_evaluated_cost_eur="604.08",
                full_evaluated_emissions_kg="64.06",
                route_only_cost_eur="454.08",
                route_only_emissions_kg="34.06",
                total_time_min="129.00",
                transport_time_min="129.00",
                total_distance_km="189.20",
                mode_sequence="road",
                path="BER_3970 -> LEI_3981",
                mode_changes="0",
                note="solver",
            ),
            ComparisonRow(
                variant="cost_min",
                method="Tabu Search",
                status="feasible",
                is_optimal="N/A",
                runtime_sec="0.010",
                objective_value="N/A",
                full_evaluated_cost_eur="760.54",
                full_evaluated_emissions_kg="89.30",
                route_only_cost_eur="260.54",
                route_only_emissions_kg="9.30",
                total_time_min="343.00",
                transport_time_min="343.00",
                total_distance_km="186.10",
                mode_sequence="rail",
                path="BER_3970 -> LEI_3981",
                mode_changes="0",
                note="heuristic",
            ),
        ]

        evaluation = build_short_evaluation(rows)

        self.assertIn("abweichende Routen oder Modi", evaluation)
        self.assertIn("fixed activation cost", evaluation)

    def test_route_accounting_adds_fixed_transport_costs_and_emissions(self):
        accounting = RouteAccounting(
            fixed_cost_by_arc_id={"rail_arc": 500.0},
            fixed_emissions_by_arc_id={"rail_arc": 80.0},
        )

        full_cost, full_emissions = accounting.evaluate(
            route_cost=260.54,
            route_emissions=9.305,
            arc_ids=["rail_arc"],
        )

        self.assertAlmostEqual(full_cost, 760.54)
        self.assertAlmostEqual(full_emissions, 89.305)


if __name__ == "__main__":
    unittest.main()

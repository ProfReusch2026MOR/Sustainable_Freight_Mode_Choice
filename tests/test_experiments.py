from __future__ import annotations

import unittest

from experiments.run_experiments import (
    _clustered_point_annotations,
    lambda_to_weights,
    mode_share_percentages,
    result_to_row,
)
from freight_routing.data_models import (
    ArcType,
    NetworkNode,
    RoutingResult,
    _TimedArc,
)


class ExperimentSummaryTests(unittest.TestCase):
    def test_lambda_to_weights_keeps_time_zero_and_normalizes_cost_emissions(self):
        weights = lambda_to_weights(2.0)

        self.assertAlmostEqual(weights.cost, 1.0 / 3.0)
        self.assertEqual(weights.time, 0.0)
        self.assertAlmostEqual(weights.emissions, 2.0 / 3.0)

    def test_mode_share_percentages_use_ton_kilometers_for_transport_arcs_only(self):
        road_arc = _TimedArc(
            from_node=NetworkNode("A", "road", 0),
            to_node=NetworkNode("B", "road", 10),
            mode="road",
            arc_type=ArcType.TRANSPORT,
            departure_min=0,
            arrival_min=10,
            distance=100.0,
            cost=1.0,
            emissions=1.0,
            capacity=10.0,
        )
        rail_arc = _TimedArc(
            from_node=NetworkNode("B", "rail", 20),
            to_node=NetworkNode("C", "rail", 40),
            mode="rail",
            arc_type=ArcType.TRANSPORT,
            departure_min=20,
            arrival_min=40,
            distance=300.0,
            cost=1.0,
            emissions=1.0,
            capacity=10.0,
        )
        waiting_arc = _TimedArc(
            from_node=NetworkNode("B", "road", 10),
            to_node=NetworkNode("B", "road", 20),
            mode="road",
            arc_type=ArcType.WAITING,
            departure_min=10,
            arrival_min=20,
            distance=0.0,
            cost=1.0,
            emissions=1.0,
            capacity=10.0,
        )

        shares = mode_share_percentages(
            {"shipment_1": (road_arc, waiting_arc, rail_arc)},
            {"shipment_1": 2.0},
        )

        self.assertAlmostEqual(shares["road"], 25.0)
        self.assertAlmostEqual(shares["rail"], 75.0)
        self.assertEqual(shares["air"], 0.0)
        self.assertEqual(shares["ship"], 0.0)

    def test_result_to_row_includes_objective_value_and_mode_shares(self):
        result = RoutingResult(
            status="Optimal",
            is_optimal=True,
            objective_value=0.42,
            total_cost=100.0,
            total_emissions=50.0,
            total_time=120.0,
            shipment_routes={},
        )

        row = result_to_row(
            instance_name="small",
            method="solver",
            runtime_sec=1.25,
            result=result,
            mode_shares={"road": 70.0, "rail": 30.0, "air": 0.0, "ship": 0.0},
            shipment_count=2,
        )

        self.assertEqual(row["instance"], "small")
        self.assertEqual(row["method"], "solver")
        self.assertEqual(row["status"], "Optimal")
        self.assertEqual(row["objective_value"], "0.420000")
        self.assertEqual(row["road_share_pct"], "70.00")
        self.assertEqual(row["rail_share_pct"], "30.00")
        self.assertEqual(row["shipment_count"], "2")

    def test_clustered_point_annotations_stack_overlapping_lambda_labels(self):
        annotations = _clustered_point_annotations(
            xs=[100.0, 100.0, 100.0],
            ys=[200.0, 200.0, 200.0],
            labels=["0", "0.1", "5"],
        )

        text_lines = [line for line in annotations.splitlines() if "<text" in line]

        self.assertEqual(len(text_lines), 3)
        self.assertIn("lambda = 0", text_lines[0])
        self.assertIn("lambda = 0.1", text_lines[1])
        self.assertIn("lambda = 5", text_lines[2])
        self.assertEqual(len(set(text_lines)), 3)


if __name__ == "__main__":
    unittest.main()

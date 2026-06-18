from __future__ import annotations

import unittest

from experiments.run_experiments import (
    PROFILES,
    _clustered_point_annotations,
    generate_shipments,
    lambda_to_weights,
    mode_share_percentages,
    result_to_row,
)
from freight_routing.data_models import (
    ArcType,
    NetworkNode,
    NetworkData,
    RoutingResult,
    FixedFactorDefaults,
    Hub,
    ModeFactor,
    TransportArcTemplate,
    VariableFactorDefaults,
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
        self.assertTrue(all('font-weight="normal"' in line for line in text_lines))
        self.assertEqual(len(set(text_lines)), 3)

    def test_modal_shift_profile_uses_heavy_shipments(self):
        spec = PROFILES["modal-shift"][0]

        self.assertGreaterEqual(spec.shipment_weight_tons, 8.0)
        self.assertEqual(spec.name, "modal_shift")

    def test_generate_shipments_can_use_fixed_heavy_weight(self):
        network = NetworkData(
            hubs={
                "A": Hub("A", "A", ("road", "rail")),
                "B": Hub("B", "B", ("road", "rail")),
            },
            mode_factors={
                "road": ModeFactor(1.2, 0.09),
                "rail": ModeFactor(0.7, 0.025),
            },
            arc_templates=(
                TransportArcTemplate(
                    id="A_B_road",
                    duration_min=60,
                    departure_minutes=(0,),
                    max_vehicles=None,
                    fixed_cost=None,
                    fixed_emissions=None,
                    capacity=None,
                    mode="road",
                    distance=200.0,
                    from_hub="A",
                    to_hub="B",
                ),
            ),
            capacities={"road": 10.0, "rail": 40.0, "waiting": 100.0, "transfer": 25.0},
            default_fixed_costs=FixedFactorDefaults(
                transport={"road": 150.0, "rail": 500.0},
                waiting=0.0,
                transfer=100.0,
            ),
            default_fixed_emissions=FixedFactorDefaults(
                transport={"road": 30.0, "rail": 80.0},
                waiting=0.0,
                transfer=10.0,
            ),
            default_variable_factors=VariableFactorDefaults(
                waiting_cost_per_hour=5.0,
                waiting_emissions_per_hour=0.0,
                transfer_cost_per_ton=50.0,
                transfer_emissions_per_ton=5.0,
            ),
        )

        shipments = generate_shipments(
            "modal_shift",
            network,
            shipment_count=2,
            shipment_weight_tons=8.0,
        )

        self.assertEqual([shipment.weight for shipment in shipments], [8.0, 8.0])


if __name__ == "__main__":
    unittest.main()

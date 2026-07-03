from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from experiments.run_experiments import (
    _scale_fixed_domain,
    write_lambda_mode_share_svg,
)


class ModeShareScalingTest(unittest.TestCase):
    def test_fixed_domain_keeps_constant_percentages_at_axis_edges(self) -> None:
        self.assertEqual(
            _scale_fixed_domain([100.0, 100.0], 300, 0.0, 100.0, reverse=True),
            [0.0, 0.0],
        )
        self.assertEqual(
            _scale_fixed_domain([0.0, 0.0], 300, 0.0, 100.0, reverse=True),
            [300.0, 300.0],
        )

    def test_mode_share_svg_uses_zero_to_hundred_percent_domain(self) -> None:
        rows = [
            {
                "lambda": "0.0",
                "road_share_pct": "100.00",
                "rail_share_pct": "0.00",
            },
            {
                "lambda": "1.0",
                "road_share_pct": "100.00",
                "rail_share_pct": "0.00",
            },
        ]
        with TemporaryDirectory() as directory:
            svg_path = Path(directory) / "mode_share.svg"
            write_lambda_mode_share_svg(svg_path, rows)
            svg = svg_path.read_text(encoding="utf-8")

        self.assertIn('points="60.0,60.0 660.0,60.0"', svg)
        self.assertIn('points="60.0,360.0 660.0,360.0"', svg)


if __name__ == "__main__":
    unittest.main()

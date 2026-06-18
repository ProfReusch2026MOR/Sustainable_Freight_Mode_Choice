# Presentation Validation Checklist

Run these checks before using the report or demo results in the final presentation.

## Environment

- Install Python dependencies:

```bash
python -m pip install -r requirements.txt ruff
```

- Install Typst if the PDF report must be built locally. GitHub Actions also builds `documentation/main.pdf` on pushes to `main`.

## Reproduce Results

```bash
python -m compileall freight_routing experiments
python -m unittest tests.test_experiments
python experiments/run_experiments.py --profile smoke
python experiments/run_experiments.py --profile presentation
python -m ruff format --check .
```

Expected presentation outputs:

- `experiments/results/computational_experiments.csv`
- `experiments/results/sensitivity_analysis.csv`
- `experiments/results/sensitivity_cost_emissions.svg`
- `experiments/results/sensitivity_lambda_mode_share.svg`

## Report Build

```bash
typst compile documentation/main.typ documentation/main.pdf --root .
```

## Speaking Notes

- The MILP implementation uses PuLP with HiGHS, not CBC.
- The presentation profile is a reproducible demo scale: 10/20/30 routes and 3/5/8 shipments.
- In the current small sensitivity instance, lambda changes the objective weight but does not change the selected mode. This is a parameter finding: fixed activation costs and fixed emissions keep road transport dominant on short relations.
- Do not claim an optimality gap unless the solver output exposes it; the current tables use status, objective value, runtime, cost, emissions, and mode share.

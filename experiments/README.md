# Reproducible Experiment Guide

This folder contains the reproducible evaluation work for the final report and
presentation. The experiments use `dataset/medium_network.json`, build
deterministic subnetworks, and solve the resulting MILP instances with PuLP and
HiGHS.

## Profiles

Run the commands from the repository root.

```bash
python experiments/run_experiments.py --profile smoke
python experiments/run_experiments.py --profile presentation
python experiments/run_experiments.py --profile modal-shift
```

- `smoke`: fastest sanity check for local validation.
- `presentation`: small/medium/large instances used in the report and slides.
- `modal-shift`: heavier long-distance sensitivity setting designed to test
  whether higher emission weights can shift ton-kilometers from road to rail.

## Outputs

The baseline profiles write to `experiments/results/`:

- `computational_experiments.csv`
- `sensitivity_analysis.csv`
- `sensitivity_cost_emissions.svg`
- `sensitivity_lambda_mode_share.svg`

The modal-shift profile writes the same artifact types to
`experiments/results/modal_shift/`.

The CSV schema includes runtime, solver status, objective value, total cost,
total emissions, total time, and road/rail/air/ship ton-kilometer mode shares.
Sensitivity rows additionally include lambda, cost weight, emissions weight,
and time weight.

## Interpretation

The presentation baseline currently shows road dominance for all tested lambda
values. This is a parameter finding rather than a solver error: the selected
short relations and fixed activation costs make road transport attractive even
when emissions are weighted more strongly.

The sensitivity weight mapping is:

```text
cost_weight = 1 / (1 + lambda)
emissions_weight = lambda / (1 + lambda)
time_weight = 0
```

Therefore, overlapping cost-emission points mean that the route selected by the
MILP did not change under the tested weight settings. The weights changed, but
the final route, cost, and emissions remained stable.

The modal-shift profile increases shipment weight and tests whether rail
becomes more attractive. In the current generated outputs it produces a stable
mixed road/rail solution across all tested lambda values. This should be
presented as scenario evidence, not as a general policy conclusion.

## Validation

Before using the outputs in the final presentation, run:

```bash
python -m unittest tests.test_experiments
python -m unittest tests.test_run_experiments
python -m compileall freight_routing experiments
python -m ruff format --check .
python -m ruff check experiments tests freight_routing
```

Then rebuild the report and slides with Typst if the local environment has
Typst installed.

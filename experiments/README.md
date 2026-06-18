# Reproducible Experiment Guide

This folder contains the reproducible evaluation work for the final report and
presentation. The experiments use `dataset/multimodal_network.json`, build
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

The modal-shift profile increases shipment weight and uses a setting where the
emissions objective can become decisive. In the current generated outputs,
lambda values of `2` and `5` produce a 100% rail solution. This gives the
presentation a reproducible example of how the model can react when emissions
receive higher priority.

## Validation

Before using the outputs in the final presentation, run:

```bash
python -m unittest tests.test_experiments
python -m compileall freight_routing experiments
python -m ruff format --check .
python -m ruff check experiments tests freight_routing
```

Then rebuild the report and slides with Typst if the local environment has
Typst installed.

= Numerische Ergebnisse & Evaluierung <ch:results>

== Experimentelles Setup
Die Rechenexperimente werden mit dem Skript `experiments/run_experiments.py` reproduzierbar erzeugt. Das Skript verwendet den Datensatz `dataset/multimodal_network.json`, extrahiert deterministische Teilnetzwerke und löst die resultierenden MILP-Instanzen mit PuLP und HiGHS. Für die Präsentationsauswertung wurde der Befehl `python experiments/run_experiments.py --profile presentation` ausgeführt.

Die CSV-Ergebnisse und Diagramme werden unter `experiments/results/` abgelegt. Diese Auswertung bildet einen eigenständigen technischen Beitrag zur experimentellen Validierung, Sensitivitätsanalyse und Reproduzierbarkeit des Projekts.

== Instanzgrößen und Skalierungstest
Zur Evaluierung der Skalierbarkeit wurden drei Teilinstanzen aus dem multimodalen Netzwerk erzeugt. Die Instanzgröße wird über die Anzahl der betrachteten Transportverbindungen und Sendungen variiert. Alle Instanzen verwenden einen Planungshorizont von sieben Tagen und ein Solver-Zeitlimit.

#align(center)[
#table(
  columns: (auto, auto, auto, auto, auto, auto, auto, auto),
  inset: 8pt,
  align: center + horizon,
  [*Instanz*], [*Routen*], [*Sendungen*], [*Status*], [*Zeitlimit*], [*Laufzeit*], [*Kosten*], [*CO2*],
  [small], [10], [3], [Optimal], [15 s], [4.010 s], [921.27 EUR], [125.35 kg],
  [medium], [20], [5], [Optimal], [15 s], [8.171 s], [1675.77 EUR], [219.43 kg],
  [large], [30], [8], [Optimal], [20 s], [18.696 s], [2644.14 EUR], [348.31 kg],
)
]

Die Laufzeit steigt bereits bei kleinen Instanzvergrößerungen deutlich an. Dies bestätigt, dass das zeitexpandierte MILP für exakte Lösungen geeignet ist, aber bei wachsender Anzahl von Sendungen und Alternativrouten schnell rechenintensiv wird. Für sehr große Netze bleibt daher die heuristische Lösung als schnelle Vergleichsmethode wichtig.

== Sensitivitätsanalyse
Für die Sensitivitätsanalyse wurde der Kosten-Emissions-Trade-off über einen Parameter $lambda$ variiert. Die Gewichte werden wie folgt gesetzt:

$ w_c = 1 / (1 + lambda), quad w_e = lambda / (1 + lambda), quad w_t = 0 $

Getestet wurden $lambda in {0, 0.1, 0.5, 1, 2, 5}$. Die small-Instanz bleibt in allen Läufen optimal und nutzt jeweils ausschließlich Straßentransport:

#align(center)[
#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 8pt,
  align: center + horizon,
  [*$lambda$*], [*$w_c$*], [*$w_e$*], [*Laufzeit*], [*Kosten*], [*CO2*], [*Road-Anteil*],
  [0], [1.000], [0.000], [4.771 s], [921.27 EUR], [125.35 kg], [100.00%],
  [0.1], [0.909], [0.091], [4.694 s], [921.27 EUR], [125.35 kg], [100.00%],
  [0.5], [0.667], [0.333], [4.749 s], [921.27 EUR], [125.35 kg], [100.00%],
  [1], [0.500], [0.500], [4.523 s], [921.27 EUR], [125.35 kg], [100.00%],
  [2], [0.333], [0.667], [4.864 s], [921.27 EUR], [125.35 kg], [100.00%],
  [5], [0.167], [0.833], [4.462 s], [921.27 EUR], [125.35 kg], [100.00%],
)
]

#figure(
  image("../experiments/results/sensitivity_cost_emissions.svg", width: 80%),
  caption: [Kosten-Emissions-Ergebnis der $lambda$-Sensitivität.]
)

#figure(
  image("../experiments/results/sensitivity_lambda_mode_share.svg", width: 80%),
  caption: [Modusanteile in der $lambda$-Sensitivität.]
)

Die konstanten Kosten- und Emissionswerte zeigen, dass die aktuell gewählte Teilinstanz robust gegen die getestete Gewichtungsvariation ist. In dieser Datenkonfiguration dominieren die fixen Aktivierungskosten und Fixemissionen der alternativen Modi stark genug, sodass der LKW auf den kurzen Relationen trotz höherer variabler Emissionsfaktoren bevorzugt wird. Das ist kein Solverfehler, sondern ein wichtiges Ergebnis der Parametrisierung: Für einen sichtbaren Modal Shift müssten entweder längere Relationen, höhere Sendungsgewichte, CO2-Preise oder angepasste Fixkosten betrachtet werden.

== Reproduzierbarkeit
Die Experimente können mit folgenden Befehlen erneut erzeugt und geprüft werden:

```bash
python -m compileall freight_routing experiments
python experiments/run_experiments.py --profile smoke
python experiments/run_experiments.py --profile presentation
python -m ruff format --check .
```

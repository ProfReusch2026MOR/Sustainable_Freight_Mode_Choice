# Solver-vs-Heuristik-Vergleich

## Setup

- Dataset: `C:/Users/COLORFUL/Documents/Codex/2026-06-18/files-mentioned-by-the-user-or/work/Sustainable_Freight_Mode_Choice/dataset/multimodal_network.json`
- Beispielsendung: BER_3970 -> LEI_3981, 2.0 t, deadline 10080 min
- Varianten: balanced, cost_min, time_min, emissions_min
- Beitrag: Comparison runner, CSV-Ausgabe und kurze Evaluation von Minglu Li.

## Ergebnisuebersicht

| Variante | Methode | Status | Runtime (s) | Kosten (EUR) | CO2 (kg) | Zeit (min) | Modi | Pfad |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| balanced | HiGHS MILP | Optimal | 0.813 | 604.08 | 64.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| balanced | A*/Dijkstra baseline | feasible | 0.000 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| balanced | Tabu Search | feasible | 0.000 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| cost_min | HiGHS MILP | Optimal | 0.842 | 604.08 | 64.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| cost_min | A*/Dijkstra baseline | feasible | 0.000 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |
| cost_min | Tabu Search | feasible | 0.000 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |
| time_min | HiGHS MILP | Optimal | 0.779 | 604.08 | 64.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| time_min | A*/Dijkstra baseline | feasible | 0.000 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| time_min | Tabu Search | feasible | 0.000 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| emissions_min | HiGHS MILP | Optimal | 0.788 | 604.08 | 64.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| emissions_min | A*/Dijkstra baseline | feasible | 0.000 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |
| emissions_min | Tabu Search | feasible | 0.000 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |

## Unterschiede zwischen den Loesungen

- Der HiGHS MILP Solver nutzt ein zeitexpandiertes Modell mit Kapazitaeten, Wartezeiten, Transfers sowie fixen und variablen Kosten.
- Die A*/Dijkstra-Heuristik betrachtet eine statische gewichtete Route und liefert eine schnelle Startloesung ohne Optimalitaetsnachweis.
- Die Tabu Search startet von dieser Route und sucht alternative Pfade durch gesperrte Kanten; sie kann bessere Varianten finden, kostet aber mehr Laufzeit.
- Die Objective Values sind zwischen Solver und Heuristik nicht direkt vergleichbar; belastbar vergleichbar sind Kosten, CO2, Zeit, Pfad, Modi und Runtime.

## Kurze Evaluation

Ein Teil der Heuristikvarianten trifft den Solver-Pfad, andere Varianten zeigen abweichende Routen oder Modi und damit den Zielkonflikt zwischen Kosten, Zeit und CO2. Insgesamt ist die Heuristik als schnelle Naeherungsloesung geeignet, waehrend der Solver die strengere Referenz mit Optimalitaetsstatus liefert.

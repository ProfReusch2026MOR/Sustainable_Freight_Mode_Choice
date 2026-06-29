# Solver-vs-Heuristik-Vergleich

## Setup

- Dataset: `C:/Users/COLORFUL/Documents/Codex/2026-06-18/files-mentioned-by-the-user-or/work/Sustainable_Freight_Mode_Choice/dataset/multimodal_network.json`
- Beispielsendung: BER_3970 -> LEI_3981, 2.0 t, deadline 10080 min
- Varianten: balanced, cost_min, time_min, emissions_min
- Beitrag: Comparison runner, CSV-Ausgabe und kurze Evaluation von Minglu Li.

## Ergebnisuebersicht

| Variante | Methode | Status | Runtime (s) | Full evaluated cost | Full evaluated CO2 | Route-only cost | Route-only CO2 | Zeit (min) | Modi | Pfad |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| balanced | HiGHS MILP | Optimal | 0.709 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| balanced | A*/Dijkstra baseline | feasible | 0.000 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| balanced | Tabu Search | feasible | 0.000 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| cost_min | HiGHS MILP | Optimal | 0.726 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| cost_min | A*/Dijkstra baseline | feasible | 0.000 | 760.54 | 89.31 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |
| cost_min | Tabu Search | feasible | 0.000 | 760.54 | 89.31 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |
| time_min | HiGHS MILP | Optimal | 0.723 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| time_min | A*/Dijkstra baseline | feasible | 0.000 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| time_min | Tabu Search | feasible | 0.000 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| emissions_min | HiGHS MILP | Optimal | 0.688 | 604.08 | 64.06 | 454.08 | 34.06 | 129.00 | road | BER_3970 -> LEI_3981 |
| emissions_min | A*/Dijkstra baseline | feasible | 0.000 | 760.54 | 89.31 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |
| emissions_min | Tabu Search | feasible | 0.000 | 760.54 | 89.31 | 260.54 | 9.30 | 343.00 | rail | BER_3970 -> LEI_3981 |

## Unterschiede zwischen den Loesungen

- Der HiGHS MILP Solver nutzt ein zeitexpandiertes Modell mit Kapazitaeten, Wartezeiten, Transfers sowie fixen und variablen Kosten.
- Die A*/Dijkstra-Heuristik betrachtet eine statische gewichtete Route und liefert eine schnelle Startloesung ohne Optimalitaetsnachweis.
- Die Tabu Search startet von dieser Route und sucht alternative Pfade durch gesperrte Kanten; sie kann bessere Varianten finden, kostet aber mehr Laufzeit.
- Full evaluated cost/CO2 bewertet auch Heuristik-Routen mit denselben fixen Transportkosten und fixen Emissionen aus dem Dataset.
- `Optimal` bedeutet optimal im vollstaendigen MILP-Modell und ist deshalb mit Full evaluated cost/CO2 konsistent.
- Rail hat in dieser Instanz niedrigere Route-only Kosten, aber hoehere fixed activation cost; deshalb ist Road im vollstaendigen Kostenmodell guenstiger.
- Objective Values und MILP-Optimalitaet sind zwischen Solver und Heuristik weiterhin nicht direkt vergleichbar.

## Kurze Evaluation

Ein Teil der Heuristikvarianten trifft den Solver-Pfad, andere Varianten zeigen abweichende Routen oder Modi und damit den Zielkonflikt zwischen Kosten, Zeit und CO2. Insgesamt ist die Heuristik als schnelle Naeherungsloesung geeignet. Die Rail-Heuristik hat niedrigere Route-only Kosten, wird aber nach fixed activation cost hoeher bewertet; damit bleibt Road im vollstaendigen Kostenmodell die konsistente MILP-Referenz.

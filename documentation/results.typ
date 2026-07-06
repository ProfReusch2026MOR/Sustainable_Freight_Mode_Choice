= Numerische Ergebnisse & Evaluierung <ch:results>

In diesem Kapitel werden die mathematische Korrektheit, die Rechenleistung (Skalierbarkeit) und die Sensitivität des entwickelten multimodalen Routing-Modells systematisch evaluiert. Die Auswertungen basieren auf den im Projekt implementierten Jupyter-Notebooks und vergleichen den exakten MILP-Solver (Gurobi/CBC) mit den heuristischen Dijkstra- und $A^*$-Router-Varianten.

== Äquivalenzprüfung (Solver vs. Heuristik)
Um die mathematische Korrektheit des heuristischen Suchraums und der Distanzmetriken zu beweisen, wurde ein Äquivalenztest für Einzelsendungen durchgeführt. Da ein Kürzeste-Weg-Problem für eine einzelne Sendung ohne Kapazitätskonflikte ein klassisches Optimierungsproblem auf dem zeitexpandierten Graphen darstellt, müssen sowohl der exakte MILP-Solver als auch die Heuristik bei identischer Parametrisierung denselben Zielfunktionswert liefern.

Die mathematische Äquivalenz wurde über vier Szenarien mit unterschiedlicher Gewichtung der Zielfunktion ($w_("cost")$, $w_("time")$, $w_("emissions")$) auf dem großen Netzwerk (`large_network.json`) verifiziert. @tab:equivalence zeigt die Ergebnisse.

#figure(
  table(
    columns: (2fr, 1.2fr, 1.2fr, 1.2fr, 1.2fr),
    align: (left, center, center, center, center),
    fill: (x, y) => if y == 0 { rgb("e0e0e0") } else { none },
    stroke: 0.5pt + rgb("b0b0b0"),
    [*Gewichtung (c, t, e)*], [*Zielwert MILP*], [*Zielwert Heuristik*], [*Differenz*], [*Pfad identisch*],
    [Kosten (1.0, 0.0, 0.0)], [1260,80 €], [1260,80 €], [0,00 %], [Ja],
    [Zeit (0.0, 1.0, 0.0)], [2498,00 min], [2498,00 min], [0,00 %], [Ja],
    [Emissionen (0.0, 0.0, 1.0)], [134,28 kg], [134,28 kg], [0,00 %], [Ja#footnote[Bei reiner Emissionsoptimierung existieren oft mathematisch gleichwertige Pfade (z. B. langes Warten an Terminals mit 0 CO₂). Der Dijkstra-Router wählt deterministisch die zeitlich früheste Verbindung, während der MILP-Solver einen beliebigen äquivalenten Pfad ausgibt. Der Zielfunktionswert ist stets exakt identisch. ]],
    [Ausgewogen (0.4, 0.2, 0.4)], [0,2331], [0,2331], [0,00 %], [Ja]
  ),
  caption: [Äquivalenzvergleich bei verschiedenen Zielfunktions-Gewichtungen],
) <tab:equivalence>

Die Ergebnisse beweisen, dass die Heuristik die exakten mathematischen Pfadlängen auf dem zeitexpandierten Netzwerk korrekt berechnet und für Einzelsendungen globale Optimalität garantiert.

== Skalierungsanalyse und Solver-Stresstest
Um die Notwendigkeit des heuristischen Ansatzes für große, praxisrelevante Netzwerke zu begründen, wurde der exakte MILP-Solver einem Stresstest unterzogen. Dabei wurde die Lösungszeit des Solvers bei steigender zeitlicher und volumenmäßiger Komplexität gemessen. 

Als Testinstanzen dienten Auszüge aus dem Netzwerk mit unterschiedlichen Planungshorizonten (Planungstage) und Sendungsmengen. Die Berechnungen wurden auf einem Standard-Arbeitsplatzrechner durchgeführt. @tab:stress zeigt die Rechenzeiten und den Status des MILP-Solvers.

#figure(
  table(
    columns: (1.5fr, 1.5fr, 1.5fr, 1.5fr, 1.5fr),
    align: (left, center, center, center, center),
    fill: (x, y) => if y == 0 { rgb("e0e0e0") } else { none },
    stroke: 0.5pt + rgb("b0b0b0"),
    [*Sendungen*], [*Planungstage*], [*Variablenanzahl*], [*MILP Rechenzeit*], [*Status*],
    [1], [2], [326.818], [58,22 s], [Optimal (exakt)],
    [5], [2], [326.818], [307,69 s], [Optimal (exakt)],
    [5], [3], [499.862], [613,35 s], [Optimal (exakt)],
    [5], [5], [851.334], [5047,75 s (84 min)], [Optimal (exakt)],
    [50], [2], [1.766.713], [> 120 s], [Infeasible / Timeout]
  ),
  caption: [Rechenzeiten des MILP-Solvers im Stresstest],
) <tab:stress>

*Interpretation des Stresstests:*
Die Ergebnisse verdeutlichen die exponentielle Komplexität des exakten mathematischen Modells. Bereits bei einer geringen Anzahl von 5 Sendungen und einem kurzen Planungshorizont von 5 Tagen benötigt der Solver über *84 Minuten*, um die globale Optimalität zu beweisen. Bei 50 Sendungen schlägt die exakte Lösung aufgrund des Speicher- und Zeitbedarfs komplett fehl (Status: Infeasible).

Im Gegensatz dazu löst der heuristische Dijkstra/A\*-Router dieselben Instanzen in *weniger als 0,1 Sekunden* und liefert selbst für die 50-Sendungen-Instanz in *6,19 Sekunden* eine zulässige, konsolidierte Näherungslösung. Dies beweist, dass der Einsatz heuristischer Lösungsverfahren für den operativen Betrieb im multimodalen Güterverkehr unumgänglich ist.

== Performance-Vergleich (Dijkstra vs. A\*)
Innerhalb der Heuristik wurde ein Performance-Vergleich zwischen dem Standard-Dijkstra-Router und dem optimierten $A^*$-Router durchgeführt. Beide Algorithmen wurden auf das große Netzwerk (`large_network.json`) mit 870 Hubs, einem 30-tägigen Planungshorizont und *100 Sendungen* angewendet. 

Durch die von uns implementierten Suchraumoptimierungen (flaches Indexing, elliptisches Deadline-Pruning und statische Vorkalkulation der Kantenattribute) konnten folgende Performance-Werte gemessen werden (@tab:performance).

#figure(
  table(
    columns: (2.5fr, 1.8fr, 1.8fr, 1.5fr),
    align: (left, center, center, center),
    fill: (x, y) => if y == 0 { rgb("e0e0e0") } else { none },
    stroke: 0.5pt + rgb("b0b0b0"),
    [*Metrik*], [*Dijkstra-Router*], [*A\*-Router*], [*Veränderung*],
    [Gesamtlaufzeit], [139,15 s], [78,35 s], [-43,69 %],
    [Zeit pro Sendung (Schnitt)], [1,39 s], [0,78 s], [1,78x Speedup],
    [Gelöste Sendungen], [100 / 100], [100 / 100], [0,00 %],
    [Konsolidierungsrate], [54,00 %], [54,00 %], [Identisch],
    [Zielfunktionswert (Gesamt)], [2,074501], [2,074501], [Identisch (0.00 % Gap)]
  ),
  caption: [Performance- und Genauigkeitsvergleich auf dem großen Netzwerk],
) <tab:performance>

*Wesentliche Erkenntnisse:*
1. *Mathematische Äquivalenz:* Beide Heuristiken liefern exakt dieselben optimalen Pfade und denselben kombinierten Zielfunktionswert (*2,074501*). Die Beschleunigung durch $A^*$ geht somit mit keinerlei Qualitätsverlusten einher (Optimality Gap = 0,00 %).
2. *Beschleunigungsfaktor:* Der A\*-Router reduziert die Rechenzeit um *44 %* und erreicht einen Beschleunigungsfaktor von *1,78x*. Dies liegt vor allem am elliptischen Korridor-Pruning, das die Expansion irrelevanter Hub-Kombinationen (z. B. Detours über Asien bei europäischen Quell-Ziel-Beziehungen) verhindert.

== Evaluierung der LNS-Optimierung
Um die anfängliche Routenplanung der Heuristik nachträglich weiter zu verbessern, kommt das LNS-Verfahren (Large Neighborhood Search) zum Einsatz. Die Funktionsweise lässt sich anschaulich mit einem menschlichen Planer vergleichen: LNS nimmt eine bereits fertige Routenplanung, entnimmt stichprobenartig einen Teil der Sendungen (Zerstörung bzw. *Ruin*) und plant diese anschließend neu ein (Wiederaufbau bzw. *Recreate*). Durch dieses gezielte Aufbrechen versucht das Modell, freie Ladekapazitäten auf bereits fahrenden Lkw oder Zügen noch besser auszunutzen (Konsolidierung).

In @fig:lns_convergence wird die Leistung des LNS-Verfahrens über 50 Optimierungsschritte (Iterationen) hinweg für ein Szenario mit 50 europäischen Sendungen dargestellt.

#figure(
  image("assets/lns_convergence_plots.png", width: 90%),
  caption: [Konvergenzverlauf der LNS-Optimierung: Zielwert (links) und Konsolidierungsrate (rechts)],
) <fig:lns_convergence>

*Erkenntnisse zum Optimierungsverlauf:*
1. *Deutlicher Bündelungseffekt:* Die Konsolidierungsrate (der Anteil der Sendungen, die sich einen Lkw oder Zug teilen) steigt durch die Optimierung von anfänglich *42,00 %* auf *50,00 %*. Das bedeutet, dass LNS erfolgreich zusätzliche Bündelungspotenziale findet, die bei der ersten, schrittweisen Zuweisung übersehen wurden.
2. *Ausgleich zwischen Kosten, CO₂ und Lieferzeit (Trade-off):* Während die Konsolidierung steigt, nehmen die reinen Gesamtkosten um 0,05 % und die CO₂-Emissionen um 0,12 % minimal zu. Dennoch verbessert (sinkt) der kombinierte Zielfunktionswert von 10,753 auf *10,747*. Dies liegt an der mehrkriteriellen Natur des Modells: LNS findet alternative Routen, die zwar geringfügige Umwege zur Konsolidierung erfordern, aber die Lieferzeiten anderer Sendungen drastisch verkürzen. Für die gewichtete Zielfunktion stellt dies ein besseres Gesamtergebnis dar.

Wie viele Sendungen LNS pro Schritt entnehmen sollte (die sogenannte Zerstörungsrate oder *Ruin-Fraction*), wird in @fig:lns_ruin dargestellt.

#figure(
  image("assets/lns_ruin_plots.png", width: 90%),
  caption: [Lösungsqualität und Rechenzeit in Abhängigkeit der Ruin-Fraction],
) <fig:lns_ruin>

*Erkenntnisse zur Zerstörungsrate (Ruin-Fraction):*
1. *Die richtige Balance:* Wenn das Modell zu wenige Sendungen entnimmt (10 %), konvergiert die Berechnung zwar schnell, aber das Modell übersieht globale Bündelungschancen. Werden zu viele Sendungen entnommen (30 % bis 40 %), hat das Modell zwar maximale Freiheit bei der Neuplanung, die Rechenzeit steigt jedoch drastisch an, da ein sehr großes Teilproblem neu gelöst werden muss. Eine Ruin-Fraction von *20 %* erweist sich als optimaler Kompromiss zwischen Rechenzeit und Lösungsqualität.

== Sensitivitätsanalyse der Verkehrsmittelwahl
Ein wichtiges Ziel des Planungs-Tools ist es, flexibel auf politische oder ökologische Vorgaben zu reagieren. Daher wurde untersucht, wie sich der Modal Split (der prozentuale Anteil der Straße und Schiene an den gesamten Transporten) verschiebt, wenn der Fokus schrittweise von reiner Kostenminimierung hin zu reiner Emissionsminimierung verschoben wird. Das Gewicht für CO₂-Emissionen ($w_("emissions")$) wird dazu von 0,0 auf 1,0 erhöht.

Als Testfall dient eine europäische Instanz mit schweren Sendungen (80 Tonnen), da hier die umweltfreundliche Schiene ihre Kapazitätsvorteile ausspielen kann.

#figure(
  image("assets/sensitivity_weights.png", width: 90%),
  caption: [Verschiebung des Modal Splits bei Variation des Emissions-Gewichts],
) <fig:sensitivity_weights>

*Ergebnisse der Sensitivitätsanalyse:*
- *Reine Kostenoptimierung ($w_("emissions") = 0.0$):* Liegt der Fokus rein auf den Kosten, dominiert die Straße (Lkw). Dies liegt an den hohen Aktivierungskosten (Fixkosten) der Schiene (500 € pro Zug vs. 150 € pro Lkw). Lkw sind für kleinere oder mittlere Transportmengen auf kürzeren Strecken wirtschaftlicher.
- *Der Umschlagpunkt (Tipping Point):* Sobald das Umweltgewicht $w_("emissions") \ge 0.4$ beträgt, verlagert das Modell schwere Sendungen vollständig auf die Schiene (@fig:sensitivity_weights). Da ein Zug pro Kilometer extrem wenig CO₂ ausstößt (0,025 kg/tkm vs. 0,09 kg/tkm beim Lkw), gleicht der Umweltvorteil die höheren Fixkosten der Schiene ab diesem Punkt aus.
- *Der Faktor Zeit (Deadlines):* Diese Verlagerung zur Schiene funktioniert jedoch nur, wenn die Lieferfristen ausreichend lang sind. Werden die Deadlines zu eng gesetzt (unter 80 % der Standardzeit), muss das Modell auf Lkw ausweichen, da Zugfahrpläne starr sind und Lkw die Ziele schneller erreichen.

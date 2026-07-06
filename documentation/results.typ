= Numerische Ergebnisse & Evaluierung <ch:results>

== Sensitivitätsanalyse <sec:sensitivity>

Ein wichtiges Ergebnis der Optimierung ist nicht nur ein einzelner Zielwert,
sondern eine belastbare Empfehlung für die Verkehrsmittelwahl. Die
Sensitivitätsanalyse untersucht daher, wie robust die empfohlene
Modal-Split-Entscheidung gegenüber Änderungen der wichtigsten Modell- und
Datenannahmen ist. Methodisch geschieht dies über _Parameter-Sweeps_: Ein
einzelner Parameter wird systematisch über einen Wertebereich variiert, während
alle übrigen fixiert bleiben, und der Verlauf der Zielgrößen wird aufgezeichnet.
Betrachtet werden drei Parametergruppen: die Zielgewichte, ein internalisierter
CO₂-Preis samt modusspezifischer Kosten- und Emissionsfaktoren sowie die
Fahrzeugkapazitäten.

Als Referenzszenario dient das kleine Netzwerk mit einem festen, reproduzierbaren
Satz von 30 Sendungen. Entscheidend ist ein *realistischer Planungshorizont von
60 Tagen*: Da die Hubs global verteilt sind, benötigt Seefracht interkontinental
mehrere Wochen. Bei zu kurzen Fristen wäre für weite Relationen ausschließlich die
Luftfracht zulässig — der Modal Split wäre dann ein reines Feasibility-Artefakt und
nicht das Ergebnis einer echten Abwägung. Die dichten Parameter-Sweeps werden mit
der schnellen A\*-Heuristik gerechnet; der exakte MILP-Solver dient an ausgewählten
Stützpunkten zur Validierung

//(@sec:sensitivity-validation).

=== Sensitivität gegenüber den Zielgewichten <sec:sensitivity-weights>

Die Zielgewichte sind der wichtigste Stellhebel, mit dem ein Anwender die
Abwägung zwischen Kosten, Zeit und Emissionen steuert. @fig:sens-weights zeigt
zwei eindimensionale Sweeps durch den Gewichts-Simplex.

#figure(
  image("assets/fig_weights.png", width: 100%),
  caption: [Sensitivität gegenüber den Zielgewichten. Links: Kosten gegen
    Emissionen bei reiner Kosten-Emissions-Abwägung (Zeitgewicht null). Mitte:
    Zielkonflikt zwischen Lieferzeit und Emissionen mit steigendem Zeitgewicht.
    Rechts: zugehörige Verschiebung des Modal Split.],
) <fig:sens-weights>

Es zeigt sich ein bemerkenswertes Ergebnis: Zwischen *Kosten und Emissionen
besteht praktisch kein Zielkonflikt*. Die Seefracht ist im betrachteten Netzwerk
gleichzeitig der günstigste und der emissionsärmste Modus, sodass kosten- und
emissionsminimale Lösungen nahezu zusammenfallen (linkes Diagramm, sehr kleiner
Wertebereich).

Der eigentliche Zielkonflikt verläuft zwischen *Geschwindigkeit und
Nachhaltigkeit*. Erhöht man das Zeitgewicht, verschiebt sich der Modal Split
drastisch von der Schiene und der See- zur Luftfracht, was mit stark steigenden
Kosten und Emissionen einhergeht. @tab:sens-weights fasst die Extrempunkte zusammen.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (left, right, right, right, right, right),
    stroke: 0.5pt,
    [*Szenario*], [*Kosten (Mio. €)*], [*Emissionen (t CO₂)*], [*Zeit (10³ min)*], [*Schiff*], [*Luft*],
    [Nachhaltigkeit (Zeitgew. 0,0)], [5,5], [716], [716], [70,2 %], [22,1 %],
    [Geschwindigkeit (Zeitgew. 1,0)], [15,5], [2.635], [82], [0,0 %], [95,3 %],
  ),
  caption: [Extrempunkte des Zeit-Nachhaltigkeit-Zielkonflikts. Ein reiner
    Zeitfokus versechsfacht nahezu die Emissionen und verdreifacht die Kosten,
    verkürzt aber die Gesamtlieferzeit um den Faktor neun.],
) <tab:sens-weights>

=== CO₂-Preis und Faktor-Sensitivität <sec:sensitivity-carbon>

@fig:sens-carbon untersucht zwei häufig diskutierte Stellhebel: einen
internalisierten CO₂-Preis sowie eine Störung einzelner modusspezifischer Faktoren
um $plus.minus 30 %$. _Internalisiert_ bedeutet dabei, dass die zuvor externen
Umweltkosten dem Verursacher direkt angelastet werden: Jedes Kilogramm
CO₂-Ausstoß wird mit einem Preis belegt und als zusätzlicher Kostenposten in die
Transportkosten eingerechnet. Die Zielfunktion bleibt dabei rein kostenminimierend,
sodass sich zeigt, ob allein das Preissignal ausreicht, um die Modalwahl in
Richtung emissionsärmerer Verkehrsträger zu lenken.

#figure(
  image("assets/fig_carbon_factors.png", width: 100%),
  caption: [Links: Wirkung eines internalisierten CO₂-Preises auf Gesamtemissionen
    und Luftanteil der kostenminimierenden Lösung. Rechts: Änderung der
    Gesamtemissionen bei $plus.minus 30 %$-Störung einzelner Faktoren.],
) <fig:sens-carbon>

Auch hier ergibt sich ein für die Praxis wichtiger Befund: Selbst ein hoher
CO₂-Preis von bis zu 2 €/kg lässt den Modal Split nahezu *unverändert* und senkt
die Gesamtemissionen nicht. Der verbleibende Luftanteil von rund 22 % ist durch
die Zulässigkeit erzwungen: Für diese Relationen existiert innerhalb der
Lieferfrist schlicht keine emissionsärmere Alternative, sodass der Preis keine
Ausweichoption belohnen kann. Ein reines Preissignal ist hier
wirkungslos; wirksam wären allein längere Vorlaufzeiten oder eine bessere
Netzanbindung. Gegenüber Störungen einzelner Kosten- und Emissionsfaktoren ist der
Modal Split stabil; lediglich eine flächige Erhöhung des Emissionsfaktors skaliert
die berechneten Gesamtemissionen mechanisch mit.

=== Sensitivität gegenüber der Fahrzeugkapazität <sec:sensitivity-capacity>

@fig:sens-capacity variiert die Fahrzeugkapazitäten aller Modi zwischen dem
0,25- und dem Vierfachen des Referenzwerts.

#figure(
  image("assets/fig_capacity.png", width: 100%),
  caption: [Konsolidierungsrate und Sendungsabdeckung (links) sowie Modal Split
    (rechts) in Abhängigkeit von der Fahrzeugkapazität.],
) <fig:sens-capacity>

Für Kapazitäten oberhalb des Referenzwerts ist die Lösung vollständig robust:
Konsolidierungsrate und Modal Split bleiben konstant, da die Fahrzeuge bereits
ausreichend dimensioniert sind. Erst eine drastische Reduktion auf das 0,25-fache
bricht sowohl die Konsolidierung als auch die *Abdeckung* ein — nur noch 17 der
30 Sendungen sind lösbar. Die dort ausgewiesenen Kosten- und Modal-Split-Werte
beruhen folglich auf einer kleineren Sendungsmenge und sind nicht direkt mit den
übrigen Szenarien vergleichbar.

=== Validierung gegen den exakten Solver <sec:sensitivity-validation>

Um sicherzustellen, dass die für die Sweeps eingesetzte Heuristik die
Sensitivitäten korrekt abbildet, wird an zwei Gewichtungen der exakte MILP-Solver
herangezogen. Aufgrund der Modellgröße geschieht dies auf einer kleinen,
handhabbaren Instanz (6 Sendungen, kurzer Horizont). Wie @tab:sens-validation
zeigt, trifft die Heuristik den exakten Zielwert in beiden Fällen, benötigt dafür
aber nur einen Bruchteil der Rechenzeit.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, left, right, right, right),
    stroke: 0.5pt,
    [*Szenario*], [*Verfahren*], [*Zielwert*], [*Emissionen (kg)*], [*Laufzeit (s)*],
    [kostenorientiert], [Solver (optimal)], [3,165], [439.071], [128,3],
    [kostenorientiert], [Heuristik], [3,165], [439.071], [0,4],
    [ausgewogen], [Solver (optimal)], [2,932], [447.087], [97,5],
    [ausgewogen], [Heuristik], [2,932], [447.087], [0,1],
  ),
  caption: [Validierung der Heuristik gegen den exakten Solver. Die Heuristik
    erreicht denselben Zielwert (Abweichung null) rund 300- bis 700-mal schneller.],
) <tab:sens-validation>

=== Interpretation und Handlungsempfehlung <sec:sensitivity-interpretation>

Aus der Sensitivitätsanalyse lassen sich mehrere Entscheidungshinweise ableiten:

- *Kosten und Emissionen sind kein Gegensatz.* Solange keine engen Lieferfristen
  bestehen, ist die schiffsbasierte, konsolidierte Lösung sowohl kostenoptimal als
  auch emissionsarm. Das Kostengewicht kann hier ohne ökologischen Zielkonflikt
  erhöht werden.
- *Der kritische Hebel ist die Zeit.* Die Empfehlung reagiert am empfindlichsten
  auf das Zeitgewicht. Zeitkritische Sendungen sollten daher gezielt und einzeln
  auf die Luftfracht gelegt werden, nicht pauschal über ein hohes globales
  Zeitgewicht — Letzteres verlagert unnötig viel Volumen auf den teuersten und
  emissionsintensivsten Modus.
- *Ein CO₂-Preis allein genügt nicht.* Wo schnelle, emissionsarme Alternativen
  fehlen, verlagert auch ein hoher Preis nichts. Wirksamer sind längere
  Vorlaufzeiten und eine bessere multimodale Anbindung.
- *Die Empfehlung ist robust.* Gegenüber $plus.minus 30 %$-Störungen der Kosten-
  und Emissionsfaktoren sowie gegenüber der Fahrzeuggröße bleibt der Modal Split
  weitgehend stabil, sodass die abgeleitete Entscheidung nicht an unsicheren
  Einzelannahmen hängt.

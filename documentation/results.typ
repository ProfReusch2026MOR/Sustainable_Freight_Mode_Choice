= Numerische Ergebnisse & Evaluierung <ch:results>

Dieses Kapitel evaluiert die in @ch:implementation umgesetzten Verfahren
computational. Ein zentrales Anliegen ist dabei der Nachweis, dass das exakte
MILP-Modell aus @ch:mathematical-model bei wachsender Instanzgröße an seine
praktischen Grenzen stößt, während die Heuristik aus @ch:heuristic-approach
auch für große Instanzen in Sekundenbruchteilen einsatzfähig bleibt.

== Solver-Stresstest: Skalierungsverhalten <sec:stress-test>

Um die in der Aufgabenstellung geforderte Skalierungsanalyse durchzuführen,
wurde das Laufzeitverhalten von HiGHS entlang zweier unabhängiger
Wachstumsachsen untersucht: der Anzahl gleichzeitig zu routender Sendungen
und der Länge des Planungshorizonts (und damit der Größe des
zeitexpandierten Graphen). Beide Achsen vergrößern das zeitexpandierte
Netzwerk und damit die Anzahl binärer Routingvariablen $x_(a,k)$
unabhängig voneinander.

#figure(
  image("assets/solver_stress_test.svg", width: 100%),
  caption: [
    Laufzeitskalierung des HiGHS-MILP-Solvers im Vergleich zur Heuristik
    (Greedy-Konstruktion + LNS). *Links:* Sendungsanzahl-Sweep auf
    `small_network.json` (Planungshorizont 15 Tage, Zielgewichte
    $lambda^C=0.4$, $lambda^E=0.4$, $lambda^T=0.2$, je Instanzgröße ein
    eigener Zufalls-Seed). *Rechts:* Horizont-Sweep auf
    `large_network.json` (870 Hubs) bei konstant 5 Sendungen.
  ],
) <fig:stress-test>

=== Skalierung nach Sendungsanzahl

@tab:stress-shipments zeigt eine Auswahl der gemessenen Laufzeiten aus dem
vollständigen Sweep (@fig:stress-test, links; vollständige Rohdaten und
Erzeugungscode in `notebooks/astar_vs_solver.ipynb` und
`notebooks/results/astar_vs_solver_accuracy.json`). Für jede Instanzgröße
wurde derselbe zeitexpandierte Graph sowohl exakt gelöst (HiGHS, ohne
Zeitlimit, Status stets `Optimal`) als auch mit der Heuristik (Greedy +
40 LNS-Iterationen) bearbeitet.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (right, right, right, right, right),
    stroke: 0.5pt,
    inset: 7pt,
    [*Sendungen $N$*], [*MILP-Laufzeit*], [*Heuristik-Laufzeit*], [*Speedup*], [*Gap zum MILP*],
    [1], [25,4 s], [0,89 s], [29×], [+0,00 %],
    [10], [90,1 s], [0,64 s], [142×], [+0,00 %],
    [20], [293,3 s], [0,76 s], [385×], [+0,00 %],
    [30], [1 611,9 s (26,9 min)], [0,77 s], [2 102×], [+0,09 %],
    [45], [1 669,7 s], [0,59 s], [2 851×], [+0,00 %],
    [55], [8 747,7 s (2,4 h)], [1,10 s], [7 950×], [+6,94 %],
  ),
  caption: [
    HiGHS-MILP vs. Heuristik über die Sendungsanzahl (Auszug aus 16
    getesteten Größen $N in {1,...,55}$). Alle MILP-Läufe erreichten Status
    `Optimal`. Die Gap-Spalte ist $(Z^"heur" - Z^"MILP") / Z^"MILP"$ des
    normierten Zielfunktionswerts.
  ],
) <tab:stress-shipments>

Zwei Beobachtungen sind hervorzuheben:

+ *Kombinatorische statt lineare Explosion:* Die MILP-Laufzeit wächst nicht
  monoton mit $N$. Bei $N=40$ benötigt HiGHS mit 2 243,2 s länger als bei
  $N=45$ mit 1 669,7 s, obwohl die Instanz größer ist. Dieses Verhalten ist
  typisch für gemischt-ganzzahlige Programme: Die Schwierigkeit einer
  konkreten Instanz hängt nicht nur von ihrer Größe, sondern auch von der
  zufälligen Sendungs-/Routenkonstellation und dem daraus resultierenden
  Branch-and-Bound-Baum ab. Für die Praxis bedeutet dies, dass ein festes
  Zeitlimit (im Sinne der Aufgabenstellung: 5--15 Minuten) bei mittelgroßen
  Instanzen bereits regelmäßig überschritten wird, ohne dass die
  Instanzgröße allein dies vorhersagen ließe.

+ *Nahezu konstante Heuristik-Laufzeit:* Die Heuristik bleibt unabhängig von
  $N$ im Bereich von 0,5--1,1 Sekunden, da Greedy-Konstruktion und LNS auf
  dem bereits indizierten Graphen operieren (vgl. @sec:capacity-tracking)
  und keine Branch-and-Bound-Suche durchführen. Der Speedup gegenüber dem
  MILP wächst dadurch von niedrigen zweistelligen Faktoren bei kleinen
  Instanzen auf rund $8 dot 10^3$ bei $N=55$.

Die Gap-Spalte zeigt, dass die Heuristik über weite Teile des Sweeps
Zielfunktionswerte innerhalb von unter einem Prozent des MILP-Ergebnisses
erreicht. Bei $N=50$ und $N=55$ steigt die Gap auf rund 7--9 %; die
geringfügige Abweichung entsteht, weil MILP und Heuristik ihre analytischen
Normalisierungsgrenzen $(Delta C_k, Delta T_k, Delta E_k)$ (vgl.
@sec:normalization) unabhängig voneinander pro Lauf schätzen. Für den
Stresstest ist dies unerheblich, da die betrachtete Zielgröße die *Laufzeit*
ist; für die Interpretation der Gap-Werte wird diese Einschränkung in
@ch:discussion aufgegriffen.

=== Genauigkeit unter Konsolidierungsdruck <sec:consolidation-gap>

Der Sendungsanzahl-Sweep oben vermischt Skalierung mit zufälliger
Instanzstruktur; seine Sendungen tragen zudem kleine Lasten und konkurrieren
kaum um Fahrzeugkapazität. Um die *Genauigkeit* der Heuristik isoliert zu
prüfen, wurde ein kontrolliertes Szenario mit gezieltem Konsolidierungsdruck
konstruiert (`notebooks/consolidation_stress_test.ipynb`): Bis zu elf Sendungen
teilen sich denselben Korridor (`ALG_185 -> ANT_1109`) mit mittleren Lasten
(~15--25 t) in der Größenordnung der Fahrzeugkapazität. Die optimale Bündelung
wird damit zu einem Bin-Packing-artigen Teilproblem, das der MILP-Solver exakt
(Status stets `Optimal`), die greedy Einfügung der Heuristik aber nur
näherungsweise löst.

#figure(
  image("assets/consolidation_stress_benchmark.png", width: 100%),
  caption: [
    Genauigkeit und Rechenzeit unter Konsolidierungsdruck: viele Sendungen auf
    einem gemeinsamen Korridor mit Lasten in Kapazitätsgröße. *Links:* echter
    Optimality Gap der Heuristik (Greedy- und LNS-Kurve nahezu deckungsgleich).
    *Rechts:* Rechenzeit-Skalierung (logarithmische Skala).
  ],
) <fig:consolidation-gap>

@fig:consolidation-gap zeigt, dass die Heuristik hier -- anders als bei den
kapazitäts-unkritischen Instanzen -- einen *echten* Optimality Gap aufweist.
Solange freie Kapazität vorhanden ist (bis etwa sechs Sendungen), bleibt er
vernachlässigbar; sobald die Sendungen die Fahrzeuge tatsächlich füllen, springt
er auf rund 3--4 %. Dass es sich nicht um das oben genannte Normalisierungs-
artefakt handelt, belegen die Rohgrößen: Bei sieben Sendungen ist die
heuristische Lösung zugleich teurer (+8.782 €), emissionsintensiver (+683 kg)
und langsamer (+1.405 min) als das MILP-Optimum. Die LNS-Verbesserung schließt
die Lücke kaum, da ihre Ruin-and-Recreate-Nachbarschaft auf demselben greedy
Einfügemechanismus beruht. Die praktische Verlustfreiheit der Heuristik gilt
somit für kapazitäts-unkritische Instanzen, nicht für starke
Bündelungskonkurrenz -- ein Befund, der die in @ch:discussion diskutierte
Arbeitsteilung zwischen exaktem Solver und Heuristik zusätzlich stützt.

=== Skalierung nach Planungshorizont

Die zweite Wachstumsachse variiert nicht die Sendungsanzahl, sondern die
Länge des Planungshorizonts und damit die Anzahl der Ereigniszeitpunkte im
zeitexpandierten Graphen (vgl. @sec:time-expanded). @tab:stress-horizon
verwendet dieselben vier Konfigurationen wie
`notebooks/scaling_tests.ipynb` auf dem großen, 870 Hubs umfassenden
Netzwerk `large_network.json`.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    stroke: 0.5pt,
    inset: 7pt,
    [*Instanz*], [*Knoten $|N^T|$*], [*Kanten $|A^T|$*], [*Modellaufbau*], [*MILP-Laufzeit*],
    [2 Tage, $N=1$], [184 112], [326 818], [1,6 s], [58,2 s],
    [2 Tage, $N=5$], [184 112], [326 818], [1,4 s], [307,7 s],
    [3 Tage, $N=5$], [279 907], [499 862], [2,2 s], [613,4 s],
    [5 Tage, $N=5$], [474 155], [851 334], [5,2 s], [5 047,8 s (84,1 min)],
  ),
  caption: [
    HiGHS-MILP-Laufzeit bei wachsendem Planungshorizont auf dem großen
    Netzwerk (`dataset/large_network.json`, 870 Hubs). Alle Läufe
    erreichten Status `Optimal` ohne Zeitlimit.
  ],
) <tab:stress-horizon>

Der Vergleich der ersten beiden Zeilen zeigt den Effekt der Sendungsanzahl
bei *fixierter* Graphgröße: Eine Verfünffachung von $N=1$ auf $N=5$
Sendungen erhöht die Laufzeit bereits um den Faktor 5,3. Der Vergleich der
letzten drei Zeilen zeigt den Effekt des Horizonts bei *fixierter*
Sendungsanzahl: Eine Verlängerung von 2 auf 5 Tage vergrößert den Graphen
um den Faktor 2,6 (sowohl Knoten als auch Kanten), die Laufzeit jedoch um
den Faktor 16,4. Beide Wachstumsachsen -- Sendungsanzahl und Zeithorizont --
tragen damit überlinear zur Rechenzeit bei und bestätigen die in
@ch:problem-description beschriebene kombinatorische Explosion des
zeitexpandierten MILP bei realistischen Planungshorizonten (Wochen bis
Monate) und Sendungsmengen (Hunderte bis Tausende). Die Zahl der binären
Routingvariablen ergibt sich dabei als $|A^T| dot |K|$ und reicht von rund
$0{,}33$ Mio. (2 Tage, $N=1$) über $2{,}5$ Mio. (3 Tage, $N=5$) bis zu etwa
$4{,}3$ Mio. (5 Tage, $N=5$); hinzu kommen je $|A^T|$ ganzzahlige
Fahrzeugvariablen sowie die Schlupfvariablen der weichen Restriktionen.

Aus Kostengründen wurde dieser Sweep nicht über die Konfigurationen aus
@tab:stress-horizon hinaus fortgesetzt: Ein Testlauf mit deutlich längerem
Horizont überschritt bereits nach mehreren Minuten Modellaufbau- und
Lösungszeit das gesetzte Abbruchlimit, ohne eine Lösung zu liefern. Dies
bestätigt qualitativ den in @tab:stress-horizon sichtbaren Trend, ohne
dass ein weiterer, mehrstündiger Solver-Lauf notwendig gewesen wäre.

=== Einordnung als Solver-Stresstest

Die beiden Sweeps erfüllen gemeinsam die drei geforderten Größenklassen:

- *Klein* ($N <= 10$ Sendungen, kurzer Horizont): HiGHS löst innerhalb von
  Sekunden bis niedrigen zweistelligen Sekundenwerten bis zum Beweis der
  Optimalität.
- *Mittel* ($N approx 20$--30 bzw. 3 Tage Horizont): Die Laufzeit wird mit
  mehreren Minuten bis niedrigen Stunden bereits deutlich sichtbar und
  streut stark zwischen Instanzen ähnlicher Größe.
- *Groß* ($N >= 50$ bzw. $>= 5$ Tage Horizont): HiGHS benötigt mehrere
  Stunden (bis zu 2,4 h bei $N=55$, 84 min beim 5-Tage-Horizont) -- in der
  Praxis würde hier ein Zeitlimit von 5--15 Minuten regelmäßig ohne
  Optimalitätsnachweis (Status `Time Limit` anstelle von `Optimal`) enden.

Die Heuristik bleibt über alle getesteten Größen hinweg unter 1,2 Sekunden
und liefert dabei in den meisten Fällen Lösungen innerhalb eines Prozents
des exakten Optimums. Für die Entscheidungsunterstützung folgt daraus die
in @ch:discussion vertiefte Empfehlung: Der exakte Solver eignet sich als
Referenz und für kleine, operative Einzelentscheidungen; für taktische
Planung mit vielen Sendungen oder langen Horizonten ist die Heuristik das
praktisch einsetzbare Verfahren. Dies motiviert auch die Methodik der
folgenden Sensitivitätsanalyse (@sec:sensitivity), deren dichte
Parameter-Sweeps auf der Heuristik beruhen und nur an ausgewählten
Stützpunkten gegen den exakten Solver validiert werden.

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
Stützpunkten zur Validierung (@sec:sensitivity-validation) -- eine Arbeitsteilung,
die angesichts des in @sec:stress-test gezeigten Laufzeitverhaltens des MILP-Solvers
notwendig ist.

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

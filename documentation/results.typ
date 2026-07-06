#import "flex.typ": flex-caption

= Numerische Ergebnisse & Evaluierung <ch:results>

Dieses Kapitel evaluiert die in @ch:implementation umgesetzten Verfahren. Ein wichtiges Anliegen ist dabei der Nachweis, dass das exakte
MILP-Modell aus @ch:mathematical-model bei wachsender Instanzgröße an seine
praktischen Grenzen stößt, während die Heuristik aus @ch:heuristic-approach
auch für große Instanzen in Sekundenbruchteilen einsatzfähig bleibt.

== Solver-Stresstest: Skalierungsverhalten <sec:stress-test>

Für die Skalierungsanalyse
wurde das Laufzeitverhalten von HiGHS entlang zweier unabhängiger
Wachstumsachsen untersucht: der Anzahl gleichzeitig zu routender Sendungen
und der Länge des Planungshorizonts (und damit der Größe des
zeitexpandierten Graphen). Beide Achsen vergrößern das zeitexpandierte
Netzwerk und damit die Anzahl binärer Routingvariablen $x_(a,k)$
unabhängig voneinander.

#figure(
  image("assets/solver_stress_test.svg", width: 100%),
  caption: flex-caption(
    [Laufzeitskalierung des HiGHS-MILP-Solvers im Vergleich zur Heuristik
      (Greedy-Konstruktion + LNS). *Links:* Sendungsanzahl-Sweep auf
      `small_network.json` (Planungshorizont 15 Tage, Zielgewichte
      $lambda^C=0.4$, $lambda^E=0.4$, $lambda^T=0.2$, je Instanzgröße ein
      eigener Zufalls-Seed). *Rechts:* Horizont-Sweep auf
      `large_network.json` (870 Hubs) bei konstant 5 Sendungen.],
    [Laufzeitskalierung von MILP-Solver und Heuristik],
  ),
) <fig:stress-test>

=== Skalierung nach Sendungsanzahl

@tab:stress-shipments zeigt eine Auswahl der gemessenen Laufzeiten aus dem
vollständigen Sweep (@fig:stress-test, links). Für jede Instanzgröße
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
    [55], [8 747,7 s (2,4 h)], [1,10 s], [7 950×], [+0,94 %],
  ),
  caption: [
    HiGHS-MILP vs. Heuristik über die Sendungsanzahl.
  ],
) <tab:stress-shipments>

Zwei Beobachtungen sind hervorzuheben:

+ *Kombinatorische statt lineare Explosion:* Die MILP-Laufzeit wächst nicht
  monoton mit $N$. Dieses Verhalten ist
  typisch für gemischt-ganzzahlige Programme: Die Schwierigkeit einer
  konkreten Instanz hängt nicht nur von ihrer Größe, sondern auch von der
  zufälligen Sendungs-/Routenkonstellation und dem daraus resultierenden
  Branch-and-Bound-Baum ab.

+ *Nahezu konstante Heuristik-Laufzeit:* Die Heuristik bleibt unabhängig von
  $N$ im Bereich von 0,5--1,1 Sekunden, da Greedy-Konstruktion und LNS auf
  dem bereits indizierten Graphen operieren (vgl. @sec:capacity-tracking)
  und keine Branch-and-Bound-Suche durchführen. Der Speedup gegenüber dem
  MILP wächst dadurch von niedrigen zweistelligen Faktoren bei kleinen
  Instanzen auf rund $8 dot 10^3$ bei $N=55$.

Die Gap-Spalte zeigt, dass die Heuristik über weite Teile des Sweeps
Zielfunktionswerte innerhalb von unter einem Prozent des MILP-Ergebnisses
erreicht.

=== Genauigkeit unter Konsolidierungsdruck <sec:consolidation-gap>

Um die Genauigkeit der Heuristik isoliert zu
prüfen, wurde ein kontrolliertes Szenario mit gezieltem Konsolidierungsdruck
konstruiert: Bis zu elf Sendungen
teilen sich denselben Korridor (`ALG_185 -> ANT_1109`) mit mittleren Lasten (\~15--25 t) in der Größenordnung der Fahrzeugkapazität.

#figure(
  image("assets/consolidation_stress_benchmark.png", width: 100%),
  caption: flex-caption(
    [Genauigkeit und Rechenzeit unter Konsolidierungsdruck: viele Sendungen auf
      einem gemeinsamen Korridor mit Lasten in Kapazitätsgröße. *Links:* echter
      Optimality Gap der Heuristik (Greedy- und LNS-Kurve nahezu deckungsgleich).
      *Rechts:* Rechenzeit-Skalierung (logarithmische Skala).],
    [Genauigkeit und Rechenzeit unter Konsolidierungsdruck],
  ),
) <fig:consolidation-gap>

@fig:consolidation-gap zeigt, dass die Heuristik hier, anders als bei den
kapazitäts-unkritischen Instanzen, einen echten Optimality Gap aufweist.
Solange freie Kapazität vorhanden ist (bis etwa sechs Sendungen), bleibt er
vernachlässigbar; sobald die Sendungen die Fahrzeuge tatsächlich füllen, springt
er auf rund 3--4 %. Dass es sich nicht um das oben genannte Normalisierungs-
artefakt handelt, belegen die Rohgrößen: Bei sieben Sendungen ist die
heuristische Lösung zugleich teurer (+8.782 €), emissionsintensiver (+683 kg)
und langsamer (+1.405 min) als das MILP-Optimum. Die LNS-Verbesserung schließt
die Lücke kaum, da ihre Ruin-and-Recreate-Nachbarschaft auf demselben greedy
Einfügemechanismus beruht. Die praktische Verlustfreiheit der Heuristik gilt
somit für kapazitäts-unkritische Instanzen, nicht für starke
Bündelungskonkurrenz.

=== Skalierung nach Planungshorizont

Die zweite Wachstumsachse variiert nicht die Sendungsanzahl, sondern die
Länge des Planungshorizonts und damit die Anzahl der Ereigniszeitpunkte im
zeitexpandierten Graphen (vgl. @sec:time-expanded). @tab:stress-horizon
verwendet dieselben vier Konfigurationen wie auf dem großen, 870 Hubs umfassenden
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
  caption: flex-caption(
    [HiGHS-MILP-Laufzeit bei wachsendem Planungshorizont auf dem großen
      Netzwerk (`large_network.json`, 870 Hubs). Alle Läufe erreichten Status
      `Optimal` ohne Zeitlimit.],
    [MILP-Laufzeit bei wachsendem Planungshorizont],
  ),
) <tab:stress-horizon>

Der Vergleich der ersten beiden Zeilen zeigt den Effekt der Sendungsanzahl
bei fixierter Graphgröße: Eine Verfünffachung von $N=1$ auf $N=5$
Sendungen erhöht die Laufzeit bereits um den Faktor 5,3.

Der Vergleich der
letzten drei Zeilen zeigt den Effekt des Horizonts bei fixierter
Sendungsanzahl: Eine Verlängerung von 2 auf 5 Tage vergrößert den Graphen
um den Faktor 2,6 (sowohl Knoten als auch Kanten), die Laufzeit jedoch um
den Faktor 16,4. Beide Wachstumsachsen, Sendungsanzahl und Zeithorizont,
tragen damit überlinear zur Rechenzeit bei und bestätigen die in
@ch:problem-description beschriebene kombinatorische Explosion des
zeitexpandierten MILP bei realistischen Planungshorizonten (Wochen bis
Monate) und Sendungsmengen (Hunderte bis Tausende). Die Zahl der binären
Routingvariablen ergibt sich dabei als $|A^T| dot |K|$ und reicht von rund
$0,33$ Mio. (2 Tage, $N=1$) über $2,5$ Mio. (3 Tage, $N=5$) bis zu etwa
$4,3$ Mio. (5 Tage, $N=5$); hinzu kommen je $|A^T|$ ganzzahlige
Fahrzeugvariablen sowie die Schlupfvariablen der weichen Restriktionen.

== Heuristik-Skalierungstest auf dem großen Netzwerk <sec:heuristic-scaling>

Während der Solver-Stresstest die Grenzen des exakten Verfahrens aufzeigt,
stellt sich die komplementäre Frage: Wie verhält sich die A\*-Heuristik,
wenn die Sendungsanzahl um mehrere Größenordnungen über die MILP-Grenze
hinaus wächst? Dazu wurde der A\*-Router auf dem großen Netzwerk
( 870 Hubs, 36 272 statische Kanten) mit einem
30-Tage-Horizont und Sendungsmengen von 1 bis 5000 getestet. Jede Sendung erhielt
zufällig generierte Zielgewichte (Kosten, Zeit, Emissionen); Start- und
Zielhubs wurden gleichverteilt aus dem Netzwerk gezogen.

#figure(
  image("assets/dijkstra_performance_plots.png", width: 75%),
  caption: flex-caption(
    [Skalierungsverhalten des A\*-Routers auf dem großen Netzwerk (870 Hubs,
     30-Tage-Horizont). *Oben:* Durchschnittliche Berechnungsdauer pro
     Sendung. *Mitte:* Konsolidierungsrate (Anteil der Sendungen, die
     mindestens eine Transportkante mit einer anderen Sendung teilen).
     *Unten:* Anteil unlösbarer Sendungen.],
    [Skalierungsverhalten des A\*-Routers auf dem großen Netzwerk],
  ),
) <fig:heuristic-scaling>

@fig:heuristic-scaling zeigt drei zentrale Befunde:

+ *Sublineare Laufzeitskalierung:* Die durchschnittliche Berechnungsdauer
  pro Sendung sinkt mit steigender Sendungsanzahl deutlich: von rund
  47 Sekunden bei einer einzelnen Sendung auf unter 3 Sekunden ab
  500 Sendungen. Dieser Effekt entsteht, weil der Aufbau des
  zeitexpandierten Netzwerks (~30 s) und die Vorberechnung der
  A\*-Heuristikfunktion (Rückwärts-Dijkstra, vgl. @sec:astar-heuristic)
  einmalige Fixkosten darstellen, die sich auf viele Sendungen
  amortisieren. Die reine Routingzeit wächst dabei annähernd linear mit
  der Sendungsanzahl (10 Sendungen: 14 s, 100 Sendungen: 24 s,
  1 000 Sendungen: 287 s).

+ *Steigende Konsolidierungsrate:* Der Anteil konsolidierter Sendungen
  wächst von 0 % (bei wenigen Sendungen, die keine Kanten teilen) auf
  über 90 % ab 500 Sendungen. Dieses Verhalten ist plausibel: Je mehr
  Sendungen das Netzwerk durchlaufen, desto wahrscheinlicher nutzen
  mehrere Sendungen dieselben Transportkanten und können sich Fahrzeuge
  teilen. Die hohe Konsolidierungsrate bei großen Sendungsmengen bestätigt,
  dass der sequentielle Greedy-Ansatz (vgl. @sec:capacity-tracking) die
  Bündelungspotenziale des Netzwerks effektiv ausnutzt.

+ *Robuste Feasibility:* Der Anteil unlösbarer Sendungen bleibt über alle
  getesteten Größen nahe null. Das 870-Hub-Netzwerk mit 30-Tage-Horizont
  bietet ausreichend alternative Routen, sodass praktisch jede zufällig
  generierte Sendung innerhalb der Deadline zugestellt werden kann.

Zusammen mit den MILP-Ergebnissen aus @sec:stress-test ergibt sich ein
klares Bild: Der exakte Solver ist bei 55 Sendungen auf dem kleinen
Netzwerk bereits nach 2,4 Stunden am Limit, während die Heuristik auf dem
deutlich größeren Netzwerk 1 000 Sendungen in unter 5 Minuten bei
gleichzeitig hoher Konsolidierung löst.

== Evaluierung der LNS-Optimierung
In @fig:lns_convergence wird die Leistung des LNS-Verfahrens über 50 Optimierungsschritte (Iterationen) hinweg für ein Szenario mit 50 europäischen Sendungen dargestellt.

#figure(
  image("assets/lns_convergence_plots.png", width: 90%),
  caption: flex-caption(
    [Konvergenzverlauf der LNS-Optimierung: Zielwert (links) und Konsolidierungsrate (rechts).],
    [Konvergenzverlauf der LNS-Optimierung],
  ),
) <fig:lns_convergence>

*Erkenntnisse zum Optimierungsverlauf:*
1. *Deutlicher Bündelungseffekt:* Die Konsolidierungsrate steigt durch die Optimierung von anfänglich *42,00 %* auf *50,00 %*. Das bedeutet, dass LNS erfolgreich zusätzliche Bündelungspotenziale findet, die bei der ersten, schrittweisen Zuweisung übersehen wurden.
2. *Ausgleich zwischen Kosten, CO₂ und Lieferzeit (Trade-off):* Während die Konsolidierung steigt, nehmen die reinen Gesamtkosten um 0,05 % und die CO₂-Emissionen um 0,12 % minimal zu. Dennoch verbessert (sinkt) der kombinierte Zielfunktionswert von 10,753 auf 10,747.


== Sensitivitätsanalyse <sec:sensitivity>

Ein wichtiges Ergebnis der Optimierung ist nicht nur ein einzelner Zielwert,
sondern eine belastbare Empfehlung für die Verkehrsmittelwahl. Die
Sensitivitätsanalyse untersucht daher, wie robust die empfohlene
Modal-Split-Entscheidung gegenüber Änderungen der wichtigsten Modell- und
Datenannahmen ist. Methodisch geschieht dies über _Parameter-Sweeps_: Ein
einzelner Parameter wird systematisch über einen Wertebereich variiert, während
alle übrigen fixiert bleiben, und der Verlauf der Zielgrößen wird aufgezeichnet.
Im Mittelpunkt steht dabei die wichtigste Stellgröße der Modalwahl: die
Zielgewichte, mit denen der Anwender die Abwägung zwischen Kosten, Zeit und
Emissionen steuert.

Als Referenzszenario dient das kleine Netzwerk mit einem festen, reproduzierbaren
Satz von 30 Sendungen. Entscheidend ist ein realistischer Planungshorizont von
60 Tagen: Da die Hubs global verteilt sind, benötigt Seefracht interkontinental
mehrere Wochen. Bei zu kurzen Fristen wäre für weite Relationen ausschließlich die
Luftfracht zulässig; der Modal Split wäre dann ein reines Feasibility-Artefakt und
nicht das Ergebnis einer echten Abwägung. Die dichten Parameter-Sweeps werden mit
der schnellen A\*-Heuristik gerechnet.

=== Sensitivität gegenüber den Zielgewichten <sec:sensitivity-weights>

Die Zielgewichte sind der wichtigste Stellhebel, mit dem ein Anwender die
Abwägung zwischen Kosten, Zeit und Emissionen steuert. @fig:sens-weights zeigt
zwei eindimensionale Sweeps durch den Gewichts-Simplex.

#figure(
  image("assets/fig_weights.png", width: 100%),
  caption: flex-caption(
    [Sensitivität gegenüber den Zielgewichten. *Links:* Kosten gegen
      Emissionen bei reiner Kosten-Emissions-Abwägung (Zeitgewicht null).
      *Mitte:* Zielkonflikt zwischen Lieferzeit und Emissionen mit steigendem
      Zeitgewicht. *Rechts:* zugehörige Verschiebung des Modal Split.],
    [Sensitivität gegenüber den Zielgewichten],
  ),
) <fig:sens-weights>

Zu erkennen ist, dass zwischen Kosten und Emissionen
praktisch kein Zielkonflikt besteht. Die Seefracht ist im betrachteten Netzwerk
gleichzeitig der günstigste und der emissionsärmste Modus, sodass kosten- und
emissionsminimale Lösungen nahezu zusammenfallen.

Der eigentliche Zielkonflikt verläuft zwischen Geschwindigkeit und
Nachhaltigkeit. Erhöht man das Zeitgewicht, verschiebt sich der Modal Split
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
  caption: [Extrempunkte des Zeit-Nachhaltigkeit-Zielkonflikts.],
) <tab:sens-weights>

=== Interpretation und Handlungsempfehlung <sec:sensitivity-interpretation>

Aus der Sensitivitätsanalyse lassen sich mehrere Entscheidungshinweise ableiten:

- *Kosten und Emissionen sind kein Gegensatz:* Solange keine engen Lieferfristen
  bestehen, ist die schiffsbasierte, konsolidierte Lösung sowohl kostenoptimal als
  auch emissionsarm. Das Kostengewicht kann hier ohne ökologischen Zielkonflikt
  erhöht werden.
- *Der kritische Hebel ist die Zeit:* Die Empfehlung reagiert am empfindlichsten
  auf das Zeitgewicht. Zeitkritische Sendungen sollten daher gezielt und einzeln
  auf die Luftfracht gelegt werden, nicht pauschal über ein hohes globales
  Zeitgewicht; Letzteres verlagert unnötig viel Volumen auf den teuersten und
  emissionsintensivsten Modus.

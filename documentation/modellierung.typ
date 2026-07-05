= Modellierung und Optimierung <ch:modelling-and-optimization>

== Exakte mathematische Formulierung <ch:mathematical-model>

Dieser Abschnitt formalisiert das in @ch:problem-description beschriebene
Planungsproblem als gemischt-ganzzahliges lineares Programm (MILP). Zunächst
wird die Netzwerkstruktur eingeführt, anschließend die vollständige
Notation definiert und schließlich das kompakte Modell mit Zielfunktion und
Nebenbedingungen präsentiert und erläutert.

=== Ereignisbasiertes zeitexpandiertes Netzwerk

Zur Abbildung zeitlicher Abhängigkeiten wird das in @sec:time-expanded
eingeführte Konzept zeitexpandierter Graphen auf das multimodale
Transportnetzwerk übertragen. Ausgangspunkt ist das statische
Netzwerk $G = (N, A)$, in dem jeder Knoten $v in N$ einen physischen
Hub mit zugehörigem Transportmodus repräsentiert und jede Kante
$e in A$ eine Verbindung mit fester Dauer, Distanz und
Kapazität beschreibt.

Durch die zeitliche Expansion wird dieses statische Netzwerk in einen
gerichteten Graphen $G^T = (N^T, A^T)$ überführt, dessen Knoten und
Kanten an konkrete Zeitpunkte innerhalb eines Planungshorizonts
$T^"H"$ (in Minuten) gebunden sind.

=== Knotenstruktur

Ein Knoten des zeitexpandierten Graphen wird als Tripel

$ n = (h, m, t) in N^T $

dargestellt, wobei $h in H$ den Hub, $m in M_h$ den Transportmodus und
$t in [0, T^"H"]$ den Zeitpunkt in Minuten seit Beginn des
Planungshorizonts beschreibt. Im Gegensatz zu einer gleichmäßigen
Zeitdiskretisierung, bei der für jeden physischen Knoten in festen
Abständen (z. B. stündlich) Kopien erzeugt werden, enthält die Knotenmenge
$N^T$ ausschließlich Zeitpunkte, zu denen tatsächlich relevante Ereignisse
stattfinden:

+ *Beginn und Ende des Planungshorizonts ($t = 0$ und $t = T^"H"$):*
  Diese Knoten spannen den zeitlichen Rahmen auf. Da Wartekanten immer von einem Ereignis zum nächsten gezogen werden, sichern diese beiden Randereignisse ab, dass zu jedem Zeitpunkt (auch vor der ersten oder nach der letzten Fahrt) an jedem Hub gewartet werden kann.

+ *Fahrplanmäßige Abfahrten und Ankünfte:*
  Ein Zug oder Lkw fährt zu einer festen Zeit ab und kommt zu einer festen Zeit an. Damit die Transportkante (z. B. Fahrt von Frankfurt nach München) im Graphen verankert werden kann, müssen die genauen Minuten der Abfahrt (Startknoten) und der Ankunft (Zielknoten) als Ereignisse registriert werden.

+ *Start- und Endzeitpunkte von Transfers:*
  Das Umladen einer Sendung (z. B. von Schiene auf Straße) benötigt Zeit. Um diese Umladekante im Graphen zu verbinden, werden ein Startknoten beim Quellmodus (Beginn des Umladens) und ein Zielknoten beim Zielmodus (Ende des Umladens) erzeugt.

+ *Freigabe der Sendungen:*
  Um eine Sendung $k$ zum frühestmöglichen Zeitpunkt in das Netzwerk einzuspeisen, wird am Starthub ein Knoten zu ihrer Freigabezeit $r_k$ benötigt.


//  *Wichtiger Hintergrund:* Sobald eine Sendung an *irgendeinem* Knoten des Zielhubs ankommt, gilt sie als zugestellt. Da Zielknoten mathematisch als Senken agieren, verlässt der Fluss diesen Zielpunkt nicht mehr. Eine Sendung muss also nicht bis zur Deadline $D_k$ warten und verursacht nach ihrer tatsächlichen Ankunft am Zielort keine weiteren Wartekosten.



Durch diese ereignisbasierte Konstruktion bleibt die Knotenmenge kompakt und
wächst proportional zur Anzahl der tatsächlichen Netzwerkereignisse statt
zur Feinheit einer festen Zeitrasterung.

=== Kantentypen

Die Kantenmenge des zeitexpandierten Graphen setzt sich aus drei disjunkten
Teilmengen zusammen:

$ A^T = A^T_"trans" union A^T_"transfer" union A^T_"wait". $

Es werden ausschließlich Kanten erzeugt, deren Ankunftszeitpunkt innerhalb
des Planungshorizonts $T^"H"$ liegt.

==== Transportkanten

Transportkanten verbinden zwei _verschiedene_ Hubs $h_1 != h_2$ im
_gleichen_ Modus $m$:

$
  a = ((h_1, m, t_"dep"), (h_2, m, t_"arr")) in A^T_"trans" quad
  "mit" quad t_"arr" = t_"dep" + tau_a <= T^"H".
$

Sie entstehen durch die zeitliche Expansion der statischen
Transportkanten. Jede statische Kante definiert eine Strecke zwischen
zwei Hubs mit fester Dauer $tau_a$, Entfernung $d_a$ und einem Satz
täglicher Abfahrtsminuten. Bei der Expansion wird für jeden Tag des
Planungshorizonts und jede definierte Abfahrtsminute eine konkrete
zeitexpandierte Kante erzeugt. Sind keine kantenspezifischen variablen
Kosten oder Emissionen hinterlegt, werden sie aus der Streckenlänge und
den modusspezifischen Faktoren berechnet:
$c_a = d_a dot c_m^"tkm"$ bzw. $e_a = d_a dot e_m^"tkm"$.

==== Transferkanten

Transferkanten beschreiben den Moduswechsel an einem Hub $h$ von Modus
$m_1$ zu Modus $m_2$ ($m_1 != m_2$):

$
  a = ((h, m_1, t_"dep"), (h, m_2, t_"arr")) in A^T_"transfer" quad
  "mit" quad t_"arr" = t_"dep" + tau_a <= T^"H".
$

Sie bilden physische Umschlagprozesse ab, etwa das Umladen von der Schiene
auf die Straße. Auch Transferkanten werden aus statischen Vorlagen
expandiert, die eigene Abfahrtszeiten und Dauern definieren. Ihre Kosten
und Emissionen werden entweder kantenspezifisch vorgegeben oder aus
globalen Standardwerten übernommen.

==== Wartekanten

Wartekanten verbinden zwei aufeinanderfolgende Ereigniszeiten $t_1 < t_2$
desselben Hub-Modus-Paares $(h, m)$:

$
  a = ((h, m, t_1), (h, m, t_2)) in A^T_"wait" quad
  "mit" quad t_1 < t_2.
$

Sie modellieren das Verweilen einer Sendung an einem Hub, etwa um eine
spätere Abfahrt abzuwarten. Ihre variablen Kosten und Emissionen ergeben
sich aus der tatsächlichen Wartedauer $(t_2 - t_1)$ und den hub- bzw.
global definierten Stundensätzen.


=== Notation <sec:notation>

Bevor das Modell formuliert wird, werden alle mathematischen Symbole
vollständig definiert.

==== Mengen und Indizes

@tab:sets-indices fasst die verwendeten Mengen und Indizes zusammen.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: 0.5pt,
    inset: 8pt,
    [*Symbol*], [*Beschreibung*],
    [$H$], [Menge aller Hubs (Logistikknoten) im Netzwerk],
    [$M_h$], [Am Hub $h$ unterstützte Transportmodi],
    [$T^"H"$], [Planungshorizont \[min\]],
    [$N^T$],
    [Knoten des zeitexpandierten Netzwerks; jeder Knoten ist ein
      Tripel $(h, m, t)$],

    [$A^T$], [Menge aller zeitabhängigen Kanten],
    [$A^T_"trans"$],
    [Transportkanten (zwischen verschiedenen Hubs, gleicher
      Modus)],

    [$A^T_"transfer"$], [Transferkanten (Moduswechsel an einem Hub)],
    [$A^T_"wait"$], [Wartekanten (Verweilen am selben Hub-Modus-Paar)],
    [$K$], [Menge aller zu routenden Sendungen],
    [$K_B subset.eq K$], [Sendungen mit definierter Preisobergrenze],
    [$K_E subset.eq K$], [Sendungen mit definierter Emissionsobergrenze],
    [$delta^+(n)$], [Menge der von Knoten $n$ ausgehenden Kanten],
    [$delta^-(n)$], [Menge der in Knoten $n$ eingehenden Kanten],
    [$N_k^"S"$],
    [Startknoten der Sendung $k$: alle Knoten am Starthub zum
      Freigabezeitpunkt $r_k$],

    [$N_k^"Z"$], [Zielknoten der Sendung $k$: alle Knoten am Zielhub],
  ),
  caption: [Mengen und Indizes des Modells.],
) <tab:sets-indices>

==== Parameter

@tab:parameters listet die Modellparameter mit ihren Einheiten.

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    inset: 8pt,
    [*Symbol*], [*Einheit*], [*Beschreibung*],
    [$q_k$], [t], [Gewicht der Sendung $k$ $(q_k > 0)$],
    [$r_k$], [min], [Freigabe- bzw. Startzeitpunkt der Sendung $k$],
    [$D_k$], [min], [Lieferfrist der Sendung $k$],
    [$B_k$], [EUR], [Optionale Preisobergrenze der Sendung $k$],
    [$E_k^"lim"$], [kg CO₂], [Optionale Emissionsobergrenze der Sendung $k$],
    [$u_a$], [t], [Kapazität einer auf Kante $a$ aktivierten Einheit $(u_a > 0)$],
    [$c_a$], [EUR/t], [Variable Kosten der Kante $a$ je Tonne $(c_a >= 0)$],
    [$e_a$], [kg CO₂/t], [Variable Emissionen der Kante $a$ je Tonne $(e_a >= 0)$],
    [$F_a$], [EUR], [Fixkosten je aktivierter Einheit auf Kante $a$ $(F_a >= 0)$],
    [$G_a$], [kg CO₂], [Fixemissionen je aktivierter Einheit auf Kante $a$ $(G_a >= 0)$],
    [$tau_a$], [min], [Dauer der Kante $a$ $(tau_a > 0)$],
    [$d_a$], [km], [Streckenlänge der Kante $a$ (nur für $a in A^T_"trans"$)],
    [$t(n)$], [min], [Zeitpunkt des Knotens $n$],
    [$overline(v)_a$], [--], [Optionale Obergrenze verfügbarer Einheiten auf Kante $a$],
    [$lambda_k^C, lambda_k^T, lambda_k^E$], [--], [Sendungsspezifische Gewichte für Kosten, Zeit und Emissionen],
  ),
  caption: [Parameter des Optimierungsmodells.],
) <tab:parameters>

Die Zielgewichte sind nichtnegativ und werden vor der Optimierung so normiert,
dass $lambda_k^C + lambda_k^T + lambda_k^E = 1$. Sind für eine Sendung
keine eigenen Gewichte hinterlegt, verwendet das Modell die globalen
Standardgewichte.

==== Entscheidungsvariablen

@tab:decision-variables gibt einen Überblick über die
Entscheidungsvariablen des Modells.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: 0.5pt,
    inset: 8pt,
    [*Variable*], [*Beschreibung*],
    [$x_(a,k)$], [Binäre Routingvariable],
    [$v_a$], [Anzahl aktivierter Kapazitätseinheiten auf Kante $a$],
  ),
  caption: [Entscheidungsvariablen des Modells.],
) <tab:decision-variables>

Die *Routingvariable* $x_(a,k)$ gibt an, ob eine Sendung $k$ die Kante $a$ nutzt:

$
  x_(a,k) = cases(
    1 & "falls Sendung " k " die Kante " a " nutzt",
    0 & "sonst"
  ) quad forall a in A^T, k in K.
$


Die *Kapazitätsvariable* $v_a$ repräsentiert die Anzahl der auf Kante $a$ eingesetzten Fahrzeuge (die Flottengröße):

$ v_a in bb(N)_0 quad forall a in A^T $

Sie kann durch die maximal verfügbare Flottengröße $overline(v)_a$ auf der Kante beschränkt werden ($v_a <= overline(v)_a$).
// TODO: Verweis auf nebenbedingung


==== Schlupfvariablen

Zusätzlich führt das Modell Schlupfvariablen ein, die eine
kontrollierte Verletzung bestimmter Grenzen ermöglichen (siehe
@sec:soft-constraints):

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    inset: 8pt,
    [*Variable*], [*Einheit*], [*Bedeutung*],
    [$s_k^D >= 0$], [min], [Überschreitung der Lieferfrist der Sendung $k$],
    [$s_k^B >= 0$],
    [EUR],
    [Überschreitung der Preisobergrenze der Sendung $k$
      (nur für $k in K_B$)],

    [$s_k^E >= 0$],
    [kg CO₂],
    [Überschreitung der Emissionsobergrenze der Sendung $k$
      (nur für $k in K_E$)],

    [$s^"sum" >= 0$],
    [EUR],
    [Überschreitung des gemeinsamen Gesamtbudgets
      (nur wenn alle Sendungen ein Budget definieren)],
  ),
  caption: [Schlupfvariablen des Modells.],
) <tab:slack-variables>


=== Kompakte Modellformulierung <sec:compact-model>

Im Folgenden wird das vollständige Optimierungsmodell zusammenhängend
dargestellt. Die Herleitung der Normalisierungsgrößen $Delta C_k$,
$Delta T_k$, $Delta E_k$ sowie der Fixkosten-Koeffizienten $alpha_C$,
$alpha_E$ erfolgt in @sec:normalization. Die Motivation der weichen
Restriktionen wird in @sec:soft-constraints erläutert.

==== Hilfsausdrücke

$
  C^"fix" = sum_(a in A^T) F_a v_a, quad
  E^"fix" = sum_(a in A^T) G_a v_a
$ <eq:fixed>

$ C_k^"var" = sum_(a in A^T) c_a q_k x_(a,k) quad forall k in K $ <eq:var-cost>

$ T_k = sum_(a in A^T) tau_a x_(a,k) quad forall k in K $ <eq:time>

$ E_k^"var" = sum_(a in A^T) e_a q_k x_(a,k) quad forall k in K $ <eq:var-emissions>

$ C^"total" = C^"fix" + sum_(k in K) C_k^"var" $ <eq:total-cost>

==== Zielfunktion

$ min quad Z = Z^"route" + rho Z^"slack" $ <eq:objective>

mit dem Routinganteil

$
  Z^"route" =
  alpha_C C^"fix" + alpha_E E^"fix"
  + sum_(k in K) (
    lambda_k^C (C_k^"var" - C_k^-) / (Delta C_k)
    + lambda_k^T (T_k - T_k^-) / (Delta T_k)
    + lambda_k^E (E_k^"var" - E_k^-) / (Delta E_k)
  )
$ <eq:routing>

und dem Strafterm

$
  Z^"slack" =
  sum_(k in K) s_k^D / (Delta T_k)
  + sum_(k in K_B) s_k^B / (Delta C_k)
  + sum_(k in K_E) s_k^E / (Delta E_k)
$ <eq:slack>


==== Nebenbedingungen

$
  sum_(n in N_k^"S") sum_(a in delta^+(n)) x_(a,k) = 1
  quad forall k in K
$ <eq:start>

$
  sum_(n in N_k^"Z") sum_(a in delta^-(n)) x_(a,k) = 1
  quad forall k in K
$ <eq:end>

$
  sum_(a in delta^-(n)) x_(a,k)
  = sum_(a in delta^+(n)) x_(a,k)
  quad forall k in K, space
  forall n in N^T backslash (N_k^"S" union N_k^"Z")
$ <eq:flow>

$
  sum_(n in N_k^"Z") sum_(a in delta^-(n)) t(n) x_(a,k)
  - s_k^D <= D_k
  quad forall k in K
$ <eq:deadline>

$
  sum_(k in K) q_k x_(a,k) <= u_a v_a
  quad forall a in A^T
$ <eq:capacity>

$
  v_a <= V_a^"road" sum_(k in K) x_(a,k)
  quad forall a in A^T_"trans" "mit Modus Straße"
$ <eq:coupling-road>

$
  v_a <= sum_(k in K) x_(a,k)
  quad forall a in A^T backslash A^T_"road"
$ <eq:coupling-other>

$ C_k^"var" - s_k^B <= B_k quad forall k in K_B $ <eq:budget>

$ E_k^"var" - s_k^E <= E_k^"lim" quad forall k in K_E $ <eq:emissions-limit>

$
  C^"total" - s^"sum" <= sum_(k in K) B_k quad
  "(nur falls" forall k in K: B_k "definiert)"
$ <eq:total-budget>


=== Erläuterung des Modells

Dieser Abschnitt erläutert die einzelnen Komponenten des in
@sec:compact-model dargestellten Modells.

==== Hilfsausdrücke

Die in @eq:fixed bis @eq:total-cost definieren die zentralen
Bewertungsgrößen als lineare Ausdrücke der Entscheidungsvariablen.
@eq:fixed erfasst die gemeinsamen Fixkosten $C^"fix"$ und
Fixemissionen $E^"fix"$ aller aktivierten Kapazitätseinheiten, die bei
Konsolidierung mehrerer Sendungen geteilt werden. Die Gleichungen
@eq:var-cost, @eq:time und @eq:var-emissions berechnen für jede Sendung $k$
die individuellen variablen Kosten, die Transportzeit und die variablen
Emissionen. @eq:total-cost aggregiert fixe und variable Kostenanteile zu
den monetären Gesamtkosten.

==== Zielfunktion

Die Zielfunktion @eq:objective minimiert die Summe aus dem normierten
Routinganteil $Z^"route"$ (@eq:routing) und dem mit $rho = 100$
gewichteten Strafterm $Z^"slack"$ (@eq:slack) für verletzte weiche Grenzen.

In $Z^"route"$ werden die sendungsspezifischen variablen Größen durch die
Normalisierungsbereiche $Delta C_k$, $Delta T_k$ und $Delta E_k$ dividiert,
sodass alle Zielkriterien auf eine vergleichbare dimensionslose Skala
abgebildet werden. Die Subtraktion der unteren Grenzen $C_k^-$, $T_k^-$
und $E_k^-$ fügt lediglich konstante Terme hinzu und verändert die Rangfolge
zulässiger Lösungen nicht. Sie bewirkt jedoch, dass der normierte Ausdruck
für eine sendungsoptimale Lösung nahe null liegt, was die numerische
Stabilität verbessert.

Fixe Größen ($C^"fix"$, $E^"fix"$) werden separat über die
Koeffizienten $alpha_C$ und $alpha_E$ bewertet. Da Fixkosten bei
Konsolidierung von mehreren Sendungen geteilt werden und somit keiner
Sendung eindeutig zugeordnet werden können, werden diese Koeffizienten als
Mittelwerte über alle Sendungen gebildet (siehe @sec:normalization).

Der Strafterm $Z^"slack"$ skaliert auch die Schlupfvariablen durch die
jeweiligen Normalisierungsbereiche dimensionslos, sodass eine Verletzung
der Lieferfrist um eine Minute denselben Strafbeitrag erzeugt wie eine
proportional äquivalente Budgetüberschreitung. Falls für alle Sendungen
ein Budget definiert ist, wird $Z^"slack"$ zusätzlich um
$s^"sum" / sum_(k in K) Delta C_k$ erweitert. Der hohe Strafkoeffizient
$rho$ priorisiert die Einhaltung der weichen Grenzen gegenüber der
Routenoptimierung, erhält aber auch bei knappen oder widersprüchlichen
Vorgaben eine diagnostisch auswertbare Lösung.

==== Nebenbedingungen

Die *Startbedingung* @eq:start stellt sicher, dass jede Sendung genau einen
zu ihrem Freigabezeitpunkt passenden Startknoten verlässt. Die
*Zielbedingung* @eq:end verlangt, dass der Zielhub genau einmal erreicht
wird. Die *Flusserhaltung* @eq:flow garantiert an allen Zwischenknoten, dass
der eingehende Fluss dem ausgehenden entspricht -- keine Sendung geht
verloren oder wird dupliziert.

Die *Lieferfristbedingung* @eq:deadline formuliert die Ankunft am Zielhub
als weiche Restriktion: Die Schlupfvariable $s_k^D$ erfasst eine etwaige
Überschreitung und wird über den Strafterm in der Zielfunktion pönalisiert.

Die *Kapazitätsbedingung* @eq:capacity begrenzt das auf einer zeitlich
konkreten Kante transportierte Gesamtgewicht auf die aktivierte Kapazität.
Da mehrere Sendungen gemeinsam auf der linken Seite stehen, reicht bei
ausreichendem Gesamtgewicht eine einzige Aktivierung ($v_a = 1$) aus.
Dies ist der zentrale Konsolidierungsmechanismus des Modells.

Die *Kopplungsbedingungen* @eq:coupling-road und @eq:coupling-other
verhindern Aktivierungen ohne Nutzung. Für Straßenkanten (@eq:coupling-road)
wird $V_a^"road"$ aus dem Gesamtgewicht aller Sendungen und der
Fahrzeugkapazität abgeleitet, um die freie Ganzzahlvariable nach oben zu
begrenzen. Für alle übrigen Kanten (@eq:coupling-other) ist die
Kopplungsbedingung schärfer, da dort $v_a in {0, 1}$ gilt.

Die *Budgetbedingungen* @eq:budget und @eq:emissions-limit formulieren
optionale Preis- und Emissionsobergrenzen als weiche Restriktionen. Sie
enthalten bewusst nur sendungsabhängige variable Anteile, da geteilte
Fixwerte bei Konsolidierung nicht eindeutig einzelnen Sendungen zugerechnet
werden können. Die *gemeinsame Budgetbedingung* @eq:total-budget begrenzt
die vollständigen Kosten einschließlich Fixkosten, wird jedoch nur
aktiviert, wenn alle Sendungen ein Budget definieren.


=== Normalisierung der Zielfunktion <sec:normalization>

Kosten (EUR), Transportzeit (Minuten) und Emissionen (kg CO₂) besitzen
unterschiedliche Einheiten und Größenordnungen. Ohne Normalisierung würden
die Gewichtungsfaktoren $lambda_k^C$, $lambda_k^T$ und $lambda_k^E$
nicht die vom Anwender beabsichtigte Präferenz widerspiegeln, da ein
Zielkriterium mit numerisch höheren Werten die Zielfunktion dominieren
würde. Eine geeignete Skalierung ist daher notwendig, um die drei
Dimensionen vergleichbar zu machen.

==== Anforderungen an die Normalisierung

Die gewählte Methode muss drei Anforderungen erfüllen:

+ *Skalenunabhängigkeit:* Alle Zielkriterien sollen auf ein vergleichbares
  Intervall abgebildet werden, sodass ein Gewicht von beispielsweise
  $lambda^C = 0.5$ tatsächlich bedeutet, dass Kosten die Hälfte der
  Gesamtbewertung ausmachen.

+ *Interpretierbarkeit:* Im Kontext der Mehrzieloptimierung (MCDM) müssen
  die Gewichte für Anwender nachvollziehbar bleiben. Eine Min-Max-Skalierung
  auf das Intervall $[0, 1]$ ermöglicht eine intuitive Interpretation: Ein
  Gewicht repräsentiert die Bereitschaft, eine prozentuale Verschlechterung
  bei einem Kriterium gegen eine Verbesserung bei einem anderen
  einzutauschen.

+ *Recheneffizienz:* Die Normalisierung darf die Lösungszeit des MILP nicht
  nennenswert erhöhen.

==== Analytische Min-Max-Skalierung

Grundsätzlich ließe sich die exakte Normalisierung über eine
*Pay-off-Tabelle* bestimmen, bei der das Modell vorab für jedes Zielkriterium
einzeln gelöst wird, um die tatsächlichen Minima und Maxima im Lösungsraum
zu ermitteln. Da das Lösen des MILP selbst bereits NP-schwer ist, würde
dieser Ansatz die Rechenzeit jedoch vervierfachen und ist daher
unpraktikabel.

Alternativ könnte eine *Z-Score-Standardisierung* ($X' = (X - mu) / sigma$)
in Betracht gezogen werden. Im Gegensatz zum maschinellen Lernen liegen
jedoch vor der Optimierung keine expliziten Datenpunkte vor, aus denen
Mittelwert und Standardabweichung über den Lösungsraum berechnet werden
könnten. Die Enumeration aller zulässigen Pfade wäre algorithmisch
aufwändiger als die eigentliche Optimierung.

Das Modell verwendet daher eine *analytische Min-Max-Skalierung*, die
sendungsspezifische Unter- und Obergrenzen in $O(1)$ aus physikalischen und
geometrischen Gesetzmäßigkeiten ableitet. Für jede Sendung $k$ werden
Schätzintervalle

$ (C_k^-, C_k^+), quad (T_k^-, T_k^+), quad (E_k^-, E_k^+) $

bestimmt sowie die geschützten Wertebereiche

$ Delta C_k = max(C_k^+ - C_k^-, epsilon), $
$ Delta T_k = max(T_k^+ - T_k^-, epsilon), $
$ Delta E_k = max(E_k^+ - E_k^-, epsilon), quad epsilon = 10^(-9). $

==== Herleitung der Schätzgrenzen

Ausgangspunkt ist die verfügbare Zeit einer Sendung

$ L_k = max(0, min(D_k, T^"H") - r_k) $

sowie die maximale Netzwerkgeschwindigkeit

$ v^"max" = max_(a in A^T_"trans") d_a / tau_a, $

wobei $d_a$ die Streckenlänge der Transportkante $a$ bezeichnet. Daraus
ergeben sich die Luftliniendistanz $d_k^-$ zwischen Start- und Zielhub
(Haversine-Formel) und die maximal erreichbare Distanz $d_k^+ = v^"max" L_k$.

Die *Zeitgrenzen* folgen unmittelbar:

$ T_k^- = d_k^- / v^"max", quad T_k^+ = L_k. $

Für die *Kosten- und Emissionsgrenzen* werden die minimalen und maximalen
modusspezifischen Faktoren $c^-$, $c^+$ (Kosten je Tonnenkilometer) sowie
$e^-$, $e^+$ (Emissionen je Tonnenkilometer) herangezogen. Die geschätzte
maximale Segmentanzahl $m_k$ ergibt sich aus der verfügbaren Zeit und
der kürzesten Kantendauer. Die maximale Fahrzeuganzahl je Segment
$nu_k^"max"$ wird aus Sendungsgewicht und kleinster Netzwerkkapazität
abgeleitet:

$
  C_k^- = d_k^- c^- q_k, quad
  C_k^+ = d_k^+ c^+ q_k + m_k F^"max" nu_k^"max",
$

$
  E_k^- = d_k^- e^- q_k, quad
  E_k^+ = d_k^+ e^+ q_k + m_k G^"max" nu_k^"max".
$

Falls eine obere Schätzung nicht strikt größer als die untere ist, wird der
Wertebereich auf mindestens eins gesetzt. Die Grenzen dienen ausschließlich
der Skalierung der Zielfunktion; die Zulässigkeit einer Route wird allein
durch die Nebenbedingungen bestimmt.

==== Fixkosten-Koeffizienten

Da Fixkosten und Fixemissionen bei Konsolidierung von mehreren Sendungen
geteilt werden, können sie keiner einzelnen Sendung eindeutig zugeordnet
werden. Ihre Zielfunktionskoeffizienten werden deshalb als Mittelwerte über
alle Sendungen gebildet:

$
  alpha_C = 1 / |K| sum_(k in K) lambda_k^C / (Delta C_k), quad
  alpha_E = 1 / |K| sum_(k in K) lambda_k^E / (Delta E_k).
$


=== Weiche Restriktionen und Diagnosefähigkeit <sec:soft-constraints>

Ein Standardansatz der ganzzahligen Optimierung formuliert alle
Nebenbedingungen als harte Restriktionen. Werden dabei Lieferfristen zu eng,
Budgets zu gering oder Emissionslimits zu restriktiv gesetzt, meldet der
Solver lediglich, dass keine zulässige Lösung existiert (_Infeasible_),
ohne anzugeben, *welche* Bedingung verletzt wurde und um wie viel.

Das vorliegende Modell unterscheidet daher zwischen zwei Klassen von
Nebenbedingungen:

- *Harte Restriktionen* (Flusserhaltung, Kapazitätsgrenzen) beschreiben
  physikalische Gesetzmäßigkeiten, die unter keinen Umständen verletzt
  werden dürfen.
- *Weiche Restriktionen* (Lieferfristen, Preis- und Emissionsbudgets)
  beschreiben betriebliche Vorgaben, die durch nichtnegative
  Schlupfvariablen aufgeweicht werden. Die Schlupfvariable $s$ misst die
  exakte Höhe einer Grenzüberschreitung:
  $ X - s <= "Limit" quad "mit" s >= 0. $

Durch die Pönalisierung der Schlupfvariablen in der Zielfunktion mit dem
Strafkoeffizienten $rho = 100$ wird sichergestellt, dass der Solver
Grenzverletzungen nur im äußersten Notfall akzeptiert. Der Koeffizient ist
groß genug, um eine Verletzung stets teurer zu machen als jede zulässige
Umleitung, bleibt aber moderat genug, um numerische Instabilitäten
zu vermeiden.

Im Ergebnis liefert das Modell auch bei unlösbaren Vorgaben eine
auswertbare Lösung: Die positiven Schlupfwerte zeigen dem Anwender
präzise, welche Restriktion um welchen Betrag verletzt wurde und
ermöglichen eine gezielte Anpassung der Eingabeparameter.


== Heuristischer Ansatz <ch:heuristic-approach>

Neben dem exakten MILP-Solver werden zwei graphbasierte Heuristiken formuliert,
die auf demselben zeitexpandierten Netzwerk $G^T = (N^T, A^T)$ operieren:
ein Dijkstra-Router und ein A\*-Router. Für Einzelsendungen liefern beide
das global optimale Ergebnis; für Mehrfachsendungen wird ein sequentielles
Verfahren mit anschließender LNS-Optimierung eingesetzt.

=== Kantenbewertungsfunktion (Arc Score) <sec:arc-score>

Für eine Sendung $k$ mit Gewicht $q_k$ wird jeder Kante $a in A^T$ ein
skalares Gewicht $sigma(a, k)$ zugewiesen, das die normierte gewichtete
Summe der drei Zielkriterien abbildet. Seien $lambda_k^C$, $lambda_k^T$,
$lambda_k^E$ die normierten Zielgewichte der Sendung und
$Delta C_k$, $Delta T_k$, $Delta E_k$ die Normalisierungsbereiche aus
@sec:normalization. Die Arc-Score-Funktion ist definiert als:

$
  sigma(a, k) =
  alpha_C dot F_a dot n_a
  + lambda_k^C dot (c_a dot q_k) / (Delta C_k)
  + lambda_k^T dot tau_a / (Delta T_k)
  + alpha_E dot G_a dot n_a
  + lambda_k^E dot (e_a dot q_k) / (Delta E_k)
$ <eq:arc-score>

wobei $n_a$ die Anzahl der zusätzlich benötigten Fahrzeuge auf Kante $a$
darstellt, die sich aus dem Kapazitätszustand ergibt (siehe @sec:capacity-tracking).
Die Koeffizienten $alpha_C$ und $alpha_E$ sind die in @sec:normalization
definierten gemittelten Fixkosten-Koeffizienten.

Dieser Score ist konstruktionsgleich zur Zielfunktion des MILP (@eq:routing),
wobei die konstanten Offset-Terme $C_k^-$, $T_k^-$, $E_k^-$ weggelassen werden.
Da diese Terme für alle Kanten konstant sind, verändern sie die Rangfolge der
Pfade nicht und die Optimalität des kürzesten Weges bleibt erhalten.

=== Kürzeste-Weg-Suche (Dijkstra) <sec:dijkstra-formulation>

Für eine Einzelsendung $k$ wird der optimale Pfad als klassisches
Kürzeste-Weg-Problem auf dem zeitexpandierten Graphen formuliert:

$
  min_(P in cal(P)_k) sum_(a in P) sigma(a, k)
$ <eq:shortest-path>

wobei $cal(P)_k$ die Menge aller zulässigen Pfade von den Startknoten
$N_k^"S"$ zu den Zielknoten $N_k^"Z"$ mit $t(n) <= D_k$ bezeichnet.

Die Suche verwendet einen Min-Heap mit Einträgen $(f, g, "counter", n)$,
wobei $g$ die kumulative Arc-Score-Distanz vom Start und $f = g + h(n)$
die Priorität darstellt. Beim Dijkstra-Router gilt $h(n) = 0$; beim
A\*-Router wird eine zulässige Heuristik $h(n)$ verwendet
(siehe @sec:astar-heuristic).

Zusätzlich wird ein zeitbasiertes Pruning eingesetzt: Ein Knoten $n$
wird nur expandiert, wenn seine Ankunftszeit plus die minimale
Restfahrzeit zum Zielhub die Deadline nicht überschreitet:

$ t(n) + t_"min"(h_n, h_k^"Z") <= D_k $

wobei $t_"min"(h, h')$ die minimale Fahrtdauer von Hub $h$ zum Zielhub
$h'$ auf dem statischen Graphen bezeichnet, die per Rückwärts-Dijkstra
vorberechnet wird.

Da der zeitexpandierte Graph kreisfrei ist (jede Kante führt strikt
vorwärts in der Zeit) und keine Suchraumbegrenzung vorgenommen wird,
garantiert der Dijkstra-Router die global optimale Lösung für eine
Einzelsendung.

=== A\*-Heuristikfunktion <sec:astar-heuristic>

Der A\*-Router erweitert den Dijkstra-Router um eine zulässige und
konsistente Heuristikfunktion $h: N^T -> bb(R)_(>=0)$, die für jeden
Knoten eine untere Schranke der verbleibenden Kosten zum Ziel liefert.

Die Berechnung erfolgt durch einen Rückwärts-Dijkstra auf dem
statischen Netzwerk, der für jeden Hub $h in H$ den minimalen
gewichteten Score zum Zielhub $h_k^"Z"$ ermittelt. Sei $overline(A)$
die Menge der statischen Transportkanten-Templates mit dem Score

$
  overline(sigma)(a, k) =
  lambda_k^C dot (c_a dot q_k) / (Delta C_k)
  + lambda_k^T dot tau_a / (Delta T_k)
  + lambda_k^E dot (e_a dot q_k) / (Delta E_k)
$

Dann berechnet der Rückwärts-Dijkstra:

$
  h(n) = min_(P: h_n -> h_k^"Z" "in" overline(A)) sum_(a in P) overline(sigma)(a, k)
$ <eq:astar-heuristic>

Da $overline(sigma)$ die Fixkosten sowie Warte- und Transferkanten
nicht berücksichtigt, unterschätzt $h$ die tatsächlichen Restkosten
auf dem zeitexpandierten Graphen stets. Damit ist die Heuristik
*zulässig* (admissible) und *konsistent* (monoton), sodass A\* die
Optimalitätsgarantie des Dijkstra-Algorithmus beibehält und gleichzeitig
die Anzahl der expandierten Knoten reduziert.

=== Sequentielles Routing mehrerer Sendungen <sec:capacity-tracking>

Für mehrere Sendungen $K = {k_1, ..., k_n}$ wird ein sequentielles
Greedy-Verfahren eingesetzt. Die Sendungen werden absteigend nach
Gewicht sortiert und nacheinander auf dem zeitexpandierten Graphen
geroutet. Nach jeder erfolgreichen Routung wird der Kapazitätszustand
aktualisiert:

Sei $r_a^"rem"$ die verbleibende Kapazität und $v_a^"act"$ die Anzahl
aktiver Fahrzeuge auf Kante $a$. Die Anzahl zusätzlich benötigter
Fahrzeuge für Sendung $k$ ist:

$
  n_a(k) = cases(
    0 & "falls" r_a^"rem" >= q_k,
    ceil((q_k - r_a^"rem") / u_a) & "sonst"
  )
$ <eq:additional-vehicles>

Eine Kante ist nur begehbar, wenn die resultierende Fahrzeuganzahl
das Limit nicht überschreitet:

$ v_a^"act" + n_a(k) <= overline(v)_a $

Nach dem Routing der Sendung $k$ über Pfad $P_k$ wird für jede Kante
$a in P_k$ aktualisiert:

$
  v_a^"act" <- v_a^"act" + n_a(k), quad
  r_a^"rem" <- r_a^"rem" + n_a(k) dot u_a - q_k
$

Dieser Mechanismus erlaubt die Konsolidierung: Wenn auf einer Kante
noch Restkapazität vorhanden ist ($r_a^"rem" >= q_k$), werden keine
zusätzlichen Fixkosten verursacht ($n_a = 0$), und die Sendung
"teilt" sich das Fahrzeug mit bereits gerouteten Sendungen.

=== Ruin-and-Recreate-Optimierung (LNS) <sec:lns>

Das sequentielle Verfahren aus @sec:capacity-tracking ist aufgrund
der festen Reihenfolge nicht global optimal. Zur Verbesserung wird
eine Large Neighbourhood Search (LNS) nach dem Ruin-and-Recreate-Prinzip
eingesetzt.

Gegeben sei eine initiale Lösung $cal(S)$ mit Routen
$P = {P_{k_1}, ..., P_{k_n}}$ und Zielfunktionswert $Z(cal(S))$.
In jeder Iteration $t = 1, ..., I$ werden folgende Schritte ausgeführt:

+ *Ruin:* Eine zufällige Teilmenge $R subset.eq K$ mit
  $|R| = max(1, floor(rho dot |K|))$ Sendungen wird aus der Lösung
  entfernt, wobei $rho in (0, 1]$ der Ruin-Anteil ist. Der
  Kapazitätszustand wird auf die verbleibenden Sendungen $K backslash R$
  zurückgesetzt.

+ *Recreate:* Die entfernten Sendungen werden absteigend nach Gewicht
  sequentiell neu geroutet (analog zu @sec:capacity-tracking), wobei
  sie von den bereits reservierten Kapazitäten der verbleibenden
  Sendungen profitieren können.

+ *Akzeptanzkriterium:* Die Kandidatenlösung $cal(S)'$ wird akzeptiert,
  falls $Z(cal(S)') < Z(cal(S)^*)$ und mindestens ebenso viele
  Sendungen geroutet wurden wie in der bisher besten Lösung
  $cal(S)^*$.

Das Verfahren terminiert nach $I$ Iterationen und gibt die beste
gefundene Lösung $cal(S)^*$ zurück.


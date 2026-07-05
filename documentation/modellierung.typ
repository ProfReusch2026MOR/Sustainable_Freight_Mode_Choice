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
    [$overline(v)_a$], [--], [Maximale Flottengröße / Obergrenze verfügbarer Fahrzeuge auf Kante $a$],
    [$lambda_k^C, lambda_k^T, lambda_k^E$], [--], [Sendungsspezifische Gewichte für Kosten, Zeit und Emissionen],
    [$rho$], [--], [Strafkoeffizient für verletzte weiche Restriktionen ($rho > 0$)],
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

Sie kann durch die maximal verfügbare Flottengröße $overline(v)_a$ auf der Kante beschränkt werden (siehe @eq:coupling).


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

Die fixen Kosten und Fixemissionen aller genutzten Kanten werden definiert über:
$
  C^"fix" = sum_(a in A^T) F_a v_a, quad
  E^"fix" = sum_(a in A^T) G_a v_a
$ <eq:fixed>

Die variablen Kosten einer Sendung berechnen sich wie folgt:
$ C_k^"var" = sum_(a in A^T) c_a q_k x_(a,k) quad forall k in K $ <eq:var-cost>

Die gesamte Transportzeit einer Sendung lautet:
$ T_k = sum_(a in A^T) tau_a x_(a,k) quad forall k in K $ <eq:time>

Die variablen Emissionen einer Sendung ergeben sich aus:
$ E_k^"var" = sum_(a in A^T) e_a q_k x_(a,k) quad forall k in K $ <eq:var-emissions>

Die monetären Gesamtkosten des Netzwerks setzen sich zusammen aus:
$ C^"total" = C^"fix" + sum_(k in K) C_k^"var" $ <eq:total-cost>

==== Zielfunktion

Die Zielfunktion minimiert die Summe aus Routenbewertung und Straftermen:
$ min quad Z = Z^"route" + rho Z^"slack" $ <eq:objective>

Der Routinganteil bewertet die gewichteten und normierten Kriterien jeder Sendung:
$
  Z^"route" =
  alpha_C C^"fix" + alpha_E E^"fix"
  + sum_(k in K) (
    lambda_k^C (C_k^"var" - C_k^-) / (Delta C_k)
    + lambda_k^T (T_k - T_k^-) / (Delta T_k)
    + lambda_k^E (E_k^"var" - E_k^-) / (Delta E_k)
  )
$ <eq:routing>

Der Strafterm bestraft Überschreitungen der weichen Restriktionen:
$
  Z^"slack" =
  sum_(k in K) s_k^D / (Delta T_k)
  + sum_(k in K_B) s_k^B / (Delta C_k)
  + sum_(k in K_E) s_k^E / (Delta E_k)
$ <eq:slack>


==== Nebenbedingungen

Die Einhaltung des Startzeitpunkts am Ursprungshub wird erzwungen durch:
$
  sum_(n in N_k^"S") sum_(a in delta^+(n)) x_(a,k) = 1
  quad forall k in K
$ <eq:start>

Die erfolgreiche Ankunft am Zielhub wird sichergestellt durch:
$
  sum_(n in N_k^"Z") sum_(a in delta^-(n)) x_(a,k) = 1
  quad forall k in K
$ <eq:end>

Die Flusserhaltung an allen transienten Zwischenknoten lautet:
$
  sum_(a in delta^-(n)) x_(a,k)
  = sum_(a in delta^+(n)) x_(a,k)
  quad forall k in K, space
  forall n in N^T backslash (N_k^"S" union N_k^"Z")
$ <eq:flow>

Die Lieferfrist jeder Sendung wird abgebildet über:
$
  sum_(n in N_k^"Z") sum_(a in delta^-(n)) t(n) x_(a,k)
  - s_k^D <= D_k
  quad forall k in K
$ <eq:deadline>

Die Kapazitätsgrenzen der aktivierten Fahrzeuge auf den Kanten lauten:
$
  sum_(k in K) q_k x_(a,k) <= u_a v_a
  quad forall a in A^T
$ <eq:capacity>

Die Kopplung von Fahrzeug- und Routingvariablen wird erzwungen durch:
$
  v_a <= overline(v)_a sum_(k in K) x_(a,k)
  quad forall a in A^T
$ <eq:coupling>

Das sendungsspezifische Preisbudget wird eingehalten über:
$ C_k^"var" - s_k^B <= B_k quad forall k in K_B $ <eq:budget>

Die sendungsspezifischen Emissionsgrenzen lauten:
$ E_k^"var" - s_k^E <= E_k^"lim" quad forall k in K_E $ <eq:emissions-limit>

Das gemeinsame Gesamtbudget für alle konsolidierten Lieferungen lautet:
$
  C^"total" - s^"sum" <= sum_(k in K) B_k quad
  "(nur falls" forall k in K: B_k "definiert)"
$ <eq:total-budget>



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

+ *Interpretierbarkeit:* Im Kontext der Mehrzieloptimierung müssen
  die Gewichte für Anwender nachvollziehbar bleiben. Eine Min-Max-Skalierung
  auf das Intervall $[0, 1]$ ermöglicht eine intuitive Interpretation: Ein
  Gewicht repräsentiert die Bereitschaft, eine prozentuale Verschlechterung
  bei einem Kriterium gegen eine Verbesserung bei einem anderen
  einzutauschen.

+ *Recheneffizienz:* Die Normalisierung darf die Lösungszeit des MILP nicht
  nennenswert erhöhen.

==== Analytische Min-Max-Skalierung

Um die verschiedenen Einheiten (Kosten in EUR, Zeit in Minuten, Emissionen in kg CO₂) vergleichbar zu machen, müssen sie normalisiert werden. Zwei theoretisch denkbare Standardverfahren scheiden hierbei aus Praxisgründen aus:

1. *Exakte Min-Max-Skalierung:*
  Hierbei würde das Optimierungsproblem vorab für jedes Kriterium (Kosten, Zeit, Emissionen) einzeln gelöst, um die exakten Best- und Worst-Case-Werte im Lösungsraum zu bestimmen. Da das Lösen dieses Modells ohnehin sehr rechenintensiv (NP-schwer) ist, würde dieses dreifache Vorab-Lösen die Gesamtrechenzeit vervierfachen.

2. *Z-Score-Standardisierung:*
  Dieses bekannte Verfahren normiert Werte über Mittelwert und Standardabweichung. Um diese Kennzahlen für alle möglichen Transportwege zu berechnen, müsste man jedoch jede theoretisch denkbare Route im Vorhinein auflisten. Diese vollständige Pfad-Auflistung ist mathematisch aufwendiger als die eigentliche Optimierung selbst.

Das Modell verwendet daher eine *analytische Min-Max-Skalierung*, die sendungsspezifische Unter- und Obergrenzen in $O(1)$ (d. h. in konstanter Rechenzeit pro Sendung) ableitet. Die hierfür benötigten globalen Netzwerkkennzahlen (wie minimale Kapazitäten oder maximale Geschwindigkeiten) werden vorab einmalig berechnet. Für jede Sendung $k$ werden die Schätzintervalle

$ (C_k^-, C_k^+), quad (T_k^-, T_k^+), quad (E_k^-, E_k^+) $

bestimmt sowie die geschützten Wertebereiche

$ Delta C_k = max(C_k^+ - C_k^-, epsilon), $
$ Delta T_k = max(T_k^+ - T_k^-, epsilon), $
$ Delta E_k = max(E_k^+ - E_k^-, epsilon), quad epsilon = 10^(-9). $

==== Herleitung der Schätzgrenzen

Ausgangspunkt ist die verfügbare Zeit einer Sendung

$ L_k = max(0, min(D_k, T^"H") - r_k) $

sowie die maximale Netzwerkgeschwindigkeit, welche aus den Transportkanten des nicht zeitexpandierten Netzwerks $A_"trans"$ abgeleitet wird:

$ v^"max" = max_(t in A_"trans") d_t / tau_t, $

wobei $d_t$ die Streckenlänge und $tau_t$ die Dauer der Kante $t$ bezeichnet. Daraus
ergeben sich die maximal erreichbare Distanz $d_k^+ = v^"max" L_k$ sowie die Luftliniendistanz $d_k^-$ zwischen Start- und Zielhub, welche über die Haversine-Formel (vgl. @enwiki:1358395081) berechnet wird:
$
  a = sin^2((phi_2 - phi_1) / 2) + cos(phi_1) cos(phi_2) sin^2((lambda_2 - lambda_1) / 2),
$
$
  d_k^- = 2 R arcsin(sqrt(a)),
$
wobei $R = 6371 "km"$ den Erdradius, $phi_1, phi_2$ die Breitengrade und $lambda_1, lambda_2$ die Längengrade (in Bogenmaß) der beiden Hubs bezeichnen.



Für die Zeitgrenzen folgt:

$ T_k^- = d_k^- / v^"max", quad T_k^+ = L_k. $

Für die *Kosten- und Emissionsgrenzen* werden die minimalen und maximalen modusspezifischen Faktoren $c^-$, $c^+$ (Kosten je Tonnenkilometer) sowie $e^-$, $e^+$ (Emissionen je Tonnenkilometer) herangezogen.

Die maximal geschätzte Anzahl an Reiseabschnitten (Segmenten) $m_k$ basiert auf der verfügbaren Zeit $L_k$ und der kürzesten Kantendauer $tau^"min"$ des Netzwerks:
$
  m_k = max(1, L_k / tau^"min").
$

Die maximale Anzahl benötigter Fahrzeuge je Segment $nu_k^"max"$ wird aus dem Sendungsgewicht $q_k$ und der kleinsten Kapazität aller Transportmittel $u^"min"$ abgeleitet:
$
  nu_k^"max" = max(1, ceil(q_k / u^"min")).
$

Die Schätzgrenzen für die Kosten und Emissionen lauten damit:


$
  C_k^- = d_k^- c^- q_k, quad
  C_k^+ = d_k^+ c^+ q_k + m_k F^"max" nu_k^"max",
$

$
  E_k^- = d_k^- e^- q_k, quad
  E_k^+ = d_k^+ e^+ q_k + m_k G^"max" nu_k^"max".
$

Falls eine obere Schätzung nicht strikt größer als die untere ist, wird der
Wertebereich auf mindestens eins gesetzt.

==== Fixkosten-Koeffizienten

Da Fixkosten und Fixemissionen bei Konsolidierung von mehreren Sendungen
geteilt werden, können sie keiner einzelnen Sendung eindeutig zugeordnet
werden. Ihre Zielfunktionskoeffizienten werden deshalb als Mittelwerte über
alle Sendungen gebildet:

$
  alpha_C = 1 / (|K|) sum_(k in K) lambda_k^C / (Delta C_k), quad
  alpha_E = 1 / (|K|) sum_(k in K) lambda_k^E / (Delta E_k).
$


=== Weiche Restriktionen und Diagnosefähigkeit <sec:soft-constraints>

Ein Standardansatz der ganzzahligen Optimierung formuliert alle
Nebenbedingungen als harte Restriktionen. Werden dabei Lieferfristen zu eng,
Budgets zu gering oder Emissionslimits zu restriktiv gesetzt, meldet der
Solver lediglich, dass keine zulässige Lösung existiert (_Infeasible_),
ohne anzugeben, welche Bedingung verletzt wurde und um wie viel.

Das Modell unterscheidet daher zwischen zwei Klassen von
Nebenbedingungen:

- *Harte Restriktionen* (Flusserhaltung, Kapazitätsgrenzen) beschreiben
  physikalische Gesetzmäßigkeiten, die unter keinen Umständen verletzt
  werden dürfen.
- *Weiche Restriktionen* (Lieferfristen, Preis- und Emissionsbudgets)
  beschreiben betriebliche Vorgaben, die durch nichtnegative
  Schlupfvariablen aufgeweicht werden. Die Schlupfvariable $s$ misst die
  exakte Höhe einer Grenzüberschreitung:
  $ X - s <= "Limit" quad "mit" s >= 0. $

Durch die Bestrafung der Schlupfvariablen in der Zielfunktion mit dem
Strafkoeffizienten $rho$ wird sichergestellt, dass der Solver
Grenzverletzungen nur im äußersten Notfall akzeptiert.

Im Ergebnis liefert das Modell auch bei unlösbaren Vorgaben eine
auswertbare Lösung: Die positiven Schlupfwerte zeigen dem Anwender
präzise, welche Restriktion um welchen Betrag verletzt wurde und
ermöglichen eine gezielte Anpassung der Eingabeparameter.


== Heuristischer Ansatz <ch:heuristic-approach>

Neben dem exakten MILP-Solver werden zwei graphbasierte Heuristiken formuliert,
die auf demselben zeitexpandierten Netzwerk $G^T = (N^T, A^T)$ operieren:
ein Dijkstra-Router und ein A\*-Router. Für Einzelsendungen liefern beide
das global optimale Ergebnis; für Mehrfachsendungen wird ein sequentielles
Verfahren mit anschließender Large-Neighborhood-Search-Optimierung (LNS) eingesetzt.

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

Dieser Score entspricht im Aufbau der Zielfunktion des MILP (@eq:routing),
wobei die konstanten Offset-Terme $C_k^-$, $T_k^-$, $E_k^-$ weggelassen werden.
Da diese Terme für alle Kanten konstant sind, verändern sie die Rangfolge der
Pfade nicht und die Optimalität des kürzesten Weges bleibt erhalten.

=== Kürzeste-Weg-Suche (Dijkstra) <sec:dijkstra-formulation>

Für eine Einzelsendung $k$ wird der optimale Pfad als klassisches
Kürzeste-Weg-Problem auf dem zeitexpandierten Graphen formuliert (vgl. @ahuja1993networkflows[S. 94]):

$
  min_(P in cal(P)_k) sum_(a in P) sigma(a, k)
$ <eq:shortest-path>

wobei $cal(P)_k$ die Menge aller zulässigen Pfade von den Startknoten
$N_k^"S"$ zu den Zielknoten $N_k^"Z"$ mit $t(n) <= D_k$ bezeichnet.

Für eine einzelne Sendung entspricht das Problem einem klassischen Kürzeste-Weg-Problem, welches durch den Dijkstra-Router @Dijkstra1959 nachweislich global optimal gelöst wird. Für mehrere Sendungen ist dies aufgrund der geteilten Fixkosten bei Konsolidierungen (vgl. @eq:fixed) nicht mehr der Fall.

Zur Beschleunigung der Suche bei Einzelsendungen kann der Dijkstra-Router durch eine Heuristik $h(n)$ zum A\*-Router erweitert werden.


=== A\*-Heuristikfunktion <sec:astar-heuristic>

Der A\*-Router @hart1968formal erweitert den Dijkstra-Router um eine Heuristikfunktion $h$, die für jeden Knoten eine untere Schranke der verbleibenden Kosten zum Ziel liefert.

In geografischen Anwendungen wird üblicherweise die Luftliniendistanz (z. B. per Haversine-Formel) als Heuristik verwendet. In einem multimodalen Netzwerk stößt dieser Ansatz jedoch an Grenzen: Zum einen ist die Kantenbewertung (Arc Score) ein gewichteter Wert aus Kosten, Zeit und Emissionen, der sich nicht direkt proportional zur Luftlinie verhält. Zum anderen vernachlässigt die Luftlinie die tatsächliche Konnektivität des Netzwerks. Sie würde Sackgassen oder spärlich verbundene Hubs übersehen, was A\* dazu zwingen würde, weite Teile des zeitexpandierten Suchraums unnötig zu explorieren.

Aus diesem Grund erfolgt die Berechnung durch einen Rückwärts-Dijkstra auf dem
nicht zeitexpandierten Netz, der für jeden Hub $h in H$ den minimalen
gewichteten Score zum Zielhub $h_k^"Z"$ ermittelt. Sei $A$ die Menge der Kanten des nicht zeitexpandierten Netzwerks mit dem Score

$
  overline(sigma)(a, k) =
  lambda_k^C dot (c_a dot q_k) / (Delta C_k)
  + lambda_k^T dot tau_a / (Delta T_k)
  + lambda_k^E dot (e_a dot q_k) / (Delta E_k)
$

Dann berechnet der Rückwärts-Dijkstra:

$
  h(n) = min_(P: h_n -> h_k^"Z" "in" A) sum_(a in P) overline(sigma)(a, k)
$ <eq:astar-heuristic>

Da $overline(sigma)$ die Fixkosten sowie Warte- und Transferkanten
nicht berücksichtigt, unterschätzt $h$ die tatsächlichen Restkosten
auf dem zeitexpandierten Graphen stets. Damit ist die Heuristik
zulässig und konsistent, sodass A\* die
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
eine Large Neighbourhood Search (LNS) nach dem Ruin-and-Recreate-Prinzip @SCHRIMPF2000139
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


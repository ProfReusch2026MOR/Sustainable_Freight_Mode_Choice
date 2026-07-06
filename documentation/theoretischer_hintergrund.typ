= Theoretischer Hintergrund <ch:theory>

Dieses Kapitel widmet sich den theoretischen Grundlagen der Netzwerkoptimierung im Operations Research. Zunächst werden grundlegende Netzwerkfluss-Modelle eingeführt und gegeneinander abgegrenzt. Darauf aufbauend wird das *Fixed-Cost Capacitated Multicommodity Network Design (CMND)* mathematisch formalisiert. Abschließend wird die zeitliche Erweiterung statischer Netzwerke durch das Konzept zeitexpandierter Graphen (*Space-Time Networks*) erörtert.

== Netzwerkfluss-Modelle im Operations Research

Die mathematische Modellierung von Logistik- und Transportsystemen stützt sich maßgeblich auf die Graphentheorie. Ein Transportnetzwerk wird als gerichteter Graph $G = (N, A)$ formalisiert, wobei $N$ die Menge der Knoten (Nodes) repräsentiert und $A$ die Menge der gerichteten Kanten (Arcs) darstellt @bertsekas1998network [S.~3]. Eine gerichtete Kante $(i, j) in A$ wird dabei als geordnetes Paar von Knoten verstanden, das eine Richtung vom Knoten $i$ zum Knoten $j$ definiert und somit strikt von der Kante $(j, i)$ zu unterscheiden ist @bertsekas1998network [S.~3]. Jedem Arc $(i, j)$ werden spezifische Parameter zugeordnet, wie variable Transportkosten $c_(i j)$, Kapazitäten $u_(i j)$ sowie Transportzeiten $d_(i j)$.

=== Shortest-Path Problem

Ein klassischer Spezialfall des allgemeinen Netzwerkfluss-Problems ist das Shortest-Path Problem. Laut @bradley1977applied [S.~233-234] besteht die Essenz des Problems darin, einen Pfad durch ein Netzwerk von einer bestimmten Quelle (Source $s$) zu einer bestimmten Senke (Sink $t$) zu finden, der die Summe der Kantenbewertungen (Distanzen, Zeiten oder Kosten $c_(i j)$) minimiert.

Dieses Problem lässt sich mathematisch als Netzwerkfluss-Problem formulieren, bei dem genau eine Flusseinheit vom Start- zum Zielknoten gesendet wird. Die Bilanzierung an den Knoten erfolgt dabei über die *Flusserhaltungsbedingung*, die sicherstellt, dass der Fluss lückenlos und ohne Verluste durch das Netzwerk fließt @bradley1977applied [S.~234]:

$ min z = sum_i sum_j c_(i j) x_(i j) $

unter den Nebenbedingungen:

$
  sum_j x_(i j) - sum_k x_(k i) = cases(
    1 & "falls " i = s " (Source)",
    0 & "sonst",
    -1 & "falls " i = t " (Sink)"
  ) quad forall i in N
$ <eq:shortest-path-conservation>

$ x_(i j) >= 0 quad forall (i, j) in A $

Hierbei repräsentiert $x_(i j) in {0, 1}$ im Optimum, ob die Kante $(i, j)$ Teil des kürzesten Pfades ist. @eq:shortest-path-conservation erzwingt die Kontinuität des Pfades:
- Am Startknoten $s$ wird eine Einheit eingespeist ($1$).
- Am Zielknoten $t$ wird eine Einheit entnommen ($-1$).
- An allen anderen Knoten (Transitknoten) entspricht der Zufluss exakt dem Abfluss ($0$), was Lücken, Zyklen oder Unterbrechungen im Pfad verhindert.

== Problemklassen der Netzwerkoptimierung

Im Operations Research wird bei Transportproblemen auf taktischer und operativer Ebene zwischen zwei wesentlichen Problemklassen unterschieden @CRAINIC2000272:

=== Network Flow Planning (NFP)
Network Flow Planning (NFP)-Probleme gehen von einer feste, unveränderlichen Infrastruktur aus, bei der alle Kantenkapazitäten und angebotenen Dienste (wie feste Fahrpläne) bereits vorgegeben sind. Die planerische Entscheidung beschränkt sich in diesem Fall ausschließlich darauf, wie viel Fluss (z. B. Sendungsmenge) über welche der existierenden Pfade geleitet wird. Ziel der Optimierung is es, die rein variablen Transportkosten zu minimieren, während Restriktionen der Infrastruktur eingehalten werden.

=== Service Network Design (SND)
Service Network Design (SND)-Probleme betrachten eine taktische Planungsebene, bei der das Angebot an Diensten (wie Züge, Lkw-Linien oder Flüge) flexibel gestaltet werden kann @CRAINIC2000272. Die Entscheidung umfasst somit zeitgleich, welche Dienste überhaupt angeboten (d. h. "geöffnet") werden und wie die Sendungsflüsse auf die aktivierten Dienste aufgeteilt werden. Die ökonomische Herausforderung liegt darin, dass das Anbieten eines Dienstes hohe, flussunabhängige Fixkosten (z. B. für die Fahrzeugbereitstellung, Trassengebühren oder Personal) verursacht, unabhängig davon, ob das Fahrzeug voll beladen oder leer betrieben wird.

== Fixed-Cost Capacitated Multicommodity Network Design (CMND)

Das mathematische Fundament für Service-Network-Design-Probleme bildet das *Fixed-Cost Capacitated Multicommodity Network Design (CMND)*. Wie @ghamlouche2003cycle beschreiben, repräsentiert das CMND-Modell eine generische Formulierung für eine Vielzahl von Planungs- und Betriebsaufgaben in Transport- und Logistiksystemen.

Das CMND-Modell dient dazu, aus einer gegebenen Menge potenzieller Verbindungen (Kanten) eine Auswahl zu treffen und gleichzeitig die Flüsse mehrerer Sendungen über diese aktivierten Verbindungen zu leiten. Für jede genutzte Verbindung fällt eine fixe Bereitstellungsgebühr an, während der tatsächliche Transport variable Kosten verursacht. Ziel ist es, die Summe aus diesen fixen Bereitstellungskosten und den variablen Transportkosten aller Sendungen zu minimieren, während die Kapazitätsgrenzen eingehalten und alle Transportbedarfe gedeckt werden @ghamlouche2003cycle.

=== Mathematische Formulierung
Die mathematische Formulierung des CMND stützt sich auf eine kantenbasierte Modellierung @ghamlouche2003cycle. Gegeben sei ein gerichteter Graph $G = (N, A)$ und eine Menge von Sendungen (Commodities) $K$, wobei jede Sendung $k in K$ ein Transportvolumen von $w^k$ Einheiten aufweist, das von einem Startknoten $O^k$ zu einem Zielknoten $D^k$ befördert werden muss. Zur Abbildung der Entscheidungen werden binäre Entscheidungsvariablen $y_(i j) in {0, 1}$ definiert, welche angeben, ob ein Arc $(i, j) in A$ geöffnet ($1$) oder geschlossen ($0$) wird. Die kontinuierlichen Fluss-Variablen $x_(i j)^k >= 0$ erfassen die absolute Menge der Sendung $k in K$, die über die Kante $(i, j)$ transportiert wird @ghamlouche2003cycle.

Das CMND-Modell lässt sich damit wie folgt formulieren:

$ min z(x, y) = sum_((i,j) in A) f_(i j) y_(i j) + sum_(k in K) sum_((i,j) in A) c_(i j)^k x_(i j)^k $

Die Zielfunktion minimiert die Systemgesamtkosten, welche sich aus den Fixkosten $f_(i j)$ für das Aktivieren der Kanten und den variablen, flussabhängigen Transportkosten $c_(i j)^k$ je Einheit zusammensetzen. Diese Minimierung erfolgt unter Berücksichtigung verschiedener Restriktionen. Zunächst muss für jede Sendung $k in K$ auf jedem Knoten $i in N$ die Flusserhaltung gewährleistet sein:

$
  sum_(j: (i,j) in A) x_(i j)^k - sum_(j: (j,i) in A) x_(j i)^k = cases(
    w^k & "falls " i = O^k " (Origin)",
    -w^k & "falls " i = D^k " (Destination)",
    0 & "sonst"
  ) quad forall i in N, forall k in K
$ <eq:cmnd-flow-conservation>

Die Kapazitätsbedingungen begrenzen den Gesamtfluss aller Sendungen durch die maximale Kapazität $u_(i j)$ der Kante:

$ sum_(k in K) x_(i j)^k <= u_(i j) y_(i j) quad forall (i,j) in A $ <eq:cmnd-capacity>

Zudem bewirkt diese Bedingung, dass Fluss über eine Kante nur transportiert werden darf, wenn diese auch aktiviert ist ($y_(i j) = 1$). Ist eine Kante geschlossen ($y_(i j) = 0$), wird der Fluss über sie auf Null gezwungen.

Vervollständigt wird das Modell durch Nichtnegativitäts- und Ganzzahligkeitsbedingungen für die Entscheidungsvariablen:

$ x_(i j)^k >= 0 quad forall (i,j) in A, forall k in K $

$ y_(i j) in {0, 1} quad forall (i,j) in A $

== Zeitexpandierte Netzwerke <sec:time-expanded>

Um dynamische Flüsse über die Zeit zu modellieren, wird das statische Netzwerk zeitlich expandiert. Die formale Definition eines solchen zeitexpandierten Graphen lässt sich nach @skutella2009introduction [S.~458-459] wie folgt beschreiben:

Gegeben sei ein statisches Netzwerk $G = (N, A)$ mit Kapazitäten $u$, nicht-negativen ganzzahligen Transportzeiten $tau$ sowie Transportkosten $c$ auf den Kanten. Für einen gegebenen Zeithorizont $T in bb(Z)_(>0)$ wird das entsprechende zeitexpandierte Netzwerk $G^T = (N^T, A^T)$ wie folgt definiert. Für jeden physischen Knoten $v in N$ werden $T$ zeitliche Kopien erzeugt, sodass die Knotenmenge $N^T$ definiert ist als:

$ N^T := { v_theta | v in N, theta = 0, 1, ..., T-1 } $

Für jeden Arc $e = (v, w) in A$ existieren $T - tau_e$ Kopien, wobei der zeitexpandierte Arc $e_theta$ den Knoten $v_theta$ mit dem Knoten $w_(theta+tau_e)$ verbindet. Jede Kantenkopie $e_theta$ erbt dabei die Kapazität $u_(e_theta) := u_e$ sowie die Transportkosten $c_(e_theta) := c_e$.

Zusätzlich enthält das Netzwerk Haltekanten (Waiting Arcs), um das Warten an einem Knoten über aufeinanderfolgende Zeitschritte abzubilden.

Die Kantenmenge $A^T$ setzt sich somit aus zwei disjunkten Teilmengen zusammen:
- *Transportkanten:*
  $ A^T_("trans") := { (v_theta, w_(theta+tau_e)) | e = (v, w) in A, 0 <= theta <= T - 1 - tau_e } $
- *Haltekanten:*
  $ A^T_("wait") := { (v_theta, v_(theta+1)) | v in N, 0 <= theta <= T - 2 } $

Es gilt somit $A^T = A^T_("trans") union A^T_("wait")$.

=== Wachstum
Die Größe des zeitexpandierten Graphen $G^T$ wächst linear mit dem Zeithorizont $T$: Für jeden physischen Knoten werden $T$ zeitliche Kopien erzeugt, sodass $|N^T| = T dot |N|$ gilt, und die Zahl der Transport- und Haltekanten wächst entsprechend proportional mit $T$. Diese lineare Expansion des Graphen überträgt sich jedoch überproportional auf die Komplexität des zugehörigen Optimierungsproblems: Da für jede Sendung $k in K$ eine eigene Routingentscheidung auf jeder Kante getroffen wird, wächst die Zahl der binären Variablen mit $O(|A^T| dot |K|)$ und damit im Produkt aus Horizont und Sendungsanzahl. Bereits moderate Erhöhungen beider Größen lassen den Suchraum des gemischt-ganzzahligen Programms kombinatorisch anwachsen -- ein Effekt, der in @sec:stress-test empirisch bestätigt wird und die Notwendigkeit heuristischer Verfahren motiviert. In der praktischen Umsetzung wird die reine Zeitrasterung zusätzlich durch eine ereignisbasierte Konstruktion ersetzt (vgl. @ch:mathematical-model), welche die Knotenmenge auf tatsächlich relevante Ereigniszeitpunkte beschränkt und so den Vorfaktor gegenüber einer festen Diskretisierung deutlich senkt.

= Implementierung & Lösungsansätze <ch:implementation>

== Datengrundlage und Datenmodell
Die Struktur der Eingabedaten lehnt sich an reale logistische Netzwerke an. Es wird eine Netzwerkinfrastruktur mit vier großen deutschen Hubs (Berlin, Hamburg, Frankfurt, München) abgebildet. Jede Transportkante besitzt einen täglichen Abfahrtsfahrplan. 

Das Datenmodell umfasst:
- *Hubs:* Spezifizieren die unterstützten Modi und die zeitlichen Transferfenster für den Wechsel zwischen Modi (z. B. Umladen von Schiene auf Straße in Berlin).
- *Verbindungen (Arc Templates):* Enthalten Start- und Zielort, Distanz, Modus und die täglichen Abfahrtszeiten.
- *Kosten- und Emissionsfaktoren:* Verkehrsträgerspezifische Faktoren je Tonnenkilometer ($t$-km) sowie feste Handlingkosten pro Umschlag.

Für größere Instanzen werden die Daten aus CSV-Dateien (`road_arcs.csv`, `air_arcs.csv`, `sea_routes_updated_18kts.csv` etc.) eingelesen, was eine flexible Skalierung des Netzwerks ermöglicht.

== Exakte Lösung mit Python PuLP
Das in ch:problem-description formulierte gemischt-ganzzahlige Optimierungsproblem wird in Python mit dem Modellierungs-Framework *PuLP* implementiert. Die Kantenvariablen $x_(a,k)$ sowie die Bündelungsvariablen $y_a$ und $z_a$ werden als `LpBinary` bzw. `LpInteger` deklariert.
Als zugrundeliegender Solver wird der COIN-OR Branch-and-Cut Solver (*CBC*) verwendet. Der Solver durchsucht den Lösungsraum systematisch mittels Branch-and-Bound und Schnittebenenverfahren (Cutting Planes), um globale Optimalität nachzuweisen.

= Heuristische Lösung

Für das multimodale Transportproblem wurden neben dem exakten MILP-Modell zwei heuristische Lösungsansätze entwickelt. Beide Verfahren verfolgen das Ziel, in großen Transportnetzwerken schnell zulässige und qualitativ hochwertige Routen zu bestimmen. Während das exakte Optimierungsmodell eine mathematisch optimale Lösung anstrebt, stehen bei den Heuristiken kurze Laufzeiten, praktische Anwendbarkeit und eine flexible Berücksichtigung mehrerer Zielgrößen im Vordergrund.

Die erste Heuristik basiert auf einem erweiterten Dijkstra-Algorithmus. Sie konstruiert direkt eine Route vom Start- zum Zielknoten. Die zweite Heuristik erweitert diesen Ansatz durch eine Tabu Search. Dabei wird zunächst ebenfalls eine Startlösung mit dem Dijkstra-Verfahren erzeugt. Anschließend wird diese Route iterativ verändert und verbessert. Somit ist die Tabu Search in diesem Projekt keine vollständig unabhängige Routensuche, sondern eine Metaheuristik zur Verbesserung der zuvor berechneten Dijkstra-Lösung.

== Multimodale Dijkstra-Heuristik

Die Dijkstra-Heuristik bildet die Grundlage des heuristischen Lösungsansatzes. Das Transportnetzwerk wird als gerichteter Graph dargestellt. Die Knoten beschreiben Standorte wie Lager, Häfen, Flughäfen oder Bahnterminals. Die Kanten beschreiben mögliche Transportverbindungen zwischen diesen Standorten.

$
G = (V, E)
$

Dabei steht $V$ für die Menge der Knoten und $E$ für die Menge der gerichteten Kanten. Eine einzelne Kante verbindet einen Startknoten mit einem Zielknoten:

$
e = (i, j)
$

Jede Kante besitzt mehrere Attribute. Dazu gehören der Verkehrsträger, die Distanz, die Transportzeit, die Kosten und die CO₂-Emissionen. Im Code werden diese Informationen in der Klasse `Edge` gespeichert:

```python
@dataclass(frozen=True)
class Edge:
    source: str
    target: str
    mode: str
    distance_km: float
    duration_min: float
    cost: float
    emissions: float
    arc_id: str
```

Die Besonderheit des Ansatzes besteht darin, dass nicht nur eine einzelne Größe wie die Distanz minimiert wird. Stattdessen werden mehrere Zielgrößen gemeinsam betrachtet. Für jede Kante werden zunächst die Transportkosten und Emissionen berechnet. Die Kosten einer Kante ergeben sich aus Distanz, Kostensatz des Verkehrsträgers und Sendungsgewicht:

$
c_e = d_e dot k_e dot w
$

Die Emissionen einer Kante ergeben sich entsprechend aus Distanz, Emissionsfaktor und Sendungsgewicht:

$
q_e = d_e dot epsilon_e dot w
$

Dabei bezeichnet $c_e$ die Kosten der Kante, $q_e$ die Emissionen, $d_e$ die Distanz, $k_e$ den Kostensatz, $epsilon_e$ den Emissionsfaktor und $w$ das Sendungsgewicht. Im Programm erfolgt diese Berechnung beim Einlesen des Netzwerks:

```python
cost = distance * float(
    factors[mode]["cost_per_ton_km"]
) * shipment_weight_tons

emissions = distance * float(
    factors[mode]["emissions_kg_per_ton_km"]
) * shipment_weight_tons
```

Da Kosten, Zeit und Emissionen unterschiedliche Einheiten und Größenordnungen besitzen, werden sie vor der Bewertung normalisiert. Ohne Normalisierung könnte eine Zielgröße allein deshalb dominieren, weil ihre Zahlenwerte größer sind. Daher werden durchschnittliche Skalenwerte für Kosten, Zeit und Emissionen bestimmt. Anschließend wird jede Zielgröße durch den jeweiligen Skalenwert geteilt:

$
c_e^* = c_e / s_c
$

$
t_e^* = t_e / s_t
$

$
q_e^* = q_e / s_q
$

Die Größen $s_c$, $s_t$ und $s_q$ stehen für die verwendeten Skalenwerte der Kosten, Zeit und Emissionen. Auf dieser Grundlage wird für jede Kante ein gewichteter Bewertungswert berechnet:

$
S(e) = alpha dot c_e^* + beta dot t_e^* + gamma dot q_e^* + delta dot M_e
$

Die Parameter $alpha$, $beta$ und $gamma$ beschreiben die Gewichtung von Kosten, Zeit und Emissionen. Der Parameter $delta$ gewichtet die Bestrafung eines Verkehrsträgerwechsels. Der Wert $M_e$ ist gleich 1, wenn sich der Verkehrsträger im Vergleich zur vorherigen Kante ändert, und sonst 0. Dadurch kann der Algorithmus nicht nur günstige, schnelle oder emissionsarme Routen bevorzugen, sondern auch unnötige Wechsel zwischen Verkehrsträgern vermeiden.

Die Bewertungsfunktion wird im Code in der Funktion `edge_score()` umgesetzt:

```python
def edge_score(edge, weights, scales, previous_mode):
    mode_change_penalty = 1.0 if previous_mode is not None \
        and previous_mode != edge.mode else 0.0

    return (
        weights["cost"] * normalize(edge.cost, scales["cost"])
        + weights["time"] * normalize(edge.duration_min, scales["time"])
        + weights["emissions"] * normalize(edge.emissions, scales["emissions"])
        + weights.get("mode_change", 0.0) * mode_change_penalty
    )
```

Der eigentliche Lösungsalgorithmus arbeitet mit einer Prioritätswarteschlange. Zu Beginn wird der Startknoten mit Kosten 0 eingefügt. Danach wird immer der aktuell beste Zustand aus der Warteschlange entnommen. Von diesem Zustand aus werden alle ausgehenden Kanten geprüft. Für jede mögliche Fortsetzung wird der neue Bewertungswert berechnet. Wenn dieser neue Wert besser ist als ein bisher bekannter Wert, wird der entsprechende Zustand aktualisiert und erneut in die Warteschlange eingefügt.

Ein wichtiger Unterschied zum klassischen Dijkstra-Algorithmus liegt im Zustand des Verfahrens. Der Zustand besteht nicht nur aus dem aktuellen Knoten, sondern zusätzlich aus dem zuletzt verwendeten Verkehrsträger:

$
s = (v, m)
$

Dabei steht $v$ für den aktuellen Standort und $m$ für den zuletzt genutzten Modus. Diese Erweiterung ist notwendig, weil der Strafwert für Verkehrsträgerwechsel nur berechnet werden kann, wenn der vorherige Modus bekannt ist. Im Code wird dieser Zustand wie folgt aufgebaut:

```python
start_state = (start, None)
new_state = (edge.target, edge.mode)
```

Die Implementierung ist formal als A\*-Suche aufgebaut. Die allgemeine Bewertungsfunktion lautet:

$
f(n) = g(n) + h(n)
$

Dabei beschreibt $g(n)$ die bisher aufgelaufenen Kosten und $h(n)$ eine Schätzung der verbleibenden Kosten bis zum Ziel. Da im verwendeten Netzwerk keine vollständige geographische Heuristik eingesetzt wird, wird $h(n)$ auf 0 gesetzt:

$
h(n) = 0
$

Damit ergibt sich:

$
f(n) = g(n)
$

Die A\*-Struktur verhält sich in diesem Fall wie ein gewichteter Dijkstra-Algorithmus. Im Code ist dies an der Heuristikfunktion erkennbar:

```python
def heuristic(_: str) -> float:
    return 0.0
```

Nach der Routensuche wird eine einfache lokale Verbesserung durchgeführt. Dabei wird geprüft, ob zwei aufeinanderfolgende Kanten durch eine direkte Verbindung ersetzt werden können. Aus einer Teilroute

$
A arrow.r B arrow.r C
$

kann somit eine kürzere oder günstigere Verbindung

$
A arrow.r C
$

werden. Diese Verbesserung wird nur übernommen, wenn die direkte Verbindung nach der Zielfunktion einen niedrigeren Wert besitzt. Die Prüfung wird im Code durch die Funktion `improve_route_by_shortcuts()` umgesetzt:

```python
direct_edges = [
    e for e in graph.get(a, [])
    if e.target == c
]
```

Zusätzlich berechnet das Verfahren vier unterschiedliche Routentypen. Neben der nutzerdefinierten Präferenzroute werden jeweils eine Kosten-, Zeit- und CO₂-minimale Route bestimmt. Dadurch können verschiedene Entscheidungsziele verglichen werden, ohne das Grundmodell verändern zu müssen:

```python
{
    "name": "Kostenminimum",
    "cost": 1.0,
    "time": 0.0,
    "emissions": 0.0,
    "mode_change": mode_change,
}
```

Die Dijkstra-Heuristik ist damit eine konstruktive Heuristik. Sie erzeugt direkt eine vollständige Route vom Start zum Ziel. Ihre Stärke liegt vor allem in der geringen Laufzeit und der klar nachvollziehbaren Vorgehensweise. Gleichzeitig ist der Suchprozess stark durch die Bewertungsfunktion geprägt. Alternative Routen, die zunächst schlechter erscheinen, später aber zu besseren Gesamtlösungen führen könnten, werden nur eingeschränkt betrachtet. Genau an diesem Punkt setzt die zweite Heuristik an.

== Tabu-Search-Heuristik

Die Tabu-Search-Heuristik erweitert die Dijkstra-Heuristik um eine iterative Verbesserung. Zunächst wird eine Startlösung mit der beschriebenen Dijkstra-Suche erzeugt. Diese Startlösung wird anschließend systematisch verändert, indem einzelne Kanten der aktuellen Route temporär gesperrt werden. Dadurch wird der Algorithmus gezwungen, alternative Wege im Netzwerk zu suchen.

Die Startlösung kann formal als $x_0$ beschrieben werden:

$
x_0 = H_D
$

Dabei steht $H_D$ für die Dijkstra-Heuristik. Im Code wird die Startlösung in der Funktion `tabu_search_route()` erzeugt:

```python
current = astar_multimodal(
    graph=graph,
    start=start,
    goal=goal,
    weights=weights,
    scales=scales,
    max_expansions=max_expansions,
)
```

Nach der Berechnung der Startlösung wird diese zunächst ebenfalls lokal verbessert:

```python
current = improve_route_by_shortcuts(
    current,
    graph,
    weights,
    scales,
)
```

Eine vollständige Route besteht aus einer Folge von Kanten:

$
R = (e_1, e_2, dots, e_n)
$

Die Bewertung der gesamten Route ergibt sich aus der Summe der Kantenbewertungen:

$
F(R) = sum_(i=1)^n S(e_i)
$

Diese Bewertungsfunktion stellt sicher, dass Dijkstra-Startlösung und Tabu-Search-Nachbarn nach demselben Zielsystem beurteilt werden. Im Code wird dies über `route_score_from_edges()` umgesetzt:

```python
def route_score_from_edges(edges, weights, scales):
    return sum(
        edge_score(
            edge,
            weights,
            scales,
            edges[i - 1].mode if i > 0 else None
        )
        for i, edge in enumerate(edges)
    )
```

Der zentrale Schritt der Tabu Search ist die Erzeugung von Nachbarschaftslösungen. Eine Nachbarlösung entsteht, indem eine Kante der aktuellen Route temporär verboten wird. Angenommen, die aktuelle Route enthält die Kante $B arrow.r C$. Wenn diese Kante gesperrt wird, muss die Routensuche einen alternativen Pfad finden. Dadurch können neue Routen entstehen, die mit der ursprünglichen Dijkstra-Suche nicht ausgewählt wurden.

Die Nachbarschaft der aktuellen Lösung wird als $N(x)$ bezeichnet. Sie enthält alle Lösungen, die durch die Sperrung einzelner Kanten der aktuellen Route erzeugt werden. Im Code geschieht dies in der Funktion `generate_tabu_neighbors()`:

```python
candidate = astar_multimodal_with_forbidden_arcs(
    graph=graph,
    start=start,
    goal=goal,
    weights=weights,
    scales=scales,
    max_expansions=max_expansions,
    forbidden_arc_ids={move},
)
```

Die Funktion `astar_multimodal_with_forbidden_arcs()` entspricht grundsätzlich der Dijkstra-Suche, überspringt jedoch bestimmte Kanten:

```python
for edge in graph.get(node, []):
    if edge.arc_id in forbidden_arc_ids:
        continue
```

Damit wird gezielt verhindert, dass die aktuell gesperrte Verbindung erneut genutzt wird. Die Sperrung führt dazu, dass der Algorithmus andere Bereiche des Netzwerks untersucht. So kann die Suche aus einem lokalen Optimum ausbrechen.

Damit die Suche nicht ständig zwischen denselben Routen hin- und herwechselt, wird eine Tabuliste verwendet. Die Tabuliste speichert kürzlich verwendete Bewegungen für eine bestimmte Anzahl an Iterationen. In diesem Projekt entspricht eine Bewegung der Sperrung einer bestimmten Kante. Die Tabuliste kann vereinfacht dargestellt werden als:

$
T = (m_1, m_2, dots, m_k)
$

Dabei beschreibt $m_i$ eine gespeicherte Bewegung. Eine Bewegung bleibt so lange tabu, bis ihre Sperrdauer abgelaufen ist. Im Code wird dies über `tabu_tenure` gesteuert:

```python
tabu_list[selected_move] = iteration + tabu_tenure
```

In jeder Iteration werden mehrere Nachbarn erzeugt. Anschließend werden diejenigen Nachbarn entfernt, deren Bewegung tabu ist. Eine Ausnahme bildet das Aspirationskriterium. Ein eigentlich tabuierter Nachbar darf trotzdem gewählt werden, wenn er eine neue beste Gesamtlösung liefert. Formal gilt:

$
F(x') < F(x^*)
$

Dabei ist $x'$ die betrachtete Nachbarlösung und $x^*$ die bisher beste gefundene Lösung. Im Code wird diese Bedingung so umgesetzt:

```python
is_tabu = move in tabu_list and tabu_list[move] > iteration
aspiration = candidate.score < best.score

if not is_tabu or aspiration:
    admissible.append((move, candidate))
```

Aus allen zulässigen Nachbarn wird anschließend der beste ausgewählt:

$
x_(k+1) = arg min_(x in N(x_k)) F(x)
$

Die ausgewählte Lösung wird zur neuen aktuellen Lösung. Falls sie besser ist als die bisher beste Route, wird auch die globale Bestlösung aktualisiert:

```python
selected_move, selected_route = min(
    admissible,
    key=lambda item: item[1].score,
)

current = selected_route
```

Die Tabu Search endet, wenn eine maximale Anzahl an Iterationen erreicht wurde, keine zulässigen Nachbarn mehr vorhanden sind oder über mehrere Iterationen keine Verbesserung erzielt wurde:

```python
if iterations_without_improvement >= no_improvement_limit:
    break
```

Die Tabu-Search-Heuristik ist somit eine verbessernde Heuristik. Sie konstruiert die Lösung nicht vollständig neu, sondern startet mit einer vorhandenen Route und untersucht gezielt Alternativen. Dadurch kann sie bessere Lösungen finden als die reine Dijkstra-Heuristik, benötigt aber auch mehr Rechenzeit.

== Vergleich der beiden Heuristiken

Die beiden Heuristiken unterscheiden sich vor allem in ihrer Suchstrategie. Die Dijkstra-Heuristik ist ein direktes Konstruktionsverfahren. Sie beginnt beim Startknoten und erweitert schrittweise den aktuell besten Zustand, bis der Zielknoten erreicht wird. Dadurch ist sie schnell, deterministisch und gut nachvollziehbar. Die Tabu Search ist dagegen ein iteratives Verbesserungsverfahren. Sie nutzt die Dijkstra-Lösung als Ausgangspunkt und sucht anschließend nach besseren Alternativen.

Der betrachtete Lösungsraum ist bei der Tabu Search größer. Die Dijkstra-Heuristik sucht vor allem entlang der nach der Bewertungsfunktion besten Zustände. Die Tabu Search sperrt dagegen gezielt einzelne Kanten und erzwingt dadurch alternative Routen. Vereinfacht kann daher angenommen werden:

$
X_D subset X_T
$

Dabei steht $X_D$ für den durch die Dijkstra-Heuristik betrachteten Lösungsbereich und $X_T$ für den durch die Tabu Search zusätzlich untersuchten Bereich.

Auch beim Rechenaufwand unterscheiden sich die Verfahren deutlich. Die Dijkstra-Heuristik benötigt im Wesentlichen eine einzelne Suche im Graphen. Vereinfacht lässt sich der Aufwand mit folgender Ordnung beschreiben:

$
O(E dot log(V))
$

Die Tabu Search führt dagegen mehrere Suchläufe aus. Wenn $I$ Iterationen durchgeführt werden, ergibt sich vereinfacht:

$
O(I dot E dot log(V))
$

Daraus folgt, dass die Tabu Search im Allgemeinen rechenintensiver ist. Dieser zusätzliche Aufwand kann jedoch gerechtfertigt sein, wenn dadurch bessere Routen gefunden werden.

In Bezug auf die Lösungsqualität ist theoretisch zu erwarten, dass die Tabu Search mindestens gleich gute und häufig bessere Lösungen liefern kann. Der Grund dafür ist, dass sie mit der Dijkstra-Lösung startet und anschließend zusätzliche Alternativen prüft. Eine Garantie für eine globale optimale Lösung besteht jedoch nicht. Auch die Tabu Search bleibt ein heuristisches Verfahren. Sie kann bessere Lösungen finden, muss dies aber nicht in jedem Einzelfall tun.

Die Dijkstra-Heuristik eignet sich besonders dann, wenn schnell eine plausible Route benötigt wird. Dies ist beispielsweise für interaktive Anwendungen, erste Szenarioanalysen oder große Netzwerke mit begrenzter Rechenzeit relevant. Die Tabu Search eignet sich eher für Situationen, in denen zusätzliche Rechenzeit verfügbar ist und eine Verbesserung der Routenauswahl angestrebt wird.

#table(
  columns: 3,
  inset: 6pt,
  align: left,
  [Kriterium], [Dijkstra-Heuristik], [Tabu-Search-Heuristik],
  [Art des Verfahrens], [Konstruktive Heuristik], [Verbessernde Metaheuristik],
  [Startpunkt], [Startknoten im Graphen], [Dijkstra-Route],
  [Suchstrategie], [Erweitert den besten Zustand], [Erzeugt alternative Nachbarn],
  [Rechenzeit], [Gering], [Höher],
  [Lösungsraum], [Eher begrenzt], [Größer durch Alternativrouten],
  [Stärke], [Schnelle zulässige Lösung], [Potenzielle Verbesserung der Lösung],
  [Schwäche], [Kann Alternativen übersehen], [Höherer Rechenaufwand],
)

Zusammenfassend ergänzen sich beide Verfahren sinnvoll. Die Dijkstra-Heuristik liefert eine schnelle und stabile Basislösung für das multimodale Transportproblem. Die Tabu Search erweitert diesen Ansatz, indem sie die gefundene Lösung gezielt verändert und dadurch zusätzliche Bereiche des Lösungsraums untersucht. Für das Projekt entsteht damit ein zweistufiger heuristischer Lösungsansatz: Zunächst wird mit Dijkstra effizient eine Route konstruiert, anschließend wird diese Route durch Tabu Search verbessert. Der tatsächliche Nutzen der Tabu Search kann im Ergebnisteil anhand von Laufzeit, Kosten, Transportdauer und CO₂-Emissionen empirisch bewertet werden.

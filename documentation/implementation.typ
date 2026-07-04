= Umsetzung <ch:implementation>

== Datengrundlage und Datenmodell
Die Struktur der Eingabedaten lehnt sich an reale logistische Netzwerke an. Es wird eine Netzwerkinfrastruktur mit vier großen deutschen Hubs (Berlin, Hamburg, Frankfurt, München) abgebildet. Jede Transportkante besitzt einen täglichen Abfahrtsfahrplan.

Das Datenmodell umfasst:
- *Hubs:* Spezifizieren die unterstützten Modi und die zeitlichen Transferfenster für den Wechsel zwischen Modi (z. B. Umladen von Schiene auf Straße in Berlin).
- *Verbindungen (Arc Templates):* Enthalten Start- und Zielort, Distanz, Modus und die täglichen Abfahrtszeiten.
- *Kosten- und Emissionsfaktoren:* Verkehrsträgerspezifische Faktoren je Tonnenkilometer ($t$-km) sowie feste Handlingkosten pro Umschlag.

Für größere Instanzen werden die Daten aus CSV-Dateien (`road_arcs.csv`, `air_arcs.csv`, `sea_routes_updated_18kts.csv` etc.) eingelesen, was eine flexible Skalierung des Netzwerks ermöglicht.

== Exakte Lösung mit Python PuLP
Das in formulierte gemischt-ganzzahlige Optimierungsproblem wird in Python mit dem Modellierungs-Framework *PuLP* implementiert. Die Kantenvariablen $x_(a,k)$ sowie die Bündelungsvariablen $y_a$ und $z_a$ werden als `LpBinary` bzw. `LpInteger` deklariert.
Als zugrundeliegender Solver wird *HiGHS* über die PuLP-Schnittstelle verwendet. HiGHS löst das MILP mit Branch-and-Bound- und Presolve-Verfahren und unterstützt zusätzlich Zeitlimits für größere Instanzen. Dadurch können die Rechenexperimente reproduzierbar mit festen Instanzgrößen und Solver-Zeitgrenzen durchgeführt werden.

= Heuristische Verfahren zur multimodalen Routenplanung

In diesem Kapitel werden zwei heuristische Lösungsverfahren vorgestellt, die zur
Bestimmung kostengünstiger, schneller bzw. emissionsarmer Transportrouten in
einem multimodalen Netzwerk eingesetzt werden. Beide Verfahren wurden in Python
implementiert und nutzen dieselbe Netzwerkrepräsentation (Hubs und Kanten in
Form von Verkehrsmitteln, Distanzen, Kosten, Zeiten und Emissionen), sodass die
Ergebnisse direkt miteinander verglichen werden können. Zunächst wird die
Dijkstra-basierte Heuristik erläutert, anschließend die Tabu-Search-Heuristik,
bevor beide Verfahren abschließend gegenübergestellt werden.

== Grundlagen der Zielfunktion

Da im Netzwerk drei konkurrierende Zielgrößen – Kosten, Zeit und CO₂-Emissionen
– gleichzeitig betrachtet werden, wird in beiden Skripten eine gewichtete
Summenbewertung pro Kante verwendet. Die Einzelgrößen werden zunächst anhand
ihrer Durchschnittswerte im Netzwerk normiert, um Größenordnungsunterschiede
(z. B. Kosten in Geldeinheiten vs. Zeit in Minuten) auszugleichen. Zusätzlich
wird ein Strafterm für einen Wechsel des Verkehrsmittels berücksichtigt, da
ein Moduswechsel in der Realität zusätzliche Umschlagkosten und -zeiten
verursacht:

```python
def edge_score(
    edge: Edge,
    weights: Dict[str, float],
    scales: Dict[str, float],
    previous_mode: Optional[str],
) -> float:
    mode_change_penalty = (
        1.0 if previous_mode is not None and previous_mode != edge.mode else 0.0
    )

    return (
        weights["cost"] * normalize(edge.cost, scales["cost"])
        + weights["time"] * normalize(edge.duration_min, scales["time"])
        + weights["emissions"] * normalize(edge.emissions, scales["emissions"])
        + weights.get("mode_change", 0.0) * mode_change_penalty
    )
```

Diese Bewertungsfunktion (`edge_score`) bildet die gemeinsame Grundlage beider
im Folgenden beschriebenen Heuristiken.

== Zeitexpandierter Dijkstra-Router

=== Idee und Funktionsweise

Das refaktorisierte Verfahren basiert auf dem klassischen Dijkstra-Algorithmus zur Bestimmung kürzester Wege in einem zeitexpandierten Graphen. Im Gegensatz zur vorherigen statischen Heuristik operiert der `DijkstraRouter` direkt auf dem zeitexpandierten Netzwerk-Graphen, der durch die Modellklasse `TimeExpandedFreightRoutingModel` konstruiert wird. Dadurch wird eine 100%-ige mathematische Konsistenz und Äquivalenz zum MILP-Solver für einzelne Sendungen garantiert.

Der Router führt folgende Schritte aus:

1. *Graphaufbau & Normalisierung*: Zunächst wird der zeitexpandierte Graph für die gegebene Sendung und den Planungshorizont aufgebaut. Die Normalisierungsgrenzen für Kosten, Zeit und Emissionen werden mit `estimate_normalization_bounds()` sendungsspezifisch analytisch geschätzt. Die maximale Zeit ergibt sich aus `deadline - start_time`; die maximal erreichbare Distanz wird aus dieser Zeit und der höchsten Netzwerkgeschwindigkeit abgeleitet. Eine zusätzliche Pfadsuche ist dafür nicht erforderlich. Solver, Dijkstra- und A\*-Router verwenden dieselbe Berechnung:

```python
bounds = network.estimate_normalization_bounds(shipment)
c_min, c_max = bounds["cost"]
t_min, t_max = bounds["time"]
e_min, e_max = bounds["emissions"]
```

2. *Kantengewichtung (Arc Scoring)*: Jede Kante (Arc) im zeitexpandierten Graphen erhält ein skalares Gewicht (Score), das auf den normalisierten Zielkomponenten basiert. Um negative Kantengewichte durch den Abzug der Mindestpfadkosten ($c_"min"$, $t_"min"$, $e_"min"$) zu verhindern, werden die konstanten Offsets bei der Bewertung der einzelnen Kanten weggelassen (was die mathematische Optimalität des kürzesten Pfades nicht verändert):

```python
def get_arc_score(arc) -> float:
    # Kosten
    c_fixed = model._get_fixed_cost(arc)
    c_var = arc.cost * shipment.weight
    c_total = c_fixed + c_var
    cost_scaled = c_total / c_diff

    # Zeit
    t_total = arc.duration_min
    time_scaled = t_total / t_diff

    # Emissionen
    e_fixed = model._get_fixed_emissions(arc)
    e_var = arc.emissions * shipment.weight
    e_total = e_fixed + e_var
    emissions_scaled = e_total / e_diff

    return (
        objective_weights.cost * cost_scaled
        + objective_weights.time * time_scaled
        + objective_weights.emissions * emissions_scaled
    )
```

3. *Kürzeste-Weg-Suche*: Unter Verwendung einer Prioritätswarteschlange (`heapq`) sucht der Algorithmus den optimalen Pfad von einem virtuellen Startknoten (`SOURCE`) zu den zeitlich zulässigen Zielknoten (`SINK`). Ein fortlaufender Zähler dient in der Queue als Tie-Breaker, um Typkonflikte bei nicht-vergleichbaren Knotenelementen zu vermeiden.

Da keine künstliche Begrenzung des Suchraums (wie z.B. maximale Nachbaranzahl oder Pruning) vorgenommen wird, findet dieser Router garantiert die global optimale Lösung für eine Einzelsendung im zeitexpandierten Graphen.


Dadurch entstehen bis zu vier unterschiedliche Routenvorschläge, die dem
Anwender einen direkten Trade-off zwischen Kosten, Zeit und Emissionen
aufzeigen.

== Tabu-Search-Heuristik

=== Idee und Funktionsweise

Das zweite Verfahren ist eine Metaheuristik der lokalen Suche und basiert auf
dem von Glover entwickelten Tabu-Search-Konzept
#footnote[Vgl. Glover, F. (1986): Future paths for integer programming and
  links to artificial intelligence, in: Computers & Operations Research, 13(5),
  S. 533–549.]. Im Gegensatz zum zeitexpandierten Dijkstra-Router wird hier nicht versucht,
in einem einzigen Suchlauf eine gute Lösung zu konstruieren. Stattdessen wird
zunächst eine zulässige, aber bewusst suboptimale *Startlösung* erzeugt – mit
demselben begrenzten Verzweigungsgrad wie im Dijkstra-Skript – und diese im
Anschluss iterativ durch eine *Nachbarschaftssuche* verbessert:

```python
current = astar_multimodal(
    graph=graph, start=start, goal=goal,
    weights=weights, scales=scales,
    max_expansions=max_expansions,
    max_neighbors_per_node=initial_max_neighbors_per_node,
)
current = improve_route_by_shortcuts(current, graph, weights, scales)
best = current

tabu_list: Dict[str, int] = {}
iterations_without_improvement = 0
```

=== Generierung der Nachbarschaft

Eine Nachbarlösung wird erzeugt, indem jeweils eine Kante der aktuellen Route
gesperrt ("tabu" verboten) und für das Teilproblem erneut ein A\*-Lauf ohne
Verzweigungsbegrenzung durchgeführt wird. Es werden bevorzugt die Kanten mit
dem schlechtesten Einzel-Score gesperrt, da hier das größte
Verbesserungspotenzial vermutet wird:

```python
candidate_edges = sorted(
    current_route.edges,
    key=lambda e: edge_score(e, weights, scales, None),
    reverse=True,
)

for edge in candidate_edges[:max_neighbors]:
    move = edge.arc_id
    candidate = astar_multimodal_with_forbidden_arcs(
        graph=graph, start=start, goal=goal,
        weights=weights, scales=scales,
        max_expansions=max_expansions,
        forbidden_arc_ids={move},
    )
    ...
    neighbors.append((move, candidate))
```

Jede so erzeugte Nachbarroute entspricht damit einer alternativen Route, die
eine bestimmte "schlechte" Kante umgeht.

=== Tabu-Liste, Aspirationskriterium und Abbruch

Damit die Suche nicht in einen Zyklus gerät, in dem wiederholt dieselbe Kante
gesperrt und wieder freigegeben wird, merkt sich der Algorithmus die zuletzt
verbotenen Kanten ("Moves") für eine festgelegte Anzahl von Iterationen
(`tabu_tenure`) in der Tabu-Liste. Ein als tabu markierter Move darf jedoch
trotzdem ausgeführt werden, wenn er zu einer insgesamt besseren Lösung führt
als die bisher beste gefundene Lösung (*Aspirationskriterium*):

```python
admissible: List[Tuple[str, RouteResult]] = []
for move, candidate in neighbors:
    is_tabu = move in tabu_list and tabu_list[move] > iteration
    aspiration = candidate.score < best.score

    if not is_tabu or aspiration:
        admissible.append((move, candidate))

selected_move, selected_route = min(admissible, key=lambda item: item[1].score)
current = selected_route

tabu_list[selected_move] = iteration + tabu_tenure
```

Die Suche terminiert entweder nach Erreichen der maximalen Iterationszahl
(`max_iterations`), wenn keine zulässigen Nachbarn mehr erzeugt werden können,
oder wenn über eine definierte Anzahl an Iterationen
(`no_improvement_limit`) keine Verbesserung der besten bekannten Lösung mehr
erzielt wurde.

== Vergleich des Dijkstra-Routers und der Tabu-Search-Heuristik

Beide Verfahren lösen das zugrunde liegende Optimierungsproblem – die Suche nach einer multikriteriellen, kostenminimalen Route in einem multimodalen Netzwerk –, verfolgen dabei jedoch grundlegend unterschiedliche Ansätze hinsichtlich der Zeitabbildung und Suchstrategie, was in @tab-vergleich gegenübergestellt wird.

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    [*Kriterium*], [*Dijkstra-Router*], [*Tabu-Search-Heuristik*],
    [Suchprinzip],
    [Exakte Kürzeste-Weg-Suche auf dem zeitexpandierten Graphen],
    [Konstruktive Startlösung + iterative\ lokale Nachbarschaftssuche (statisch)],

    [Quelle der Heuristik / Vereinfachung],
    [Keine (vollständige Suche auf dem zeitexpandierten Graphen)],
    [Begrenzte Startlösung +\ gezieltes Verbieten einzelner Kanten],

    [Optimalitätsgarantie],
    [Ja (garantiert mathematisch optimal für Einzelsendungen)],
    [Keine (heuristische Meta-Suche auf statischem Graphen)],

    [Rechenaufwand],
    [Sehr gering: ein Suchlauf auf dem zeitexpandierten Graphen],
    [Höher: ein Suchlauf zur Initialisierung\ plus mehrere Suchläufe pro Iteration],

    [Vermeidung von Zyklen],
    [Inhärent gegeben (kreisfreier zeitexpandierter Graph)],
    [Explizit über Tabu-Liste\ und Tenure-Parameter],

    [Verbesserungsmechanismus],
    [Keiner erforderlich (da bereits global optimal)],
    [Shortcuts zusätzlich zur\ systematischen Nachbarschaftssuche],

    [Lösungsqualität],
    [Global optimal (identisch zum MILP-Solver)],
    [Heuristisch, kann durch statische Vereinfachung suboptimal sein],
  ),
  caption: [Gegenüberstellung von zeitexpandiertem Dijkstra-Router und Tabu-Search-Heuristik],
) <tab-vergleich>

Der Dijkstra-Router liefert durch die Suche auf dem vollständigen zeitexpandierten Graphen in wenigen Millisekunden eine garantiert optimale Lösung für eine Einzelsendung. Da er die exakten zeitlichen Abfahrtspläne, Umladezeiten und Wartezeiten vollumfänglich abbildet, ist das Ergebnis mathematisch identisch zu dem des zeitexpandierten MILP-Solvers. Der Rechenaufwand bleibt dabei minimal, da das Problem für eine Einzelsendung als klassischer shortest path gelöst werden kann.

Die Tabu-Search-Heuristik hingegen operiert auf einem statischen Graphen und nutzt eine iterative Verbesserungsphase auf Basis einer Tabu-Liste. Da sie die zeitlichen Dimensionen und Fahrpläne nur vereinfacht oder statisch abbildet, kann sie für komplexe zeitabhängige Restriktionen suboptimale Routen liefern und besitzt keine Optimalitätsgarantie. Ihr Vorteil liegt primär darin, dass sie auch auf statischen Netzwerken ohne den Overhead einer Zeitexpansion arbeiten kann.

Zusammenfassend lässt sich sagen, dass der zeitexpandierte Dijkstra-Router für Einzelsendungen dem MILP-Solver qualitativ ebenbürtig ist und diesen in puncto Laufzeit weit übertrifft. Die Tabu-Search-Heuristik bleibt als statische Alternative für Szenarien relevant, in denen kein zeitexpandiertes Netz aufgebaut werden kann oder soll.
derungen oder sehr
großen Netzwerken, während die Tabu-Search-Heuristik dann vorzuziehen ist,
wenn eine höhere Lösungsqualität wichtiger ist als die Rechenzeit.

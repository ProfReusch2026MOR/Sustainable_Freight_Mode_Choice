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

== Dijkstra-Heuristik

=== Idee und Funktionsweise

Das erste Verfahren basiert auf dem klassischen Algorithmus von Dijkstra zur
Bestimmung kürzester Wege in einem Graphen mit nichtnegativen Kantengewichten
#footnote[Vgl. Dijkstra, E. W. (1959): A note on two problems in connexion with
graphs, in: Numerische Mathematik, 1, S. 269–271.]. Im vorliegenden Code wird
der Dijkstra-Algorithmus technisch als A\*-Suche mit einer Heuristikfunktion
von konstant null umgesetzt:

```python
def heuristic(_: str) -> float:
    return 0.0
```

Da die geschätzten Restkosten zum Ziel in diesem Fall stets null betragen,
verhält sich die A*-Suche exakt wie ein Dijkstra-Algorithmus: Es werden
ausschließlich die bereits akkumulierten tatsächlichen Kosten (`g`-Werte)
zur Priorisierung der Knoten in der Prioritätswarteschlange verwendet. Der
Zustandsraum besteht dabei nicht nur aus den Knoten (Hubs) selbst, sondern aus
Tupeln *(Knoten, zuletzt genutztes Verkehrsmittel)\*, damit der oben genannte
Moduswechsel-Strafterm korrekt entlang des Pfades berücksichtigt werden kann.

Der eigentliche Heuristik-Charakter des Verfahrens ergibt sich aus einer
gezielten Einschränkung des Suchraums: Pro Knoten werden nicht alle
ausgehenden Kanten betrachtet, sondern nur eine begrenzte Anzahl
(`max_neighbors_per_node`), die lokal anhand des Scores vorsortiert wurde. Dies
beschleunigt die Suche erheblich, kann aber dazu führen, dass global günstigere
Pfade übersehen werden, da das Verfahren dadurch seine Optimalitätsgarantie
verliert:

```python
out_edges = graph.get(node, [])
if max_neighbors_per_node is not None and len(out_edges) > max_neighbors_per_node:
    # Nur die lokal guenstigsten Kanten betrachten: macht die Suche
    # schnell, kann aber global guenstigere Pfade uebersehen.
    out_edges = sorted(
        out_edges, key=lambda e: edge_score(e, weights, scales, prev_mode)
    )[:max_neighbors_per_node]

for edge in out_edges:
    step = edge_score(edge, weights, scales, prev_mode)
    new_state = (edge.target, edge.mode)
    new_g = current_g + step

    if new_g < dist.get(new_state, math.inf):
        dist[new_state] = new_g
        parent[new_state] = (state, edge)
        f = new_g + heuristic(edge.target)
        heapq.heappush(pq, (f, new_g, edge.target, edge.mode))
```

Nach Terminierung der Suche – entweder durch Erreichen des Zielknotens oder
durch Überschreiten der maximalen Anzahl an Knotenexpansionen
(`max_expansions`) – wird der gefundene Pfad rekonstruiert. Anschließend
durchläuft die Lösung eine lokale Nachbearbeitung (`improve_route_by_shortcuts`),
bei der geprüft wird, ob zwei aufeinanderfolgende Kanten $A -> B -> C$ durch
eine direkte Kante $A -> C$ mit besserem Score ersetzt werden können. Diese
2-Opt-ähnliche Glättung kompensiert teilweise die durch die
Nachbarschaftsbegrenzung verursachte Suboptimalität.

=== Mehrfachausführung für unterschiedliche Präferenzen

Um sowohl eine individuelle Nutzerpräferenz als auch jeweils ein reines
Kosten-, Zeit- und CO₂-Minimum auszugeben, wird die Dijkstra-Heuristik viermal
mit unterschiedlichen Gewichtungsvektoren ausgeführt:

```python
def build_four_weight_sets() -> List[Dict[str, float]]:
    return [
        {"name": "Deine Praeferenz", "cost": pc, "time": pt,
         "emissions": pe, "mode_change": mode_change},
        {"name": "Kostenminimum", "cost": 1.0, "time": 0.0,
         "emissions": 0.0, "mode_change": mode_change},
        {"name": "Zeitminimum", "cost": 0.0, "time": 1.0,
         "emissions": 0.0, "mode_change": mode_change},
        {"name": "CO2-Minimum", "cost": 0.0, "time": 0.0,
         "emissions": 1.0, "mode_change": mode_change},
    ]
```

Dadurch entstehen bis zu vier unterschiedliche Routenvorschläge, die dem
Anwender einen direkten Trade-off zwischen Kosten, Zeit und Emissionen
aufzeigen.

== Tabu-Search-Heuristik

=== Idee und Funktionsweise

Das zweite Verfahren ist eine Metaheuristik der lokalen Suche und basiert auf
dem von Glover entwickelten Tabu-Search-Konzept
#footnote[Vgl. Glover, F. (1986): Future paths for integer programming and
links to artificial intelligence, in: Computers & Operations Research, 13(5),
S. 533–549.]. Im Gegensatz zur Dijkstra-Heuristik wird hier nicht versucht,
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
erzielt wurde. Auch hier wird – wie bei der Dijkstra-Heuristik – die finale
Lösung für jede der vier Gewichtungen separat ermittelt (`calculate_four_tabu_routes`).

== Vergleich der beiden Heuristiken

Beide Verfahren lösen dasselbe zugrunde liegende Optimierungsproblem – die
Suche nach einer multikriteriellen, kostenminimalen Route in einem
multimodalen Netzwerk – verfolgen dabei jedoch grundlegend unterschiedliche
Suchstrategien, was in @tab-vergleich gegenübergestellt wird.

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    [*Kriterium*], [*Dijkstra-Heuristik*], [*Tabu-Search-Heuristik*],
    [Suchprinzip],
    [Konstruktive Einzelsuche (A\*\ mit Nullheuristik = Dijkstra)],
    [Konstruktive Startlösung + iterative\ lokale Nachbarschaftssuche],
    [Quelle der Heuristik],
    [Begrenzung der betrachteten\ Nachbarn pro Knoten],
    [Begrenzte Startlösung +\ gezieltes Verbieten einzelner Kanten],
    [Optimalitätsgarantie],
    [Keine (durch Nachbarbegrenzung\ verloren), aber pro Lauf deterministisch],
    [Keine, jedoch potenziell bessere\ Annäherung durch Verbesserungsschritte],
    [Rechenaufwand],
    [Gering: ein Suchlauf pro\ Gewichtung],
    [Höher: ein Suchlauf zur Initialisierung\ plus mehrere Suchläufe pro Iteration],
    [Vermeidung von Zyklen],
    [Nicht erforderlich (Single-Pass)],
    [Explizit über Tabu-Liste\ und Tenure-Parameter],
    [Verbesserungsmechanismus],
    [Lokale 2-Opt-ähnliche\ Kantenglättung (Shortcuts)],
    [Shortcuts zusätzlich zur\ systematischen Nachbarschaftssuche],
    [Lösungsqualität],
    [Schnell, aber tendenziell\ suboptimal bei engem Limit],
    [In der Regel gleich gut oder\ besser als die Startlösung],
  ),
  caption: [Gegenüberstellung von Dijkstra-Heuristik und Tabu-Search-Heuristik],
) <tab-vergleich>

Die Dijkstra-Heuristik liefert durch die Begrenzung der pro Knoten betrachteten
Kanten (`max_neighbors_per_node`) sehr schnell eine zulässige Lösung, da pro
Gewichtungs-Szenario nur ein einziger Suchlauf nötig ist. Dieser
Geschwindigkeitsvorteil wird jedoch mit einem Verlust an Lösungsqualität
erkauft: Da nur ein eingeschränkter Teil des Suchraums betrachtet wird, kann
das Verfahren global bessere Routen übersehen, was im Code explizit als
bewusster Trade-off dokumentiert ist.

Die Tabu-Search-Heuristik nutzt exakt dieselbe eingeschränkte A\*-Suche, um
eine Startlösung zu erzeugen – sie ist also in dieser Phase der
Dijkstra-Heuristik äquivalent. Der entscheidende Unterschied liegt in der
sich anschließenden Verbesserungsphase: Durch wiederholtes, gezieltes
Verbieten einzelner, schlecht bewerteter Kanten und erneute uneingeschränkte
Suche kann sich die Lösung über mehrere Iterationen hinweg der ursprünglich
übersehenen, besseren Route annähern. Das Aspirationskriterium stellt dabei
sicher, dass die Tabu-Restriktion nicht zu einer Verschlechterung gegenüber
der bisher besten Lösung führt. Im Ergebnis liefert die Tabu-Search-Heuristik
tendenziell mindestens so gute, häufig aber bessere Routen als die reine
Dijkstra-Heuristik, benötigt dafür allerdings deutlich mehr Rechenzeit, da in
jeder Iteration mehrere zusätzliche Suchläufe (`astar_multimodal_with_forbidden_arcs`)
durchgeführt werden.

Zusammenfassend lässt sich der Unterschied zwischen beiden Verfahren auf das
klassische Spannungsfeld zwischen *Konstruktionsheuristik* und
*Verbesserungsheuristik (Metaheuristik)* zurückführen: Während die
Dijkstra-Heuristik eine Lösung in einem Schritt konstruiert und dabei
bewusst Suchraum beschneidet, nutzt die Tabu-Search-Heuristik eben diese
Konstruktionslösung lediglich als Ausgangspunkt einer systematischen,
gedächtnisbasierten Verbesserung. Für die vorliegende Anwendung empfiehlt sich
die Dijkstra-Heuristik daher insbesondere bei Echtzeitanforderungen oder sehr
großen Netzwerken, während die Tabu-Search-Heuristik dann vorzuziehen ist,
wenn eine höhere Lösungsqualität wichtiger ist als die Rechenzeit.

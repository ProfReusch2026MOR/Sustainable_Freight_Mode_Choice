= Umsetzung <ch:implementation>
Dieses Kapitel beschreibt die softwaretechnische Umsetzung des in @ch:mathematical-model formulierten Optimierungsmodells. Die Implementierung gliedert sich in vier Bereiche: zunächst die Spezifikation des Datensatzes (@sec:dataset), dann die automatisierte Datenbeschaffung (@sec:data-collection), anschließend die exakte Lösung mittels MILP-Solver (@sec:solver-implementation) und schließlich die heuristische Lösung (@sec:heuristic-implementation). Sämtlicher Quellcode ist in Python umgesetzt.
== Datensatz und Datenmodell <sec:dataset>
=== JSON-Datenformat
Das multimodale Transportnetzwerk wird in einer zentralen JSON-Datei (`multimodal_network.json`) gespeichert. Dieses Format wurde gewählt, da es sowohl für Menschen lesbar als auch maschinell einfach zu verarbeiten ist. Die Datei beschreibt die vollständige physische Infrastruktur – Hubs, Verbindungen, Fahrpläne und Kostenparameter – und dient als einzige Datenquelle für Solver und Heuristiken.
Die JSON-Datei enthält die folgenden Toplevel-Schlüssel:
#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    [*Schlüssel*], [*Typ*], [*Beschreibung*],
    [`hubs`], [Liste], [Alle Terminals, Häfen und Flughäfen im Netzwerk],
    [`mode_factors`], [Dict], [Variable Kosten- und Emissionsfaktoren pro Transportmodus],
    [`capacities`], [Dict], [Standard-Kapazitätsgrenzen je Modus (in Tonnen)],
    [`arc_templates`], [Liste], [Verbindungsvorlagen mit Fahrplänen und Parametern],
    [`default_fixed_costs`], [Dict], [Fixkosten pro Fahrzeugdispatch (z.B. LKW-Bereitstellung)],
    [`default_fixed_emissions`], [Dict], [Fixemissionen pro Fahrzeugdispatch],
    [`default_variable_factors`], [Dict], [Fallback-Faktoren für Warte- und Umschlagkosten],
  ),
  caption: [Toplevel-Struktur der JSON-Netzwerkdatei],
) <tab:json-structure>
=== Hubs
Jeder Hub repräsentiert einen physischen Knotenpunkt im Netzwerk – beispielsweise einen Containerhafen, ein Güterterminal oder einen Flughafen. Neben einer eindeutigen ID und geographischen Koordinaten definiert jeder Hub die an diesem Standort verfügbaren Transportmodi:
```python
{
    "id": "BER",
    "name": "Berlin Hub",
    "supported_modes": ["road", "rail", "air"],
    "latitude": 52.5200,
    "longitude": 13.4050
}
```
Das Feld `supported_modes` steuert dabei, welche Kanten an diesem Hub angebunden werden können. Ein Hub ohne den Modus `"ship"` kann beispielsweise keine maritimen Verbindungen nutzen, was die reale Netzwerktopologie widerspiegelt.
=== Verbindungsvorlagen (Arc Templates)
Die Verbindungen im Netzwerk werden über sogenannte Arc Templates definiert. Es existieren zwei grundlegende Typen:
*Transport-Arcs* beschreiben den physischen Transport zwischen zwei verschiedenen Hubs. Sie enthalten den Transportmodus, die Distanz in Kilometern, die Fahrtdauer sowie einen täglichen Fahrplan in Form von Abfahrtsminuten ab Mitternacht:
```python
{
    "id": "T_BER_MUC_ROAD",
    "arc_type": "transport",
    "from": "BER",
    "to": "MUC",
    "mode": "road",
    "dist": 505.0,
    "duration_min": 360,
    "departure_minutes": [360, 720, 1080]
}
```
*Transfer-Arcs* modellieren den Moduswechsel innerhalb eines Hubs, beispielsweise das Umladen von der Schiene auf die Straße. Sie verbleiben am selben Hub, verbinden aber zwei verschiedene Modi und verursachen eigene Kosten und Zeitaufwände:
```python
{
    "id": "X_BER_ROAD_RAIL",
    "arc_type": "transfer",
    "from": "BER",  "to": "BER",
    "from_mode": "road",
    "to_mode": "rail",
    "duration_min": 60,
    "departure_minutes": [0, 360, 720, 1080]
}
```
=== Kostenfaktoren und Kapazitäten
Variable Kosten und Emissionen werden über modusspezifische Faktoren pro Tonnenkilometer definiert. @tab:mode-factors zeigt die im Datensatz verwendeten Standardwerte.
#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    stroke: 0.5pt,
    [*Modus*], [*Kosten (€/tkm)*], [*Emissionen (kg CO₂/tkm)*],
    [Straße (LKW)], [1,20], [0,090],
    [Schiene], [0,70], [0,025],
    [Luft], [3,50], [0,600],
    [Schiff], [0,40], [0,015],
  ),
  caption: [Variable Kosten- und Emissionsfaktoren nach Transportmodus],
) <tab:mode-factors>
Zusätzlich werden für jeden Modus Fixkosten pro Fahrzeugdispatch, Fahrzeugkapazitäten (in Tonnen) sowie Standardkosten für Warte- und Umschlagvorgänge definiert. Diese Werte können auf Ebene einzelner Arc Templates überschrieben werden, was eine flexible Modellierung unterschiedlicher Infrastrukturstandorte ermöglicht.
=== Datensatzgrößen
Um die Skalierbarkeit der Lösungsverfahren zu evaluieren, werden drei Datensatzgrößen bereitgestellt:
#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    stroke: 0.5pt,
    [*Parameter*], [*S (Small)*], [*M (Medium)*], [*L (Large)*],
    [Max. Hubs], [100], [300], [1.000],
    [Städte pro Land], [3], [6], [15],
    [Straßen-Nachbarn ($k$)], [2], [3], [3],
    [Schienen-Nachbarn ($k$)], [1], [2], [2],
  ),
  caption: [Konfigurationsparameter der drei Datensatzgrößen],
) <tab:dataset-sizes>
== Datenbeschaffung <sec:data-collection>
Die Generierung des multimodalen Netzwerkdatensatzes erfolgt vollautomatisch über das Skript `data_collector.py`. Dieses kombiniert öffentlich verfügbare Geodaten mit analytischen Berechnungen und API-Abfragen zu einem realistischen Netzwerk.
=== Überblick der Pipeline
Die Datenbeschaffung gliedert sich in fünf aufeinanderfolgende Schritte:
+ *Rohdaten herunterladen*: Städte, Flughäfen und Seehäfen aus öffentlichen GitHub-Repositories
+ *Hub-Selektion*: Auswahl und Zuordnung der Transportknoten mit modaler Klassifizierung
+ *Kantenberechnung*: Erzeugung der Verbindungen je Transportmodus
+ *Transfer-Kanten*: Moduswechsel-Verbindungen innerhalb multimodaler Hubs
+ *JSON-Export*: Zusammenführung und Serialisierung des Gesamtdatensatzes
Der Einstiegspunkt des Skripts orchestriert diese Schritte sequentiell:
```python
def main():
    # Step 1: Download
    cities_df, airports_df, ports_df = download_data()
    # Step 2: Select Hubs
    hubs = select_hubs(cities_df, airports_df, ports_df)
    # Step 3: Calculate Arcs
    road_arcs = calculate_road_arcs(hubs)
    rail_arcs = calculate_rail_arcs(hubs)
    ship_arcs = calculate_maritime_arcs(hubs)
    air_arcs = calculate_aviation_arcs(hubs)
    # Step 4: Transfer Arcs
    transfer_arcs = generate_transfer_arcs(hubs)
    # Step 5: JSON Export
    all_arcs = road_arcs + rail_arcs + ship_arcs + air_arcs + transfer_arcs
    ...
```
=== Datenquellen
Die Rohdaten stammen aus drei externen, quelloffenen Datensätzen:
#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    [*Datensatz*], [*Quelle*], [*Inhalt*],
    [World Cities], [GitHub (bahar)], [Globales Städteverzeichnis mit Koordinaten],
    [OpenFlights], [GitHub (jpatokal)], [Flughafendaten mit IATA-Codes und Positionen],
    [LINERLIB], [GitHub (blof)], [Seehafen-Verzeichnis mit UN/LOCODE],
  ),
  caption: [Verwendete externe Datenquellen],
) <tab:data-sources>
Alle Datensätze werden zur Laufzeit per HTTP-Request heruntergeladen und als Pandas-DataFrames verarbeitet. API-Schlüssel für optionale Dienste (z.B. OSRM für Straßenrouting) werden über Umgebungsvariablen konfiguriert.
=== Hub-Selektion und modale Klassifizierung
Die Hub-Auswahl verfolgt das Ziel einer global gleichmäßigen Verteilung. Dazu wird die Anzahl der Städte pro Land auf `MAX_CITIES_PER_COUNTRY` begrenzt. Für jeden ausgewählten Hub wird anschließend geprüft, welche Transportmodi verfügbar sind:
- *Straße*: Immer verfügbar (Grundmodus)
- *Schiene*: Verfügbar, wenn das Land in einer vordefinierten Liste von Staaten mit Eisenbahnnetz enthalten ist
- *Luft*: Verfügbar, wenn ein Flughafen innerhalb von 50 km Luftlinie liegt
- *Schiff*: Verfügbar, wenn ein Seehafen innerhalb von 50 km Luftlinie liegt
Die Näherungsprüfung nutzt zunächst einen Bounding-Box-Filter (±0,45° ≈ 50 km) zur Vorfilterung und berechnet anschließend die exakte geodätische Distanz:
```python
# Bounding-Box Pre-Filter für Flughäfen
near_airports = airports_df[
    (airports_df["lat"] >= city_lat - 0.45)
    & (airports_df["lat"] <= city_lat + 0.45)
    & (airports_df["lon"] >= city_lon - 0.45)
    & (airports_df["lon"] <= city_lon + 0.45)
]
# Exakte geodätische Distanzberechnung
for _, air in near_airports.iterrows():
    dist = geodesic((city_lat, city_lon), (air["lat"], air["lon"])).km
    if dist < min_air_dist:
        min_air_dist = dist
        closest_airport = air["iata"]
```
=== Kantenberechnung nach Transportmodus
Für jeden Transportmodus werden die Verbindungen nach spezifischen Regeln erzeugt:
*Straße:* Jeder Hub wird mit seinen $k$-nächsten Nachbarn auf demselben Kontinent verbunden, sofern die geodätische Distanz 800 km nicht überschreitet. Die Fahrtdistanzen werden nach Möglichkeit über die öffentliche OSRM-API (Open Source Routing Machine) berechnet. Bei einem Timeout oder Fehler wird als Fallback die geodätische Distanz mit einem Umwegfaktor von 1,2 verwendet:
```python
url = f"http://router.project-osrm.org/route/v1/driving/..."
try:
    response = requests.get(url, timeout=3)
    if response.status_code == 200:
        data = response.json()
        dist_km = round(data["routes"][0]["distance"] / 1000.0, 1)
        duration_min = int(data["routes"][0]["duration"] / 60.0)
except Exception:
    pass  # Fall back to geodesic estimate
```
*Schiene:* Analoges $k$-Nearest-Neighbour-Verfahren innerhalb des gleichen Kontinents mit einer maximalen Distanz von 1.500 km und einem Umwegfaktor von 1,25. Die Durchschnittsgeschwindigkeit wird mit 50 km/h plus 2 Stunden Puffer angesetzt. Abfahrten erfolgen fahrplanbasiert zweimal täglich (06:00 und 18:00).
*Schiff:* Verbindung aller Hafenhubs mit einer geodätischen Distanz zwischen 200 und 15.000 km. Es wird ein maritimer Umwegfaktor von 1,35 und eine Durchschnittsgeschwindigkeit von 22 km/h (12 Knoten) plus 12 Stunden Hafenzeit angesetzt. Tägliche Abfahrt um 08:00.
*Luft:* Für die Luftfracht wird ein Hub-and-Spoke-Modell implementiert. Definierte Super-Hubs (z.B. Frankfurt, London, Singapore, Tokyo) bilden das Rückgrat des Netzwerks. Jeder Flughafen wird mit seinem nächsten Super-Hub verbunden, und die Super-Hubs untereinander werden für Langstreckenflüge über 1.000 km verknüpft:
```python
super_hub_names = {
    "Berlin", "Hamburg", "Frankfurt", "München",
    "London", "Paris", "New York", "Singapore",
    "Tokyo", "Shanghai", "Los Angeles", "Chicago", "Dubai",
}
for h1 in air_hubs:
    closest_super = min(
        super_hubs,
        key=lambda sh: geodesic(...).km
    )
    # Spoke → Hub und Hub → Spoke Kanten erzeugen
```
=== Transfer-Kanten
An jedem Hub mit mindestens zwei unterstützten Modi werden Transfer-Kanten für alle Moduskombinationen erzeugt. Die Umschlagdauer variiert je nach Moduskombination (z.B. 60 Minuten für Straße↔Schiene, 480 Minuten für Luft↔Schiff) und reflektiert die realen Umschlagprozesse.
== Exakte Lösung mit Python PuLP <sec:solver-implementation>
Das in @ch:mathematical-model formulierte gemischt-ganzzahlige Optimierungsproblem wird in Python mit dem Modellierungs-Framework *PuLP* implementiert. Die Implementierung gliedert sich in zwei zentrale Klassen: `TimeExpandedNetwork` für den Graphaufbau und `TimeExpandedFreightRoutingModel` für die MILP-Formulierung.
=== Aufbau des zeitexpandierten Netzwerks
Die Klasse `TimeExpandedNetwork` transformiert die statischen Arc Templates aus der JSON-Datei in einen vollständigen zeitexpandierten Graphen. Die Konstruktion erfolgt im Rahmen der `_build()`-Methode in drei Phasen:
+ *Ereigniszeitpunkte registrieren*: Für jede (Hub, Modus)-Kombination werden die relevanten Zeitpunkte gesammelt – Abfahrten, Ankünfte, Sendungsfreigaben und Deadlines.
+ *Transport- und Transfer-Kanten instanziieren*: Jedes Arc Template wird für jeden Tag des Planungshorizonts und jede Abfahrtszeit zu einer konkreten `_TimedArc`-Instanz expandiert.
+ *Wartekanten erzeugen*: Zwischen aufeinanderfolgenden Ereigniszeitpunkten desselben (Hub, Modus)-Paares werden Wartekanten eingefügt.
Ein zentraler Entwurf ist die ereignisbasierte Zeitexpansion, die nur tatsächlich benötigte Zeitpunkte erzeugt. Dies hält die Knotenmenge kompakt im Vergleich zu einer gleichmäßigen Zeitdiskretisierung:
```python
# Nur tatsächliche Ereignisse als Zeitpunkte registrieren
for template in self.network_data.arc_templates:
    if isinstance(template, TransportArcTemplate):
        for day in range(self.planning_days):
            for departure_min in template.departure_minutes:
                start_min = day * 24 * 60 + departure_min
                arrival_min = start_min + template.duration_min
                if arrival_min <= self.max_time_min:
                    self.event_times[(template.from_hub, template.mode)].add(start_min)
                    self.event_times[(template.to_hub, template.mode)].add(arrival_min)
```
Jede instanziierte Kante wird als `_TimedArc`-Objekt gespeichert, das die berechneten Kosten und Emissionen (basierend auf Distanz und Modusfaktoren) sowie die Kapazität enthält:
```python
@dataclass(frozen=True)
class _TimedArc:
    from_node: NetworkNode
    to_node: NetworkNode
    mode: str
    arc_type: ArcType
    departure_min: int
    arrival_min: int
    cost: float        # Variable Kosten pro Tonne
    emissions: float   # Variable Emissionen pro Tonne
    capacity: float    # Fahrzeugkapazität in Tonnen
```
=== MILP-Formulierung
Die Klasse `TimeExpandedFreightRoutingModel` übersetzt das mathematische Modell in PuLP-Variablen und -Constraints. Die Entscheidungsvariablen und die Zielfunktion werden dabei direkt aus dem zeitexpandierten Graphen abgeleitet.
==== Entscheidungsvariablen
Das Modell verwendet drei Variablentypen:
```python
# Binäre Nutzungsvariable: 1, wenn Sendung k Kante i nutzt
self.use_arc = pulp.LpVariable.dicts(
    "UseArc",
    [(i, k) for i in arc_indices for k in shipment_indices],
    cat=pulp.LpBinary,
)
# Ganzzahlige Fahrzeugzähler pro Kante
self.vehicle_count[i] = pulp.LpVariable(
    f"VehicleCount_{i}",
    lowBound=0,
    upBound=up_bound,
    cat=cat,  # LpBinary oder LpInteger je nach Modus
)
```
Zusätzlich werden Slack-Variablen für Deadline-, Budget- und Emissionsrestriktionen deklariert. Diese ermöglichen eine Soft-Constraint-Formulierung: Falls keine vollständig zulässige Lösung existiert, werden Verletzungen in der Zielfunktion mit einem hohen Strafterm ($= 100$) penalisiert, anstatt das Problem als infeasibel abzubrechen.
==== Zielfunktion
Die Zielfunktion realisiert die gewichtete multikritierielle Optimierung. Kosten, Zeit und Emissionen werden sendungsspezifisch auf den Wertebereich $[0, 1]$ normiert, um Größenordnungsunterschiede auszugleichen. Die Normalisierungsgrenzen werden analytisch aus den Netzwerkparametern geschätzt:
```python
bounds = network.estimate_normalization_bounds(shipment)
# bounds = {"cost": (min_cost, max_cost), "time": (...), "emissions": (...)}
```
Die normierte Zielfunktion kombiniert die fixen Fahrzeugkosten (gewichtet über alle Sendungen gemittelt) mit den sendungsspezifischen variablen Komponenten:
```python
routing_objective = (
    fixed_cost_coefficient * fixed_cost
    + fixed_emissions_coefficient * fixed_emissions
    + pulp.lpSum(
        weights[k].cost * (var_cost[k] - bounds[k]["cost"][0]) / cost_range[k]
        + weights[k].time * (time[k] - bounds[k]["time"][0]) / time_range[k]
        + weights[k].emissions * (var_em[k] - bounds[k]["emissions"][0]) / em_range[k]
        for k in shipment_indices
    )
)
```
==== Nebenbedingungen
Die Nebenbedingungen bilden die in @ch:mathematical-model definierten Restriktionen ab:
- *Flusserhaltung:* An jedem Zwischenknoten muss der eingehende Fluss jeder Sendung dem ausgehenden entsprechen. An den Startknoten wird genau eine ausgehende Kante aktiviert, an den Zielknoten genau eine eingehende.
- *Kapazitätskopplung:* Die Summe der Sendungsgewichte auf einer Kante darf die Kapazität mal der Fahrzeuganzahl nicht überschreiten: $ sum_k w_k dot x_(i,k) <= c_i dot y_i $
- *Budget- und Emissionsgrenzen:* Optionale sendungsspezifische Obergrenzen für Kosten und Emissionen werden als Soft Constraints formuliert.
==== Solver-Ausführung
Als Solver wird *HiGHS* über die PuLP-Schnittstelle eingesetzt. HiGHS löst das MILP mit Branch-and-Bound- und Presolve-Verfahren und unterstützt konfigurierbare Zeitlimits:
```python
highs_py = pulp.HiGHS(
    msg=show_progress,
    timeLimit=time_limit_sec,
)
status = self.prob.solve(highs_py)
```
Nach der Lösung werden die Entscheidungsvariablen mit einem Schwellwert von $0{,}5$ ausgelesen, um Gleitkomma-Toleranzen des Solvers zu kompensieren. Aus den aktivierten Kanten werden die Routen je Sendung rekonstruiert und als `RoutingResult` zurückgegeben. Eventuelle Slack-Variablen-Verletzungen werden in einem diagnostischen Report ausgegeben.


== Heuristische Lösungsverfahren <sec:heuristic-implementation>

Dieses Unterkapitel beschreibt die Implementierung der in @ch:heuristic-approach mathematisch definierten heuristischen Verfahren. Alle Klassen befinden sich im Modul `dijkstra_router.py` und operieren auf demselben zeitexpandierten Netzwerk (`TimeExpandedNetwork`), das auch der MILP-Solver verwendet. Die zentrale Architektur besteht aus einer Basisklasse `DijkstraRouter` und der davon abgeleiteten Klasse `AStarRouter`.

=== Architektur und Hilfsstrukturen

Die Implementierung nutzt drei Hilfs-Dataclasses, die den Zustand während der Suche kapseln:

```python
@dataclass
class _NetworkIndex:
    outgoing: dict[NetworkNode, list[_TimedArc]]
    arc_to_index: dict[_TimedArc, int]
    nodes_by_hub_time: dict[tuple[str, int], list[NetworkNode]]
    nodes_by_hub: dict[str, list[NetworkNode]]

@dataclass
class _CapacityState:
    active_vehicles: list[int]
    remaining_capacity: list[float]

@dataclass
class _NormalizationContext:
    bounds: dict[str, dict[str, tuple[float, float]]]
    ranges: dict[str, dict[str, float]]
    fixed_cost_coefficient: float
    fixed_emissions_coefficient: float
```

Der `_NetworkIndex` baut beim ersten Aufruf eine Adjazenzliste aller ausgehenden Kanten pro Knoten auf und indiziert die Knotenmenge nach `(hub_id, time_min)` sowie nach `hub_id`. Dieses Caching ermöglicht die Lokalisierung der Startknoten einer Sendung in $O(1)$ und vermeidet redundante Graphtraversierungen bei mehreren Sendungen. Der Index wird nur bei einem Netzwerkwechsel neu aufgebaut:

```python
def _get_network_index(self, network: TimeExpandedNetwork) -> _NetworkIndex:
    if self._cached_network is not network or self._network_index is None:
        outgoing = defaultdict(list)
        arc_to_index = {}
        for index, arc in enumerate(network.all_arcs):
            outgoing[arc.from_node].append(arc)
            arc_to_index[arc] = index

        nodes_by_hub_time = defaultdict(list)
        nodes_by_hub = defaultdict(list)
        for node in network.nodes:
            nodes_by_hub_time[(node.hub_id, node.time_min)].append(node)
            nodes_by_hub[node.hub_id].append(node)
        ...
    return self._network_index
```

Der `_NormalizationContext` bündelt die sendungsspezifischen Normalisierungsgrenzen und -bereiche sowie die gemittelten Fixkosten-Koeffizienten $alpha_C$ und $alpha_E$. Er wird einmalig vor dem Routing berechnet und an alle Suchmethoden weitergereicht, um konsistente Skalierung sicherzustellen.

=== Kantenbewertung (Arc Score)

Die Methode `_arc_score` setzt die in @sec:arc-score definierte Kantenbewertungsfunktion $sigma(a, k)$ um. Zunächst wird geprüft, ob die Kante kapazitiv noch begehbar ist – andernfalls gibt die Methode `None` zurück, wodurch die Kante aus der Suche ausgeschlossen wird:

```python
def _arc_score(self, network, arc, arc_index, shipment, capacity,
               normalization, weights, ranges) -> float | None:
    needed = self._additional_vehicles(
        arc, shipment.weight, capacity.remaining_capacity[arc_index]
    )
    if capacity.active_vehicles[arc_index] + needed > self._vehicle_limit(arc):
        return None  # Kante kapazitiv nicht begehbar

    fixed_cost = network._get_fixed_cost(arc) * needed
    fixed_emissions = network._get_fixed_emissions(arc) * needed
    return (
        normalization.fixed_cost_coefficient * fixed_cost
        + weights.cost * arc.cost * shipment.weight / ranges["cost"]
        + weights.time * arc.duration_min / ranges["time"]
        + normalization.fixed_emissions_coefficient * fixed_emissions
        + weights.emissions * arc.emissions * shipment.weight / ranges["emissions"]
    )
```

Die Berechnung der zusätzlich benötigten Fahrzeuge implementiert die in @eq:additional-vehicles definierte Fallunterscheidung:

```python
@staticmethod
def _additional_vehicles(
    arc: _TimedArc, shipment_weight: float, remaining_capacity: float
) -> int:
    if remaining_capacity >= shipment_weight:
        return 0  # Konsolidierung auf bestehendem Fahrzeug
    return math.ceil(
        (shipment_weight - remaining_capacity) / max(arc.capacity, 1e-9)
    )
```

Für Straßenkanten ist die Fahrzeuganzahl nach oben unbegrenzt (`math.inf`), da beliebig viele LKWs eingesetzt werden können. Für alle anderen Modi gilt standardmäßig ein Limit von einem Fahrzeug, sofern nicht explizit ein `max_vehicles`-Wert definiert ist.

=== Kürzeste-Weg-Suche

Die Kernmethode `_find_shortest_path` implementiert die in @sec:dijkstra-formulation formulierte Suche. Sie ist als generalisierter Best-First-Search konzipiert und unterstützt sowohl reines Dijkstra ($h(n) = 0$) als auch A\* ($h(n) > 0$):

```python
def _find_shortest_path(self, network, shipment, capacity, normalization):
    index = self._get_network_index(network)
    start_nodes = sorted(
        index.nodes_by_hub_time.get((shipment.start_hub, shipment.start_time), []),
        key=lambda node: node.mode,
    )
    end_nodes = {
        node for node in index.nodes_by_hub.get(shipment.end_hub, [])
        if node.time_min <= shipment.deadline
    }
```

Die Prioritätswarteschlange enthält Tupel `(f, g, counter, node)`, wobei der `counter` als Tie-Breaker dient, um Typkonflikte bei nicht-vergleichbaren `NetworkNode`-Objekten zu vermeiden. Das zeitbasierte Pruning filtert Knoten, die den Zielhub zeitlich nicht mehr erreichen können:

```python
min_time = self._min_time_by_hub(network, shipment)

for arc in index.outgoing.get(node, []):
    next_node = arc.to_node
    # Zeitbasiertes Pruning
    if (next_node.time_min + min_time.get(next_node.hub_id, math.inf)
        > shipment.deadline):
        continue
    # Heuristik-basiertes Pruning (A*)
    estimate_to_goal = estimate(next_node)
    if math.isinf(estimate_to_goal):
        continue
```

Die minimalen Fahrtzeiten `min_time` werden per Rückwärts-Dijkstra auf dem statischen Netzwerk vorberechnet und nach Zielhub gecacht:

```python
def _min_time_by_hub(self, network, shipment) -> dict[str, float]:
    reverse_graph = defaultdict(list)
    for template in network_data.arc_templates:
        if isinstance(template, TransportArcTemplate):
            reverse_graph[template.to_hub].append(
                (template.from_hub, template.duration_min)
            )
    # Dijkstra vom Zielhub rückwärts
    distance = {shipment.end_hub: 0.0}
    queue = [(0.0, shipment.end_hub)]
    while queue:
        current_distance, hub = heapq.heappop(queue)
        ...
    return distance
```

=== A\*-Router

Die Klasse `AStarRouter` erbt von `DijkstraRouter` und überschreibt ausschließlich die Methode `_heuristic_by_hub`, um die in @sec:astar-heuristic definierte Heuristikfunktion $h(n)$ bereitzustellen. Die Berechnung erfolgt analog zum zeitbasierten Pruning per Rückwärts-Dijkstra, verwendet jedoch den gewichteten Arc Score statt der reinen Fahrtdauer:

```python
class AStarRouter(DijkstraRouter):
    def _heuristic_by_hub(self, network, shipment, weights, ranges):
        reverse_graph: dict[str, list[tuple[str, float]]] = defaultdict(list)
        for template in network_data.arc_templates:
            if not isinstance(template, TransportArcTemplate):
                continue
            factor = network_data.mode_factors[template.mode]
            cost = template.cost if template.cost is not None \
                else template.distance * factor.cost_per_ton_km
            emissions = template.emissions if template.emissions is not None \
                else template.distance * factor.emissions_kg_per_ton_km
            score = (
                weights.cost * cost * shipment.weight / ranges["cost"]
                + weights.time * template.duration_min / ranges["time"]
                + weights.emissions * emissions * shipment.weight / ranges["emissions"]
            )
            reverse_graph[template.to_hub].append((template.from_hub, score))
        # Dijkstra liefert: dict[hub_id -> min_score_to_goal]
        ...
```

Das Ergebnis wird nach den Parametern `(end_hub, weight, weights, ranges)` gecacht, sodass bei wiederholten Aufrufen mit denselben Sendungsparametern keine Neuberechnung stattfindet.

=== Einzelsendungs-Lösung

Die Methode `solve()` bildet den einfachsten Anwendungsfall ab. Sie löst genau eine Sendung, berechnet die Normalisierung und führt die kürzeste-Weg-Suche aus. Aus den gefundenen Kanten werden die finalen Metriken (Gesamtkosten, Emissionen, Transportzeit) berechnet und als `RoutingResult` mit Status `"Optimal"` zurückgegeben:

```python
def solve(self, network: TimeExpandedNetwork) -> RoutingResult:
    shipment = network.shipments[0]
    normalization = self._normalization_context(network, [shipment])
    route_arcs = self._find_shortest_path(
        network=network,
        shipment=shipment,
        capacity=self._empty_capacity_state(network),
        normalization=normalization,
    )
    # Metriken berechnen
    total_cost = sum(network._get_fixed_cost(arc) * network._required_vehicles(...)
                     for arc in route_arcs)
                 + sum(arc.cost * shipment.weight for arc in route_arcs)
    ...
    return RoutingResult(status="Optimal", is_optimal=True, ...)
```

Da der Router das vollständige zeitexpandierte Netzwerk ohne Suchraumbegrenzung durchsucht, ist das Ergebnis für Einzelsendungen mathematisch identisch zum MILP-Solver.

=== Sequentielle Multi-Sendungs-Lösung

Die Methode `solve_multiple()` implementiert das in @sec:capacity-tracking definierte sequentielle Verfahren. Die Sendungen werden absteigend nach Gewicht sortiert, um schwere Sendungen bevorzugt auf den kapazitiv besten Kanten zu platzieren:

```python
def solve_multiple(self, network, show_progress=False) -> RoutingResult:
    normalization = self._normalization_context(network, shipments)
    sorted_shipments = sorted(shipments, key=lambda s: s.weight, reverse=True)
    capacity = self._empty_capacity_state(network)
    shipment_routes = {}

    for shipment in sorted_shipments:
        route_arcs = self._find_shortest_path(
            network=network,
            shipment=shipment,
            capacity=capacity,
            normalization=normalization,
        )
        if route_arcs is None:
            diagnostics.append(f"Shipment {shipment.id}: No feasible path found.")
            continue

        self._reserve_route(network, route_arcs, shipment, capacity)
        shipment_routes[shipment.id] = tuple(route_arcs)
```

Nach jedem erfolgreichen Routing wird `_reserve_route` aufgerufen, die den `_CapacityState` gemäß @eq:additional-vehicles aktualisiert. Dadurch können nachfolgende Sendungen auf Kanten mit Restkapazität konsolidiert werden, ohne zusätzliche Fixkosten zu verursachen:

```python
def _reserve_route(self, network, route, shipment, capacity):
    for arc in route:
        arc_index = arc_to_index[arc]
        needed = self._additional_vehicles(
            arc, shipment.weight, capacity.remaining_capacity[arc_index]
        )
        capacity.active_vehicles[arc_index] += needed
        capacity.remaining_capacity[arc_index] += needed * arc.capacity
        capacity.remaining_capacity[arc_index] -= shipment.weight
```

=== Ruin-and-Recreate-Optimierung (LNS)

Die Methode `optimize_multiple()` implementiert die in @sec:lns definierte Large Neighbourhood Search. Sie erhält eine initiale Lösung (z.B. aus `solve_multiple`) und verbessert diese iterativ:

```python
def optimize_multiple(self, initial_result, network,
                      iterations=20, ruin_fraction=0.2, seed=None):
    rng = random.Random(seed)
    best_result = initial_result
    best_routes = dict(initial_result.shipment_routes)
    num_to_ruin = max(1, int(len(shipments) * ruin_fraction))

    for _ in range(iterations):
        # Ruin: zufällige Sendungen entfernen
        ruined_ids = rng.sample(list(best_routes.keys()), num_to_ruin)

        # Kapazitäten der verbleibenden Routen wiederherstellen
        capacity = self._empty_capacity_state(network)
        for s_id in remaining_ids:
            self._reserve_route(network, best_routes[s_id], ...)

        # Recreate: entfernte Sendungen absteigend nach Gewicht neu routen
        ruined_shipments.sort(key=lambda s: s.weight, reverse=True)
        for shipment in ruined_shipments:
            route = self._find_shortest_path(network, shipment, capacity, ...)
            if route is None:
                routing_failed = True
                break
            self._reserve_route(network, route, shipment, capacity)

        # Akzeptiere bessere Lösungen
        if candidate.objective_value < best_obj:
            best_result = candidate
```

Die Ruin-Phase wählt zufällig einen Anteil $rho$ (Standard: 20%) der Sendungen aus und entfernt ihre Routen aus dem Kapazitätszustand. Die Recreate-Phase routet diese Sendungen unter Berücksichtigung der verbleibenden Belegung neu. Durch die Zufallsauswahl und die Neuberechnung der Kapazitäten wird die sequentielle Reihenfolge-Abhängigkeit des Greedy-Verfahrens effektiv aufgebrochen, was insbesondere bei Konsolidierungseffekten zu verbesserten Lösungen führt.

=== Ergebnisaggregation

Die Methode `_build_combined_result` berechnet die aggregierten Metriken für Multi-Sendungs-Lösungen. Die Fixkosten werden aus den aktivierten Fahrzeugen über alle Kanten summiert und nicht einzelnen Sendungen zugerechnet, was das Konsolidierungsmodell des MILP korrekt widerspiegelt:

```python
total_fixed_cost = sum(
    network._get_fixed_cost(arc) * active_vehicles[idx]
    for idx, arc in enumerate(network.all_arcs)
)
```

Der Zielfunktionswert wird analog zur MILP-Zielfunktion (@eq:routing) berechnet, wobei die gemittelten Fixkosten-Koeffizienten $alpha_C$ und $alpha_E$ sowie die sendungsspezifischen variablen Komponenten addiert werden. Dies gewährleistet, dass die Lösungsqualität des heuristischen Verfahrens direkt mit der des exakten Solvers verglichen werden kann.

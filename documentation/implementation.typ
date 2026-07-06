= Umsetzung <ch:implementation>
Dieses Kapitel beschreibt die softwaretechnische Umsetzung des in @ch:mathematical-model formulierten Optimierungsmodells. Die Implementierung gliedert sich in vier Bereiche: zunächst die Spezifikation des Datensatzes (@sec:dataset), dann die automatisierte Datenbeschaffung (@sec:data-collection), anschließend die exakte Lösung mittels MILP-Solver (@sec:solver-implementation) und schließlich die heuristische Lösung (@sec:heuristic-implementation). Sämtlicher Quellcode ist in Python umgesetzt.
== Datensatz und Datenmodell <sec:dataset>
// TODO: text hier
=== JSON-Datenformat
Das multimodale Transportnetzwerk wird in einer zentralen JSON-Datei gespeichert. Die Datei beschreibt die vollständige physische Infrastruktur – Hubs, Verbindungen, Fahrpläne und Kostenparameter – und dient als einzige Datenquelle für Solver und Heuristiken.
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
Jeder Hub repräsentiert einen physischen Knotenpunkt im Netzwerk – beispielsweise einen Containerhafen, ein Güterterminal oder einen Flughafen. Neben einer eindeutigen ID und geographischen Koordinaten definiert jeder Hub die an diesem Standort verfügbaren Transportmodi, wie in @lst:json-hub beispielhaft dargestellt:
#figure(
  ```json
  {
      "id": "BER",
      "name": "Berlin Hub",
      "supported_modes": ["road", "rail", "air"],
      "latitude": 52.5200,
      "longitude": 13.4050
  }
  ```,
  caption: [JSON-Repräsentation eines Hubs],
) <lst:json-hub>
Das Feld `supported_modes` steuert dabei, welche Kanten an diesem Hub angebunden werden können.
=== Verbindungsvorlagen (Arc Templates)
Die Verbindungen im Netzwerk werden über sogenannte Arc Templates definiert. Es existieren zwei grundlegende Typen:
*Transport-Arcs* beschreiben den physischen Transport zwischen zwei verschiedenen Hubs. Sie enthalten den Transportmodus, die Distanz in Kilometern, die Fahrtdauer sowie einen täglichen Fahrplan:
#figure(
  ```json
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
  ```,
  caption: [JSON-Format eines Transport-Arc-Templates],
) <lst:json-transport-arc>

*Transfer-Arcs* modellieren den Moduswechsel innerhalb eines Hubs, beispielsweise das Umladen von der Schiene auf die Straße. Sie verbleiben am selben Hub, verbinden aber zwei verschiedene Modi und verursachen eigene Kosten und Zeitaufwände:
#figure(
  ```json
  {
      "id": "X_BER_ROAD_RAIL",
      "arc_type": "transfer",
      "from": "BER",  "to": "BER",
      "from_mode": "road",
      "to_mode": "rail",
      "duration_min": 60,
      "departure_minutes": [0, 360, 720, 1080]
  }
  ```,
  caption: [JSON-Format eines Transfer-Arc-Templates],
) <lst:json-transfer-arc>
=== Kostenfaktoren und Kapazitäten

Die ökonomischen und ökologischen Parameter sowie Kapazitätsgrenzen des Netzwerks sind als Standardwerte im JSON-Datensatz hinterlegt. @tab:json-parameters gibt eine Übersicht der verschiedenen Parameterarten und deren Abbildung im JSON-Schema über entsprechende Schlüssel und Pfade:

#figure(
  table(
    columns: (auto, auto),
    align: (left, left),
    stroke: 0.5pt,
    [*Parameterbeschreibung*], [*Schlüssel / Pfad im JSON-Datensatz*],
    // Transport
    [Variable Kosten (Transport)], [`mode_factors.[modus].cost_per_ton_km`],
    [Variable Emissionen (Transport)], [`mode_factors.[modus].emissions_kg_per_ton_km`],
    [Fahrzeugkapazität], [`capacities.[modus]`],
    [Fixkosten pro Fahrzeugdispatch], [`default_fixed_costs.transport.[modus]`],
    [Fixemissionen pro Fahrzeugdispatch], [`default_fixed_emissions.transport.[modus]`],
    // Warten
    [Wartekapazität am Hub], [`capacities.waiting`],
    [Variable Wartekosten (pro Stunde)], [`default_variable_factors.waiting_cost_per_hour`],
    [Variable Wartemissionen (pro Stunde)], [`default_variable_factors.waiting_emissions_per_hour`],
    [Fixkosten für Wartevorgang], [`default_fixed_costs.waiting`],
    [Fixemissionen für Wartevorgang], [`default_fixed_emissions.waiting`],
    // Umschlag
    [Transferkapazität (Moduswechsel)], [`capacities.transfer`],
    [Variable Transferkosten (pro Tonne)], [`default_variable_factors.transfer_cost_per_ton`],
    [Variable Transferemissionen (pro Tonne)], [`default_variable_factors.transfer_emissions_per_ton`],
    [Fixkosten für Transfervorgang], [`default_fixed_costs.transfer`],
    [Fixemissionen für Transfervorgang], [`default_fixed_emissions.transfer`],
  ),
  caption: [Übersicht der Netzwerk- und Kostenparameter im JSON-Schema],
) <tab:json-parameters>

Diese globalen Faktoren dienen als Standardwerte für das gesamte Netzwerk. Sie können auf Ebene einzelner Verbindungen in den `arc_templates` überschrieben werden (beispielsweise durch Angabe spezifischer `capacity` oder `fixed_cost` Werte), was eine flexible Modellierung unterschiedlicher Infrastrukturen ermöglicht.
=== Datensatzgrößen
Um die Skalierbarkeit der Lösungsverfahren zu evaluieren, werden drei Datensatzgrößen bereitgestellt. Die Generierung basiert auf einer Reihe von Konfigurationsparametern, die in @tab:dataset-configs aufgeführt sind.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    stroke: 0.5pt,
    [*Konfigurationsparameter*], [*S (Small)*], [*M (Medium)*], [*L (Large)*],
    [Max. Hubs (globales Limit)], [100], [300], [1.000],
    [Städte pro Land (Limit)], [3], [6], [15],
    [Straßen-Nachbarn ($k$)], [2], [3], [3],
    [Schienen-Nachbarn ($k$)], [1], [2], [2],
  ),
  caption: [Konfigurationsparameter der drei Datensatzgrößen],
) <tab:dataset-configs>

Die aus diesen Parametern tatsächlich resultierenden Netzwerkgrößen sind in @tab:dataset-sizes dargestellt.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    stroke: 0.5pt,
    [*Strukturgröße*], [*S (Small)*], [*M (Medium)*], [*L (Large)*],
    [Hubs (Knoten)], [100], [300], [870],
    [Transport-Kanten], [1.186], [6.816], [32.694],
    [Transfer-Kanten], [478], [1.364], [3.578],
  ),
  caption: [Tatsächliche Strukturgrößen der generierten Datensätze],
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

=== Datenquellen
Die Rohdaten stammen aus drei externen, quelloffenen Datensätzen:
#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    [*Datensatz*], [*Quelle*], [*Inhalt*],
    [World Cities],
    [#link("https://github.com/bahar/WorldCityLocations")[GitHub (bahar)] @worldcitylocations],
    [Globales Städteverzeichnis mit Koordinaten],

    [OpenFlights],
    [#link("https://github.com/jpatokal/openflights")[GitHub (jpatokal)] @openflights],
    [Flughafendaten mit IATA-Codes und Positionen],

    [LINERLIB],
    [#link("https://github.com/blof/LINERLIB")[GitHub (blof)] @linerlib],
    [Seehafen-Verzeichnis mit UN/LOCODE],
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
Die Näherungsprüfung nutzt zunächst einen Bounding-Box-Filter (±0,45° ≈ 50 km) zur Vorfilterung und berechnet anschließend die exakte geodätische Distanz (vgl. @lst:bounding-box-filter):
#figure(
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
  ```,
  caption: [Geodätische Distanzprüfung mit Bounding-Box-Vorfilter],
) <lst:bounding-box-filter>
=== Kantenberechnung nach Transportmodus
Für jeden Transportmodus werden die Verbindungen nach spezifischen Regeln erzeugt:


*Straße:* Jeder Hub wird mit seinen $k$-nächsten Nachbarn auf demselben Kontinent verbunden, sofern die geodätische Distanz 800 km nicht überschreitet. Die Fahrtdistanzen werden nach Möglichkeit über die öffentliche OSRM-API (Open Source Routing Machine) berechnet. Bei einem Timeout oder Fehler wird als Fallback die geodätische Distanz mit einem Umwegfaktor von 1,2 verwendet.

*Schiene:* Analoges $k$-Nearest-Neighbour-Verfahren innerhalb des gleichen Kontinents mit einer maximalen Distanz von 1.500 km und einem Umwegfaktor von 1,25. Die Durchschnittsgeschwindigkeit wird mit 50 km/h plus 2 Stunden Puffer angesetzt.


*Schiff:* Verbindung aller Hafenhubs mit einer geodätischen Distanz zwischen 200 und 15.000 km. Es wird ein maritimer Umwegfaktor von 1,35 und eine Durchschnittsgeschwindigkeit von 22 km/h (12 Knoten) angesetzt.


*Luft:* Für die Luftfracht wird eine Hub-and-Spoke-Architektur implementiert, um eine kombinatorische Explosion der Kantenanzahl zu vermeiden und die Struktur realer Luftfrachtnetzwerke abzubilden @bryan1999hub. Hierbei werden bestimmte Hubs als sogenannte Super-Hubs definiert (z. B. Frankfurt, London, Singapore, Tokyo, New York, Dubai). Kleinere Flughäfen (Spokes) besitzen keine Direktverbindungen untereinander, sondern werden ausschließlich bidirektional mit ihrem jeweils geografisch nächstgelegenen Super-Hub über Zubringerflüge (Spoke-Kanten) verknüpft. Die Super-Hubs untereinander bilden das globale Rückgrat des Netzwerks und sind für Langstreckenflüge ab einer Distanz von 1.000 km direkt miteinander verbunden.

=== Transfer-Kanten
An jedem Hub mit mindestens zwei unterstützten Modi werden Transfer-Kanten für alle Moduskombinationen erzeugt. Die Umschlagdauer variiert je nach Moduskombination (z.B. 60 Minuten für Straße↔Schiene, 480 Minuten für Luft↔Schiff) und reflektiert die realen Umschlagprozesse.

=== Plausibilitätsprüfung der generierten Daten <sec:plausibility>
Da der Datensatz teils aus realen Geodaten, teils aus analytischen Annahmen zusammengesetzt wird, werden die erzeugten Parameter vor der Optimierung gegen einfache Plausibilitätsregeln geprüft. @tab:plausibility fasst die wichtigsten Prüfaspekte und ihre Ausprägung im generierten Netzwerk zusammen. Alle Kosten- und Emissionsfaktoren sind nichtnegativ, sämtliche Distanzen positiv, und die modusspezifischen Kennzahlen folgen der aus der Praxis erwarteten Rangfolge.

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (left, left, center),
    stroke: 0.5pt,
    inset: 7pt,
    [*Prüfaspekt*], [*Regel bzw. Wert im Datensatz*], [*Status*],
    [Distanzen positiv],
    [Alle Kantendistanzen $> 0$; Modusgrenzen: Straße $<= 800$ km, Schiene $<= 1.500$ km, Schiff $200$--$15.000$ km],
    [OK],

    [Geschwindigkeit ↔ Modus],
    [Schiene $approx 50$ km/h, Schiff $approx 22$ km/h (12 kn), Straße via OSRM-Realdistanz, Luft am schnellsten],
    [OK],

    [Umwegfaktoren realistisch], [Straße $1{,}2$, Schiene $1{,}25$, Schiff $1{,}35$ gegenüber der Luftlinie], [OK],
    [Kapazitäten fahrzeugtypisch \[t\]], [Straße $40$, Luft $50$, Schiene $1.000$, Schiff $8.000$], [OK],
    [Kostenrangfolge \[€/t·km\]], [Schiff $0{,}4 <$ Schiene $0{,}7 <$ Straße $1{,}2 <$ Luft $3{,}5$], [OK],
    [Emissionsrangfolge \[kg CO₂/t·km\]], [Schiff $0{,}015 <$ Schiene $0{,}025 <$ Straße $0{,}09 <$ Luft $0{,}6$], [OK],
    [Nichtnegativität], [Alle variablen und fixen Kosten- sowie Emissionswerte $>= 0$], [OK],
    [Modale Erreichbarkeit], [Luft/See nur, wenn Flughafen bzw. Seehafen innerhalb $50$ km liegt], [OK],
  ),
  caption: [Plausibilitätsprüfung der generierten Netzwerkdaten.],
) <tab:plausibility>

== Exakte Lösung mit Python PuLP <sec:solver-implementation>
Das in @ch:mathematical-model formulierte gemischt-ganzzahlige Optimierungsproblem wird in Python mit dem Modellierungs-Framework *PuLP* implementiert. Die Implementierung gliedert sich in zwei zentrale Klassen: `TimeExpandedNetwork` für den Graphaufbau und `TimeExpandedFreightRoutingModel` für die MILP-Formulierung.
=== Aufbau des zeitexpandierten Netzwerks
Die Klasse `TimeExpandedNetwork` transformiert die statischen Arc Templates aus der JSON-Datei in einen vollständigen zeitexpandierten Graphen. Die Konstruktion erfolgt im Rahmen der `_build()`-Methode in drei Phasen:
+ *Ereigniszeitpunkte registrieren*: Für jede (Hub, Modus)-Kombination werden die relevanten Zeitpunkte gesammelt – Abfahrten, Ankünfte, Sendungsfreigaben und Deadlines.
+ *Transport- und Transfer-Kanten instanziieren*: Jedes Arc Template wird für jeden Tag des Planungshorizonts und jede Abfahrtszeit zu einer konkreten `_TimedArc`-Instanz expandiert.
+ *Wartekanten erzeugen*: Zwischen aufeinanderfolgenden Ereigniszeitpunkten desselben (Hub, Modus)-Paares werden Wartekanten eingefügt.
Ein zentraler Entwurf ist die ereignisbasierte Zeitexpansion, die nur tatsächlich benötigte Zeitpunkte erzeugt. Dies hält die Knotenmenge kompakt im Vergleich zu einer gleichmäßigen Zeitdiskretisierung (siehe @lst:event-time-expansion):
#figure(
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
  ```,
  caption: [Algorithmus zur ereignisbasierten Zeitexpansion],
) <lst:event-time-expansion>
Jede instanziierte Kante wird als `_TimedArc`-Objekt gespeichert (siehe @lst:timed-arc), das die berechneten Kosten und Emissionen (basierend auf Distanz und Modusfaktoren) sowie die Kapazität enthält:
#figure(
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
  ```,
  caption: [Datenstruktur `_TimedArc` für zeitexpandierte Kanten],
) <lst:timed-arc>
=== MILP-Formulierung
Die Klasse `TimeExpandedFreightRoutingModel` übersetzt das mathematische Modell in PuLP-Variablen und -Constraints. Die Entscheidungsvariablen und die Zielfunktion werden dabei direkt aus dem zeitexpandierten Graphen abgeleitet.
==== Entscheidungsvariablen
Das Modell verwendet drei Variablentypen (siehe @lst:pulp-variables):
#figure(
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
  ```,
  caption: [Deklaration der PuLP-Entscheidungsvariablen im MILP-Modell],
) <lst:pulp-variables>
Zusätzlich werden Slack-Variablen für Deadline-, Budget- und Emissionsrestriktionen deklariert. Diese ermöglichen eine Soft-Constraint-Formulierung: Falls keine vollständig zulässige Lösung existiert, werden Verletzungen in der Zielfunktion mit einem hohen Strafterm ($= 100$) penalisiert, anstatt das Problem als infeasibel abzubrechen.
==== Zielfunktion
Die Zielfunktion realisiert die gewichtete multikritierielle Optimierung. Kosten, Zeit und Emissionen werden sendungsspezifisch auf den Wertebereich $[0, 1]$ normiert, um Größenordnungsunterschiede auszugleichen. Die Normalisierungsgrenzen werden analytisch aus den Netzwerkparametern geschätzt (siehe @lst:normalization-bounds):
#figure(
  ```python
  bounds = network.estimate_normalization_bounds(shipment)
  # bounds = {"cost": (min_cost, max_cost), "time": (...), "emissions": (...)}
  ```,
  caption: [Schätzung der Normalisierungsgrenzen pro Sendung],
) <lst:normalization-bounds>
Die normierte Zielfunktion kombiniert die fixen Fahrzeugkosten (gewichtet über alle Sendungen gemittelt) mit den sendungsspezifischen variablen Komponenten (vgl. @lst:pulp-objective):
#figure(
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
  ```,
  caption: [Implementation der multikriteriellen Zielfunktion in PuLP],
) <lst:pulp-objective>
==== Nebenbedingungen
Die Nebenbedingungen bilden die in @ch:mathematical-model definierten Restriktionen ab:
- *Flusserhaltung:* An jedem Zwischenknoten muss der eingehende Fluss jeder Sendung dem ausgehenden entsprechen. An den Startknoten wird genau eine ausgehende Kante aktiviert, an den Zielknoten genau eine eingehende.
- *Kapazitätskopplung:* Die Summe der Sendungsgewichte auf einer Kante darf die Kapazität mal der Fahrzeuganzahl nicht überschreiten: $ sum_k w_k dot x_(i,k) <= c_i dot y_i $
- *Budget- und Emissionsgrenzen:* Optionale sendungsspezifische Obergrenzen für Kosten und Emissionen werden als Soft Constraints formuliert.
==== Solver-Ausführung
Als Solver wird *HiGHS* über die PuLP-Schnittstelle eingesetzt. HiGHS löst das MILP mit Branch-and-Bound- und Presolve-Verfahren und unterstützt konfigurierbare Zeitlimits (siehe @lst:solver-execution). Eine vollständige Übersicht aller in diesem Projekt eingesetzten Softwarekomponenten samt Versionsangaben findet sich im Softwareverzeichnis in @tab:software-directory im Anhang.
#figure(
  ```python
  highs_py = pulp.HiGHS(
      msg=show_progress,
      timeLimit=time_limit_sec,
  )
  status = self.prob.solve(highs_py)
  ```,
  caption: [Solver-Konfiguration und Ausführung über PuLP],
) <lst:solver-execution>
Nach der Lösung werden die Entscheidungsvariablen mit einem Schwellwert von $0{,}5$ ausgelesen, um Gleitkomma-Toleranzen des Solvers zu kompensieren. Aus den aktivierten Kanten werden die Routen je Sendung rekonstruiert und als `RoutingResult` zurückgegeben. Eventuelle Slack-Variablen-Verletzungen werden in einem diagnostischen Report ausgegeben.

== Heuristische Lösungsverfahren <sec:heuristic-implementation>

Dieses Unterkapitel beschreibt die softwareseitige Umsetzung der in @ch:heuristic-approach vorgestellten heuristischen Lösungsverfahren. Alle Klassen befinden sich im Modul `heuristics/dijkstra_router.py` und greifen auf dieselbe zeitexpandierte Netzwerkstruktur (`TimeExpandedNetwork`) zurück, die auch der exakte MILP-Solver verwendet. Die Architektur baut auf der Basisklasse `DijkstraRouter` auf, von der die Klasse `AStarRouter` erbt, um die modusspezifische Heuristikfunktion bereitzustellen.

=== Architektur und Datenhaltung
Zur Verwaltung des Suchzustands und zur Effizienzsteigerung nutzt die Implementierung drei interne Datenstrukturen, die als Python-Dataclasses realisiert sind:
- `_NetworkIndex`: Baut eine Adjazenzliste aller ausgehenden Kanten auf und indiziert Knoten nach Hubs sowie nach Hub-Zeit-Kombinationen. Dieser Index wird beim ersten Routing-Aufruf erstellt und nur bei einem Netzwerkwechsel neu berechnet, wodurch Lokalisierungen von Startknoten in $O(1)$ möglich sind.
- `_CapacityState`: Kapselt den Belegungszustand des Netzwerks. Er speichert die Anzahl aktiver Fahrzeuge sowie die verbleibende Restkapazität für jede zeitexpandierte Kante.
- `_NormalizationContext`: Bündelt sendungsspezifische Normalisierungsgrenzen und Gewichtungsfaktoren, um bei jedem Suchschritt eine konsistente Skalierung sicherzustellen.

=== Dynamische Kantenbewertung (Arc Score)
Die Methode `_arc_score` implementiert die Kantenbewertungsfunktion $sigma(a, k)$ (siehe @sec:arc-score). Sie ermittelt für eine Kante den kombinierten Score aus gewichteten Kosten, Fahrzeiten und Emissionen. Ein zentrales Element ist dabei die dynamische Kapazitätsprüfung: Ist eine Kante kapazitiv nicht mehr begehbar – etwa weil das Fahrzeuglimit der Kante überschritten würde –, wird die Kante verworfen (siehe @lst:arc-score-calc).

#figure(
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
  ```,
  caption: [Dynamische Kantenbewertung mit Kapazitätsprüfung],
) <lst:arc-score-calc>

Die Methode `_additional_vehicles` berechnet dabei auf Basis der Restkapazität des aktuell aktiven Fahrzeugs, ob ein neues Fahrzeug bereitgestellt werden muss. Kann die Sendung auf dem bestehenden Fahrzeug konsolidiert werden, entstehen keine zusätzlichen Fixkosten ($0$ zusätzliche Fahrzeuge). Andernfalls wird die benötigte Anzahl neuer Fahrzeuge auf Basis der Maximalkapazität der Kante bestimmt. Für Straßenkanten ist die Fahrzeuganzahl nach oben unbegrenzt (`math.inf`), während für Schiene, Luft und See standardmäßig ein Fahrzeuglimit gilt.

=== Kürzeste-Weg-Suche und Pruning
Die Methode `_find_shortest_path` realisiert die eigentliche Routensuche als Best-First-Suche über eine Prioritätswarteschlange. Um die Leistung im zeitexpandierten Netzwerk zu optimieren, werden zwei Pruning-Verfahren eingesetzt:
1. *Zeitbasiertes Pruning:* Knoten werden verworfen, wenn die aktuelle Reisezeit plus die minimale Restreisezeit zum Ziel die Deadline überschreitet. Diese minimale Restreisezeit wird vorab mittels eines Rückwärts-Dijkstra-Laufs auf dem statischen Netzwerk für alle Hubs berechnet.
2. *Heuristikbasiertes Pruning (A\*):* Knoten, die rechnerisch keine zulässige Lösung zum Zielhub mehr erreichen können (Heuristikwert unendlich), werden verworfen (siehe @lst:pruning-logic).

#figure(
  ```python
  # Hauptschleife der Routensuche (Ausschnitt)
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
  ```,
  caption: [Pruning-Logik in der Kürzeste-Weg-Suche],
) <lst:pruning-logic>

=== A\*-Router
Die Klasse `AStarRouter` erweitert den `DijkstraRouter` und überschreibt die Heuristikmethode `_heuristic_by_hub`. Sie berechnet vorab die minimalen Restkosten zum Zielhub mittels Rückwärts-Dijkstra auf dem statischen Netzwerk. Anstelle der reinen Reisezeit wird hierfür der gewichtete und normierte Kanten-Score (Kosten, Zeit, Emissionen) herangezogen. Das Ergebnis wird gecacht, sodass wiederholte Suchen mit identischen Sendungsparametern keine Neuberechnung erfordern.

=== Multi-Sendungs-Routing und LNS-Optimierung
Bei mehreren Sendungen (`solve_multiple`) sortiert der Router die Sendungen absteigend nach Gewicht. Dies stellt sicher, dass schwere Sendungen zuerst Kapazitäten belegen und leichtere Sendungen flexibler auf freie Restkapazitäten gebucht werden. Nach jeder Zuweisung wird der Belegungszustand über `_reserve_route` angepasst, um Konsolidierungen zu ermöglichen.

Um die Abhängigkeit von dieser sequentiellen Reihenfolge aufzubrechen und lokale Optima zu verlassen, wird eine Large Neighborhood Search (LNS) als Ruin-and-Recreate-Heuristik eingesetzt (siehe @lst:lns-optimization):

#figure(
  ```python
  def optimize_multiple(self, initial_result, network,
                        iterations=20, ruin_fraction=0.2, seed=None):
      rng = random.Random(seed)
      best_result = initial_result
      best_routes = dict(initial_result.shipment_routes)
      num_to_ruin = max(1, int(len(shipments) * ruin_fraction))

      for _ in range(iterations):
          # Ruin: zufällige Auswahl und Entfernung von Sendungsrouten
          ruined_ids = rng.sample(list(best_routes.keys()), num_to_ruin)

          # Kapazitäten der verbleibenden Routen wiederaufbauen
          capacity = self._empty_capacity_state(network)
          for s_id in remaining_ids:
              self._reserve_route(network, best_routes[s_id], ...)

          # Recreate: entfernte Sendungen nach Gewicht sortiert neu routen
          ruined_shipments.sort(key=lambda s: s.weight, reverse=True)
          for shipment in ruined_shipments:
              route = self._find_shortest_path(network, shipment, capacity, ...)
              if route is None:
                  routing_failed = True
                  break
              self._reserve_route(network, route, shipment, capacity)

          # Akzeptiere Kandidaten mit besserem Gesamtzielwert
          if candidate.objective_value < best_obj:
              best_result = candidate
  ```,
  caption: [Ruin-and-Recreate-Optimierungsschleife (LNS)],
) <lst:lns-optimization>

=== Ergebnisaggregation
Nach Abschluss des Routings aggregiert `_build_combined_result` alle Pfadmetriken. Die Fixkosten der aktivierten Fahrzeuge werden über das gesamte Netzwerk hinweg summiert und nicht prozentual auf einzelne Sendungen umgelegt. Dies garantiert eine exakte methodische Vergleichbarkeit mit der Zielfunktionsstruktur des exakten MILP-Solvers. Der Zielfunktionswert wird analog zur MILP-Zielfunktion (@eq:routing) berechnet, wobei die gemittelten Fixkosten-Koeffizienten $alpha_C$ und $alpha_E$ sowie die sendungsspezifischen variablen Komponenten addiert werden. Dies gewährleistet, dass die Lösungsqualität des heuristischen Verfahrens direkt mit der des exakten Solvers verglichen werden kann.

== Weboberfläche <sec:web-app>

Für die interaktive Nutzung steht das Dashboard OptiFreight zur Verfügung, das die Routingplanung ohne direkten Code-Zugriff ermöglicht (@fig:dashboard). Über das Dashboard lässt sich ein Netzwerkdatensatz laden, eine oder mehrere Sendungen mit Start, Ziel, Gewicht und Zeitfenster anlegen und zwischen exaktem MILP-Solver und heuristischem Routing wählen. Die Gewichtung der Zielfunktion (Kosten, Zeit, Emissionen) kann direkt über Schieberegler angepasst werden.

Nach dem Start der Routenberechnung zeigt die Karte die gewählte Route eingefärbt nach Transportmodus (Straße, Schiene, Luft, Schiff). Das rechte Panel listet den Routenverlauf Station für Station mit Distanz, Kosten und Gewicht auf, während unten die aggregierten Ergebnisse – Gesamtkosten, CO2-Emissionen, Transportzeit und Konsolidierungsgrad – sowie ein Konsolenprotokoll des Lösungsvorgangs angezeigt werden.

#figure(
  image("assets/dashboard_screenshot.png", width: 100%),
  caption: [Dashboard mit berechneter Route und Ergebnismetriken],
) <fig:dashboard>

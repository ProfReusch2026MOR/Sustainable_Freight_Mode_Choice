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

= Heuristische Lösung (Multimodaler Dijkstra-Algorithmus)

Neben dem exakten MILP-Modell wurde eine heuristische Lösung entwickelt, um auch für größere Transportnetzwerke in kurzer Zeit hochwertige Lösungen bestimmen zu können. Während exakte Optimierungsverfahren mit zunehmender Netzwerkgröße und Anzahl möglicher Transportalternativen einen hohen Rechenaufwand verursachen, ermöglichen heuristische Verfahren die Ermittlung guter Lösungen innerhalb deutlich kürzerer Laufzeiten.

Der entwickelte Ansatz basiert auf einem erweiterten Dijkstra-Verfahren für multimodale Transportnetzwerke. Das Netzwerk wird dabei als gerichteter Graph

$
G = (V, E)
$

modelliert. Die Knoten $V$ repräsentieren die verschiedenen Standorte des Netzwerks, beispielsweise Häfen, Flughäfen, Bahnhöfe oder Lagerstandorte. Die Kanten $E$ beschreiben die verfügbaren Transportverbindungen zwischen diesen Standorten.

Jede Kante besitzt mehrere Attribute, die für die spätere Bewertung einer Route verwendet werden. Dazu zählen die Transportkosten, die Transportzeit, die CO₂-Emissionen sowie der verwendete Verkehrsträger. Im Python-Code werden diese Informationen in der Datenstruktur `Edge` gespeichert:

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

== Berechnung der Kantenkosten

Die Grundlage der Heuristik bildet die Bewertung jeder Transportverbindung. Die Kosten und Emissionen einer Kante werden aus der Transportdistanz, dem Sendungsgewicht sowie den verkehrsträgerspezifischen Faktoren berechnet:

$
c_e = d_e dot k_(m_e) dot w
$

$
q_e = d_e dot epsilon_(m_e) dot w
$

Dabei bezeichnet

* $d_e$ die Distanz der Kante,
* $k_(m_e)$ die Kosten pro Tonnenkilometer des Verkehrsträgers,
* $epsilon_(m_e)$ den Emissionsfaktor des Verkehrsträgers,
* $w$ das Transportgewicht.

Die Berechnung erfolgt beim Einlesen des Netzwerks:

```python
cost = distance * float(
    factors[mode]["cost_per_ton_km"]
) * shipment_weight_tons

emissions = distance * float(
    factors[mode]["emissions_kg_per_ton_km"]
) * shipment_weight_tons
```

== Gewichtete Zielfunktion

Da Kosten, Zeit und Emissionen unterschiedliche Größenordnungen besitzen, werden diese zunächst normalisiert. Anschließend wird für jede Kante ein gewichteter Bewertungswert berechnet:

$
S(e) =
alpha dot c_e / bar(c)

* beta dot t_e / bar(t)
* gamma dot q_e / bar(q)
* delta dot M_e
  $

mit

* $c_e$ = Transportkosten,
* $t_e$ = Transportzeit,
* $q_e$ = CO₂-Emissionen,
* $M_e$ = Strafwert für einen Verkehrsträgerwechsel,
* $alpha$, $beta$, $gamma$ = Gewichtungsfaktoren,
* $delta$ = Gewichtung des Verkehrsträgerwechsels.

Der Strafwert $M_e$ nimmt den Wert 1 an, wenn sich der Verkehrsträger im Vergleich zur vorherigen Kante ändert, andernfalls den Wert 0.

Die Implementierung dieser Bewertungsfunktion erfolgt in der Methode `edge_score()`:

```python
return (
    weights["cost"] *
    normalize(edge.cost, scales["cost"])

    + weights["time"] *
    normalize(edge.duration_min, scales["time"])

    + weights["emissions"] *
    normalize(edge.emissions, scales["emissions"])

    + weights.get("mode_change", 0.0)
    * mode_change_penalty
)
```

Durch die Gewichtungsfaktoren können unterschiedliche Optimierungsziele verfolgt werden. Der Nutzer definiert hierfür individuelle Präferenzen für Kosten, Zeit und CO₂-Emissionen.

== Suchverfahren

Die eigentliche Routensuche erfolgt mittels eines erweiterten Dijkstra-Verfahrens. Formal basiert der Algorithmus auf der allgemeinen A\*-Struktur

$
f(n) = g(n) + h(n)
$

wobei

* $g(n)$ die bisher aufgelaufenen Kosten beschreibt,
* $h(n)$ eine Schätzung der verbleibenden Kosten bis zum Ziel darstellt.

Da im aktuellen Netzwerkmodell keine geographischen Koordinaten für alle Hubs genutzt werden, wird die Heuristikfunktion auf

$
h(n) = 0
$

gesetzt. Damit reduziert sich die Suche auf einen gewichteten Dijkstra-Algorithmus.

Im Code wird dies durch folgende Funktion umgesetzt:

```python
def heuristic(_: str) -> float:
    return 0.0
```

Der Suchzustand besteht dabei nicht nur aus dem aktuellen Knoten, sondern zusätzlich aus dem zuletzt verwendeten Verkehrsträger:

$
"Zustand" = (v, m)
$

Dadurch kann der Algorithmus Verkehrsträgerwechsel explizit berücksichtigen. Die Erweiterung des Zustandsraums erfolgt über:

```python
start_state = (start, None)

new_state = (
    edge.target,
    edge.mode
)
```

Für jeden besuchten Zustand werden die aktuell besten Kosten gespeichert. Wird ein günstigerer Pfad gefunden, wird dieser in die Prioritätswarteschlange eingefügt und später weiter untersucht.

== Mehrzieloptimierung

Um verschiedene Entscheidungsperspektiven abzubilden, berechnet die Heuristik vier unterschiedliche Routingstrategien:

1. Nutzerdefinierte Präferenzroute
2. Kostenminimum
3. Zeitminimum
4. CO₂-Minimum

Die zugehörigen Gewichtungen werden im Programm wie folgt definiert:

```python
{
    "name": "Kostenminimum",
    "cost": 1.0,
    "time": 0.0,
    "emissions": 0.0
}
```

```python
{
    "name": "Zeitminimum",
    "cost": 0.0,
    "time": 1.0,
    "emissions": 0.0
}
```

```python
{
    "name": "CO2-Minimum",
    "cost": 0.0,
    "time": 0.0,
    "emissions": 1.0
}
```

Dadurch entstehen mehrere Lösungsalternativen, die anschließend hinsichtlich Kosten, Transportzeit und Emissionen miteinander verglichen werden können.

== Lokale Verbesserung

Nach der eigentlichen Routensuche wird eine lokale Verbesserungsphase durchgeführt. Dabei wird geprüft, ob zwei aufeinanderfolgende Verbindungen

$
A arrow.r B arrow.r C
$

durch eine direkte Verbindung

$
A arrow.r C
$

ersetzt werden können.

Ist die direkte Verbindung hinsichtlich der Zielfunktion günstiger, wird die bestehende Teilroute ersetzt. Dies reduziert unnötige Umwege und verbessert die Qualität der gefundenen Lösung.

Die Prüfung erfolgt im Verfahren `improve_route_by_shortcuts()`:

```python
direct_edges = [
    e for e in graph.get(a, [])
    if e.target == c
]
```

Anschließend wird die Bewertung der direkten Verbindung mit der ursprünglichen Teilroute verglichen und gegebenenfalls übernommen.

== Zusammenfassung

Die entwickelte Heuristik kombiniert eine gewichtete Dijkstra-Suche mit einer Mehrzielbewertung und einer lokalen Verbesserungsstrategie. Durch die Berücksichtigung von Kosten, Zeit, CO₂-Emissionen und Verkehrsträgerwechseln können unterschiedliche Entscheidungspräferenzen abgebildet werden. Gleichzeitig ermöglicht der heuristische Ansatz sehr kurze Rechenzeiten und eignet sich daher insbesondere für große multimodale Transportnetzwerke.

Die Heuristik dient im weiteren Verlauf der Arbeit als Vergleichsverfahren zum exakten MILP-Modell und ermöglicht eine Bewertung des Zielkonflikts zwischen Wirtschaftlichkeit, Transportdauer und Nachhaltigkeit.

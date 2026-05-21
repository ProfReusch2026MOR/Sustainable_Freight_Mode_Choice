# Sustainable Freight Mode Choice

## Projektbeschreibung

Dieses Projekt beschäftigt sich mit der nachhaltigen Planung und Optimierung von Gütertransporten in einem multimodalen Transportnetzwerk. Ziel ist es, Sendungen effizient über verschiedene Verkehrsträger zu transportieren und dabei wirtschaftliche, zeitliche sowie ökologische Aspekte gleichzeitig zu berücksichtigen.

Im Mittelpunkt steht die Entwicklung eines Operations-Research-Modells zur Entscheidungsunterstützung in der Logistik.

Das Modell entscheidet:

- welche Transportwege genutzt werden  
- welche Verkehrsträger eingesetzt werden  
- wann intermodale Transporte sinnvoll sind  
- wann Transporte konsolidiert werden sollten  
- wie Lieferfristen trotz Kapazitätsrestriktionen eingehalten werden können  

Das Transportnetzwerk umfasst folgende Verkehrsträger:

- LKW (Straßentransport)
- Bahn (Schienentransport)
- Schiff (See- und Binnenschifffahrt)
- Flugzeug (Luftfracht)

Zusätzlich werden Umschlagterminals berücksichtigt, an denen ein Wechsel zwischen verschiedenen Verkehrsträgern stattfinden kann.

---

## Operations-Research-Entscheidungsfrage

Wie können mehrere Sendungen in einem multimodalen Transportnetzwerk so geplant werden, dass Transportkosten und CO₂-Emissionen minimiert werden, während Lieferfristen, Umschlagsprozesse und Kapazitätsgrenzen eingehalten werden?

Dabei muss entschieden werden:

- welche Routen verwendet werden  
- welcher Verkehrsträger gewählt wird  
- wann ein Moduswechsel sinnvoll ist  
- welche Transporte gemeinsam konsolidiert werden können  

---

## Reale Motivation

Der weltweite Güterverkehr ist essenziell für globale Lieferketten und internationale Wirtschaftssysteme. Gleichzeitig verursacht der Transportsektor erhebliche Mengen an CO₂-Emissionen.

Typische Entscheidungen in der Praxis:

- Soll eine Sendung per Flugzeug transportiert werden?
- Ist Bahn ausreichend?
- Wann lohnt sich Schiffstransport?
- Welche Transporte können gebündelt werden?
- Wie lassen sich Emissionen reduzieren?

Typische Nutzung:

- LKW: regionale Zustellung  
- Bahn: Langstrecke  
- Schiff: internationale Transporte  
- Flugzeug: zeitkritische Lieferungen  

---

## Projektziele

### Fachliche Ziele

- Entwicklung eines Optimierungsmodells  
- Analyse multimodaler Transportentscheidungen  
- Untersuchung von Kosten-Emissions-Zielkonflikten  
- Bewertung intermodaler Strategien  
- Analyse von Konsolidierungseffekten  

### Methodische Ziele

- Vergleich exakter und heuristischer Verfahren  
- Untersuchung der Skalierbarkeit  
- Laufzeitanalyse  
- Bewertung der Lösungsqualität  

### Praktische Ziele

- Entwicklung realistischer Entscheidungshilfen  
- Ableitung logistischer Empfehlungen  
- Unterstützung nachhaltiger Transportplanung  

---

## Transportnetzwerk

### Bestandteile

- Städte  
- Häfen  
- Flughäfen  
- Bahnhöfe  
- Logistikzentren  
- Umschlagterminals  
- Intermodale Hubs  

### Verbindungen

- Straßenverbindungen  
- Bahnverbindungen  
- Schifffahrtsrouten  
- Flugrouten  

---

## Verkehrsträger

### LKW

- flexibel  
- hohe Emissionen  
- mittlere Kapazität  
- geeignet für First- & Last-Mile  

### Bahn

- kosteneffizient  
- geringe Emissionen  
- hohe Kapazität  
- längere Transportzeiten  

### Schiff

- sehr günstig  
- sehr hohe Kapazität  
- sehr langsam  
- ideal für internationale Transporte  

### Flugzeug

- sehr schnell  
- sehr teuer  
- hohe Emissionen  
- geringe Kapazität  

---

## Intermodale Transporte

Beispiele:

- LKW → Bahn  
- Schiff → LKW  
- Flugzeug → LKW  
- Bahn → Schiff  

Eigenschaften an Terminals:

- Umschlagskosten  
- zusätzliche Zeit  
- Kapazitätsgrenzen  

---

## Datenmodell

### Netzwerkdaten

- Knoten: Städte, Häfen, Flughäfen, Bahnhöfe, Terminals  
- Kanten: Transportverbindungen  

### Sendungsdaten

- Ursprung / Ziel  
- Gewicht / Volumen  
- Priorität  
- Deadline  

### Transportparameter

- Kosten  
- Zeiten  
- Emissionen  
- Kapazitäten  

### Terminaldaten

- Umschlagskosten  
- Transferzeiten  
- Kapazitäten  

---

## Instanzen

### Kleine Instanz

- Modellvalidierung  
- einfache Struktur  
- wenige Sendungen  

### Mittlere Instanz

- erste Optimierungseffekte  
- mehrere Terminals  
- mehr Sendungen  

### Große Instanz

- hohe Komplexität  
- viele Entscheidungen  
- realistische Netzwerke  

---

## Mathematisches Modell

### Entscheidungsvariablen

- Routing-Entscheidungen  
- Moduswahl  
- Terminalnutzung  
- Konsolidierung  

### Zielfunktion

Minimierung von:

- Transportkosten  
- Umschlagskosten  
- CO₂-Emissionen  
- Verspätungskosten  

### Nebenbedingungen

- Flusserhaltung  
- Kapazitäten  
- Deadlines  
- Konsistenz  
- Moduswechselregeln  

---

## Solver-Implementierung

Technologien:

- Python  
- Gurobi  
- PuLP  
- OR-Tools  

### Auswertung

- Laufzeit  
- Gap  
- Zielfunktionswert  
- Bounds  

---

## Heuristische Verfahren

- Greedy  
- Shortest Path Heuristic  
- Local Search  
- Konsolidierungsheuristiken  

Ziel:

- schnelle gute Lösungen für große Instanzen  

---

## Vergleich: Solver vs. Heuristik

Verglichen werden:

- Qualität  
- Laufzeit  
- Robustheit  
- Skalierbarkeit  

---

## Visualisierung

- Netzwerke  
- Routen  
- Modal Split  
- CO₂-Vergleich  
- Kostenanalyse  
- Kapazitätsauslastung  

---

## Interpretation

Analyse:

- wann Flugzeug sinnvoll ist  
- wann Bahn/Schiff bevorzugt wird  
- Emissionsreduktion  
- kritische Terminals  
- effiziente Strategien  

---

## Handlungsempfehlungen

- Bahn & Schiff für Langstrecke  
- Flugzeug nur bei Deadline-Druck  
- LKW für regionale Verteilung  
- Ausbau intermodaler Terminals  
- Konsolidierung von Sendungen  

---

## Skalierbarkeit

Probleme bei großen Instanzen:

- viele binäre Variablen  
- dichte Netzwerke  
- Kapazitätsrestriktionen  
- Konsolidierung  

---

## Praktische Limitationen

- unsichere Fahrzeiten  
- fehlende Echtzeitdaten  
- vereinfachte Emissionsmodelle  
- Datenverfügbarkeit  

---

## GitHub Projektstruktur

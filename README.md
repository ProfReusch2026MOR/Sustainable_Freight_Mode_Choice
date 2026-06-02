<img width="1693" height="929" alt="image" src="https://github.com/user-attachments/assets/20bdd247-d42a-4f91-87f7-d887448eef8f" />

# Sustainable Freight Mode Choice

## Projektmitglieder: 

- Benedikt (bennewehn)
- Phil Kahlert (phil-kl)
- Laurens Rüther (LaurensRuether)
- Luis Kruse (Ikruse301) 
- Minglu Li - Sam  (Sam1806927581) 

---

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

## Entscheidungsfrage

Im Mittelpunkt dieses Projekts steht die Frage, wie Gütertransporte in einem multimodalen Transportnetzwerk optimal geplant werden können. Unternehmen müssen täglich entscheiden, welche Verkehrsträger für bestimmte Sendungen eingesetzt werden sollen, um sowohl wirtschaftliche als auch ökologische Ziele zu erreichen. Dabei stehen verschiedene Transportmöglichkeiten wie LKW, Bahn, Schiff und Flugzeug zur Verfügung, die sich hinsichtlich Kosten, Lieferzeit, Kapazitäten und CO₂-Emissionen deutlich unterscheiden.

Die zentrale Entscheidungsfrage lautet daher:

#### "Wie können mehrere Sendungen in einem multimodalen Transportnetzwerk so geplant werden, dass Transportkosten und Emissionen minimiert werden, während Lieferfristen, Kapazitätsgrenzen und Umschlagsprozesse eingehalten werden?"

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
- PuLP  
- OR-Tools  

### Auswertung

- Laufzeit  
- Gap  
- Zielfunktionswert  

---

## Heuristische Verfahren

- Greedy  
- Shortest Path Heuristic  
- Local Search  
- Konsolidierungsheuristiken  

Ziel:

- schnelle gute Lösungen für große Instanzen  

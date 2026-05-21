Sustainable Freight Mode Choice

Projektbeschreibung

Dieses Projekt beschäftigt sich mit der nachhaltigen Planung und Optimierung von Gütertransporten in einem multimodalen Transportnetzwerk. Ziel ist es, Sendungen effizient über verschiedene Verkehrsträger zu transportieren und dabei wirtschaftliche, zeitliche sowie ökologische Aspekte gleichzeitig zu berücksichtigen.

Im Mittelpunkt steht die Entwicklung eines Operations-Research-Modells zur Entscheidungsunterstützung in der Logistik.

Das Modell entscheidet:

* welche Transportwege genutzt werden,
* welche Verkehrsträger eingesetzt werden,
* wann intermodale Transporte sinnvoll sind,
* wann Transporte konsolidiert werden sollten,
* und wie Lieferfristen trotz Kapazitätsrestriktionen eingehalten werden können.

Das Transportnetzwerk umfasst folgende Verkehrsträger:

* LKW (Straßentransport)
* Bahn (Schienentransport)
* Schiff (See- und Binnenschifffahrt)
* Flugzeug (Luftfracht)

Zusätzlich werden Umschlagterminals berücksichtigt, an denen ein Wechsel zwischen verschiedenen Verkehrsträgern stattfinden kann.

Das Projekt verbindet klassische Netzwerkoptimierung mit nachhaltiger Logistikplanung und realitätsnahen Transportentscheidungen.

⸻

Operations-Research-Entscheidungsfrage

Die zentrale Entscheidungsfrage des Projekts lautet:

Wie können mehrere Sendungen in einem multimodalen Transportnetzwerk so geplant werden, dass Transportkosten und CO₂-Emissionen minimiert werden, während Lieferfristen, Umschlagsprozesse und Kapazitätsgrenzen eingehalten werden?

Dabei muss entschieden werden:

* welche Routen verwendet werden,
* welcher Verkehrsträger gewählt wird,
* wann ein Moduswechsel sinnvoll ist,
* und welche Transporte gemeinsam konsolidiert werden können.

Das Projekt untersucht damit einen klassischen Zielkonflikt moderner Logistiksysteme:

* geringe Kosten,
* schnelle Lieferzeiten,
* und nachhaltige Transporte.

⸻

Reale Motivation

Der weltweite Güterverkehr ist essenziell für globale Lieferketten und internationale Wirtschaftssysteme. Gleichzeitig verursacht der Transportsektor erhebliche Mengen an CO₂-Emissionen und steht zunehmend unter regulatorischem und wirtschaftlichem Druck.

Unternehmen müssen täglich Entscheidungen treffen wie:

* Soll eine Sendung schnell per Flugzeug transportiert werden?
* Ist ein günstigerer Bahntransport ausreichend?
* Wann lohnt sich der Einsatz von Schiffstransporten?
* Welche Transporte können gemeinsam gebündelt werden?
* Wie können Emissionen reduziert werden, ohne Lieferzeiten zu verletzen?

Besonders internationale Lieferketten basieren heute auf der Kombination verschiedener Verkehrsträger.

Typische Beispiele:

* LKW für regionale Zustellung
* Bahn für Langstreckentransporte
* Schiff für internationale Massentransporte
* Flugzeug für zeitkritische Lieferungen

Das Projekt simuliert eine realistische Entscheidungsumgebung moderner Logistikunternehmen und untersucht, wie nachhaltige und wirtschaftliche Transportstrategien entwickelt werden können.

⸻

Projektziele

Das Projekt verfolgt mehrere wissenschaftliche und praktische Ziele.

Fachliche Ziele

* Entwicklung eines mathematischen Optimierungsmodells
* Analyse multimodaler Transportentscheidungen
* Untersuchung von Kosten-Emissions-Zielkonflikten
* Bewertung intermodaler Transportstrategien
* Analyse von Konsolidierungseffekten

Methodische Ziele

* Vergleich exakter und heuristischer Verfahren
* Untersuchung der Skalierbarkeit
* Bewertung der Laufzeiten bei großen Instanzen
* Analyse der Lösungsqualität verschiedener Verfahren

Praktische Ziele

* Entwicklung realistischer Entscheidungshilfen
* Ableitung logistischer Handlungsempfehlungen
* Unterstützung nachhaltiger Transportplanung

⸻

Transportnetzwerk

Das Projekt basiert auf einem multimodalen Netzwerkmodell.

Bestandteile des Netzwerks

Das Netzwerk enthält:

* Städte
* Häfen
* Flughäfen
* Bahnhöfe
* Logistikzentren
* Umschlagterminals
* Intermodale Hubs

Zwischen den Knoten existieren verschiedene Transportverbindungen.

⸻

Verkehrsträger

LKW (Straßentransport)

Eigenschaften:

* hohe Flexibilität
* direkte Zustellung möglich
* schnelle regionale Transporte
* hohe Emissionen
* mittlere Kapazitäten

Typische Verwendung:

* First-Mile- und Last-Mile-Transport
* regionale Transporte
* flexible Direktlieferungen

⸻

Bahn (Schienentransport)

Eigenschaften:

* kosteneffizient bei großen Mengen
* geringere Emissionen
* hohe Kapazitäten
* längere Transportzeiten
* eingeschränkte Netzabdeckung

Typische Verwendung:

* Langstreckentransporte
* Containertransporte
* konsolidierte Güterströme

⸻

Schiff (See- und Binnenschifffahrt)

Eigenschaften:

* sehr geringe Kosten pro Transporteinheit
* niedrige Emissionen
* sehr hohe Kapazitäten
* lange Transportzeiten

Typische Verwendung:

* internationale Transporte
* Massengüter
* globale Lieferketten

⸻

Flugzeug (Luftfracht)

Eigenschaften:

* sehr schnelle Lieferungen
* höchste Transportkosten
* hohe Emissionen
* begrenzte Kapazitäten

Typische Verwendung:

* zeitkritische Sendungen
* Expresslieferungen
* hochwertige Güter

⸻

Intermodale Transporte

Ein Schwerpunkt des Projekts liegt auf intermodalen Transportketten.

Beispiele:

* LKW → Bahn
* Schiff → LKW
* Flugzeug → LKW
* Bahn → Schiff

An Umschlagterminals entstehen:

* Umschlagskosten
* zusätzliche Transportzeiten
* Kapazitätsrestriktionen

Das Modell entscheidet automatisch, wann sich ein Wechsel zwischen Verkehrsträgern lohnt.

⸻

Datenmodell

Das Projekt nutzt ein realistisches Datenmodell für multimodale Transportnetzwerke.

⸻

Netzwerkdaten

Knoten

* Städte
* Häfen
* Flughäfen
* Bahnhöfe
* Umschlagterminals

Verbindungen

* Straßenverbindungen
* Bahnverbindungen
* Schifffahrtsrouten
* Flugrouten

⸻

Sendungsdaten

Jede Sendung besitzt:

* Ursprung
* Ziel
* Volumen
* Gewicht
* Priorität
* Lieferdeadline

⸻

Transportparameter

Für jede Verbindung werden gespeichert:

* Transportkosten
* Fahr-/Transportzeiten
* CO₂-Emissionen
* Kapazitäten
* Transportmodus

⸻

Terminaldaten

Für Umschlagterminals:

* Umschlagskosten
* Transferzeiten
* maximale Kapazitäten
* unterstützte Verkehrsträger

⸻

Instanzen

Zur Untersuchung der Modellskalierbarkeit werden mehrere Instanzgrößen verwendet.

⸻

Kleine Instanz

Eigenschaften:

* wenige Knoten
* wenige Sendungen
* einfache Netzwerkstruktur
* Fokus auf Modellvalidierung

Ziel:

* Überprüfung der Modelllogik
* Test der Nebenbedingungen
* Analyse erster Transportentscheidungen

⸻

Mittlere Instanz

Eigenschaften:

* größere Netzwerke
* mehrere Umschlagterminals
* mehr Sendungen
* höhere Netzwerkkonnektivität

Ziel:

* Untersuchung intermodaler Entscheidungen
* Analyse erster Konsolidierungseffekte

⸻

Große Instanz

Eigenschaften:

* dichtes Transportnetzwerk
* viele Sendungen
* zahlreiche Transportalternativen
* hohe Anzahl binärer Entscheidungen
* relevante Konsolidierungsentscheidungen

Ziel:

* Untersuchung der Skalierbarkeit
* Bewertung der Solverperformance
* Analyse heuristischer Verfahren

⸻

Datenquellen

Das Projekt verwendet reale sowie künstlich erzeugte Daten.

Reale Datenquellen

Mögliche Quellen:

* OpenStreetMap
* Eurostat
* Umweltbundesamt
* Deutsche Bahn Infrastrukturinformationen
* Internationale Transport- und Emissionsdatenbanken
* Wissenschaftliche Literatur

⸻

Künstliche Datengenerierung

Falls reale Daten nicht vollständig verfügbar sind, werden realitätsnahe Szenarien erzeugt.

Die Generierung orientiert sich an:

* realistischen Transportkosten
* typischen Geschwindigkeiten
* realen Emissionswerten
* plausiblen Kapazitäten
* echten geografischen Distanzen

⸻

Plausibilitätsprüfungen

Zur Sicherstellung realistischer Daten werden verschiedene Prüfungen durchgeführt.

Beispiele:

* Vergleich von Fahrzeiten mit realistischen Durchschnittsgeschwindigkeiten
* Prüfung unrealistischer Transportketten
* Validierung der Emissionswerte
* Kontrolle von Kapazitäten und Sendungsvolumen
* Prüfung der Netzwerkkonnektivität
* Analyse unrealistischer Deadlines

⸻

Mathematisches Modell

Das Projekt basiert auf einem mathematischen Netzwerkflussmodell.

⸻

Entscheidungsvariablen

Beispiele:

* Nutzung einer Verbindung durch eine Sendung
* Wahl des Verkehrsträgers
* Nutzung eines Umschlagterminals
* Zeitpunkt von Ankünften
* Konsolidierung mehrerer Sendungen

⸻

Zielfunktion

Die Zielfunktion minimiert:

* Transportkosten
* Umschlagskosten
* CO₂-Emissionen
* Verspätungskosten

Möglich ist ein Multi-Objective-Ansatz zur Kombination von:

* Wirtschaftlichkeit
* Nachhaltigkeit

⸻

Nebenbedingungen

Das Modell berücksichtigt:

* Flusserhaltung
* Kapazitätsrestriktionen
* Lieferdeadlines
* Terminalkapazitäten
* Konsistenz der Transportpfade
* Moduswechselbedingungen
* maximale Transportzeiten

⸻

Solver-Implementierung

Das mathematische Modell wird mit professionellen Optimierungstools implementiert.

Verwendete Technologien

* Python
* Gurobi
* PuLP
* OR-Tools

⸻

Solver-Auswertung

Für jede Instanz werden dokumentiert:

* Solverstatus
* Laufzeit
* Zielfunktionswert
* Optimalitätslücke (Gap)
* Lower und Upper Bounds

Dadurch kann die Qualität der Lösungen bewertet werden.

⸻

Heuristische Verfahren

Zusätzlich zum exakten Solver wird eine Heuristik implementiert.

Mögliche Ansätze:

* Greedy-Heuristik
* Kürzeste-Wege-Heuristik
* Lokale Suche
* Konsolidierungsheuristiken

Ziel:

* schnell gute Lösungen zu erzeugen,
* insbesondere bei großen Instanzen.

⸻

Vergleich: Solver vs. Heuristik

Das Projekt enthält einen direkten Vergleich zwischen:

* exakten Optimierungsverfahren
* heuristischen Verfahren

Verglichen werden:

* Zielfunktionswerte
* Laufzeiten
* Lösungsqualität
* Robustheit
* Skalierbarkeit

Dadurch kann bewertet werden:

* wann Heuristiken sinnvoll sind,
* und ab welcher Problemgröße exakte Verfahren an Grenzen stoßen.

⸻

Visualisierung

Zur Interpretation der Ergebnisse werden verschiedene Visualisierungen erstellt.

Beispiele:

* Netzwerkdarstellungen
* Genutzte Transportwege
* Modal Split
* CO₂-Vergleiche
* Kostenanalysen
* Kapazitätsauslastungen
* Solver-Performance
* Vergleich verschiedener Instanzen

Die Visualisierungen dienen dazu:

* Entscheidungen nachvollziehbar zu machen,
* und Ergebnisse verständlich zu präsentieren.

⸻

Interpretation der Ergebnisse

Die Ergebnisse werden als Entscheidungshilfe interpretiert.

Untersucht wird beispielsweise:

* wann Luftfracht wirtschaftlich sinnvoll ist,
* welche Transporte auf Bahn oder Schiff verlagert werden können,
* wie Emissionen reduziert werden können,
* welche Terminals kritisch sind,
* und welche Transportstrategien besonders effizient sind.

⸻

Handlungsempfehlung

Auf Basis der Ergebnisse werden konkrete Empfehlungen formuliert.

Beispiele:

* Nutzung von Bahn und Schiff für Langstrecken
* Einsatz von Flugzeugtransport nur bei kritischen Deadlines
* Nutzung von LKW für regionale Verteilung
* Ausbau intermodaler Umschlagterminals
* Konsolidierung von Sendungen zur Emissionsreduktion

Die Empfehlungen werden direkt mit der realen Motivation des Projekts verknüpft.

⸻

Skalierbarkeit

Ein zentraler Bestandteil des Projekts ist die Analyse der Skalierbarkeit.

Untersucht wird:

* wie sich Laufzeiten mit der Problemgröße verändern,
* warum exakte Solver bei großen Instanzen Schwierigkeiten bekommen,
* und welche Modellbestandteile besonders komplexitätssteigernd wirken.

Besonders relevant:

* viele binäre Variablen
* dichte Netzwerke
* Kapazitätsrestriktionen
* Konsolidierungsentscheidungen
* Multi-Objective-Optimierung

⸻

Praktische Limitationen

Das Projekt diskutiert außerdem praktische Einschränkungen.

Beispiele:

* Unsicherheiten bei Fahrzeiten
* fehlende Echtzeitdaten
* vereinfachte Netzwerke
* begrenzte Datenverfügbarkeit
* vereinfachte Emissionsannahmen
* infrastrukturelle Unterschiede zwischen Regionen

⸻

Projektorganisation mit GitHub

Für die Zusammenarbeit wird GitHub als zentrale Plattform genutzt.

⸻

Themenbasierte Ordnerstruktur

Das Repository ist in verschiedene Themenbereiche gegliedert.

Jeder Ordner enthält den aktuellen Fortschritt des jeweiligen Teilbereichs.

Struktur

* Bericht
    Dokumentation und schriftliche Ausarbeitung
* Datensammlung
    Sammlung und Aufbereitung der Daten
* Heuristic
    Entwicklung heuristischer Verfahren
* Literatursammlung
    Wissenschaftliche Quellen und Recherche
* Mathematisches Modell
    Formulierung des Optimierungsmodells
* Projektrahmen
    Organisatorische Inhalte und Anforderungen
* Präsentationen
    Präsentationen und Zwischenstände
* Solver
    Implementierung des Solvers
* Testungen
    Tests und Ergebnisanalysen

⸻

Nutzung von GitHub Issues

Zur Aufgabenverwaltung werden GitHub Issues verwendet.

Die Issues dienen dazu:

* Aufgaben zu definieren,
* Fortschritte zu dokumentieren,
* Verantwortlichkeiten festzulegen,
* Diskussionen zu führen,
* offene Probleme zu verwalten.

Die Struktur der Issues orientiert sich an den jeweiligen Projektbereichen.

⸻

GitHub Project-Visualisierung

Zusätzlich wird GitHub Projects verwendet, um den aktuellen Arbeitsstand transparent darzustellen.

Die Visualisierung unterstützt:

* Sprintplanung
* Aufgabenverwaltung
* Fortschrittskontrolle
* Priorisierung offener Aufgaben
* Kommunikation im Team

Dadurch bleibt der Projektfortschritt jederzeit nachvollziehbar.

⸻

Technische Umsetzung

Das Projekt wird in Python entwickelt.

Verwendete Werkzeuge:

* Python
* Jupyter Notebook
* Pandas
* NetworkX
* Matplotlib
* Gurobi / PuLP / OR-Tools

⸻

Abgabeformat

Die Projektergebnisse werden bereitgestellt als:

* Jupyter Notebook mit sichtbaren Outputs
* PDF-Export des Notebooks
* Dokumentation im Repository
* Visualisierungen und Ergebnisanalysen

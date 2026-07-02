= Einleitung <ch:introduction>

== Motivation und Relevanz
Der weltweite Güterverkehr ist das Rückgrat globaler Lieferketten und internationaler Wirtschaftskreisläufe. Gleichzeitig ist der Transportsektor für einen erheblichen Teil der globalen Treibhausgasemissionen verantwortlich. Angesichts strengerer gesetzlicher Auflagen, wie dem europäischen Green Deal, und eines wachsenden gesellschaftlichen Bewusstseins für Nachhaltigkeit stehen Logistikunternehmen vor einer doppelten Herausforderung: Sie müssen Gütertransporte nicht nur wirtschaftlich und zeitgerecht abwickeln, sondern auch deren ökologischen Fußabdruck minimieren.

Traditionell wurden Transportwege primär nach Kosten und Laufzeiten optimiert. Die Einbeziehung von CO₂-Emissionen führt jedoch zu komplexen Zielkonflikten. Um diese Konflikte systematisch zu lösen, gewinnt der kombinierte bzw. multimodale Transport an Bedeutung. Hierbei werden verschiedene Verkehrsträger – wie Lastkraftwagen (Straße), Güterzüge (Schiene), Frachtschiffe (See- und Binnenschifffahrt) und Flugzeuge (Luftfracht) – über Umschlagterminals hinweg zu intermodalen Transportketten kombiniert.

== Problemstellung
Das Optimierungsproblem des nachhaltigen multimodalen Gütertransports (Sustainable Freight Mode Choice) befasst sich mit der Frage, wie mehrere Sendungen effizient über ein Transportnetzwerk geroutet werden können. Für jede Sendung muss entschieden werden:
- Welche Transportwege genutzt werden.
- Welche Verkehrsträger eingesetzt werden.
- Wann und wo intermodale Umschlagprozesse stattfinden.
- Wie Sendungen auf gemeinsamen Strecken konsolidiert (gebündelt) werden können, um Skaleneffekte bei Kosten und Emissionen zu nutzen.

Dabei müssen zahlreiche praxisrelevante Restriktionen eingehalten werden:
1. *Lieferfristen (Deadlines):* Jede Sendung hat ein definiertes Zeitfenster.
2. *Kapazitätsgrenzen:* Sowohl Transportmittel (z. B. Zugkapazitäten) als auch Umschlagterminals haben begrenzte Kapazitäten.
3. *Umschlagsprozesse:* Ein Wechsel des Verkehrsträgers erfordert Zeit und verursacht zusätzliche Kosten sowie Umschlagsemissionen.
4. *Konnektivität:* Nicht jeder Verkehrsträger ist an jedem Knotenpunkt verfügbar.

== Zielsetzung der Arbeit
Das Hauptziel dieser Projektarbeit ist die mathematische Modellierung und algorithmische Lösung des beschriebenen multimodalen Transportplanungsproblems. Folgende Teilziele stehen im Fokus:
- *Modellentwicklung:* Formulierung des Problems als gemischt-ganzzahliges lineares Optimierungsmodell (MILP).
- *Verfahrensvergleich:* Implementierung eines exakten Lösungsverfahrens (PuLP/Solver) und eines heuristischen Verfahrens (Dijkstra-basierte Heuristik).
- *Evaluierung:* Untersuchung der Skalierbarkeit beider Ansätze anhand verschiedener Instanzgrößen (Small, Medium, Large) sowie Analyse des Zielkonflikts zwischen Kosten und CO₂-Emissionen (Pareto-Frontier).

== Aufbau der Arbeit
Die Arbeit gliedert sich wie folgt: @ch:theory erörtert die theoretischen Grundlagen des Netzwerkflusses und des Service Network Designs. In @ch:problem-description wird das mathematische Modell des multimodalen Gütertransports formal definiert. @ch:implementation beschreibt die softwareseitige Umsetzung. Die experimentellen Ergebnisse werden in @ch:results präsentiert, gefolgt von einer kritischen Diskussion in @ch:discussion. Die Arbeit schließt mit einem Fazit und Ausblick in @ch:conclusion.


= Legacy 

== Einschränkungen
Einschränkungen und Constraints des Projekts

Das Optimierungsmodell unterliegt verschiedenen realitätsnahen Einschränkungen.

1. Kapazitätsrestriktionen

Jede Transportverbindung besitzt begrenzte Kapazitäten.

Beispiele:

- maximale Anzahl transportierbarer Container,
- begrenzte Zugkapazitäten,
- beschränkte Laderaumkapazitäten von Schiffen,
- begrenzte Frachtkapazitäten von Flugzeugen,
- begrenzte Transportmengen auf Straßenverbindungen.

Das Modell darf diese Kapazitäten nicht überschreiten.

2. Terminalkapazitäten

Umschlagterminals besitzen nur begrenzte Ressourcen.

Berücksichtigt werden:

- maximale Umschlagsmengen,
- begrenzte Lagerkapazitäten,
- Anzahl verfügbarer Umschlagprozesse,
- begrenzte Infrastruktur.

Dadurch können Engpässe im Netzwerk entstehen.

3. Lieferdeadlines

Jede Sendung besitzt eine maximale Lieferzeit bzw. eine Deadline.

Das Modell muss sicherstellen, dass:

- Transportzeiten,
- Wartezeiten,
- und Umschlagszeiten

zusammen die vorgegebene Lieferfrist nicht überschreiten.

Dies beeinflusst insbesondere die Wahl langsamerer, aber günstigerer Verkehrsträger wie Schiff oder Bahn.

4. Transportzeiten

Jede Verbindung besitzt unterschiedliche Fahr- oder Transportzeiten.

Beispiele:

- LKW: schnelle regionale Transporte,
- Bahn: mittlere Transportzeiten,
- Schiff: lange Laufzeiten,
- Flugzeug: sehr kurze Laufzeiten.

Zusätzlich entstehen Zeitverluste durch:

- Umschläge,
- Wartezeiten,
- Terminalprozesse.

5. Umschlags- und Transferkosten

Beim Wechsel zwischen Verkehrsträgern entstehen zusätzliche Kosten.

Diese beinhalten:

- Be- und Entladung,
- Containerumschlag,
- Lagerkosten,
- administrative Prozesse.

Das Modell muss entscheiden, ob sich intermodale Transporte trotz zusätzlicher Umschlagskosten lohnen.

6. Emissionsrestriktionen

Ein Schwerpunkt des Projekts liegt auf nachhaltiger Logistikplanung.

Daher werden CO₂-Emissionen aller Transporte berücksichtigt.

Das Modell untersucht:

- emissionsarme Transportalternativen,
- Verlagerung auf Bahn und Schiff,
- Auswirkungen nachhaltiger Entscheidungen auf Kosten und Lieferzeiten.

Optional können maximale Emissionsgrenzen definiert werden.

7. Netzwerkkonnektivität

Nicht jeder Verkehrsträger steht an jedem Standort zur Verfügung.

Beispiele:

- Schienenanbindung nur an bestimmten Knoten,
- Häfen nur für Schiffstransporte,
- Flughäfen nur für Luftfracht,
- bestimmte Regionen nur per LKW erreichbar.

Dadurch entstehen realistische Einschränkungen im Netzwerk.

8. Konsolidierungsbedingungen

Mehrere Sendungen können gemeinsam transportiert werden.

Dabei müssen berücksichtigt werden:

- gemeinsame Kapazitäten,
- gleiche oder kompatible Routen,
- ähnliche Lieferzeiten,
- verfügbare Transportmittel.

Die Konsolidierung kann Kosten und Emissionen reduzieren, erhöht jedoch die Komplexität des Problems.

9. Multi-Objective-Konflikte

Das Projekt betrachtet mehrere Zielgrößen gleichzeitig.

Daraus entstehen Zielkonflikte zwischen:

- minimalen Kosten,
- kurzen Lieferzeiten,
- geringer Umweltbelastung.

Eine besonders nachhaltige Lösung ist häufig nicht die günstigste oder schnellste Alternative.

10. Skalierungsprobleme

Mit wachsender Netzwerkgröße steigt die Komplexität des Problems erheblich.

Besonders problematisch sind:

viele Knoten und Verbindungen,
- zahlreiche Sendungen,
- viele binäre Entscheidungsvariablen,
- intermodale Kombinationen,
- Kapazitätsrestriktionen.

Dadurch stoßen exakte Optimierungsverfahren bei großen Instanzen an ihre Grenzen.


== Problemstellung 
Problemstellung

Der globale Güterverkehr bildet die Grundlage moderner Lieferketten und ist ein zentraler Bestandteil internationaler Wirtschaftsprozesse. Unternehmen stehen heute vor der Herausforderung, Waren schnell, kosteneffizient und gleichzeitig möglichst nachhaltig zu transportieren. Durch zunehmende Globalisierung, steigende Kundenerwartungen hinsichtlich Lieferzeiten sowie strengere Umwelt- und Klimavorgaben wächst die Komplexität logistischer Entscheidungen erheblich.

Insbesondere multimodale Transportnetzwerke gewinnen zunehmend an Bedeutung. In solchen Netzwerken werden unterschiedliche Verkehrsträger wie LKW, Bahn, Schiff und Flugzeug kombiniert, um Transporte effizient durchzuführen. Jeder Verkehrsträger besitzt dabei spezifische Vor- und Nachteile hinsichtlich Kosten, Geschwindigkeit, Flexibilität, Kapazitäten und CO₂-Emissionen.

- LKW-Transporte ermöglichen eine hohe Flexibilität und direkte Zustellung, verursachen jedoch vergleichsweise hohe Emissionen und Transportkosten.
- Bahntransporte sind kosteneffizient und emissionsärmer, allerdings weniger flexibel und abhängig von vorhandener Infrastruktur.
- Schiffstransporte eignen sich besonders für große Mengen und internationale Transporte, sind jedoch deutlich langsamer.
- Flugzeugtransporte bieten die schnellsten Lieferzeiten, verursachen jedoch die höchsten Kosten und Emissionen.

Logistikunternehmen müssen daher täglich komplexe Entscheidungen treffen, um geeignete Transportstrategien auszuwählen. Dabei reicht die Wahl eines einzelnen Verkehrsträgers häufig nicht aus. Stattdessen entstehen intermodale Transportketten, bei denen mehrere Verkehrsträger kombiniert werden. Beispielsweise kann eine Sendung zunächst per LKW zu einem Terminal transportiert, anschließend per Bahn oder Schiff weitergeleitet und schließlich erneut per LKW zum Zielort gebracht werden.

Durch diese intermodalen Transporte entstehen zusätzliche Herausforderungen. Beim Wechsel zwischen Verkehrsträgern müssen Umschlagprozesse an Terminals durchgeführt werden, die zusätzliche Kosten, Wartezeiten und Kapazitätsbeschränkungen verursachen. Gleichzeitig müssen Lieferfristen eingehalten und vorhandene Transportkapazitäten effizient genutzt werden.

Die zentrale Problemstellung dieses Projekts besteht daher darin, ein multimodales Transportnetzwerk so zu planen, dass wirtschaftliche und ökologische Ziele gleichzeitig berücksichtigt werden. Das entwickelte Optimierungsmodell soll entscheiden:

- welche Routen verwendet werden,
- welche Verkehrsträger eingesetzt werden,
- wann ein Wechsel zwischen Verkehrsträgern sinnvoll ist,
- und wie mehrere Sendungen effizient konsolidiert werden können.

Dabei müssen zahlreiche Restriktionen und Nebenbedingungen berücksichtigt werden, um realistische und umsetzbare Transportpläne zu erzeugen.

== Zielsetzung 
Zielsetzung

Ziel des Projekts ist die Entwicklung eines realitätsnahen Entscheidungsmodells für nachhaltige multimodale Transportplanung. Das Modell soll Unternehmen dabei unterstützen, komplexe Transportentscheidungen wirtschaftlich und ökologisch sinnvoll zu treffen.

Im Mittelpunkt steht die Optimierung von Gütertransporten innerhalb eines multimodalen Netzwerks unter Berücksichtigung von:

Kosten,
- Lieferzeiten,
- CO₂-Emissionen,
- Kapazitäten,
- und Umschlagsprozessen.

Das Projekt verfolgt dabei mehrere fachliche, methodische und praktische Zielsetzungen.

Fachliche Zielsetzung

Ein wesentliches Ziel besteht in der Entwicklung eines mathematischen Optimierungsmodells für multimodale Gütertransporte.

Das Modell soll:

- optimale Transportwege bestimmen,
- geeignete Verkehrsträger auswählen,
- intermodale Transportketten planen,
- und Konsolidierungsmöglichkeiten identifizieren.

Dabei sollen sowohl wirtschaftliche als auch ökologische Kriterien berücksichtigt werden.

Zusätzlich soll untersucht werden:

- wann Bahn- oder Schiffstransporte wirtschaftlich sinnvoll sind,
- wann Luftfracht trotz hoher Kosten notwendig wird,
- und wie stark Emissionen durch alternative Transportstrategien reduziert werden können.

Methodische Zielsetzung

Das Projekt soll verschiedene Lösungsverfahren analysieren und vergleichen.

Hierzu gehören:

Exakte Optimierungsverfahren

Beispielsweise:

- Mixed Integer Programming (MIP),
- Netzwerkflussmodelle,
- Multi-Objective-Optimierung.

Diese Verfahren liefern optimale Lösungen, stoßen jedoch bei großen Instanzen an Laufzeitgrenzen.

Heuristische Verfahren

Zusätzlich sollen heuristische Ansätze entwickelt werden.

Ziele der Heuristiken:

- schnell gute Lösungen erzeugen,
- große Instanzen effizient bearbeiten,
- praktikable Transportpläne erzeugen.

Anschließend erfolgt ein direkter Vergleich zwischen:

- Solverlösungen,
- heuristischen Lösungen,
- Laufzeiten,
- Lösungsqualität,
- und Skalierbarkeit.

Praktische Zielsetzung

Das Projekt soll reale Entscheidungsprobleme moderner Logistikunternehmen abbilden.

Die Ergebnisse sollen als Entscheidungsunterstützung dienen, beispielsweise für:

- nachhaltige Transportstrategien,
- Verlagerung von Transporten auf Bahn oder Schiff,
- Investitionen in Umschlagterminals,
- Kapazitätsplanung,
- und Emissionsreduktion.

Das Modell soll zeigen, wie wirtschaftliche und nachhaltige Ziele gleichzeitig berücksichtigt werden können.

Wissenschaftliche Zielsetzung

Darüber hinaus verfolgt das Projekt wissenschaftliche Ziele im Bereich Operations Research und nachhaltige Logistik.

Untersucht werden insbesondere:

- Zielkonflikte zwischen Kosten und Nachhaltigkeit,
- Auswirkungen von Kapazitätsrestriktionen,
- Effekte intermodaler Transporte,
- sowie die Skalierbarkeit mathematischer Optimierungsverfahren.

Dadurch liefert das Projekt Erkenntnisse über die praktische Anwendbarkeit verschiedener Optimierungsansätze in komplexen Logistiknetzwerken.


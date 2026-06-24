= Einleitung <ch:introduction>
Diese Projektarbeit befasst sich mit der Entwicklung und Analyse eines Optimierungsmodells für multimodale Transportnetzwerke. Das Ziel ist die Planung von Gütertransporten unter gleichzeitiger Berücksichtigung von ökonomischen, zeitlichen und ökologischen Kriterien wie Kosten, Lieferzeiten und CO₂-Emissionen.

== Motivation und Relevanz
Der globale Güterverkehr ist das Rückgrat moderner Lieferketten und spielt eine zentrale Rolle in der globalen Wirtschaft. Die Fähigkeit, Waren schnell, kosteneffizient und zuverlässig zu transportieren, ist entscheidend für die Aufrechterhaltung internationaler Wirtschaftsprozesse und hat einen maßgeblichen Einfluss auf das moderne Leben. Gleichzeitig rückt der ökologische Fußabdruck des Transportsektors zunehmend in den Fokus. Angesichts des Klimawandels und strengerer Umweltvorgaben gewinnt die Forderung nach nachhaltigen Transportlösungen stetig an Bedeutung.

Logistikunternehmen stehen daher vor der Herausforderung, eine Balance zwischen ökonomischer Effizienz und ökologischer Verantwortung zu finden. Eine alleinige Fokussierung auf Nachhaltigkeit ist oft nicht praxistauglich, wenn dadurch Kosten oder Lieferzeiten inakzeptabel steigen. Moderne Transportnetzwerke sind hochgradig komplex und umfassen eine Vielzahl von Verkehrsträgern wie LKW, Bahn, Schiff und Flugzeug sowie diverse Umschlagpunkte wie Häfen, Terminals und Logistikzentren. Diese Komplexität eröffnet die Möglichkeit, durch eine intelligente Kombination verschiedener Verkehrsträger (multimodaler Verkehr) optimale Routen zu finden, die einen Kompromiss zwischen den konkurrierenden Zielen Kosten, Zeit und Emissionen ermöglichen.

== Problemstellung
Die zentrale Problemstellung dieser Arbeit besteht darin, für eine oder mehrere Sendungen die optimale Route durch ein multimodales Transportnetzwerk zu finden. Durch die Kombinationsmöglichkeiten verschiedener Verkehrsträger und Transitpunkte ergibt sich eine immense Anzahl potenzieller Transportketten. Die Herausforderung liegt darin, diejenige Route zu identifizieren, die eine gewichtete Zielfunktion aus Kosten, Zeit und CO₂-Emissionen minimiert.

Dabei müssen realitätsnahe Einschränkungen, sogenannte Constraints, berücksichtigt werden, die die Lösungsfindung maßgeblich beeinflussen:

- *Lieferfristen (Deadlines):* Für jede Sendung muss eine maximale Lieferzeit eingehalten werden, was die Wahl langsamerer, aber günstigerer Verkehrsträger einschränken kann.
- *Kapazitätsgrenzen:* Sowohl die Transportmittel (z.B. Ladekapazität eines LKW oder Zuges) als auch die Umschlagterminals (z.B. maximale Umschlagsmenge pro Tag) verfügen nur über begrenzte Kapazitäten.
- *Umschlagsprozesse:* Der Wechsel zwischen verschiedenen Verkehrsträgern an Terminals ist mit zusätzlichen Kosten, Zeitaufwänden und potenziellen Emissionen verbunden.
- *Netzwerkkonnektivität:* Nicht jeder Verkehrsträger ist an jedem Knotenpunkt des Netzwerks verfügbar. Beispielsweise sind Häfen nur für Schiffe und Flughäfen nur für Flugzeuge erreichbar.

== Zielsetzung der Arbeit
Das Hauptziel dieser Projektarbeit ist die mathematische Modellierung und die algorithmische Lösung des beschriebenen Problems der multimodalen Transportplanung. Es soll eine analytische und heuristische Untersuchung der Zielkonflikte zwischen Kosten, Zeit und CO₂-Emissionen stattfinden.

Daraus leiten sich folgende konkrete Teilziele ab:

- *Modellentwicklung:* Das Transportproblem wird als gemischt-ganzzahliges lineares Optimierungsmodell (MILP) formuliert. Dies schafft eine präzise mathematische Beschreibung der Entscheidungsvariablen, der Zielfunktion und der Nebenbedingungen.
- *Verfahrensvergleich:* Zur Lösung des Modells werden zwei unterschiedliche Ansätze implementiert und verglichen: ein exaktes Lösungsverfahren, das optimale Lösungen garantiert, und ein heuristisches Verfahren, das darauf abzielt, in kürzerer Zeit qualitativ hochwertige Näherungslösungen zu finden.
- *Evaluierung:* Die Leistungsfähigkeit und Skalierbarkeit beider Lösungsansätze werden systematisch anhand von Testinstanzen unterschiedlicher Größe und Komplexität bewertet. Ein besonderer Fokus liegt dabei auf der Analyse des Zielkonflikts zwischen den ökonomischen und ökologischen Zielen.

== Aufbau der Arbeit
Die Arbeit gliedert sich wie folgt: in @ch:problem-description wird das mathematische Modell formal definiert. @ch:implementation beschreibt die softwareseitige Umsetzung. Die experimentellen Ergebnisse werden in @ch:results präsentiert, gefolgt von einer kritischen Diskussion in @ch:discussion. Die Arbeit schließt mit einem Fazit und Ausblick in @ch:conclusion.


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


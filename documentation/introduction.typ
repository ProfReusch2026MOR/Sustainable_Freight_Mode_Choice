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
Die Arbeit gliedert sich wie folgt: @ch:theory erörtert die theoretischen Grundlagen des Netzwerkflusses und des Service Network Designs. In @ch:problem-description wird das multimodale Transportplanungsproblem detailliert beschrieben und abgegrenzt. @ch:modelling-and-optimization formalisiert anschließend das mathematische MILP-Modell sowie die heuristischen Lösungsverfahren. @ch:implementation beschreibt die softwareseitige Umsetzung. Die experimentellen Ergebnisse werden in @ch:results präsentiert, gefolgt von einer kritischen Diskussion in @ch:discussion. Die Arbeit schließt mit einem Fazit und Ausblick in @ch:conclusion.

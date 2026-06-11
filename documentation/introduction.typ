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
Die Arbeit gliedert sich wie folgt: @ch:literature gibt einen Überblick über den aktuellen Forschungsstand. In @ch:problem-description wird das mathematische Modell formal definiert. @ch:implementation beschreibt die softwareseitige Umsetzung. Die experimentellen Ergebnisse werden in @ch:results präsentiert, gefolgt von einer kritischen Diskussion in @ch:discussion. Die Arbeit schließt mit einem Fazit und Ausblick in @ch:conclusion.

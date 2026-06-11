= Numerische Ergebnisse & Evaluierung <ch:results>

== Experimentelles Setup
Die Rechenexperimente werden auf einem Standard-PC durchgeführt. Der PuLP-Solver (CBC) wird mit einem Standard-Zeitlimit (Time Limit) von 600 Sekunden konfiguriert. Die Heuristik läuft ohne Zeitbeschränkung, da ihre Ausführungszeiten typischerweise im Millisekundenbereich liegen.

== Instanzgrößen und Skalierungstest
Zur Evaluierung der Skalierbarkeit werden drei Szenarien getestet:
1. *Kleine Instanz:* 4 Hubs, 2 Sendungen, Planungshorizont von 48 Stunden.
2. *Mittlere Instanz:* Erweitertes nationales Netzwerk mit mehreren Umschlagterminals und ca. 20 Sendungen.
3. *Große Instanz:* Realistisches Netzwerk (z. B. unter Einbindung der CSV-Dateien aus Luft- und Straßennetzwerken) mit über 100 Sendungen und engmaschigen Zeitfenstern.

== Performanzvergleich (Solver vs. Heuristik)
Im Rahmen des Stress-Tests werden die beiden Lösungsverfahren bezüglich folgender Kriterien verglichen:
- *Zielfunktionswert (Lösungsqualität):* Wie groß ist der Optimality Gap der Heuristik im Vergleich zur exakten Optimierung des Solvers?
- *Rechenzeit (CPU-Time):* Ab welcher Instanzgröße benötigt der Solver mehr als 5 Minuten?
- *Zulässigkeit:* Findet die Heuristik auch dann noch zulässige Lösungen, wenn der Solver aufgrund von Speicher- oder Zeitlimits abbricht?

Die Ergebnisse werden tabellarisch gegenübergestellt:

#align(center)[
#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 10pt,
  align: center + horizon,
  [*Instanz*], [*Verfahren*], [*Status*], [*Laufzeit*], [*Zielfunktionswert*],
  [Klein], [Solver (CBC)], [Optimal], [< 1s], [1758.50 EUR / 123.88 kg CO₂],
  [], [Heuristik], [Zulässig], [< 0.1s], [...],
  [Mittel], [Solver (CBC)], [Optimal / Feasible], [...], [...],
  [], [Heuristik], [Zulässig], [< 0.5s], [...],
  [Groß], [Solver (CBC)], [Time Limit / Abbruch], [> 600s], [...],
  [], [Heuristik], [Zulässig], [< 2s], [...]
)
]

== Analyse des Kosten-Emissions-Zielkonflikts
Durch Variation der Gewichtungsfaktoren $w_c$ (Kosten) und $w_e$ (CO₂) lässt sich die Pareto-Front bestimmen. 
- Bei $w_c = 1, w_e = 0$ dominiert der günstige Straßentransport (LKW) bzw. Schiffstransport, was zu hohen Laufzeiten oder Emissionen führt.
- Bei $w_c = 0, w_e = 1$ wählt das Modell bevorzugt Bahn- und Schiffstransporte auf Hauptläufen und minimiert LKW-Fahrten, sofern die Deadlines dies zulassen.
- Flugzeuge werden nur dann eingesetzt, wenn extreme Zeitknappheit ($w_t = 1$ oder sehr kurze Deadlines) dies erzwingt.

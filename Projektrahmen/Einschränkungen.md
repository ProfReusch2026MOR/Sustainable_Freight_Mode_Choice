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

= Diskussion & Limitationen <ch:discussion>

== Interpretation der Ergebnisse und Entscheidungshilfe
Die Optimierungsergebnisse zeigen, dass die Moduswahl stark von Sendungsgewicht, Distanz und fixen Aktivierungskosten abhängt. In der kleinen Präsentationsinstanz bleibt der Straßentransport trotz variierter Kosten-Emissions-Gewichtung dominant. Im zusätzlichen schweren Langstrecken-Szenario wird dagegen ein klarer Modal Shift zur Schiene sichtbar, sobald Emissionen stärker gewichtet werden.

Für Logistikmanager bietet das Modell eine fundierte Entscheidungshilfe:
- Es zeigt auf, unter welchen Parametern sich ein Umstieg auf nachhaltigere Verkehrsträger wirtschaftlich oder ökologisch rechnet.
- Es identifiziert Kapazitätsengpässe an Terminalhubs, die den Fluss blockieren.

== Modell- und Datenlimitationen
Das aktuelle Optimierungsmodell beruht auf mehreren vereinfachenden Annahmen:
1. *Deterministische Daten:* Fahrzeiten, Umschlagzeiten und Kapazitäten werden als konstant angenommen. In der Realität führen Stau, Verspätungen und Wetter zu Unsicherheiten (Stochastik).
2. *Diskrete Zeitstruktur:* Die Modellierung in stündlichen Zeitschritten rundet Fahrzeiten auf. Für sehr kurze Strecken ist diese Granularität zu ungenau.
3. *Lineare Emissionsmodelle:* CO₂-Emissionen hängen in der Realität nicht-linear von der Fahrzeugauslastung, dem Streckenprofil (Steigungen) und der Geschwindigkeit ab.
4. *Begrenzte Rückwege:* Im aktuellen Datenmodell fehlen teilweise Rückrichtungen für Transportmittel, was die Umlaufplanung (Vehicle Scheduling) einschränkt.

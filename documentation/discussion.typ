= Diskussion & Limitationen <ch:discussion>

== Interpretation der Ergebnisse und Entscheidungshilfe
Die Optimierungsergebnisse zeigen deutliche Einsparpotenziale bei CO₂-Emissionen durch eine gezielte Verlagerung von Gütertransporten auf die Schiene. Intermodale Transporte (z. B. LKW-Bahn-LKW) lohnen sich vor allem auf Langstrecken, da die hohen Fixkosten und Zeitverluste beim Umschlag an den Hubs durch die niedrigen variablen Kosten und Emissionen der Bahn kompensiert werden.

Für Logistikmanager bietet das Modell eine fundierte Entscheidungshilfe:
- Es zeigt auf, ab welchen CO₂-Preisen sich ein Umstieg auf nachhaltigere Verkehrsträger wirtschaftlich rechnet.
- Es identifiziert Kapazitätsengpässe an Terminalhubs, die den Fluss blockieren.

== Modell- und Datenlimitationen
Das aktuelle Optimierungsmodell beruht auf mehreren vereinfachenden Annahmen:
1. *Deterministische Daten:* Fahrzeiten, Umschlagzeiten und Kapazitäten werden als konstant angenommen. In der Realität führen Stau, Verspätungen und Wetter zu Unsicherheiten (Stochastik).
2. *Diskrete Zeitstruktur:* Die Modellierung in stündlichen Zeitschritten rundet Fahrzeiten auf. Für sehr kurze Strecken ist diese Granularität zu ungenau.
3. *Lineare Emissionsmodelle:* CO₂-Emissionen hängen in der Realität nicht-linear von der Fahrzeugauslastung, dem Streckenprofil (Steigungen) und der Geschwindigkeit ab.
4. *Begrenzte Rückwege:* Im aktuellen Datenmodell fehlen teilweise Rückrichtungen für Transportmittel, was die Umlaufplanung (Vehicle Scheduling) einschränkt.

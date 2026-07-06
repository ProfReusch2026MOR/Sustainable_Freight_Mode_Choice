= Diskussion & Limitationen <ch:discussion>

== Interpretation der Ergebnisse und Entscheidungshilfe
Die Sensitivitätsanalyse (@sec:sensitivity) liefert für die Verkehrsmittelwahl mehrere robuste Kernaussagen. Erstens besteht zwischen *Kosten und Emissionen praktisch kein Zielkonflikt*: Im betrachteten Netzwerk ist die konsolidierte Seefracht zugleich der günstigste und der emissionsärmste Verkehrsträger, sodass sich das Kostengewicht ohne ökologischen Zielkonflikt erhöhen lässt. Der eigentliche Zielkonflikt verläuft zwischen *Geschwindigkeit und Nachhaltigkeit* -- erst ein hohes Zeitgewicht verschiebt den Modal Split drastisch zur emissions- und kostenintensiven Luftfracht.

Für Logistikmanager ergeben sich daraus konkrete Handlungshinweise:
- Zeitkritische Sendungen sollten gezielt und einzeln auf die Luftfracht gelegt werden, statt pauschal über ein hohes globales Zeitgewicht Volumen auf den teuersten Modus zu verlagern.
- Ein reiner CO₂-Preis bleibt wirkungslos, wo innerhalb der Lieferfrist keine emissionsärmere Alternative existiert; wirksamer sind längere Vorlaufzeiten und eine bessere multimodale Anbindung.
- Die empfohlene Lösung ist gegenüber $plus.minus 30 %$-Störungen der Kosten- und Emissionsfaktoren sowie moderaten Kapazitätsänderungen stabil; erst eine drastische Kapazitätsreduktion bricht Konsolidierung und Sendungsabdeckung ein.

== Genauigkeit der Heuristik und Einordnung des Optimality Gaps
Die in @sec:stress-test ausgewiesenen Gap-Werte bedürfen einer differenzierten Einordnung. Auf den zufälligen Instanzen des Sendungsanzahl-Sweeps zerfällt das Problem -- mangels Kapazitätskonkurrenz -- in unabhängige Kürzeste-Weg-Probleme, die die Heuristik exakt löst; der Gap liegt hier bei $approx 0 %$. Die bei $N=50$ und $N=55$ sichtbaren $7$--$9 %$ sind kein echtes Qualitätsdefizit, sondern ein *Normalisierungsartefakt*, da MILP und Heuristik ihre analytischen Normierungsgrenzen unabhängig voneinander pro Lauf schätzen (vgl. @sec:normalization). Ein *echter* Optimality Gap tritt hingegen unter gezieltem Konsolidierungsdruck auf (@sec:consolidation-gap): Sobald sich viele Sendungen dieselbe knappe Fahrzeugkapazität teilen, bleibt die greedy Einfügung um bis zu $approx 4 %$ hinter dem beweisbaren Optimum zurück -- nachweislich als echte Verschlechterung in Kosten, Emissionen und Zeit zugleich, die auch die LNS-Nachoptimierung nicht vollständig schließt. Die Heuristik ist somit *kein* exaktes Verfahren; ihre praktische Verlustfreiheit gilt für kapazitäts-unkritische Instanzen, während unter starker Bündelungskonkurrenz der exakte Solver die bessere Lösung liefert.

== Modell- und Datenlimitationen
Das aktuelle Optimierungsmodell beruht auf mehreren vereinfachenden Annahmen:
1. *Deterministische Daten:* Fahrzeiten, Umschlagzeiten und Kapazitäten werden als konstant angenommen. In der Realität führen Stau, Verspätungen und Wetter zu Unsicherheiten (Stochastik).
2. *Fahrplangebundene Ereigniszeiten:* Abfahrten und Fahrtdauern werden minutengenau aus festen Fahrplänen abgeleitet. Kontinuierliche Zeitdynamiken (z. B. lastabhängige Fahrzeiten oder frei wählbare Abfahrtszeitpunkte) werden dadurch abstrahiert.
3. *Lineare Emissionsmodelle:* CO₂-Emissionen hängen in der Realität nicht-linear von der Fahrzeugauslastung, dem Streckenprofil (Steigungen) und der Geschwindigkeit ab.
4. *Begrenzte Rückwege:* Im aktuellen Datenmodell fehlen teilweise Rückrichtungen für Transportmittel, was die Umlaufplanung (Vehicle Scheduling) einschränkt.
5. *Begrenzte experimentelle Abdeckung:* Die Auswertungen beruhen auf deterministischen Teilnetzen -- dem Stresstest bis 55 Sendungen bzw. 5 Planungstagen, der Sensitivitätsanalyse mit 30 Sendungen sowie dem Heuristikvergleich bis 100 Sendungen. Sie zeigen das Modellverhalten in reproduzierbaren Szenarien, erlauben aber keine allgemeine Aussage über die Wirksamkeit eines Modal Shifts in realen, stochastischen Gesamtnetzen.

= Fazit & Ausblick <ch:conclusion>

== Zusammenfassung der Erkenntnisse und Beiträge der Arbeit
Im Rahmen dieser Projektarbeit wurde ein Operations-Research-Modell zur nachhaltigen multimodalen Transportplanung erfolgreich konzipiert, implementiert und evaluiert. Die Arbeit liefert wesentliche methodische, softwaretechnische und praktische Beiträge zur Lösung komplexer logistischer Fragestellungen unter Berücksichtigung ökonomischer und ökologischer Kriterien:

- *Mathematische Modellierung und Graphenexpansion:* Durch die Formulierung des Planungsproblems als gemischt-ganzzahliges lineares Programm (MILP) auf einem ereignisbasierten, zeitexpandierten Netzwerk wurde eine präzise mathematische Abbildung von Umschlagprozessen, fahrplangebundenen Transportmitteln und Wartezeiten realisiert. Ein besonders positiver Aspekt ist dabei der ereignisbasierte Ansatz zur Graphengenerierung. Anstelle einer starren Zeitdiskretisierung verhinderte dieser eine kombinatorische Explosion der Knotenzahlen und ermöglichte eine minutengenaue Modellierung komplexer Prozesse bei moderatem Speicher- und Rechenzeitbedarf.
- *Entwicklung performanter Metaheuristiken:* Da die exakte Lösung über den solver-basierten Ansatz bei größeren Instanzen an Skalierungsgrenzen stößt, wurde eine maßgeschneiderte Heuristiken-Familie entwickelt. Die Kombination aus einer A\*-basierten Suche für Einzelsendungen, einer sequenziellen Multi-Sendungs-Planung und einer Large Neighborhood Search (LNS) zur kapazitativen Reorganisation stellt einen leistungsfähigen Beitrag dar. Die LNS-Metaheuristik erwies sich in der Umsetzung als äußerst effektiv, da sie kapazitative Engpässe des Netzwerks effizient auflöst und auch bei großen Instanzen qualitativ hochwertige Näherungslösungen in Sekundenbruchteilen berechnet.
- *Nachhaltigkeitsorientierte Entscheidungsunterstützung:* Durch eine flexibel parametrisierbare Zielfunktion wurde ein fundiertes Werkzeug geschaffen, das die Zielkonflikte zwischen Transportkosten, Lieferzeiten und CO₂-Emissionen quantifizierbar macht. Es zeigt systematisch auf, unter welchen ökonomischen Rahmenbedingungen (wie beispielsweise CO₂-Bepreisung) ein ökologisch vorteilhafter Modal Shift auf Schiene oder Wasserstraße realisiert werden kann.

== Umsetzung der Anforderungen des Moduls
Die im Rahmen des Moduls *Operations Research* gestellten wissenschaftlichen und methodischen Voraussetzungen wurden in der Arbeit konsequent und erfolgreich umgesetzt:
- *Dualer Lösungsansatz:* Das Problem wurde sowohl durch einen exakten solver-basierten Ansatz (MILP via Python PuLP und dem HiGHS-Solver) als auch durch selbst entwickelte Heuristiken (A\*-Algorithmus und LNS-Metaheuristik) gelöst. Die gesamte Implementierung zeichnet sich durch ein hohes Software-Engineering-Niveau aus: Die klare, modulare Trennung zwischen Datenverwaltung (`dataset`), Graphenexpansion (`freight_routing`) und Lösungsalgorithmen (`heuristics`) garantiert eine hohe Wartbarkeit und leichte Erweiterbarkeit des Codes.
- *Solver-Stress-Test und Skalierungsanalyse:* In systematischen Skalierungstests (Stress-Tests) wurden die Rechenlaufzeiten und die Qualität der Heuristiken im Vergleich zur exakten mathematischen Optimierung detailliert analysiert. Dadurch konnten die Grenzen der exakten Lösbarkeit und die Performanzgewinne der Heuristiken wissenschaftlich fundiert gegenübergestellt werden.
- *Datenbasierte Validierung:* Zur Absicherung der Ergebnisse wurde das Modell sowohl mit synthetischen Skalierungsinstanzen als auch mit realitätsnahen Geodaten (Distanzmatrizen, Hub-Koordinaten und realen Transportgeschwindigkeiten) evaluiert.

== Ausblick
Für zukünftige Forschungs- und Entwicklungsschritte bieten sich folgende Erweiterungen an, um das Modell noch praxisnäher zu gestalten:
- *Stochastik und Unsicherheit:* Die Integration stochastischer Fahr- und Umschlagzeiten zur Modellierung von Verkehrsverzögerungen, Streiks oder wetterbedingten Ausfällen, um robustere Transportpläne zu erzeugen.
- *Elektrifizierung und alternative Antriebe:* Die Berücksichtigung von Reichweitenbeschränkungen und Ladezeiten für Batterie-elektrische Lkw (BEV) sowie Wasserstoff-Fahrzeuge im zeitexpandierten Netzwerk.
- *Dynamisches Re-Routing:* Die Entwicklung echtzeitfähiger Algorithmen, die bei Störungen während des Transports dynamisch alternative Routen vorschlagen.
- *Saisonale und tageszeitliche Schwankungen:* Einbindung tageszeitspezifischer Mautgebühren, Wochenendfahrverbote und zeitvariabler Verkehrsbelastungen (Congestion Pricing).

== Aufgabenverteilung und individuelle Beiträge
Zur Herstellung von Transparenz über die individuellen Beiträge im Rahmen des Projekts sind die tatsächlichen Hauptaufgabenbereiche der Teammitglieder auf Basis der Repository-Commit-Historie in der folgenden Tabelle zusammengefasst:

#table(
  columns: (1.5fr, 4fr),
  inset: 8pt,
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { luma(230) } else { none },
  [*Teammitglied (Git-Author)*], [*Tatsächliche Beiträge (Repository-Historie)*],
  [Benedikt Wehner \ (`bennetwehn`)], [
    - *MILP-Modell & Solver-Implementierung:* Formulierung des mathematischen Modells auf dem zeitexpandierten Netzwerk und Implementierung des exakten Solvers (PuLP/HiGHS) inkl. Normalisierung der Zielfunktion und Infeasibility-Diagnose.
    - *Software-Engineering:* Erstellung des Dockerfiles, CI/CD-Pipelines (GitHub Actions) sowie des interaktiven Web-Dashboards.
    - *Dokumentation:* Schreiben der Mathematischen Definition, Solver-Beschreibung, Web-Dashboards, Diskussion, Literaturrecherche.https://github.com/Sam18069272581
  ],
  [Phil Kahlert \ (`Phil-kl`)], [
    - *Heuristik-Optimierung:* Konzeption und Implementierung des $A^*$-Routers, Optimierung des Suchraums (Pruning-Strategien, bedarfsgesteuerte APSP-Vorberechnung) und Performanz-Tuning.
    - *Experimente & Analyse:* Erstellung und Ausführung von Skalierungs- Performanz-Notebooks, sowie fertigstellung der Sensitivitätsanalyse.
    - *MILP-Modell:* Mitentwicklung erster Ideen zur Solver Modellierung
    - *Datensammlung:* Implementierung der automatisierten Extraktion von Geodaten und daraus resultierendem Datensatzaufbau. 
    - *Dokumentation:* Schreiben der Einleitung und Problemstellung (Klarheit, Struktur), Heuristik-Beschreibung, Fazit, Datensammlung.
  ],
  [Luis Kruse \ (`lkruse301`)], [
    - *Frühe Heuristiken:* Erste prototypische Entwürfe und Implementierung einer Tabu-Search- und Dijkstra-Heuristik (im historischen Ordner `Heuristic/`).
    - *Datenvorbereitung:* Erste Entwürfe von Straßen- und Luftfrachtverbindungen als CSV-Dateien.
  ],
  [Laurens Rüther \ (`LaurensRuether`)], [
    - *Datensammlung:* Händische Extraktion von ersten Geodaten, Erarbeiten von realen kosten.  
    - *Projektkoordination:* Pflege des Fortschrittsberichts (`Fortschritt Begleitung.md`), und anlegen der README.md.
  ],
  [Minglu Li \ (`Sam18069272581`)], [
    - *Analysen:* Entwurf der Sensitivitätsanalyse (Modal Shift Profile).
    - *Dokumentation:* Schreiben eines ersten Entwurfs der Analyse und Diskussion
  ]
)  
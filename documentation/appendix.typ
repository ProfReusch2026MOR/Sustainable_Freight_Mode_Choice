// appendix.typ — author your appendix here and render it from your main file
// Edit the `appendix-content` function below. In your main file, just import
// `appendix` and call it with parameters (no content argument needed):
//   #import "appendix.typ": appendix
//   ...
//   #appendix(title: "Supplementary Material", break: true, numbered: false)

// --- Write your appendix content here -------------------------------------
#let appendix-content = {
  [
    = Benchmark-Setup <sec:benchmark-setup>
    Sämtliche in dieser Arbeit berichteten Laufzeitmessungen wurden auf ein und demselben Laptop mit identischer Hard- und Softwarekonfiguration ausgeführt, um die Vergleichbarkeit der gemessenen Werte sicherzustellen. @tab:benchmark-setup fasst die verwendete Umgebung zusammen.

    #figure(
      table(
        columns: (auto, 1fr),
        align: (left, left),
        stroke: 0.5pt,
        [*Komponente*], [*Spezifikation*],
        [Gerät], [Laptop],
        [Prozessor], [Intel Core i7-11800H (11. Generation, 8 Kerne / 16 Threads, Basistakt 2,30 GHz)],
        [Arbeitsspeicher], [32 GB RAM],
        [Betriebssystem], [Arch Linux (Rolling Release), Kernel 7.0.14-arch1-1],
        [Python-Version], [3.14.6],
        [MILP-Solver], [HiGHS 1.13.0 (via `highspy`)],
        [Ausführung], [Einzelprozess, sequentiell ohne Parallelisierung der Benchmarkläufe],
        [Zeitmessung], [Wall-Clock-Zeit mittels Python `time.time()`],
      ),
      caption: [Hard- und Softwarekonfiguration des Benchmark-Systems],
    ) <tab:benchmark-setup>

    = Softwareverzeichnis <sec:software-directory>
    @tab:software-directory listet die im Rahmen dieses Projekts eingesetzten Software­komponenten, Frameworks und Bibliotheken mit den verwendeten Versionsständen auf.

    #figure(
      table(
        columns: (auto, auto, 1fr),
        align: (left, left, left),
        stroke: 0.5pt,
        [*Software*], [*Version*], [*Verwendungszweck*],
        [Python], [3.14.6], [Implementierungssprache für Solver, Heuristiken und Datenbeschaffung],
        [PuLP], [3.3.2], [MILP-Modellierungs-Framework],
        [HiGHS (`highspy`)], [1.13.0], [MILP-Solver-Backend],
        [NumPy], [2.4.6], [Numerische Berechnungen],
        [pandas], [3.0.3], [Verarbeitung und Aufbereitung der Rohdaten],
        [geopy], [2.4.1], [Geodätische Distanzberechnung],
        [folium], [0.20.0], [Interaktive Kartendarstellung (Python)],
        [msgspec], [0.21.1], [Performante Serialisierung des Netzwerkdatensatzes],
        [python-dotenv], [1.2.2], [Verwaltung von Umgebungsvariablen (z.B. API-Schlüssel)],
        [tqdm], [4.68.3], [Fortschrittsanzeigen bei der Datenverarbeitung],
        [seaborn], [0.13.2], [Statistische Visualisierung der Benchmark-Auswertung],
        [matplotlib], [3.11.0], [Erstellung der Benchmark-Diagramme],
        [Leaflet.js], [1.9.4], [Interaktive Kartendarstellung im Web-Dashboard OptiFreight],
        [Lucide], [0.511.0], [Icon-Bibliothek im Web-Dashboard],
        [Typst], [0.15.0], [Textsatzsystem zur Erstellung dieser Arbeit],
      ),
      caption: [Softwareverzeichnis: In diesem Projekt eingesetzte Software und Bibliotheken],
    ) <tab:software-directory>

    = Aufgabenverteilung und individuelle Beiträge <sec:contributions>

    #table(
      columns: (1.5fr, 4fr),
      inset: 8pt,
      stroke: 0.5pt + luma(150),
      fill: (x, y) => if y == 0 { luma(230) } else { none },
      [*Teammitglied (Git-Author)*], [*Tatsächliche Beiträge (Repository-Historie)*],
      [Benedikt Wehner \ (`bennetwehn`)],
      [
        - *MILP-Modell & Solver-Implementierung:* Formulierung des mathematischen Modells auf dem zeitexpandierten Netzwerk und Implementierung des exakten Solvers (PuLP/HiGHS) inkl. Normalisierung der Zielfunktion und Infeasibility-Diagnose.
        - *Software-Engineering:* Erstellung des Dockerfiles, CI/CD-Pipelines (GitHub Actions) sowie des interaktiven Web-Dashboards.
        - *Dokumentation:* Schreiben der Mathematischen Definition, Solver-Beschreibung, Web-Dashboards, Diskussion, Literaturrecherche.
      ],

      [Phil Kahlert \ (`Phil-kl`)],
      [
        - *Heuristik-Optimierung:* Konzeption und Implementierung des $A^*$-Routers, Optimierung des Suchraums (Pruning-Strategien, bedarfsgesteuerte APSP-Vorberechnung) und Performanz-Tuning.
        - *Experimente & Analyse:* Erstellung und Ausführung von Skalierungs- Performanz-Notebooks, sowie fertigstellung der Sensitivitätsanalyse.
        - *MILP-Modell:* Mitentwicklung erster Ideen zur Solver Modellierung
        - *Datensammlung:* Implementierung der automatisierten Extraktion von Geodaten und daraus resultierendem Datensatzaufbau.
        - *Dokumentation:* Schreiben der Einleitung und Problemstellung (Klarheit, Struktur), Heuristik-Beschreibung, Fazit, Datensammlung.
      ],

      [Luis Kruse \ (`lkruse301`)],
      [
        - *Problemstellung und Zielsetzung:* Anlegen der konkreten Problemstellung und Zielsetzung.
        - *Recherche nach geeigneten heuristischen Lösungsansätzen:* Informatiosnaufnahme von passenden heuristischen Lösungsverfahren im Bezug auf das Kernproblem.
        - *Entwicklung heuristischer Ansätze:*  Entwürfe und Implementierung einer Tabu-Search- und Dijkstra-Heuristik. Vergleich und Funktionsanalyse der Heuristiken.
        - *Datenrecherche:* Recherche nach geeigneten Datensätzen und Datenmodellen.
        - *Datenvorbereitung:* Erste Entwürfe von Straßen-, Bahn-, Schiff- und  Luftfrachtverbindungen als CSV-Dateien.
        - *Dokumentation:* Erste Entwürfe einer theoretischen Ausarbeitung des heuristischen Lösungsverfahrens.
      ],

      [Laurens Rüther \ (`LaurensRuether`)],
      [
        - *Datensammlung:* Händische Extraktion von ersten Geodaten, Erarbeiten von realen kosten.
        - *Projektkoordination:* Pflege des Fortschrittsberichts (`Fortschritt Begleitung.md`), und anlegen der README.md.
      ],

      [Minglu Li \ (`Sam18069272581`)],
      [
        - *Analysen:* Entwurf der Sensitivitätsanalyse (Modal Shift Profile).
        - *Dokumentation:* Schreiben eines ersten Entwurfs der Analyse und Diskussion
      ],
    )
  ]
}


// --- Utility ---------------------------------------------------------------
#let _to-content(x) = if type(x) == function { x() } else { x }
#let unary(.., last) = {
  numbering("A", last)
}

// Inserts an appendix section. If `content` is omitted (auto), uses the
// content you authored above in `appendix-content`.
#let appendix(
  title: "Appendix",
  numbering: "A",
  outlined: true,
) = {
  let body = _to-content(appendix-content)
  counter(heading).update(0)
  set heading(numbering: unary, offset: 1)
  body
}


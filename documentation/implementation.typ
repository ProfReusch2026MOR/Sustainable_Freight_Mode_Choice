= Implementierung & Lösungsansätze <ch:implementation>

== Datengrundlage und Datenmodell
Die Struktur der Eingabedaten lehnt sich an reale logistische Netzwerke an. Es wird eine Netzwerkinfrastruktur mit vier großen deutschen Hubs (Berlin, Hamburg, Frankfurt, München) abgebildet. Jede Transportkante besitzt einen täglichen Abfahrtsfahrplan. 

Das Datenmodell umfasst:
- *Hubs:* Spezifizieren die unterstützten Modi und die zeitlichen Transferfenster für den Wechsel zwischen Modi (z. B. Umladen von Schiene auf Straße in Berlin).
- *Verbindungen (Arc Templates):* Enthalten Start- und Zielort, Distanz, Modus und die täglichen Abfahrtszeiten.
- *Kosten- und Emissionsfaktoren:* Verkehrsträgerspezifische Faktoren je Tonnenkilometer ($t$-km) sowie feste Handlingkosten pro Umschlag.

Für größere Instanzen werden die Daten aus CSV-Dateien (`road_arcs.csv`, `air_arcs.csv`, `sea_routes_updated_18kts.csv` etc.) eingelesen, was eine flexible Skalierung des Netzwerks ermöglicht.

== Exakte Lösung mit Python PuLP
Das in @ch:problem-description formulierte gemischt-ganzzahlige Optimierungsproblem wird in Python mit dem Modellierungs-Framework *PuLP* implementiert. Die Kantenvariablen $x_(a,k)$ sowie die Bündelungsvariablen $y_a$ und $z_a$ werden als `LpBinary` bzw. `LpInteger` deklariert.
Als zugrundeliegender Solver wird der COIN-OR Branch-and-Cut Solver (*CBC*) verwendet. Der Solver durchsucht den Lösungsraum systematisch mittels Branch-and-Bound und Schnittebenenverfahren (Cutting Planes), um globale Optimalität nachzuweisen.

== Heuristische Lösung (Multimodaler Dijkstra-Algorithmus)
Da die exakte Lösung für große Netzwerke mit vielen Sendungen rechenintensiv wird, wurde eine Dijkstra-basierte Konstruktionsheuristik in Python entworfen:
1. *Graph-Repräsentation:* Das zeitexpandierte Netzwerk wird als Adjazenzliste aufgebaut, bei der jeder Knoten dem Zustand `Hub_Modus_Zeit` entspricht.
2. *Zustandssuche:* Ein Prioritätswarteschlangen-basierter Suchalgorithmus (Dijkstra unter Verwendung von `heapq`) findet den kürzesten Pfad.
3. *Bewertungsfunktion:* Die Kantengewichte im Graphen entsprechen dem normalisierten Score:
   $ S_a = w_c (c_a / C_("max")) + w_t (tau_a / T_("max")) + w_e (e_a / E_("max")) $
4. *Restriktionsprüfung:* Während der Pfadsuche werden Deadlines und Budgetgrenzen an jedem Zwischenknoten geprüft. Pfade, die diese verletzen, werden sofort verworfen (Pruning).

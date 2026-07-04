= Problembeschreibung  <ch:problem-description>
1. Die zentrale Entscheidungsfrage
  -  Fragestellung: Wie können mehrere Sendungen in einem multimodalen Transportnetzwerk so geplant und geroutet werden, dass Transportkosten, Transportzeiten und CO₂-Emissionen minimiert werden?
  -  Rahmenbedingungen: Einhaltung von Lieferfristen (Deadlines), Fahrzeug-/Netzwerkkapazitäten und Umschlagsprozessen an Terminals.                                      

2. Das multimodale Transportnetzwerk 
  - Das Netzwerk besteht aus verschiedenen physischen Knoten und Kanten, die durch vier Verkehrsträger abgedeckt werden:                                                   
  - LKW (Straßentransport): Flexibel, mittlere Kapazität, hohe CO₂-Emissionen (ideal für Erst-/Letztmeile).                                                              
  - Bahn (Schienentransport): Kosteneffizient, geringe Emissionen, hohe Kapazität, aber längere Transportzeiten.                                                         
  - Schiff (Wasserweg): Sehr günstige Kosten, extrem hohe Kapazität, aber sehr langsam (ideal für internationale Langstrecken).                                          
  - Flugzeug (Luftfracht): Sehr schnell für zeitkritische Lieferungen, aber extrem teuer und hohe CO₂-Emissionen bei geringer Kapazität.                                 
  - Umschlagterminals (Hubs): Knotenpunkte (Flughäfen, Häfen, Bahnhöfe), an denen Wechsel zwischen Verkehrsträgern stattfinden (inklusive Transferzeiten und             
  Transferkosten).                                                                                                                                                       
                                                                                                                                                                         
3. Die Entscheidungen des Modells (Entscheidungsvariablen)                                                                                                         
  Das Optimierungsmodell muss für jede Sendung folgendes festlegen:                                                                                                      
  - Routenwahl: Welcher konkrete Pfad vom Start-Hub zum Ziel-Hub gewählt wird.                                                                                           
  - Moduswahl: Welche Verkehrsträger (LKW, Bahn, Schiff, Flugzeug) auf den Teilstrecken verwendet werden.                                                                
  - Intermodalität: Wann und an welchen Hubs ein Wechsel des Verkehrsträgers (Umschlag) stattfindet.                                                                     
  - Konsolidierung: Wann Lieferungen auf Teilstrecken zusammengelegt (gebündelt) werden können, um Fixkosten für Fahrzeuge aufzuteilen und Auslastungen zu optimieren.   
                                                                                                                                                                         
4. Die Zielfunktion (Optimierungsziele)                                                                                                                            
  Es handelt sich um ein multikriterielles Optimierungsproblem (Multi-Objective), bei dem ein gewichteter Score aus folgenden Komponenten minimiert wird:                
  - Transportkosten: Variable Frachtkosten (nach Gewicht) + feste Bereitstellungskosten für Fahrzeuge.                                                                   
  - Umschlagskosten: Kosten für das Umladen an den Terminals.                                                                                                            
  - CO₂-Emissionen: Variable Emissionen (pro Tonnenkilometer) + feste Bereitstellungsemissionen.                                                                         
  - Transportzeit: Gesamte Transit- und Wartezeit.                                                                                                                       
                                                                                                                                                                         
5. Nebenbedingungen (Constraints)                                                                                                                                  
                                                                                                                                                                         
  - Flusserhalt (Flow Conservation): Sendungen müssen lückenlos vom Ursprung zum Ziel fließen.                                                                           
  - Kapazitätsgrenzen: Die Summe aller Sendungsgewichte auf einer Kante darf die maximale Kapazität der eingesetzten Fahrzeuge nicht überschreiten.                      
  - Lieferfristen (Deadlines): Jede Sendung muss vor ihrer individuellen Deadline am Zielort eintreffen.                                                                 
  - Moduswechselregeln: Ein Moduswechsel ist nur an dafür qualifizierten Hubs (z. B. Hafen für Schiffe, Flughafen für Flugzeuge) unter Berücksichtigung von              
  Transferzeiten zulässig.                                                                                                                                               
                                                                                                                                                                         
6. Heuristische Motivation (Projektfokus)                                                                                                                          
  
  - Während kleine bis mittlere Instanzen mit exakten Solvern (z. B. PuLP, OR-Tools) gelöst werden können, führt das zeitexpandierte Netzwerk bei großen Instanzen (z. B.
  50.000 Sendungen über 30 Tage) zu einer kombinatorischen Explosion (Zahl der Arcs wächst massiv).
  - Aus diesem Grund werden heuristische Verfahren (wie euer optimierter Dijkstra- und A\*
  -Router in Kombination mit Local-Search-Verfahren) entwickelt, um in sehr kurzer Laufzeit (Minuten statt Stunden) mathematisch nahe an das Optimum heranzureichen.

  Final lässt sich das Entscheidungsproblem wie folgt formulieren: 
  Welche exakten Routen und Transportmittel (Straße, Schiene, Luft) sollten für eine gegebene Menge an Sendungen gewählt werden, um eine gewichtete Kombination aus Transportkosten (inklusive Kapazitäts-Fixkosten) und CO₂-Emissionen zu minimieren, während gleichzeitig Flottenkapazitäten, zeitaufwändige Terminal-Prozesse, Lieferfristen und frachtspezifische Transportverbote eingehalten werden?
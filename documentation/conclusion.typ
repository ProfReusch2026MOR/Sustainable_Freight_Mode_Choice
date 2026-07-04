= Fazit & Ausblick <ch:conclusion>

== Zusammenfassung der Erkenntnisse
Im Rahmen dieser Projektarbeit wurde ein Operations-Research-Modell zur nachhaltigen multimodalen Transportplanung entwickelt. Es konnte erfolgreich gezeigt werden, dass gemischt-ganzzahlige lineare Modelle (MILP) in Kombination mit zeitexpandierten Netzwerken in der Lage sind, komplexe Trade-offs zwischen Kosten, Emissionen und Lieferdeadlines exakt zu optimieren. 

Der direkte Vergleich zeigt, dass der exakte Solver HiGHS für kleine bis mittlere Instanzen hervorragende, global optimale Ergebnisse liefert. Für den Praxiseinsatz bei sehr großen Netzwerken bietet die entwickelte Dijkstra-basierte Heuristik jedoch eine performante Alternative, da sie gute Lösungen in Sekundenbruchteilen berechnet.

== Ausblick  
Um das Modell praxisnäher zu gestalten, bieten sich folgende Erweiterungen an:
- *Alternative Antriebe:* Einbindung von Elektro-LKWs mit Ladeinfrastruktur- und Batteriekapazitätsbeschränkungen.
- *Dynamisches Routing:* Echtzeit-Anpassung der Routen bei Störungen während des Transports.
- *Sesionale Unterschiede*  
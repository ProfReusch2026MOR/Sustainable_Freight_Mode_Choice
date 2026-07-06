= Diskussion & Limitationen <ch:discussion>

Dieses Kapitel benennt die Grenzen des Modells, der Lösungsverfahren und
der Datengrundlage. Drei Leitfragen stehen im Mittelpunkt: Welche
realweltlichen Faktoren fehlen? Wie könnten sie die Empfehlung verändern?
Und wann sollte der Empfehlung _nicht_ vertraut werden?

== Modellannahmen und Vereinfachungen <sec:model-assumptions>

*Determinismus.* Alle Parameter -- Fahrzeiten, Umschlagdauern, Kosten- und
Emissionsfaktoren -- gelten als im Voraus bekannt. Reale Schwankungen
(Wetter, Streiks, Hafenstaus) können Transportzeiten um Stunden bis Tage
verschieben. Die Ergebnisse sind daher _Soll-Planungen_ für den
Normalbetrieb; für störungsanfällige Korridore sollten Sicherheitspuffer
bei Lieferfristen eingeplant werden.

*Statisches Netzwerk.* Das Netzwerk wird einmalig aufgebaut und bleibt
über den Planungshorizont unverändert. Ein dynamisches Re-Routing bei
Störungen ist nicht vorgesehen -- besonders relevant bei langen Horizonten
(mehrere Wochen), wo Netzwerkänderungen wahrscheinlicher werden.

*Vernachlässigte Kosten.* Nicht abgebildet sind u. a. mengenbezogene
Lagergebühren an Hubs, Zölle und Hafengebühren bei interkontinentalem
Transport sowie vertragliche Konventionalstrafen. Würden diese modelliert,
könnte der in @sec:sensitivity-weights gezeigte Befund -- dass Kosten und
Emissionen kaum konfligieren -- kippen, da Seefracht mit Hafengebühren und
Zöllen nicht mehr zwingend die günstigste Option wäre.

== Skalierbarkeit und Rechengrenzen <sec:scalability-discussion>

*Exakter Solver.* Die Stresstests (@sec:stress-test) zeigen, dass HiGHS
bei wachsender Instanzgröße an seine Grenzen stößt. Die binären
Routingvariablen erreichen auf
dem großen Netzwerk bereits 4,3 Mio. Die Lösungszeit hängt zudem von der
konkreten Instanzstruktur ab, was sich in der nicht-monotonen
Laufzeitkurve (@tab:stress-shipments) zeigt. Für operative Szenarien
(Hunderte Sendungen, wochenlange Horizonte) ist der exakte Solver _nicht
praktikabel_.

*Heuristik.* Die A\*-Heuristik mit LNS bleibt stets unter 1,2 Sekunden,
hat aber strukturelle Grenzen: Die feste Sortierreihenfolge (absteigend
nach Gewicht) beeinflusst die Lösung erheblich, und LNS schließt den Gap
bei kapazitätskritischen Instanzen kaum, da Ruin-and-Recreate auf
demselben greedy Mechanismus beruht. Der Optimality Gap beträgt dort bis
zu 4 % mit real höheren Kosten, Emissionen und Lieferzeiten
(@sec:consolidation-gap).


== Normalisierung <sec:normalization-discussion>

Die analytische Min-Max-Skalierung (@sec:normalization) ist
rechenzeiteffizient, bringt aber eine Einschränkungen mit sich.
Die Normalisierungsbereiche $Delta C_k$, $Delta T_k$, $Delta E_k$ hängen
vom heuristisch gewählten Umwegfaktor $beta = 3$ ab -- liegt die optimale
Route deutlich außerhalb der Schätzgrenzen, kann ein Zielkriterium
unbeabsichtigt über- oder untergewichtet werden.

== Limitationen der Datengrundlage <sec:data-limitations>

*Netzwerktopologie.* Beide Netzwerke (handkuratiert bzw. aus Geodaten
generiert, vgl. @sec:data-collection) repräsentieren nicht die operative
Realität eines bestimmten Logistikdienstleisters. Fahrplanannahmen und
Kapazitätswerte sind vereinfachte Schätzungen; in einem realen Einsatz
würden sie aus operativen Systemen stammen und nach Strecke, Tageszeit
und Saison variieren.

*Sendungserzeugung.* Die Sendungen werden per Zufallsverfahren mit festem
Seed erzeugt. In der Praxis konzentrieren sich Güterströme auf bestimmte
Korridore (z. B. Asien--Europa) und folgen saisonalen Mustern. Die
gleichmäßige Streuung kann Engpässe auf Hauptkorridoren unterschätzen.

*Emissionsfaktoren.* Die globalen Durchschnittswerte (kg CO₂/tkm)
differenzieren nicht nach Antriebstechnologie oder Auslastungsgrad. Ein
LNG-Frachter emittiert deutlich weniger als ein Schweröl-Schiff; ein
elektrischer Güterzug nahezu null. Die pauschale Zuordnung kann den
Emissionsvorteil einzelner Modi systematisch verzerren.

== Fehlende realweltliche Faktoren <sec:missing-factors>

*Regulierung.* Nicht modelliert sind innerstädtische Fahrverbote,
länderspezifische Mautsysteme (z. B. deutsche LKW-Maut) sowie
regulatorische CO₂-Instrumente wie absolute Emissionsobergrenzen.

*Betriebliche Restriktionen.* Lenk- und Ruhezeiten (EG Nr. 561/2006 @regulation5612006),
Gefahrgutvorschriften und reale Terminalzeitfenster sind nicht abgebildet
und könnten das Routing auf langen Straßenverbindungen einschränken.

*Nachfrageseitige Faktoren.* Warenwert, Verderblichkeit und explizite
Kundenpräferenzen (z. B. Ausschluss der Luftfracht aus
Nachhaltigkeitsgründen) könnten als zusätzliche Restriktionen modelliert
werden.

== Grenzen der Handlungsempfehlung <sec:trust-boundaries>

Die Empfehlung aus @sec:sensitivity-interpretation -- Seefracht als
Standard und Luftfracht gezielt für zeitkritische Sendungen -- ist unter
folgenden Bedingungen _nicht vertrauenswürdig_:

+ *Stark gestörte Netzwerke:* Bei Ausfällen ganzer Korridore (z. B.
  Sperrung des Suezkanals) verliert die statische Planung ihre Gültigkeit.
+ *Abweichende Kostenstruktur:* Hafengebühren, Zölle oder
  Versicherungskosten, die die pauschalen Parameter übersteigen,
  verschieben die Kostenoptimalität der Seefracht.
+ *Kapazitätskritische Szenarien:* Bei starkem Konsolidierungsdruck
  beruht die Empfehlung auf einer Heuristiklösung mit bis zu 4 % Gap.
+ *Extreme Gewichtungen:* Ein global hohes Zeitgewicht verschiebt
  unnötig viel Volumen auf die Luftfracht.
+ *Technologiewandel:* Alternative Antriebe (BEV-LKW, Wasserstoff,
  LNG-Schifffahrt) könnten die relative Emissionsposition der Modi
  innerhalb weniger Jahre verändern.

Die Modellergebnisse sollten daher als _strukturelle Orientierung_
verstanden werden: Sie zeigen zuverlässig die Richtung der Zielkonflikte,
die konkreten Zahlenwerte sind aber im Licht dieser Einschränkungen zu
interpretieren.

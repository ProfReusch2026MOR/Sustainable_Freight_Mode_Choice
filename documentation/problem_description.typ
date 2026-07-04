= Problembeschreibung <ch:problem-description>

Dieses Kapitel beschreibt das betrachtete Planungsproblem und die zugrunde
liegende Netzwerkstruktur. Die formale mathematische Modellierung folgt
anschließend in @ch:mathematical-model.

== Planungsproblem

Gegenstand dieser Arbeit ist die gemeinsame Routenplanung mehrerer
Gütersendungen in einem multimodalen Transportnetzwerk. Jede Sendung wird durch
einen Starthub, einen Zielhub, einen frühestmöglichen Freigabezeitpunkt, eine
gewünschte Lieferfrist sowie ein Frachtgewicht in Tonnen charakterisiert.
Optional können darüber hinaus eine Preisobergrenze, eine maximale
CO₂-Emissionsgrenze und individuelle Präferenzgewichte für Kosten, Transportzeit
und Emissionen angegeben werden.

Das zentrale Ziel besteht darin, für jede Sendung eine Route durch das
Transportnetzwerk zu bestimmen, die eine gewichtete Kombination aus
Transportkosten, Transportzeit und CO₂-Emissionen minimiert und dabei
gleichzeitig die gegebenen Kapazitäts- und Zeitrestriktionen einhält. Da mehrere
Sendungen gemeinsam betrachtet werden, ergeben sich zusätzliche
Bündelungsmöglichkeiten: Sendungen, die zur gleichen Zeit dieselbe Verbindung
nutzen, können sich die bereitgestellte Transportkapazität und damit auch die
anfallenden Fixkosten und Fixemissionen teilen. Diese Konsolidierung ist ein
wesentlicher Bestandteil des Planungsproblems.

== Das multimodale Transportnetzwerk

Das Transportnetzwerk setzt sich aus Logistikknoten (Hubs) und den
Verbindungen zwischen ihnen zusammen. Jeder Hub repräsentiert einen
physischen Standort -- etwa ein Logistikzentrum, einen Bahnhof, einen
Seehafen oder einen Flughafen -- und unterstützt eine oder mehrere
Transportmodi.

=== Verkehrsträger und ihre Charakteristika

Die betrachteten Verkehrsträger unterscheiden sich grundlegend in ihren
betrieblichen Eigenschaften, was unmittelbare Auswirkungen auf die
Modellierungsentscheidungen hat:

- *Straßentransport (LKW)* bietet maximale Flexibilität. Wenn das
  Frachtvolumen die Kapazität eines einzelnen Fahrzeugs übersteigt, können
  zusätzliche Fahrzeuge ohne infrastrukturelle Einschränkungen eingesetzt
  werden. Die Kapazität skaliert nahezu linear, entsprechend der Praxis
  im Charter- und Spotmarkt. Im Gegenzug verursacht der Straßentransport
  vergleichsweise hohe variable Emissionen pro Tonnenkilometer.

- *Schienentransport* vereint hohe Ladekapazität mit niedrigen variablen
  Kosten und Emissionen, ist jedoch an feste Fahrpläne und bestehende
  Infrastruktur gebunden. Je nach Betriebsmodell -- Charterverkehr mit
  flexibler Waggonanzahl oder Stellplatzbuchung in einem
  Liniengüterzug -- kann die verfügbare Kapazität teil-elastisch oder
  starr sein.

- *Seefracht* eignet sich besonders für große Volumina auf internationalen
  Verbindungen, ist allerdings mit deutlich längeren Transportzeiten
  verbunden. Die Kapazität ist durch den Linienfahrplan und die
  Schiffsgrößen fest vorgegeben.

- *Luftfracht* erzielt die kürzesten Lieferzeiten, verursacht jedoch die
  höchsten Kosten und Emissionen. Wie bei der Seefracht ist die Kapazität
  eines einzelnen Slots hart limitiert; zusätzliche Flugzeuge können nicht
  kurzfristig auf eine Route geschickt werden.

Diese verkehrsträgerspezifischen Unterschiede in der Kapazitätsflexibilität
beeinflussen die Modellierung unmittelbar: Während bei Straßenkanten die
Anzahl einsetzbarer Fahrzeuge als freie ganzzahlige Variable modelliert wird,
beschränkt sich die Aktivierungsentscheidung bei fahrplangebundenen
Verkehrsträgern auf eine binäre Wahl (Nutzung oder Nicht-Nutzung der
vorhandenen Kapazität).

=== Transferprozesse an Hubs

Beim Wechsel zwischen zwei Verkehrsträgern an einem Hub -- etwa beim Umladen
von der Schiene auf die Straße -- fallen Transferkosten, Transferemissionen
und eine zeitliche Verzögerung an. Diese Umschlagprozesse bilden eine
wesentliche Restriktion der multimodalen Transportplanung: Ein Moduswechsel
lohnt sich nur dann, wenn die Einsparungen auf der nachfolgenden
Transportstrecke die zusätzlichen Umschlagkosten und -zeiten kompensieren.

=== Wartezeiten an Hubs

Sendungen können an einem Hub verweilen, etwa um eine spätere Abfahrt
abzuwarten. Auch das Warten ist mit Kosten verbunden -- beispielsweise durch
Lagergebühren -- und kann gegebenenfalls Emissionen verursachen.

== Konsolidierung als Kernmechanismus

Ein zentrales Merkmal des Modells ist die Fähigkeit zur Frachtbündelung
(Konsolidierung). Nutzen mehrere Sendungen gleichzeitig dieselbe zeitlich
konkrete Transportverbindung, teilen sie sich die aktivierte
Fahrzeugkapazität. Die Fixkosten und Fixemissionen der Bereitstellung --
beispielsweise Trassengebühren, Fahrzeugmiete oder Hafengebühren -- fallen
dadurch nur einmal an, unabhängig davon, wie viele Sendungen das Fahrzeug
nutzen.

Dieser Mechanismus erzeugt einen Anreiz, Sendungen auf gemeinsame
Verbindungen zu bündeln, selbst wenn die resultierende Route für eine
einzelne Sendung isoliert betrachtet nicht optimal wäre. Die Entscheidung,
ob sich eine Konsolidierung lohnt, hängt dabei vom Zusammenspiel der
Sendungsgewichte, der Fahrzeugkapazitäten und der Fixkosten ab. Für leichte
Sendungen auf kurzen Strecken dominiert häufig der direkte
Einzeltransport per LKW. Bei schweren Sendungen auf langen Relationen kann
dagegen ein gemeinsamer Schienentransport trotz höherer Fixkosten pro
Aktivierung insgesamt günstiger und emissionsärmer sein.

== Zielkonflikte und Abwägungen

Die drei Optimierungsziele -- Kosten, Zeit und Emissionen -- stehen in einem
inhärenten Spannungsverhältnis:

- Die *kostengünstigste* Route nutzt häufig den Straßentransport, da hier
  keine hohen Fixkosten für die Fahrzeugbereitstellung anfallen und die
  direkte Zustellung Umschlagprozesse vermeidet.
- Die *schnellste* Route bevorzugt Verkehrsträger mit kurzen Laufzeiten,
  schließt aber potenziell günstigere oder emissionsärmere Alternativen
  aus.
- Die *nachhaltigste* Route verlagert Transporte auf die Schiene oder das
  Schiff, was die CO₂-Emissionen pro Tonnenkilometer deutlich senkt,
  jedoch längere Transportzeiten und zusätzliche Umschlagprozesse
  verursacht.

Das Modell ermöglicht es, diese Zielkonflikte über sendungsspezifische
Gewichtungsfaktoren transparent abzuwägen. Durch Variation der Gewichte
lassen sich Pareto-optimale Transportstrategien identifizieren und die
Auswirkungen einer stärkeren Nachhaltigkeitsorientierung auf Kosten und
Lieferzeiten quantifizieren.

== Einordnung in die Problemklasse

Das beschriebene Planungsproblem lässt sich der Klasse des *Service Network
Design* zuordnen, die in @ch:theory eingeführt wurde. Im Unterschied zu
reinen Netzwerkflussproblemen, bei denen die Infrastruktur als gegeben
betrachtet wird, umfasst die Entscheidung hier sowohl die Aktivierung von
Transportverbindungen (Fahrzeugbereitstellung) als auch die Zuweisung der
Sendungsflüsse auf diese Verbindungen. Die Fixkosten der Aktivierung und
die variablen Transportkosten bilden zusammen die ökonomische Zielfunktion.
Darüber hinaus erweitert das Modell die klassische CMND-Formulierung um
eine zeitliche Dimension (zeitexpandiertes Netzwerk), eine
Mehrzieloptimierung (Kosten, Zeit, Emissionen) sowie weiche Restriktionen
für Lieferfristen und Budgets.

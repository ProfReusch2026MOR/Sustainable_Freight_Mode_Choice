= Literaturübersicht & Theoretischer Hintergrund <ch:literature>

== Multimodaler Güterverkehr und Intermodalität
In der modernen Logistik bezeichnet multimodaler Transport die Beförderung von Gütern mit mindestens zwei verschiedenen Verkehrsträgern. Der intermodale Transport ist ein Spezialfall, bei dem die Güter in derselben Ladeeinheit (z. B. Container) transportiert werden, ohne dass die Güter selbst beim Trägerwechsel umgeladen werden. Dies reduziert Umschlagskosten und Beschädigungsrisiken, erfordert jedoch koordinierte Umschlaghubs.

== Green Logistics und Nachhaltigkeitsmetriken
Traditionell stand die Minimierung von Transportkosten und Transportzeiten im Vordergrund. Durch politische Vorgaben und CO₂-Preise rückt die Ökobilanzierung in den Fokus. Die Modellierung von Emissionen erfolgt meist über emissionsfaktorenbasierte Ansätze, bei denen die zurückgelegte Strecke, das transportierte Gewicht und der spezifische Emissionsfaktor des Verkehrsträgers (in kg CO₂ pro Tonnenkilometer) multipliziert werden. Flugzeuge weisen dabei die höchsten, Schiffe und Bahnen die geringsten Faktoren auf.

== Operations Research in der Netzwerkflussoptimierung
Die Planung multimodaler Verkehre wird in der OR-Literatur häufig als zeitexpandiertes Netzwerkflussproblem (Time-Expanded Network Flow Problem) formuliert. Da Fahrpläne (Abfahrtszeiten) diskret sind, wird das statische physikalische Netzwerk über den Planungshorizont hinweg in diskreten Zeitschritten dupliziert. Dadurch können Abfahrtszeiten und Wartezeiten präzise als Kanten im zeitexpandierten Graphen abgebildet werden.

== Lösungsansätze: Exakte vs. Heuristische Verfahren
- *Gemischt-ganzzahlige lineare Programmierung (MILP):* Liefert nachweislich optimale Lösungen für Routing und Konsolidierung, ist jedoch aufgrund der NP-Schwere des Problems (verwandt mit dem Multi-Commodity Flow und Vehicle Routing Problem) bei großen Netzwerken rechenintensiv.
- *Heuristische Verfahren:* Um in der Praxis schnelle Entscheidungen zu ermöglichen, werden Näherungsverfahren eingesetzt. Dijkstra-basierte Heuristiken oder Metaheuristiken (z. B. Local Search) liefern in Bruchteilen einer Sekunde gute, wenn auch nicht garantiert optimale Lösungen.

_Hinweis gemäß Richtlinien: Zitieren Sie in diesem Kapitel mindestens sechs Quellen (davon mindestens vier wissenschaftliche Papers) zur theoretischen Fundierung Ihres Modells (z. B. zur Berechnung von CO₂-Äquivalenten oder zur Formulierung von Mehrgüterflussproblemen)._

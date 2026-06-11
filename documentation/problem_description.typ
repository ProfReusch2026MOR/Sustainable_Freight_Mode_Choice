= Problembeschreibung & Mathematisches Modell <ch:problem-description>

== Das Multimodale Transportnetzwerk
Das logistische Netzwerk wird als gerichteter, zeitexpandierter Graph $G = (N, A)$ modelliert. 
Ein Zeitknoten $n = (h, m, t) in N$ repräsentiert einen Zustand, in dem sich eine Sendung an einem bestimmten Hub $h in H$, in einem bestimmten Modus $m in M_h$ und zu einem bestimmten Zeitpunkt $t in T = {0, ..., T_"max"}$ befindet.

Die Kantenmenge $A$ setzt sich aus drei disjunkten Teilmengen zusammen:
$ A = A_"trans" union A_"wait" union A_"transfer" $

- *Transportkanten ($A_"trans"$):* Stellen die physische Fahrt zwischen zwei Hubs $h_1$ und $h_2$ unter Nutzung des Modus $m$ dar. Fahrzeiten werden auf volle Stunden aufgerundet:
  $ Delta t_l = |~ d_l / v_m ~| $
- *Wartekanten ($A_"wait"$):* Modellieren das Warten oder die Lagerung von Gütern an einem Hub $h$ im selben Modus $m$ von Zeitpunkt $t$ auf $t+1$:
  $ A_"wait" = { ((h, m, t), (h, m, t+1)) | h in H, m in M_h, t < T_"max" } $
- *Transferkanten ($A_"transfer"$):* Bilden das Umladen von Modus $m_1$ auf Modus $m_2$ am selben Hub $h$ ab. Dies benötigt eine feste Transferzeit $tau^"tr" = 2$ Stunden und ist an zeitliche Transferfenster $Theta_(h, m_1, m_2)$ gebunden:
  $ A_"transfer" = { ((h, m_1, t), (h, m_2, t + tau^"tr")) | h in H, m_1, m_2 in M_h, t in D^"tr"_(h, m_1, m_2), t + tau^"tr" <= T_"max" } $

== Mathematische Formulierung (MILP)

=== Mengen und Indizes
- $H$: Menge der Hubs (Knoten)
- $M$: Menge der Transportmodi ($M = {"road", "rail", "air", "ship"}$)
- $M_h$: Unterstützte Modi am Hub $h in H$
- $T$: Diskreter Planungshorizont ${0, ..., T_"max"}$
- $A$: Kanten im zeitexpandierten Netz
- $K$: Menge der zu transportierenden Sendungen

=== Parameter
- $w_k$: Gewicht der Sendung $k in K$ in Tonnen
- $d_l$: Distanz einer Verbindung $l$ in km
- $c_(a,k)$: Sendungsspezifische variable Kosten der Kante $a in A$ für Sendung $k$ (Kosten pro t-km $times$ Distanz $times$ Gewicht)
- $e_(a,k)$: Sendungsspezifische variable CO₂-Emissionen der Kante $a in A$ für Sendung $k$
- $tau_a$: Transport- bzw. Transferdauer der Kante $a in A$ in Stunden
- $B_k$: Maximales Budget der Sendung $k in K$
- $D_k$: Späteste Ankunftszeit (Deadline) der Sendung $k in K$
- $U_a$: Kapazität der Nicht-Road-Kante $a in A$ in Tonnen
- $Q_a$: Kapazität eines LKWs auf einer Road-Kante $a in A^"road"$
- $F_a$: Fixkosten für die Aktivierung der Kante $a in A$
- $G_a$: Fix-Emissionen bei Aktivierung der Kante $a in A$
- $w_c, w_t, w_e$: Gewichtungsfaktoren für Kosten, Zeit und Emissionen in der Zielfunktion ($w_c + w_t + w_e = 1$)
- $C_("max"), T_("max"), E_("max")$: Normalisierungsfaktoren zur Skalierung der Zielfunktionsanteile

=== Entscheidungsvariablen
$ x_(a,k) = cases(1 quad "wenn Sendung " k " die Kante " a " nutzt", 0 quad "sonst") $
$ y_a = cases(1 quad "wenn Nicht-Road-Kante " a " aktiviert wird", 0 quad "sonst") $
$ z_a in {0, 1, 2, ...} quad "Anzahl eingesetzter LKWs auf Road-Kante " a in A^"road" $

=== Zielfunktion
Das Modell minimiert die gewichteten, normalisierten Fixkosten, variablen Kosten, Transportzeiten und Emissionen über alle Sendungen und aktivierten Kanten:

$ min_x sum_(a in A backslash A^"road") F_a y_a + sum_(a in A^"road") F_a z_a + sum_(k in K) sum_(a in A) x_(a,k) ( w_c (c_(a,k) / C_("max")) + w_t (tau_a / T_("max")) + w_e (e_(a,k) / E_("max")) ) $

=== Nebenbedingungen
- *Flusserhaltung:* Stellt sicher, dass jede Sendung einen zusammenhängenden Pfad vom Start zum Ziel wählt:
  $ sum_(a in A^"in"(n)) x_(a,k) - sum_(a in A^"out"(n)) x_(a,k) = 0 quad forall k in K, forall n in N backslash (N_k^"start" union N_k^"end") $
- *Start- und Zielbedingungen:* Jede Sendung beginnt genau am Startknoten und kommt am Zielknoten an:
  $ sum_(n in N_k^"start") sum_(a in A^"out"(n)) x_(a,k) = 1 quad forall k in K $
  $ sum_(n in N_k^"end") sum_(a in A^"in"(n)) x_(a,k) = 1 quad forall k in K $
- *Lieferfristen (Deadlines):*
  $ sum_(n in N_k^"end") sum_(a in A^"in"(n)) t(n) x_(a,k) <= D_k quad forall k in K $
- *Sendungsbudget:*
  $ sum_(a in A) x_(a,k) c_(a,k) <= B_k quad forall k in K $
- *Kapazitäten und Konsolidierung:*
  - Für Schiene, Luft und See ($a in A backslash A^"road"$):
    $ sum_(k in K) w_k x_(a,k) <= U_a y_a $
  - Für Straßentransport ($a in A^"road"$):
    $ sum_(k in K) w_k x_(a,k) <= Q_a z_a $

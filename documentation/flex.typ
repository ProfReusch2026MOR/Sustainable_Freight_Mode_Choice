// Flexible Bildunterschriften: lange Fassung unter der Abbildung/Tabelle,
// kurze Fassung im Abbildungs-/Tabellenverzeichnis.
//
// Verwendung:
//   #import "flex.typ": flex-caption
//   #figure(..., caption: flex-caption([lange Unterschrift ...], [Kurztitel]))
//
// Der State `in-outline` wird in main.typ über eine `show outline`-Regel
// aktiviert, damit im Verzeichnis der Kurztitel gerendert wird.
#let in-outline = state("in-outline", false)
#let flex-caption(long, short) = context if in-outline.get() { short } else { long }

#let tab(title, tabfill) = box(
  fill: tabfill,
  stroke: black,
  radius: 3pt,
  inset: (x: 1em, y: 0.5em),
  text(title),
)

#let panel(title, body, tabfill) = stack(
  spacing: 0pt,
  // overlay tab in the top-left corner
  tab(title, tabfill),
  // main box
  box(
    width: 100%-50pt,
    radius: 3pt,
    stroke: black + 0.5pt,
    inset: 10pt,
    fill: luma(250),
    text(body),
  ),
)
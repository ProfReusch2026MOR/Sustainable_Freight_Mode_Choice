#let abstract-content = {
  [
  *0,5 S.*
  
  #text(red, [Achtung]): Nur bei Bachelor- und Masterarbeiten üblich. Das Kapitel sollten bei Haus- und Projektarbeiten gelöscht werden.

  #lorem(100);
  ]
}

#let _to-content(x) = if type(x) == function { x() } else { x }
#let unary(.., last) = {
  numbering("A", last)
}

#let abstract(
  title: "Abstract",
  numbering: "1",
  outlined: true,
) = {
  let body = _to-content(abstract-content)
  counter(heading).update(0)
  set heading(numbering: unary, offset: 1)
  body
}
// Bei Projektarbeiten nicht erforderlich; wird in main.typ derzeit nicht gerendert.
#let abstract-content = {
  []
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
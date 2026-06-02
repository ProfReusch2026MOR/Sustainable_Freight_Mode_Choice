// appendix.typ — author your appendix here and render it from your main file
// Edit the `appendix-content` function below. In your main file, just import
// `appendix` and call it with parameters (no content argument needed):
//   #import "appendix.typ": appendix
//   ...
//   #appendix(title: "Supplementary Material", break: true, numbered: false)

// --- Write your appendix content here -------------------------------------
#let appendix-content = {
  // Replace everything in this block with your real appendix content.
  // This is only a placeholder so the module compiles out of the box.
   [
   ]
}


// --- Utility ---------------------------------------------------------------
#let _to-content(x) = if type(x) == function { x() } else { x }
#let unary(.., last) = {
  numbering("A", last)
}

// Inserts an appendix section. If `content` is omitted (auto), uses the
// content you authored above in `appendix-content`.
#let appendix(
  title: "Appendix",
  numbering: "A",
  outlined: true,
) = {
  let body = _to-content(appendix-content)
  counter(heading).update(0)
  set heading(numbering: unary, offset: 1)
  body
}


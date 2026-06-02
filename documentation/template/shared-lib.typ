#let is-in-dict(dict-type, state, element) = {
  let b = false
  context {
    let list = state.get()
    if key not in list { 
      panic(element + " is not a key in the " + dict-type + " dictionary.")
      b = false
    } else {
      b = true
    }
  }
  return b 
}

#let display-link(dict-type, state, element, text) = {
  if is-in-dict(dict-type, state, element) {
    link(label(dict-type + "-" + element), text)
  }
}

#let display(dict-type, state, element, text, link: true) = {
  if link {
    display-link(dict-type, state, element, text)
  } else {
    text
  }
}
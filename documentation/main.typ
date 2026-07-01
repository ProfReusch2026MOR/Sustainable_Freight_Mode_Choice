#import "template/lib.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node
#import "@preview/showybox:2.0.4": showybox
#import "@preview/finite:0.5.0": automaton
#import "acronyms.typ": acronyms
#import "abstract.typ": abstract
#import "appendix.typ": appendix
#import "@preview/callisto:0.2.5"


#let language = "de" // "de" or "en"
#show: supercharged-dhbw.with(
  language: "de",
  title: "Nachhaltige multimodale Transportplanung: Optimierungsmodell und heuristische Lösungsverfahren",
  authors: (
    (
      name: "Benedikt Wehner",
      student-id: "50118397,",
      course: "Operations Research",
      course-of-studies: "Ingenieurwissenschaften und Mathematik",
    ),
    (
      name: "Luis Kruse",
      student-id: "50137130",
      course: "Operations Research",
      course-of-studies: "Ingenieurwissenschaften und Mathematik",
    ),
    (
      name: "Phil Kahlert",
      student-id: "50112704",
      course: "Operations Research",
      course-of-studies: "Ingenieurwissenschaften und Mathematik",
    ),
    (
      name: "Laurens Rüther",
      student-id: "50129889",
      course: "Operations Research",
      course-of-studies: "Ingenieurwissenschaften und Mathematik",
    ),
    (
      name: "Minglu Li",
      student-id: "50292723",
      course: "Operations Research",
      course-of-studies: "Ingenieurwissenschaften und Mathematik",
    ),
  ),
  appendix: appendix(), // From "appendix.typ"
  acronyms: acronyms, // displays the acronyms defined in the acronyms dictionary
  at-university: true, // if true the company name on the title page and the confidentiality statement are hidden
  bibliography: bibliography("../literature/sources.bib"),
  bib-style: "ieee",
  date: datetime(day: 29, month: 06, year: 2026),
  header: (
    show-left-logo: false,
    show-right-logo: false,
  ),
  logo-left: image("assets/Hsbi_logo.png", fit: "contain", width: 200pt),
  show-confidentiality-statement: false,
  show-declaration-of-authorship: true,
  supervisor: (university: "Prof. Dr. Pascal Reusch"),
  type-of-thesis: TITLEPAGE_TYPE_OF_THESIS_PROJECT.at(language), // check "template/locale.typ"
  university: "Hochschule Bielefeld, University of Applied Sciences and Arts", // unused, but break if removed xD
  university-location: "Bielefeld Germany", // unused, but break if removed xD
  university-short: "HSBI",
  city: "Bielefeld",
  // for more options check the package documentation (https://typst.app/universe/package/supercharged-dhbw)
)



// ////////////////////////////////////////////////////////////////////////

#include "introduction.typ"
#include "problem_description.typ"
#include "implementation.typ"
#include "results.typ"
#include "discussion.typ"
#include "conclusion.typ"

= Jupyter Notebook
#let mainSolverNotebook = json("../notebooks/main.ipynb")

#callisto.render(nb: mainSolverNotebook)


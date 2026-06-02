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
  title: "Test-Titel",
  authors: (
    (
      name: "Benedikt Wehner",
      student-id: "50118397,",
      course: "Operations Research",
      course-of-studies: "Ingenieurwissenschaften und Mathematik",
    ),
    (
      name: "Luis Kruse",
      student-id:"50137130",
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
  at-university: true , // if true the company name on the title page and the confidentiality statement are hidden
  bibliography: bibliography("../literature/sources.bib"),
  bib-style: "ieee",
  date: datetime(day: 01, month: 01, year: 1970),
  header: (
    show-left-logo: false,
    show-right-logo: false,
  ),
  logo-left: image("assets/Hsbi_logo.png", fit: "contain", width: 200pt),
  show-confidentiality-statement: false,
  show-declaration-of-authorship: false,
  supervisor: (university: "Prof. Dr. Pascal Reusch"),
  type-of-thesis: TITLEPAGE_TYPE_OF_THESIS_PROJECT.at(language), // check "template/locale.typ"
  university: "Hochschule Bielefeld, University of Applied Sciences and Arts", // unused, but break if removed xD
  university-location: "Bielefeld Germany", // unused, but break if removed xD
  university-short: "HSBI",
  city: "Bielefeld"
  // for more options check the package documentation (https://typst.app/universe/package/supercharged-dhbw)
)



////////////////////////////////////////////////////////////////////////
= #INTRODUCTION.at(language)
Welche Routen und welche Abfolge von Transportmitteln (Straße, Schiene, Luft) sollten für
eine gegebene Menge an Sendungen gewählt werden, um eine gewichtete Kombination aus
Transportkosten und CO₂-Emissionen zu minimieren, während gleichzeitig Lieferfristen, Kapazitätsgrenzen im Netzwerk und spezifische Transportvorgaben für bestimmte Güter eingehalten werden?



= Problemformulierung


== Transportmittel


== Zielfunktion


== Einschränkungen
- Für jede einzelne Sendung muss ein gültiger Weg durch den gerichteten Graphen (bestehend aus Städten und Terminals) vom Ursprung zum Zielort berechnet werden
- Das Modell muss sicherstellen, dass die gesamte Transport- und Transferzeit einer Sendung die für sie festgelegte Lieferfrist (Deadline) nicht überschreitet
- Die gebündelten Volumina der Sendungen dürfen die maximalen Kapazitätsgrenzen der genutzten Strecken (Straße, Schiene, Luft) sowie die Abfertigungskapazitäten in den Transfer-Terminals nicht überschreiten (Wir nehmen an, dass die Kantenkapazität durch die Anzahl der verfügbaren Transportmittel (Lkw/Waggons/Flugzeuge) auf dieser Strecke limitiert ist und nicht durch die physische Straßeninfrastruktur)



= Notebook 
#let mainSolverNotebook = json("../notebooks/main.ipynb")

#callisto.render(nb: mainSolverNotebook)


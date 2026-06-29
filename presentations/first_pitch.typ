#import "@preview/typslides:1.3.3": *
#import "@preview/diagraph:0.3.7": raw-render

// Project configuration
#show: typslides.with(
  ratio: "16-9",
  theme: "bluey",
  font: "Fira Sans",
  font-size: 20pt,
  link-style: "color",
  show-progress: true,
)

#front-slide(
  title: "Sustainable Multimodal Freight Routing",
  subtitle: [Network Flow Optimization with Cost--Emission Trade-offs],
  authors: "Phil Kahlert, Benedikt Wehner, Luis Kruse, Laurens Rüther, Minglu Li",
  info: [#link("https://github.com/ProfReusch2026MOR/Sustainable_Freight_Mode_Choice")],
)

#slide(title: "Topic & Problem Setting")[
  - Plan shipments through a #stress[multimodal transport network]
  - Decide which #stress[route] and #stress[transport mode] each shipment should use
  - Transport modes: road, rail, air, and transfer connections at terminals
  - Multiple shipments with different:
    - origins and destinations
    - volumes, sizes
    - delivery deadlines
  - Respect capacity limits of road, rail, air, and transfer terminals
  - Consolidation: multiple shipments can be bundled through the same rail/air connections or transfer terminals
]

#slide(title: "Optimization Approach")[
  - #stress[Network flow problem] solved as a #stress[Mixed-Integer Linear Program (MILP)]
  - Model the transport system as a directed graph:
    - nodes = cities and terminals
    - edges = road, rail, air, and transfer connections
  - Each edge has parameters:
    - cost, travel time, CO₂ emissions, capacity

  #framed(title: "Objective")[
    $min_x quad alpha dot "Cost"(x) + (1 - alpha) dot "Emissions"(x)$
  ]

  - Objective: minimize a weighted combination of transportation cost and CO₂ emissions
  - Main constraints:
    - each shipment must form a valid path from origin to destination
    - delivery deadlines must be respected
    - edge and terminal capacities cannot be exceeded
    - restrictions on mode of transport based on the type of cargo (batteries)
]

#slide(title: "Example Directed Transport Graph")[
  #align(center)[
    #raw-render(
      ```
      digraph G {
        graph [
          rankdir=LR,
          splines=true,
          nodesep=0.55,
          ranksep=0.75,
          bgcolor="transparent"
        ];

        node [
          shape=box,
          style="rounded,filled",
          fillcolor="#EAF2FF",
          color="#2B5DAA",
          penwidth=1.4,
          fontname="Fira Sans",
          fontsize=13,
          margin="0.13,0.08"
        ];

        edge [
          penwidth=1.8,
          arrowsize=0.75,
          fontname="Fira Sans",
          fontsize=9,
          labeldistance=1.0,
          labelangle=8
        ];

        Hamburg   [label="Hamburg"];
        CologneR  [label="Cologne\nRoad"];
        CologneL  [label="Cologne\nRail"];
        Frankfurt [label="Frankfurt"];
        Munich    [label="Munich"];

        Hamburg -> CologneR [
          color="#555555",
          style=dashed,
          label="road"
        ];

        CologneR -> Hamburg [
          color="#555555",
          style=dashed,
          label="road",
          constraint=false
        ];

        CologneL -> Munich [
          color="#2B5DAA",
          label="rail"
        ];

        Munich -> CologneL [
          color="#2B5DAA",
          label="rail",
          constraint=false
        ];

        Hamburg -> Frankfurt [
          color="#555555",
          style=dashed,
          label="road"
        ];

        Frankfurt -> Hamburg [
          color="#555555",
          style=dashed,
          label="road",
          constraint=false
        ];

        Frankfurt -> Munich [
          color="#7C3AED",
          style=bold,
          label="air"
        ];

        Munich -> Frankfurt [
          color="#7C3AED",
          style=bold,
          label="air",
          constraint=false
        ];

        CologneR -> CologneL [
          color="#D97706",
          style=dotted,
          label="transfer"
        ];

        CologneL -> CologneR [
          color="#D97706",
          style=dotted,
          label="transfer",
          constraint=false
        ];
      }
      ```
    )
  ]
]

#slide(title: "Computational Experiments")[
  - Reproducible experiment runner: `experiments/run_experiments.py`
  - Solver: #stress[PuLP + HiGHS]
  - Dataset: deterministic subnetworks from `dataset/multimodal_network.json`
  - Presentation profile: 10/20/30 routes and 3/5/8 shipments

  #align(center)[
    #table(
      columns: (auto, auto, auto, auto, auto),
      inset: 7pt,
      align: center + horizon,
      [*Instance*], [*Routes*], [*Shipments*], [*Runtime*], [*Cost / CO2*],
      [small], [10], [3], [1.587 s], [921.27 EUR / 125.35 kg],
      [medium], [20], [5], [7.913 s], [1675.77 EUR / 219.43 kg],
      [large], [30], [8], [17.355 s], [2644.14 EUR / 348.31 kg],
    )
  ]

  - Runtime increases clearly with model size, even at demo scale.
]

#slide(title: "Sensitivity Analysis")[
  - Cost-emission trade-off:
    $ w_c = 1 / (1 + lambda), quad w_e = lambda / (1 + lambda), quad w_t = 0 $
  - Baseline small instance: all lambda values remain 100% road
  - Interpretation: fixed activation costs and fixed emissions dominate on short, light shipments

  #align(center)[
    #image("../experiments/results/sensitivity_cost_emissions.svg", width: 68%)
  ]
]

#slide(title: "Modal-Shift Scenario")[
  - Additional heavy-shipment scenario: 8.0 t per shipment
  - Goal: test whether high emission weight can shift the solution toward rail

  #align(center)[
    #table(
      columns: (auto, auto, auto, auto),
      inset: 7pt,
      align: center + horizon,
      [*$lambda$*], [*Road share*], [*Rail share*], [*CO2*],
      [0], [24.26%], [75.74%], [352.28 kg],
      [1], [24.26%], [75.74%], [352.28 kg],
      [2], [0.00%], [100.00%], [339.24 kg],
      [5], [0.00%], [100.00%], [339.24 kg],
    )
  ]

  - Higher emission weights produce a full rail solution in this scenario.
]

#slide(title: "Limitations & Next Evaluation Steps")[
  - These results are reproducible scenario evidence, not a general policy conclusion
  - Current scope: deterministic subnetworks, 3--8 shipments, linear emission factors
  - Solver status is reported; no optimality gap is claimed when HiGHS does not expose one
  - Next evaluation:
    - compare MILP, Dijkstra, and Tabu Search on identical instances
    - test multiple demand and disruption scenarios
    - report solution quality, timeout behavior, and variance

  #framed(title: "Defensible takeaway")[
    The experiments demonstrate model behavior and parameter sensitivity within the tested scenarios.
  ]
]
#slide(title: "Reproducibility & Sam Contribution")[
  - Designed and implemented computational experiments
  - Added cost-emission sensitivity analysis with lambda sweep
  - Generated CSV/SVG result artifacts for the report and presentation
  - Added unit tests for experiment summaries and chart labels
  - Added validation checklist for reproducible presentation results

  #framed(title: "Reproduce the evaluation")[
    `python experiments/run_experiments.py --profile presentation` \
    `python experiments/run_experiments.py --profile modal-shift`
  ]
]

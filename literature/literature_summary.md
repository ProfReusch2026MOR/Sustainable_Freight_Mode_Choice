# Literature Summary — Sustainable Freight Mode Choice

> **Project**: Sustainable Freight Mode Choice (Cluster 6, #21)  
> **Last updated**: 2026-05-22

---

## Academic Sources

### 1. Kuchenbecker, Krauth, Ribesmeier, Bešinović (2025)

**Full Reference**: Kuchenbecker, F., Krauth, M., Ribesmeier, M. & Bešinović, N. (2025). Optimising Mode Choice in a Bi-modal Freight Network. *Transportation Research Interdisciplinary Perspectives*, Vol. 31, 101442.

**OR Problem Class**: Bi-modal network flow (truck + parcel train); inner-city freight hub optimization.

**Key Insights**:
- Formulates parcel mode choice as **point-to-point vs. hub-and-spoke routing** with mode-switch at inner-city hubs
- Uses real BIEK parcel shipment data (German CEP market) — validates our shipment generation approach
- Includes **sensitivity analysis**: toll prices, train speed, subsidy amounts — directly informs our policy scenarios
- Route-based enumeration, not solver-based — we improve by using MILP solver

**How We Use It**:
- Flow formulation structure (node-arc with mode attribute)
- BIEK data pattern for realistic shipment generation
- Policy sensitivity parameters (toll/subsidy ranges)
- Validates shortest-path as natural heuristic decomposition for mode choice

---

### 2. Springer (2024)

**Full Reference**: Springer, H. (2024). On the Optimization of Green Multimodal Transportation: A Case Study of the West German Canal System. *Annals of Operations Research*.

**OR Problem Class**: Bi-objective MILP (cost × CO₂); Vehicle Routing with Transshipment.

**Key Insights**:
- **AUGMECON ε-constraint method** for Pareto frontier — our core solution algorithm
- **EcoTransit well-to-wheel** emission calculation methodology — our CO₂ computation basis
- **Virtual depot technique** for handling transshipment in routing models
- Bundesverkehrswegeplan 2015 cost functions for road/rail/ship — our cost parameter source
- Demonstrates that weighted-sum fails on non-convex regions of Pareto frontier

**How We Use It**:
- AUGMECON implementation structure and ε-step sizing
- EcoTransit emission factors (kgCO₂/ton·km per mode, load-dependent)
- Cost parameter calibration from BVWP 2015
- Justification for choosing ε-constraint over weighted-sum

---

### 3. MDPI (2026)

**Full Reference**: (2026). Decarbonizing Freight Through Intermodal Transport: An Operations Research Perspective – Part II. *Future Transportation*, 6(1), 37.

**OR Problem Class**: Literature review — OR methods for freight decarbonization (2015–2025).

**Key Insights**:
- **Four-phase evolution**: Phase 1 (basic emission minimization) → Phase 2 (carbon pricing/policy) → Phase 3 (multi-objective Pareto) → Phase 4 (stochastic/game-theoretic)
- Carbon tax/trading and rail subsidies are the dominant policy instruments studied
- Most papers use deterministic models; stochastic demand/disruption still rare
- Emission estimation methods classified: macro (TKM-based), meso (mode+link-specific), micro (vehicle+load)

**How We Use It**:
- Positioning: we operate in **Phase 2-3** (deterministic + multi-objective + policy scenarios)
- Provides literature chain for our review section — papers to cite and methods to reference
- Validates our choice of deterministic + scenario analysis (not stochastic)
- Justifies scope limitation (Phase 4 requires data we don't have)

---

### 4. TU Dresden (2025)

**Full Reference**: (2025). A Mode Choice Model for Sustainable Freight Transport Considering Urban Logistics Stakeholder Perspectives. *FIS TU Dresden*.

**OR Problem Class**: Stakeholder-aware mode choice; multi-criteria decision making.

**Key Insights**:
- Three stakeholder perspectives: **carrier** (cost), **citizen** (emissions + noise), **municipality** (both)
- Point-to-point road vs. hub-and-spoke (road + cargo tram) comparison
- Uses German parcel network real-data pattern
- Demonstrates that stakeholder framing changes the "optimal" solution

**How We Use It**:
- Multi-stakeholder framing: our cost objective = carrier view, emission objective = citizen/environment view
- Pareto frontier naturally shows the trade-off between these stakeholders
- Validates German parcel network as realistic scenario context

---

### 5. Energy and Emissions Balance of Modal Shift (2025)

**Full Reference**: (2025). Energy and Emissions Balance of Modal Shift. *Transportation Research Interdisciplinary Perspectives*.

**OR Problem Class**: Life-cycle assessment of modal shift policies.

**Key Insights**:
- Modal shift emission reduction quantified: road→rail saves ~60–80% CO₂/tkm; road→ship saves ~30–50%
- Well-to-wheel vs. tank-to-wheel difference matters for electrified rail
- Infrastructure emissions (construction + maintenance) are small relative to operational savings

**How We Use It**:
- Validates our CO₂ parameter ranges (LKW ~62, Bahn ~12, Schiff ~8, Flugzeug ~600 gCO₂/tkm)
- Justifies using well-to-wheel (not just tank-to-wheel) emission factors

---

### 6. 北京交通大学 (2021)

**Full Reference**: (2021). 基于运输模式转移的货运碳减排研究综述 [Review on Freight Carbon Emission Reduction Based on Modal Shift]. *北京交通大学学报*.

**OR Problem Class**: Literature review — modal shift for freight decarbonization in China.

**Key Insights**:
- Chinese context: road→rail shift target is 30% by 2035
- Modal shift carbon reduction quantified under different electrification scenarios
- Identifies data gap: Chinese freight emission factors less standardized than European (EcoTransit)

**How We Use It**:
- Provides Chinese-language literature chain for the review section
- Cross-reference: compare EU vs. China modal shift potential and barriers
- Demonstrates international relevance of our model

---

## Policy & Context Sources

### 7. UBA (2024) — Heavy Freight. Big Challenge. One Goal.

**Reference**: Umweltbundesamt (2024). *Heavy Freight. Big Challenge. One Goal.* Policy report.

**How We Use It**: Carbon price ranges (50/100/200 EUR/tCO₂); rail capacity expansion target (+50%); 70+ measures catalog validates our policy scenario selection; 2045 climate neutrality target as long-term motivation.

### 8. ITF-OECD — Mode Choice in Freight Transport

**Reference**: International Transport Forum (OECD). *Mode Choice in Freight Transport*. Policy report.

**How We Use It**: International policy comparison; cross-country barriers to modal shift; validates that cost is the dominant factor, not just infrastructure availability.

### 9. ICCT (2025) — EU Inland Waterway & Multimodal Development

**Reference**: International Council on Clean Transportation (2025). *EU Inland Waterway and Multimodal Development*.

**How We Use It**: Inland waterway (Schiff) capacity and cost data for our European network instance; validates inclusion of ship mode.

### 10. FLEX Logistik — Germany's Role in EU Green Transport

**Reference**: FLEX Logistik. *Germany's Role in the EU Green Transport Transition*. Industry white paper.

**How We Use It**: Industry perspective on real-world constraint calibration; validates our cost hierarchy (Schiff < Bahn < LKW < Flugzeug) and capacity hierarchy (Schiff >> Bahn > LKW >> Flugzeug).

---

## Literature Gaps (To Close Before Final Submission)

- [ ] Additional paper on **multi-commodity flow** exact solution methods (decomposition, Lagrangian relaxation)
- [ ] Metaheuristic paper for multimodal routing (GA/SA/ALNS) — for heuristic comparison context
- [ ] Paper on **EcoTransit v4** methodology update — verify our emission factors are current
- [ ] Case study on **transshipment terminal capacity** — calibrate our terminal capacity assumptions
- [ ] Benchmark dataset paper for multimodal network design instances

---

## Summary Table

| Source | Type | Problem Class | Model Insight | Heuristic Insight | Data | Our Use |
|--------|------|---------------|---------------|-------------------|------|---------|
| Kuchenbecker 2025 | Academic | Bi-modal flow | Flow formulation | SP decomposition | BIEK parcel data | Core model; policy params |
| Springer 2024 | Academic | Bi-obj MILP | AUGMECON | — | EcoTransit; BVWP | Solution algorithm; CO₂ calculation |
| MDPI 2026 | Academic | Review | Phase evolution | Carbon tax models | — | Literature chain; positioning |
| TU Dresden 2025 | Academic | Stakeholder MCA | Multi-stakeholder | Hub vs. P2P | German parcel | Objective framing |
| Emissions Balance 2025 | Academic | LCA | Modal shift balance | — | CO₂ factors | Parameter validation |
| 北京交通 2021 | Academic | Review (CN) | Modal shift | — | Chinese context | International comparison |
| UBA 2024 | Policy | — | — | — | Carbon price; capacity | Scenario parameters |
| ITF-OECD | Policy | — | — | — | Intl. comparison | Motivation |
| ICCT 2025 | Policy | — | — | — | Inland waterway data | Ship mode data |
| FLEX Logistik | Industry | — | — | — | Cost hierarchy | Constraint calibration |
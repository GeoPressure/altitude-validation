# Manuscript comments: proposed responses, edits and tasks

Prepared from `paper/paper.qmd` on 18 October 2026. Line numbers refer to the current QMD and will move after editing. This is a planning document: no manuscript text, analysis, figures or bibliography has been changed, and no new literature search has been performed.

**Follow-up, 18 October 2026:** The expanded T01–T03 request produced a [scoped literature review](../literature/review-T01-T03.md), a selected biological evidence table and a conversion matrix now expanded to 24 study/model rows. The bibliography/PDF libraries and Zotero collection were updated under that request. The original paragraph above describes the initial planning pass; later author-approved edits and analyses are recorded below. T01–T02 have a completed scoped synthesis; T03 is now complete to accessible-source limits, with unavailable implementation details documented explicitly.


**Author-approved implementation, 18 October 2026:** Following the GPS/barometer report and the author's scope decisions, the manuscript introduction, relevant abstract sentence, comparison/limitations and height-reference discussion have now been edited. Pressure-equipped GPS tags are included; satellite-derived height remains outside the evaluated scope. No general barometer-versus-GPS accuracy ranking or priority claim is made. The updated PDF/HTML are generated from the QMD. T04 has also been completed as a technical audit with corresponding Methods/supplement edits: [verification note](../methods/T04/verification.md), reproducible checks and a record of implementation approximations. Numerical analysis outputs and figures were not recalculated.

### Current comment/task status

| Comments/task | Status after this edit |
|---|---|
| C01–C09 / T01–T03 | Scope and literature-based replacement prose implemented. T03 source audit is complete to accessible-source limits; remaining source gaps and their claim implications are documented in the [review follow-up](../literature/review-T01-T03.md). |
| C10–C14 / T04 | Hydrostatic/column-mean explanation, humidity inputs, GPT3 cycles/interpolation and full-profile trade-off addressed. Numeric safeguard, height convention and two reference-implementation differences are documented. |
| C18 | Radiosonde explanation and dataset-specific reported-height provenance addressed in T04–T05; per-level height-generation methods remain unverified. |
| C21 / C23 | Surface-referenced flight-error equation clarified in T04; exact-input assumption and realised sampling/timing audited in T05. Metric presentation remains T06. |
| New author point: terrain height | Added a separate Discussion explanation of sea-level altitude versus local ground clearance and `path2elevation()` limitations. |
| New author point: 50 km position error | Small paired 0–200 km pilot completed and added to S6, distinguishing absolute altitude from surface-referenced height. Terrain clearance remains separate; the pilot does not establish a universal acceptable radius. |
| C15 / T08 | Closed at the author's request for now. Shared design standard defined; Figure 1 redesigned with observed points, directly labelled profiles and a separate numerical error strip. Main conversion colours updated. Individual redesigns and final-size checks are deferred. |
| C16–C21 / T05 | Completed: provenance/sampling audit and manuscript/S1/S4 edits, provider citations, realised coverage and qualified independence claims. MeteoSwiss retained as metadata corroboration. GNSS duplicate hours identified for T06; historical version/retrieval gaps documented. |
| C22–C25 / T06–T07 | T06 recommendations implemented: shorter S1, simpler metrics, MeteoSwiss in S4, unique GNSS hours, post-QC ground cell weights and regenerated sensitivity tables/figures. Primary flight values unchanged; T07 implemented with published Master GeoLocator Data Package version 2026.0: 203 contributing tags, all classified flight retained, target/individual-weight sensitivities in S4, updated citation and weighted results. |
| T09 | Skipped at the author’s request. |

T04 identified a further correction that was implemented: an additive pressure-sensor offset only partly cancels in altitude differences, because pressure sensitivity varies with altitude. The audit also records that the saved package-version table predates the currently checked formula code; T05 traced the version file to step 12, checked cached standard errors against the current formula and recorded the unrecoverable historical execution metadata; see its audit.

All embedded editorial comments are grouped below, including multiple questions within the same annotation. The three declaration placeholders are listed separately. The supplement was read for context; it contains no comparable editorial annotations. Suggested wording is provisional. “Checked locally” means supported by the current scripts, not independently verified against publications or provider documentation.

## 1. Introduction: biological motivation and scope

### C01 — Start with birds, pressure loggers and flight; make ground geolocation secondary

**Comments:** Opening annotation, line 157: start with birds/geolocators; missing references; other ground uses; whether to include GPS; animal movement versus aviation/atmospheric literature.

**Proposed response:** Agree with a bird-first introduction centred on what altitude measurements reveal. Keep pressure geolocators as the focal application. Introduce GPS and other measurement approaches explicitly as context, and use aviation/GNSS meteorology to explain the correction methods after the ecological motivation. Final scope should follow the literature audit.

**Suggested edit:** Rebuild the introduction in this order: biological questions → available altitude measurements and pressure loggers → pressure-to-altitude assumptions → specific validation gap → study objectives. Move ground geolocation after flight applications. Avoid opening with a technical positioning argument.

**Tasks:** T01–T03. Decide how broadly the title, abstract and recommendations should address pressure-equipped GPS tags once the scope is settled.

### C02 — Separate altitude constraints during geolocation from subsequent position refinement

**Comments:** Line 159: two separate processes; altitude/absolute-pressure mask within geolocation versus refining a location inside a coarse ERA5 cell; woodland kingfisher, wheatear, ring ouzel and possible other examples.

**Proposed response:** Agree that the current sentence conflates two uses. Explain the distinction and only attach species examples to the use actually demonstrated in each source.

**Suggested edit:** Draft structure: “Pressure-derived altitude can constrain candidate locations during geolocation. Once an approximate location is available, comparison with local terrain can also help refine the location within a coarse atmospheric grid cell.” Add separate evidence for each claim and a separate sentence for habitat/elevational movements.

**Tasks:** T01, T03. Verify the precise algorithmic role of absolute pressure/altitude in GeoPressureR and find the original kingfisher, wheatear and ring-ouzel examples. Do not assume all demonstrate the same refinement procedure.

### C03 — Broaden ecological applications beyond day–night altitude changes

**Comments:** Lines 159 and 161: deeper review of pressure/altitude studies, including raptors and other birds; more than day and night.

**Proposed response:** Agree. The current examples give a narrow view of the biological questions. Organise applications by question rather than adding a long list of species or papers.

**Suggested edit:** Select evidence for migration and barrier crossing, atmospheric conditions/wind use, soaring and flight strategies, habitat/elevational use on the ground, and conservation exposure. These are search themes, not claims that every theme already has a pressure-logger study.

**Tasks:** T01. For each retained example, distinguish pressure-derived altitude from GPS-, radar- or observation-derived altitude.

### C04 — Clarify the GPS transition and what “barometric heights” means

**Comments:** Lines 161 and 163: GPS appears unexpectedly; are GPS tags within scope? Are barometric heights pressure-based? What are the alternatives? Abrupt transition to “Pressure, however, is not altitude.”

**Proposed response:** Introduce the measurement distinction before comparing performance. GPS altitude and pressure-derived altitude are different measurements; a GPS tag may also contain a pressure sensor. A comparison needs the device, processing and reference to be specified. Avoid treating “less noisy but biased” as universal.

**Suggested edit:** Add a short bridge explaining altitude measurement approaches, then state that the present study isolates the atmospheric conversion of pressure. Start a new paragraph for the conversion problem. Replace the blanket “Small migrants are too light to carry GPS” with wording specific to the species, tag mass and recording duration supported by the review.

**Tasks:** T02–T03. Check the original GPS/barometer validation studies before retaining comparative accuracy claims.

### C05 — Moderate the claim about ecological consequences

**Comment:** Line 161: “ecological conclusions drawn” may be too strong.

**Proposed response:** Agree that the wording should distinguish possible effects from consequences actually demonstrated.

**Suggested edit:** “Errors in these assumptions affect estimated flight heights and can influence analyses that depend on height distributions or thresholds.” Reserve stronger claims for studies that quantify an effect on an ecological or conservation result.

**Tasks:** T03. Link each consequence to evidence at the appropriate level.

## 2. Introduction: conversion terminology and research gap

### C06 — Define pressure, barometer, altimeter and standard atmosphere

**Comment:** Line 163: terminology around aircraft altimeters, barometers, pressure and the first conversion.

**Proposed response:** Agree. Separate the measured quantity, instrument and assumed atmosphere. The aircraft analogy adds little before those terms are defined.

**Suggested edit:** Define a barometer as the pressure sensor and pressure-derived/barometric altitude as the converted quantity. Define the standard-atmosphere conversion through its fixed reference pressure and temperature profile. Introduce aviation later only where it motivates a specific correction.

**Tasks:** T03–T04. Audit “altitude,” “height above ground,” “pressure altitude” and vertical-reference terminology throughout the text and captions.

### C07 — Attribute weather-error observations to specific studies

**Comment:** Line 163: “These authors” means some or all?

**Proposed response:** The collective attribution is too broad unless every cited study supports it.

**Suggested edit:** Attribute the tens-of-metres statement directly to Liechti et al. and the high-altitude example directly to Lindström et al., subject to checking the original passages. Separate papers using a conversion from papers evaluating its errors.

**Tasks:** T03. Record source passage, conditions, error definition and page/section for each quantitative claim.

### C08 — Classify conversions by their assumptions, not “reanalysis” versus “weather model”

**Comments:** Line 163: could the pressure reference come from a weather station? How is the third approach different from reanalysis?

**Proposed response:** Agree that the current categories overlap. The useful distinctions are the reference level, source of reference pressure/temperature and assumed vertical temperature profile.

**Suggested edit:** Describe fixed standard conditions, locally referenced pressure conversions, and surface-referenced conversions with explicit temperature assumptions. Explain that ERA5 is a reanalysis used as an atmospheric data source. Treat sea-surface calibration and station calibration as reference strategies where documented, rather than asserting three exhaustive historical categories.

**Tasks:** T03. Build a study-by-study conversion matrix before rewriting this paragraph; verify which inputs Meier et al. and the seabird studies actually used.

### C09 — Make the validation gap and cross-field motivation coherent

**Comments:** Lines 165 and 167: paragraph interesting but disconnected; why these other fields? “Poorly known” despite many studies; different sensor constraints; introduce the lapse-rate correction earlier.

**Proposed response:** Narrow the gap to what is being validated: the atmospheric conversion component across sites and flight heights. Field-device comparisons, surface-pressure evaluations and profile-based conversions answer different questions. GNSS meteorology belongs here because it supplies the candidate correction; aviation is useful as a methodological comparison with different data and instrument conditions.

**Suggested edit:** Replace the blanket gap statement with a precise distinction between total device error and conversion error. Briefly explain why humidity and the vertical temperature gradient matter, then introduce the borrowed correction. Move detailed aviation performance and resource trade-offs to the Discussion.

**Tasks:** T03–T04. Check novelty and coverage against prior studies; do not claim the correction itself is new or transfer aircraft validation performance directly to birds.

## 3. Methods: physical explanation and implementation

### C10 — Explain the hydrostatic assumption

**Comment:** Line 175: does the first sentence actually describe hydrostatic balance?

**Proposed response:** The explanation should state the assumption explicitly rather than imply that pressure necessarily follows from a motionless atmosphere.

**Suggested edit:** Provisional wording: “Under hydrostatic balance, the vertical pressure gradient balances the weight of the air. Combining this approximation with the ideal gas law gives the hypsometric relation.” State the constant-gravity approximation and keep the explanation at the level needed for the conversions.

**Tasks:** T04. Verify the derivation, terminology and reference before inserting the wording.

### C11 — Distinguish a column-mean temperature from an isothermal atmosphere

**Comment:** Line 179: does the hypsometric equation already assume a constant temperature between the reference and bird?

**Proposed response:** No: a suitable column mean represents a varying profile. The manuscript should specify that this is a mean weighted over log pressure; using a mean does not itself impose a constant temperature profile. The linear lapse-rate profile is a subsequent approximation.

**Suggested edit:** Define the mean explicitly, for example \(\bar T_v=[\ln(p_0/p)]^{-1}\int_p^{p_0}T_v(p')\,d\ln p'\). Explain separately how a linear profile leads to the next equation, including the negative lapse-rate convention and the treatment of virtual temperature in the corrected conversion.

**Tasks:** T04. Check integration, units and geopotential/geometric-height conventions against the implementation and source. Treat this as a proposed technical clarification pending that check.

### C12 — Explain how virtual temperature is calculated

**Comment:** Line 187: is ERA5 virtual temperature provided directly or computed? Separate this from lapse-rate correction.

**Proposed response:** Checked locally: the code computes virtual temperature from ERA5 air temperature, dewpoint and surface pressure. It computes vapour pressure from dewpoint, then specific humidity, then \(T_v=T(1+0.608q)\). It does not read a dedicated virtual-temperature variable.

**Suggested edit:** Split the corrected conversion into two steps: humidity adjustment to the reference temperature, followed by the GPT3 lapse-rate specification. Say “virtual temperature calculated from ERA5 variables.” Include the calculation details in the supplement if they interrupt the main text.

**Tasks:** T04. Verify the formula citation and acknowledge the use of 2 m quantities with surface pressure; clarify what vertical humidity/virtual-temperature profile the subsequent conversion approximates.

### C13 — State which GPT3 cycles are used and how time enters

**Comments:** Line 187: annual or semi-annual cycle? Linear interpolation between two dates?

**Proposed response:** Checked locally: both annual and semi-annual sine/cosine terms are evaluated, together with the mean, for the calendar day of year. The result is interpolated spatially between grid centres. Time is not interpolated linearly between two dates.

**Suggested edit:** “We evaluate the GPT3 mean, annual and semi-annual harmonics for the measurement day and interpolate the resulting lapse rate bilinearly on the 1° grid.” Explain edge handling in supplementary reproducibility details if needed.

**Tasks:** T04. Compare with the GPT3 reference implementation, including phase/day convention and any modification applied after `gpt3_lapse()` in the calling scripts. Do not infer complete agreement from the helper alone.

### C14 — Move full-profile ERA5 discussion out of implementation details

**Comment:** Line 189: discuss pressure-level profiles as a better but computationally expensive option.

**Proposed response:** Agree on moving the trade-off. Full-profile retrieval is a potential extension, but “best” and “not computationally realistic” need qualification for the intended data volume and access method.

**Suggested edit:** Retain only the inputs and retrieval method actually used in Methods. Discuss profile-informed conversion, published validation and additional data requirements in Discussion, with no categorical claim that it is infeasible.

**Tasks:** T03–T04. Verify available ERA5 products and estimate the relevant data-access/computation burden if a quantitative feasibility statement is wanted.

## 4. Figure design

### C15 — Consistent conversion colours and a clearer Figure 1

**Comments:** Line 198: define a global colour scheme; too much text; unclear key message; confirm radiosonde is the reference.

**Proposed response:** Checked locally: the manuscript figure script already defines a shared conversion palette (`pal_f`), while `R/palette.R` also has a palette for other formula variants. A full consistency audit is still needed. Yes, the radiosonde provides the comparison profile, subject to the height-reference limitations already discussed in the manuscript.

**Suggested edit:** Use the same conversion colours and line styles throughout the paper. Give the radiosonde an unmistakable reference label. Retain a short statement of the temperature-to-height mechanism and concise error labels; move sounding selection details, class counts and class medians to the caption/supplement. Avoid relying on colour alone.

**Tasks:** T08. Inspect rendered figures at manuscript size, clarify whether the plot shows local or column-mean temperature, and align its labels with the equations. No figure changes made here.

## 5. Reference datasets and sampling

### C16 — Dataset citations, versions and analysis years

**Comments:** Lines 205–209: missing GNSS and MeteoSwiss references; check every dataset reference; why use recent years when the papers are older?

**Proposed response:** Distinguish the publication describing a dataset from the version and observation period analysed. An older methods paper does not imply an old data period. The actual rationale for choosing 2022–2024 and 2023–2024 still needs documenting rather than inventing.

**Suggested edit:** Cite provider/product documentation and dataset version/access information alongside methodological papers. Give the observation periods and an explicit, verified reason for their selection. Put detailed coverage criteria in S1.

**Tasks:** T05. Audit HadISD/ISD, IGS/EUREF/BKG, MeteoSwiss, IGRA2 and ERA5 citations, releases, retrieval dates and period choices.

### C17 — Substantiate assimilation and independence claims

**Comment:** Line 205: how do we know GNSS pressure is not assimilated by ERA5?

**Proposed response:** This needs evidence. Code comments and the supplementary assertion are not sufficient to establish that none of the selected pressure records reach ERA5 by another route. Also distinguish GNSS station pressure from assimilated GNSS-derived products.

**Suggested edit:** Pending verification, qualify “never assimilated” and separate documented status from an inference about data exchange. Apply consistent qualifications to the dataset table and the “Reliability of the references” section. A station's presence in ISD is not, by itself, proof of assimilation of a particular pressure record.

**Tasks:** T05. Check ECMWF observation documentation and station identifiers/data pathways. Record remaining uncertainty if station-level status cannot be established.

### C18 — Explain radiosondes for a biological audience

**Comment:** Line 207: a little more explanation of what radiosondes are.

**Proposed response:** Agree. Readers need to know what a sounding provides and what is independent of the conversion being tested.

**Suggested edit:** Add a short explanation of balloon-borne instruments recording atmospheric profiles during ascent, then identify the pressure and reported height used here. Explain how those heights are obtained, their possible dependence on pressure/temperature, and the launch-site/drift approximation. Use “our in-flight reference” rather than implying no other reference approach exists.

**Tasks:** T04–T05. Verify IGRA2 variable definitions and height provenance; align main text with the existing limitation.

### C19 — Decide whether MeteoSwiss belongs in the main text

**Comment:** Line 210: do we really need MeteoSwiss?

**Proposed response:** Provisional recommendation: retain the dataset in the study because documented barometer heights and overlap with HadISD address an identifiable reference-height issue. Its prominence in the main text is a separate decision. The current overlap analysis is more specific evidence than simply adding a fourth dataset.

**Suggested edit:** Consider keeping a short corroboration result in the main text and moving the Swiss map inset and most dataset-specific detail to the supplement. Remove the dataset entirely only after checking which reliability claims depend on it.

**Tasks:** T05. Map its unique contribution versus GNSS and HadISD and propose a concrete keep/move/remove decision. Do not rerun or remove anything yet.

### C20 — Describe actual observation cadence and missingness

**Comment:** Line 212: full hourly time series for all stations over the two or three years?

**Proposed response:** Checked locally: the sources do not all supply complete hourly series. HadISD retains available observations in the selected years; GNSS records are reduced to near-hour samples; MeteoSwiss retains observations at the full hour; radiosondes are ascent profiles at available launch times. Coverage filters do not guarantee complete time series.

**Suggested edit:** Add source-specific native/retained cadence, coverage requirements and time matching to ERA5. Distinguish ERA5's hourly fields from reference observation frequency. Explain that missing observations remain missing.

**Tasks:** T05. Confirm realised coverage and time matching from retained data and scripts; prepare a compact sampling summary for S1. No new downloads are needed simply to answer the drafting question.

## 6. Error definitions, summaries and bird weighting

### C21 — Replace “perfect pressure sensor” with an explicit conditional assumption

**Comment:** Line 249: perfect or negligible pressure sensor?

**Proposed response:** Neither description should imply that the reference barometers are literally error-free. The study adds no tag measurement error and treats the supplied reference pressure as exact for evaluating conversion error; reference measurement uncertainty remains a limitation.

**Suggested edit:** “We treat the reference pressure measurements as exact inputs to each conversion and do not add geolocator sensor error.” Qualify residual uncertainty in reference pressure/height separately. Apply the wording consistently to abstract, captions, Discussion and Conclusions.

**Tasks:** T04–T05. Check available reference-sensor specifications before claiming their errors are negligible.

### C22 — Simplify the metric presentation and distinguish station from observation summaries

**Comments:** Line 251: why p90 and p95? Bias/precision are station-level summaries while the other metrics describe measurements; too many metrics.

**Proposed response:** Agree that the hierarchy is obscured. Station bias describes persistent offset; station SD describes temporal scatter. MAE and p95 summarise individual errors. The p90 of station summaries and p95 of individual absolute errors are different quantities; using different probabilities is optional, not essential.

**Suggested edit:** Proposed main-text set: individual-error MAE and p95, supported by median station bias magnitude and SD to explain mechanism. Move p90 station summaries, repeated RMSE summaries and threshold exceedances to the supplement unless a specific argument needs them. Present ground versus flight definitions separately. State that bias is one component of accuracy rather than equating the terms without qualification.

**Tasks:** T06. Map each reported metric to its question and denominator, then make a table/figure retention proposal. If the same percentile is desired at both levels, calculate it in a later authorised analysis step; do not relabel existing p90 values.

### C23 — Rewrite the surface-referenced flight error

**Comments:** Line 253: very hard to understand; remove the long height-bin list.

**Proposed response:** Agree. Define estimated and observed vertical separation first, then their difference. This also makes clear that the statistic excludes an absolute surface offset and does not validate every field ground-calibration procedure.

**Suggested edit:** “For each sounding, we compare the estimated vertical separation between an airborne level and the surface with the separation reported by the radiosonde. Subtracting these gives the flight-height error.” Follow with \(e_h=(\hat z_{\mathrm{level}}-\hat z_{\mathrm{surface}})-(z_{\mathrm{level}}-z_{\mathrm{surface}})\). Give the same-sounding reference explicitly. Move exact bin boundaries to S1 or a table note.

**Tasks:** T06. Confirm the equation against `scripts/18_three_formulas.R`, including level-specific ERA5 times. Review uses of “height above ground” so this surface-referenced quantity is not confused with height above terrain along a moving bird's route.

### C24 — Decide on flight-duration and low-altitude filters

**Comment:** Line 253: trim flights around a two-hour criterion and/or altitudes below 50 m; near-ground flights may not be the focus.

**Proposed response:** A filter changes the target population and therefore the bird-weighted result. It should follow the biological question and a sensitivity comparison. Checked locally: `scripts/00_bird_heights.R` currently applies neither an explicit two-hour duration filter nor a 50 m exclusion; residual negative heights are assigned to ground level. The wording “flight longer than 2hr” is ambiguous about whether to retain or remove those flights.

**Suggested edit:** Describe the current flight definition and ground-offset treatment transparently. If the intended target is sustained migratory flight, label a restricted summary accordingly; retain separate near-ground reporting for conservation applications. Do not silently discard low flights from a purported all-flight distribution.

**Tasks:** T07. Define the intended direction of the duration threshold, then plan an all-flights versus duration-filtered versus height-filtered comparison. Include below-ground handling, sampling cadence, retained flight hours and representation by bird/species.

### C25 — Establish whether radiosonde cell weighting matters

**Comment:** Line 253: are there even multiple sondes in one 2° cell?

**Proposed response:** Checked locally: radiosonde selection uses the same thinning rule as surface stations, retaining extra high-elevation stations. That permits multiple stations in a cell, but the actual frequency and effect have not been quantified here. Station sampling frequency and within-cell multiplicity are separate weighting issues.

**Suggested edit:** State the purpose briefly in Methods and move implementation details to S1. Report whether the weighting materially changes the conclusions once checked; do not assert that it matters or is negligible without the comparison.

**Tasks:** T06. Count retained stations per cell and compare equal-cell with equal-station summaries, keeping observation-level weighting explicit.

## 7. Declaration placeholders

| Location | Outstanding item | Preparation task |
|---|---|---|
| Line 477 | Funding: “To be completed.” | T09: obtain funders and grant identifiers or confirm the appropriate no-funding statement. |
| Line 479 | Authors' contributions: “To be confirmed.” | T09: confirm authorship roles and wording with the authors. |
| Line 481 | Acknowledgements: “To be completed.” | T09: compile names, provider acknowledgements and any required permissions. |

These require author input; no statements have been filled in.

## 8. Larger task briefs

### T01 — Literature search: biological applications of altitude and pressure

**Addresses:** C01–C03. **Priority:** first, before restructuring the introduction.

**Starting material:** `literature/reference_inventory.csv`, `docs/literature/README.md`, `paper/references.bib`, available PDFs, and `archive/report/literature-review-and-paper-positioning.md`. Existing inventories and summaries are leads, not verified evidence.

**Search plan:** Search scholarly indexes from database inception to the search date using combinations of `(bird* OR avian OR raptor* OR seabird* OR passerine*)`, `(pressure OR barometr* OR altimet* OR multi-sensor OR multisensor OR geolocator*)` and `(altitude OR flight height OR elevational movement OR migration OR soaring OR roost*)`. Run focused searches for woodland kingfisher, wheatear and ring ouzel; follow backward/forward citations from the existing migration, ground-movement and raptor studies. Add complementary searches for altitude applications that use other instruments, marking those separately.

**Extract:** Species, biological question, device and measured variable, pressure-to-altitude conversion, atmospheric/ground reference, vertical datum, validation, demonstrated finding, and exact supporting passage. Separate measured pressure, inferred altitude and other pressure uses such as weather-related behavioural responses.

**Deliverable:** Deduplicated evidence table, gaps needing full text, and a short shortlist supporting each biological motivation. Select a few strong examples for the introduction rather than expanding it into a catalogue. Describe this as a scoped literature review unless a systematic-review protocol is actually followed.

### T02 — Literature search: alternative altitude measurements and GPS context

**Addresses:** C01, C04. **Priority:** alongside T01.

**Search plan:** Start from Péron, Poessel, Lato, Schaub, Johnston and optical-rangefinder comparisons in the inventory. Search avian flight-height validation with GPS/GNSS, pressure sensors, radar, optical/rangefinder methods and combined sensors. Distinguish individual year-round tracking from population-level observation and local validation instruments.

**Extract:** Tag mass and deployment duration where relevant, altitude reference, temporal resolution, raw versus processed GPS, calibration, field reference, bias/scatter, and constraints on small migrants. Verify contemporary device-capability claims rather than assuming a permanent size boundary.

**Deliverable:** Comparison table and a proposed short scope paragraph explaining why pressure loggers are the focal application and where pressure-equipped GPS tags fit. Do not rank methods globally from incomparable validation designs.

### T03 — Literature audit: conversions, evidence and novelty

**Addresses:** C01–C09, C14. **Priority:** before rewriting the conversion-history and gap paragraphs.

**Work:** Read original methods and supplements for the cited ecological conversions. Tabulate reference altitude/pressure, pressure source, temperature input, humidity, lapse rate/profile, local calibration, vertical datum, location uncertainty and evaluated error. Check pamlr and GeoPressureR implementation/version claims. Broaden to aviation and atmospheric methods where they directly explain a candidate correction or comparable validation.

**Deliverable:** Conversion matrix, claim-to-source ledger with page/section and numerical context, and an evidence-based gap statement. Explicitly identify what prior studies establish about devices, surface pressure, temperature profiles and ecological consequences. Verify “these authors,” “most conversions” and claims of feasibility/novelty.

### T04 — Technical verification of atmospheric methods

**Addresses:** C06, C09–C14, C18, C21. **Priority:** before methods edits.

**Work:** Check hydrostatic derivation, log-pressure temperature mean, lapse-rate sign/units, humidity calculation, and geometric versus geopotential height. Trace the complete implemented corrected conversion, including any lapse-rate limits, GPT3 harmonic phase and spatial interpolation. Compare with authoritative formulas and the relevant package/reference implementation. Separate what the code does from what a source recommends.

**Deliverable:** Short verified method note with proposed equations and replacement prose, plus an explicit list of approximations and any discrepancies requiring a later implementation decision. Investigate full-profile ERA5 as a discussion option; no new conversion implementation is part of this task brief.

### T05 — Dataset provenance, coverage and independence audit

**Addresses:** C16–C21. **Priority:** before finalising reference-data claims.

**Work:** Audit product citations, versions, temporal windows, selection criteria, native/retained cadence, realised gaps, time matching, sensor-height provenance and vertical reference. Establish how much assimilation status can actually be documented for each selected network and pressure variable. Assess MeteoSwiss's unique overlap/terrain contribution and dependencies of current claims.

**Deliverable:** Dataset provenance/sampling table, supported assimilation wording with uncertainties, a documented explanation of year selection, and a keep/move/remove recommendation for MeteoSwiss presentation. Distinguish published dataset age from analysed observation dates.

**Completed, 18 October 2026:** [Audit and implementation record](../methods/T05/audit.md), [dataset table](../methods/T05/dataset-provenance.csv), realised station-year coverage, timing counts and cached-formula checks. C16–C21 edits implemented in the main manuscript and S1/S4. Missing historical metadata and station-record assimilation status remain explicit limitations, rather than presumed facts. Retain MeteoSwiss for the paired height-metadata check; T08 will address figure prominence. GNSS duplicate-hour sensitivity is added to T06.

### T06 — Simplify metric reporting and check spatial weighting

**Addresses:** C22–C23, C25. **Priority:** decide presentation before editing Results tables.

**Work:** Map station summaries and individual-error summaries to their scientific purpose. Propose a reduced main-text metric set and allocate the rest to the supplement. Add a paired GNSS check with/without repeated station-hours identified by T05, preserving the station selection and comparing all three conversions; determine whether deduplication warrants regenerating numerical outputs. Verify flight-error algebra/time matching and bin definitions. Quantify stations per cell, including high-elevation additions, and plan equal-cell versus equal-station comparisons.

**Deliverable:** Proposed main/supplement metric layout, plain-language definitions with denominators, and a narrowly scoped list of comparisons or recalculations needed. Existing numerical outputs must not be relabelled as different statistics.

**Completed assessment, 18 October 2026:** [T06 evidence and recommendations](../methods/T06/recommendations.md) and a [439-word S1 replacement draft plus rules table](s1-simplification-proposal.md). All three conversions were compared under station screens/weighting, 200 within-cell station draws, GNSS duplicate handling, and flight weights/1–30–100 sounding minima per band. Main conclusions survive; ground MAE/p95 depend materially on the offset screen, while some high-flight tails depend on weighting. The 648 retained radiosonde stations occupy 648 distinct cells. A height-only re-expression of the same Swiss HadISD series strengthens the case for retaining MeteoSwiss as an appendix metadata check. Recommend retaining the spatial sample and current primary flight weights with an accurate definition/sensitivity appendix; limited cached-data updates for GNSS duplicates and post-QC ground cell weights, rather than a new full sample. No primary manuscript numbers or figures changed.

**Author-approved implementation:** [Current implementation record](../methods/T06/implementation.md). Recommendations are applied in code, main text, S1/S4 and figures. Existing primary flight tables are unchanged; the three primary ground tables were regenerated after the small processing/weight corrections. The original assessment numbers and S1 proposal remain historical notes.

### T07 — Bird-weighting sensitivity and definition of target flight

**Addresses:** C24 and the interpretation of C22–C23. **Priority:** settle the biological target before choosing filters.

**Work:** Resolve the direction and rationale of the two-hour threshold. Plan contrasts for all flight, sustained flight, exclusion of <50 m points, and their combination, using a common conversion comparison. Inspect cadence, duration classification, negative-height handling, tag/species contributions and dependence of the weights on the original altitude conversion. Distinguish total flight-time weighting from equal-bird weighting.

**Deliverable:** Predefined sensitivity table layout reporting retained birds/flights/hours, height distribution, weighted errors for all three conversions, and changes in conclusions. Keep the low-height radiosonde results separate from decisions about the bird-weighted target. Assessment completed; see the evidence and recommendation below.

**Completed assessment and author-approved implementation, 18 October 2026:** [T07 recommendations](../methods/T07/recommendations.md) and [implementation record](../methods/T07/implementation.md). The published Master GeoLocator Data Package version 2026.0 (doi:10.5281/zenodo.18187093) replaces the older biological weights; local public files match its checksums. Only 203 tags with usable classified flight pressurepaths contribute (25 species, 34,580 represented hours). All classified flight remains primary, with ≥2 h, ≥50 m and equal-bird contrasts in S4. The citation, bird count, weighted results, supplementary fitted comparisons and figures are updated. The previous restricted-data assessment is preserved in T07/baseline. The public/local snapshot and non-flight-tag count issues are resolved; no new biological or altitude-specific reference filter is applied. Upstream processing remains as published; the paired height-formula check covers only 18 tags with complete annotations. The conversion ranking remains unchanged.

### T08 — Figure 1 redesign and palette audit

**Addresses:** C15. **Priority:** after C10–C13 are settled.

**Work:** Audit conversion colours/line styles in all main figures and relevant supplement figures. Propose a simpler Figure 1 with a clear radiosonde reference, short annotations and an explicit relation between assumed temperature and height error. Check readability at final size and identify which explanatory details move to the caption/supplement.

**Deliverable:** Shared visual standard and palette, then individual figure specifications, caption edits and verified graphics.

**Design definition completed, 18 October 2026:** [T08 figure standard](T08/figure-style.md), [machine-readable palette](T08/palette.csv) and [visual preview](T08/palette-preview.png). The author requests sparse, result-driven scientific figures: empirical detail under summary curves, direct labels and anchored numerical results, without titles, subtitles or narrative text inside the artwork. Conversion identities are slate/dotted for standard atmosphere, charcoal/long-dashed for ERA5 standard lapse rate and teal/solid for virtual temperature + GPT3; observations use explicit reference markers. The source-level audit identifies the next changes for each main figure and the supplement. Figure 1 is now implemented with an updated caption and S5 selection explanation; the shared conversion palette and main graphics are updated. Remaining layouts await individual review; T08 stays open.

### T09 — Author-supplied declarations

**Status:** Skipped at the author’s request; no declaration text invented or changed.

**Addresses:** Funding, contribution and acknowledgement placeholders. **Priority:** before submission.

**Deliverable:** A concise author-information checklist and confirmed declaration text when the information is available. No messages to coauthors or invented declarations.

### T10 — Location uncertainty and the proposed 50 km appendix

**Addresses:** the author's follow-up on uncertain coordinates; complements C21 and the terrain-clearance Discussion. **Priority:** after T05 establishes reference/sampling provenance and before making any claim that position uncertainty is negligible.

**Work:** Follow [the paired experiment specification](location-sensitivity-plan.md). Keep observed pressure, time and truth fixed while querying weather/orography/GPT3 at displaced locations, beginning with 50 km in eight directions and balanced flat/mountainous and seasonal samples. Separate absolute altitude, the existing surface-referenced flight metric, terrain subtraction and any location-dependent uncertainty lookup. Keep the standard atmosphere as a location-independent control. Do not interpret directional cancellation of signed errors as robustness.

**Deliverable:** Compact appendix figure of MAE and error SD versus 0–200 km displacement, plus paired-change/MAE tables and query counts. The author-approved small pilot uses ten climate/roughness-stratified stations, eight seasonal launches each and a fixed layer near 2 km: [active design](../methods/T10/design.md). The broader terrain-clearance and uncertainty-lookup experiments remain outside this pilot. The completed pilot reproduces its central ERA5 standard-conversion error to within 5.5×10⁻¹² m and confirms the location-independent standard-atmosphere control. At 50 km, virtual/GPT3 MAE rose by 0.6 m in absolute altitude and 0.5 m in surface-referenced height, while 95th-percentile paired changes were 21.1 and 22.6 m. At 200 km, its MAE rose by 4.6 and 2.2 m, respectively. These are descriptive results for a balanced ten-station, 80-sounding pilot; per-bearing changes can be much larger than the mean MAE increment. See [T10 implementation/design](../methods/T10/design.md), code, cached input fingerprints and S6.

## 9. Suggested sequence (updated after author approval)

1. T01–T03 scope decisions and the authorised introduction/discussion edits are implemented.
2. T04 and T05 are complete: see the [T05 audit](../methods/T05/audit.md), realised coverage tables and provenance record. The manuscript and supplement now reflect these findings.
3. T06 is implemented and checked: see its [implementation record](../methods/T06/implementation.md). The cached-data rebuild now includes steps 18–20 and both document renders. T07 is implemented using the checksum-verified published bird release, with noncontributing tags excluded and its target-flight sensitivity in S4. No new biological or altitude-specific filters were applied to primary results. The station map/ground panels were updated for appendix placement; the T08 Figure 1 redesign is now implemented, with remaining layouts awaiting review.
4. T10 pilot and S6 appendix are implemented for the limited near-2-km atmospheric-query question; the known-position and separate terrain-clearance limitations remain explicit.
5. T08 is closed at the author's request; resume figure-by-figure review only if requested. T09 is skipped at the author’s request.

The historical proposals above are retained for traceability. The latest status table distinguishes implemented edits, checked approximations and pending analyses; the earlier planning-only statements no longer describe the current manuscript state.

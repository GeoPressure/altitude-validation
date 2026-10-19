# Discussion revision — 19 October 2026

The Discussion in `paper/paper.qmd` was rewritten around practical use for bird tracking, following the author's request to restructure freely and make it substantially tighter. The finalized Introduction, Methods and Results, the Conclusions, and all numerical analyses were preserved. Narrative length fell from approximately 1,844 to 1,086 words, excluding the executable table chunk (about 41%).

## Revised argument

1. **Choose the conversion and interpret its error correctly.** Lead with ERA5 single-level surface conditions and the virtual-temperature/GPT3 correction for flight height. Explain the distinction between reference offsets, station scatter, individual errors and the bird-weighted summary. Keep the mechanisms needed to support these choices.
2. **Match the error to the biological question.** Discuss migration-height comparisons, seasonal and day/night contrasts, terrain clearance and turbine-height thresholds. Use height-specific tails to explain why an overall bird-weighted summary cannot be applied to every high flight or used as complete uncertainty near the ground.
3. **Connect atmospheric conversion with calibration and alternative profiles.** Retain local known-height anchors, controlled and field validation, existing variable-lapse methods, and the question of when time-specific atmospheric profiles justify additional data retrieval.
4. **Define what transfers to deployed tracking records.** Keep the reference screen, radiosonde height dependence, potential assimilation dependence, land-based coverage, balloon drift and empirical bird-weight limitations. Finish with practical reporting guidance for both geolocators and pressure-equipped GPS tags.

## Summary table

The numerical conversion summaries are unchanged. The table now contains only the quantities evaluated in this study; the speculative “Sensor adds” column was replaced by a concise discussion of sensor offset, drift and relative error. “Change at one site” was relabelled “Within-station scatter”: a station SD is not the error distribution of the difference between two observations. The caption distinguishes the ground station summaries from individual surface-referenced flight errors and states the excluded sensor component and remaining reference-height uncertainty.

## Material removed or consolidated

- Repeated inventories of main Results numbers and separate, overlapping recommendations.
- The unsupported claim that weather explains little additional variation; the retained interpretation refers to displayed environmental profiles.
- The precise “1–1.5%” generalization about airborne bias; the interpretation now follows the observed station bias and scatter in the reporting band.
- The pressure-RMSE literature comparison, whose metrics and reference conditions did not support a direct comparison with the present altitude medians.
- Detailed lists of field-study numerical errors and calibration examples; retained studies establish methodological context without creating an accuracy ranking.
- An unquantified claim that sparsely observed regions probably have larger errors; the revised text identifies limited coverage and the need to test transfer.
- The historical five-station comparison from the main Discussion; it remains available as a descriptive supplementary result.

No new priority claim, sensor accuracy specification, GPS-versus-barometer ranking, global location tolerance, offshore validation or turbine-classification validation was introduced. The correction is presented as reducing one component of uncertainty, with particular attention to the different meanings of absolute altitude, surface-referenced flight height and local ground clearance.

## Evidence checks

The retained literature comparisons were checked against the locally archived full texts of Lindström et al. (2021), Lato et al. (2022), Schaub et al. (2023), Johnston et al. (2023) and Simonetti & García Crespillo (2024), together with the repository's reviewed calibration and conversion evidence. Existing bibliography keys were reused. The table still reads the same cached numerical outputs and the two retained height-specific p95 values are generated inline from the primary tail table.

## Validation

The manuscript rendered successfully to PDF and HTML. The revised Discussion and summary table were visually checked in the PDF; there is no table clipping or missing text. Citation keys and manuscript cross-references resolve, and both inline p95 summaries render from the primary tail table (86 m at 2–3 km; 22 m at 100–250 m). Evaluating the original and revised table chunks confirms that all 18 numerical conversion summaries are unchanged. A source comparison confirms that everything before the Discussion and from the Conclusions onward remains identical to the pre-edit manuscript. No analysis or figure-generation pipeline was rerun.

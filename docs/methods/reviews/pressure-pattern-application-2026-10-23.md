# Application and simplification of pressure-only screening

## Selection procedure

The primary selection applies the pressure-pattern checks from `R/ghcnh_pressure_patterns.R`, together with the existing spike, discontinuity, rapid-reversal and frozen-value checks. All decision inputs are station pressure, report times, archive quality, coverage and independent terrain/reference information. ERA5 comparisons evaluate the resulting sample after selection.

A failed period causes backwards search for the latest qualifying twelve-month window. It does not permanently remove the station. A different candidate is considered if the station has no qualifying window. Full-history pressure evidence identifies persistent steps and noisy episodes before window selection; clipping a support period at the candidate-year boundary cannot erase a confirmed failure. Noise episodes extend between the actual reports supporting the flagged block, rather than its calendar boundaries. A year fails if it overlaps such an episode. A discontinuity fails a year when both bounding reports lie within it.

## Applied result and residual review

The sample retains the same 2,179 stations. Nineteen station years move backwards: eighteen because of sustained irregularity and one because of a persistent step. No replacement station is needed. The selected report count changes from 11,683,676 to 11,687,510 because the recovered years have different reporting coverage. The initial within-year trial identified seventeen affected stations; full-history confirmation also changes the boundary years at BRM00081729 and FPI0000NTAT.

| Motivating station | Previous ERA5 error SD (m) | Selected-year ERA5 error SD (m) |
| --- | ---: | ---: |
| La Quiaca | 24.84 | 6.44 |
| San Luis | 14.08 | 5.28 |
| Halvfarryggen | 29.41 | 7.58 |
| Xining | 6.52 | 6.52 |

La Quiaca now uses 18 March 2024–18 March 2025, before the pressure step. Its mean error changes from −18.3 to +31.3 m: removing a transition reduces scatter but does not guarantee a smaller absolute mean offset. San Luis uses 15 February 2024–15 February 2025, and Halvfarryggen uses 16 December 2024–16 December 2025. A few isolated excursions remain near the end of Halvfarryggen's year; its large terminal disturbance is avoided. Xining remains unchanged because its pressure series is coherent under the applied criteria.

The station-weighted median absolute ERA5 error is essentially unchanged (4.2471 to 4.2460 m), while its 95th percentile decreases from 29.1727 to 29.0564 m. The number of stations with ERA5 error SD above 20 m decreases from 34 to 31, and those above 50 m decrease from six to five. The median absolute station mean bias changes from 3.2318 to 3.2259 m. These are modest aggregate changes despite substantial improvement in the motivating examples, consistent with the robustness of the median summaries.

All 34 residual records with absolute mean ERA5 error above 150 m or error SD above 20 m were plotted and visually inspected. Four records remain above the mean-bias threshold: Limoncocha (+2,183 m), Xining (+168 m), Sinan (+157 m) and Kithira (−155 m). For comparison, 34 stations have absolute ISA mean error above 150 m; 26 of these have absolute ERA5 mean error below 25 m and remain represented. ISA departures are therefore not used as station-fault criteria. The four large ERA5 biases are persistent-offset cases, not the intermittent-noise pattern targeted here. Their bias does not itself establish a pressure-only rejection reason.

The residual plots contain clear transitions across gaps, including Barcelos, Valenca do Piaui and Curaca. Several Brazilian records change pressure level after a common late-March/early-April 2026 reporting gap. Their new levels can persist despite low short-term irregularity. Other residual patterns include apparent reference changes around 1 January at Jarud Qi and Mengla, isolated excursions adjacent to sparse reporting, and recurring error scatter at the French Southern Islands stations. Pressure-only discrimination is harder for these cases than for the three motivating examples; the current screening does not remove every erroneous report.

## Additional gap-step experiment

A separate exploratory test uses the same principle of stable, separated pressure levels across a gap. Candidate transitions differ by at least 10 hPa across 24 hours to seven days. Four weeks on either side supply daily medians from at least four reports; every week must contribute at least one such day and each side at least twelve days. The range of weekly medians on each side must be at most one quarter of the observed jump. Every following weekly median must remain displaced in the jump direction by at least half its magnitude relative to the preceding weekly reference. Confirmation can use pressure reports outside the selected year; both transition endpoints must be inside it for the trial flag.

The trial identifies eleven transitions in ten Brazilian stations: BRM00081870, BRM00081984, BRM00081792, BRM00086671, BRM00081711, BRM00081638, BRM00081609, BRM00086703, BRM00081648 and BRM00081890. All ten plots show a large change in ERA5 error after the pressure transition. This agrees with a reporting/reference problem around the shared gap, but the cause has not been independently established. An initial version with a looser half-jump stability limit and four supported days per week also marked weather-like changes at four non-Brazilian stations; this exposed the need to test specificity rather than simply lower the large-jump cutoff.

This gap extension remains an experiment, not part of the applied selection. Its cutoffs were developed on these residuals, and its effect on full-history backwards selection has not been established. The appropriate next candidate improvement is to extend the discontinuity family with this supported gap-transition calculation, rather than add more unrelated noise tests. It will still miss unsupported or gradually evolving faults.

## Can the checks be combined?

The five episode components form three interpretable failure families: pressure discontinuities (large jumps and supported smaller steps), excessive irregularity (rapid reversals and sustained increased irregularity), and frozen values. Isolated-spike cleaning and coverage remain separate operations with different purposes.

The omission experiment reruns backwards-year selection for each of the original 2,179 candidates, omitting one episode component at a time. A changed result means a different latest qualifying year or a change in availability. It is a comparison of selection decisions, not a count of independently confirmed sensor faults or an estimate of sensitivity.

| Omitted component | Candidates with changed selection |
| --- | ---: |
| Large jumps | 183 |
| Rapid reversals | 8 |
| Sustained irregularity | 18 |
| Smaller persistent steps | 1 |
| Frozen values | 2 |

Every component makes a distinct contribution under the applied thresholds. Grouping them into three families simplifies the procedure and its explanation; deleting a component is not supported by this comparison. The comparison holds candidate identities fixed and does not count downstream replacement stations. It also does not assess removing isolated-spike cleaning or coverage.

## Reproduction

Run `Rscript run_all.R ground_selection prepare analysis figures check` to rebuild selection and results. Run `Rscript scripts/drafts/evaluate_pressure_application.R` afterwards to compare the rebuilt sample with the saved preceding sample and plot all remaining stations with absolute ERA5 bias above 150 m or error standard deviation above 20 m. These are review thresholds, not acceptance criteria. Run `Rscript scripts/drafts/pressure_rule_ablation.R` for the rule-omission comparison. Run `Rscript scripts/drafts/test_gap_steps.R` and `Rscript scripts/drafts/plot_gap_steps.R` for the separate gap experiment. Outputs are in `output/drafts/pattern-application/`.

## Verification

The complete selection, preparation, analysis, figure and checking run completed successfully (`logs/pattern-application.log`). Every accepted year passes the combined full-history pressure checks, exact equality to the cleaned source reports and monthly coverage. Integration checks confirm station identities, cell balance, row counts, selected windows, direct conversions and summary consistency. The deterministic spike, episode and pattern controls also pass. Updated manuscript method descriptions are in `paper/paper.qmd` and `paper/supplement.qmd`; the document PDFs and HTML were not rerendered in this application run.

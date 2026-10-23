# Experimental pressure-only pattern checks

This note records the initial trial. The subsequent application, full-history episode handling and rule-omission comparison are described in [the application review](pressure-pattern-application-2026-10-23.md).

This experiment evaluates two additional screening rules against the 2,179-station curated sample. The rules use only pressure and time. ERA5 errors are plotted afterwards to assess the detections; they are not inputs to either rule. These exploratory rules are not yet part of the primary selection, and no accepted station or year is changed by this experiment.

## Sustained change in short-term irregularity

For three equally spaced consecutive reports, define irregularity as the absolute departure of the middle pressure from the mean of its neighbours, divided by the spacing in hours. Use only triplets with spacing of one to three hours and compare each spacing separately. This measures departure from a locally linear pressure trajectory; it is a screening statistic, not an estimate of instrument noise variance.

Summarise irregularity in fixed 14-day blocks. A block needs at least 30 supported triplets on at least seven distinct days. For each report spacing, the reference is the 20th percentile of block-level 90th percentiles across the available cleaned pressure history. A trial flag requires the block's 90th percentile to reach 1.5 hPa/h, exceed four times its historical reference (with a 0.1 hPa/h reference floor), and contain at least ten triplets above 1 hPa/h. Only triplets wholly inside the selected year contribute to its evaluated blocks. Historical data supply the reference level, not evidence that an out-of-window failure occurred inside the selected year.

This catches both deterioration and improvement: an earlier noisy regime can be identified relative to a later quieter one. It need not infer a unique change date. It can miss a record that is uniformly bad throughout its available history, gradual drift, sparsely reported faults, or broad smooth excursions with little short-term irregularity. A strong real weather event can also trigger it. The fourfold and absolute thresholds are exploratory choices assessed against the reviewed examples, not independently calibrated scientific limits.

## Smaller abrupt pressure step

Test an hourly pressure change of at least 4 hPa when both neighbouring hourly changes are no more than one third as large. Require the jump to exceed six times the median absolute hourly change within 14 days on either side, with a 0.1 hPa scale floor. Require at least 18 reports in each adjacent 24-hour period, and a difference between the two pressure medians with the same sign as the jump and at least half its magnitude. Both 24-hour periods must lie wholly inside the selected year.

Then require four weeks before and four weeks after the jump, entirely within the selected year. Compute daily medians from days with at least 18 reports and weekly medians from at least four such days. All eight weeks must be supported. The range of weekly medians must be no more than half the jump magnitude on each side separately. Every following weekly median must differ from the median of the four preceding weekly medians in the jump direction by at least half the jump magnitude. This demands stable levels and persistence, rather than only the pressure response to a short-lived front.

This identifies an isolated abrupt transition followed by a sustained level difference. It does not establish that the cause is instrumentation: a real abrupt and persistent weather-regime change remains a potential false positive. It deliberately does not bridge long gaps, and a step within 28 days of a year boundary lacks sufficient within-year evidence. It can miss real sensor changes in a highly variable atmosphere. It is a conservative candidate pressure-discontinuity test, not a complete homogenisation method.

## Reviewed examples

| Station | Noise blocks | Abrupt steps | Interpretation |
| --- | ---: | ---: | --- |
| La Quiaca, ARI0000SASQ | 0 | 1 | The 18 March 2025 22:00 UTC rise is 5.9 hPa, versus a local median hourly change of 0.4 hPa (ratio 14.75). The adjacent 24-hour pressure medians are 671 and 677 hPa. Weekly medians span 1.95 hPa before and 0.40 hPa after; all four following weeks remain at least 3.24 hPa above the preceding reference. |
| San Luis, COI0000SKIP | 11 | 0 | The noisier period before the source transition has block irregularity around 1.65–2.30 hPa/h; the historical hourly reference is 0.399 hPa/h. The later quieter regime is preserved by this test. |
| Halvfarryggen, AYM00089003 | 2 | 0 | The blocks starting 13 and 27 December 2025 reach 1.945 and 2.325 hPa/h, versus a historical reference of 0.2 hPa/h. These coincide with the late pressure excursions. |
| Xining, CHI0000ZLXN | 0 | 0 | The largest evaluated block irregularity is approximately 0.597 hPa/h, below the absolute threshold; the coherent series remains unflagged. Its persistent ERA5 offset is a separate reference question. |

The noise flag marks a period, rather than declaring every report in it erroneous. In particular, Halvfarryggen's flagged blocks overlap the late disturbance but do not delimit every excursion precisely. A production implementation would need explicit episode boundaries and the existing backwards-year selection, rather than simply removing a station forever.

The initial 24-hour-only step screen marked 126 stations. Visual review showed multiple weather-like transitions with no lasting change in ERA5 error, including Breakwater, Cape Sorell and Chatham Island. That broad version is unsuitable as an automatic exclusion rule. The four-week stability and persistence requirement is intended to distinguish persistent offsets from those temporary pressure changes. Its thresholds were developed during this investigation, so the resulting detections are exploratory rather than a held-out estimate of detection accuracy.

## Full-sample result

The final trial marks 16 stations for increased irregularity and one for a persistent abrupt step, with no overlap: 17 of 2,179 stations (0.78%). La Quiaca is the only station meeting the final step rule. San Luis and Halvfarryggen meet the irregularity rule, and Xining meets neither rule. The full scan completed successfully, and the deterministic synthetic checks passed. The primary accepted sample remains unchanged.

At the same fourfold historical-reference requirement, reducing the irregularity threshold to 1.0 hPa/h marks 18 stations and increasing it to 2.0 hPa/h marks nine. A sixfold requirement at 1.5 hPa/h marks six stations but misses San Luis. The persistent-step result remains La Quiaca alone at minimum jumps of 4 or 5 hPa; a 6 hPa threshold misses its observed 5.9 hPa transition. These comparisons expose sensitivity to the chosen thresholds rather than establish optimal values.

The plotted additional detections include substantial changes in error scatter at Itirucu, Diori Hamani and Pichit Agromet, episodic errors at Mangareva and Soldotna, and smaller changes at other stations. Some detections, such as Bettles' winter irregularity, need closer examination of reporting sources and weather before being treated as sensor faults. Agreement with the three motivating examples and synthetic controls does not establish that every one of the 17 is erroneous, nor measure the number of missed faults. The recommended next implementation step is to review the additional detections and test rejection of affected years with recovery of earlier qualifying years, while retaining the existing ERA5-independent selection principle.

## Verification and reproduction

`R/ghcnh_pressure_patterns.R` contains the experimental calculations. `Rscript tests/check_ghcnh_pressure_patterns.R` checks smooth weather, changing weather amplitude, reporting-cadence changes, sustained random irregularity, isolated spikes, abrupt steps and selected-year boundaries. The synthetic controls are deterministic and pass; they do not establish a field false-positive rate.

Run `Rscript scripts/drafts/test_pressure_patterns.R` to evaluate the current sample and write `output/drafts/pressure-pattern-tests/`. `station_results.csv` contains detection counts, `noise_blocks.csv` contains block scores and historical references, `step_candidates.csv` contains candidate jump evidence, and `threshold_sensitivity.csv` compares alternative numerical cutoffs. The figures show the four target cases and a reproducible random sample of other detections. Their columns are pressure with candidate periods marked, pressure irregularity and ERA5 error for evaluation only. The log is `logs/pressure-pattern-tests.log`.

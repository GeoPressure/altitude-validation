# Simple pressure-only station filtering plan

Author-facing research plan, 23 October 2026. Revised objective: define a short, deterministic filtering procedure using station pressure and timestamps, then use ERA5 only to evaluate the resulting sample. Catch clear recording failures without trying to remove every erroneous record. The four-rule procedure has now been implemented; fixed thresholds, verification and the active selection path are documented in [the implementation record](pressure-only-filtering-2026-10-23.md). The planning text below records the agreed scope.

## Principle

Apply the same numerical rules to every candidate. Use archive QC, pressure, timestamps and independently documented station metadata for selection. Do not use ERA5 residuals, ERA5-derived heights, lag improvements against ERA5 or the ranking of ERA5 errors in an acceptance decision. Source identity alone is not a rejection criterion.

The previously inspected examples identify realistic failure patterns to target. Define thresholds from their raw pressure behaviour and a sample of ordinary pressure records, without optimising the resulting ERA5 agreement. Keep the first version small: isolated spikes, repeated rapid noise, large jumps and frozen pressure.

## Proposed rules

| Pattern | Objective metric | Selection action |
|---|---|---|
| Isolated spike | Existing bracketing rule: a large departure from both nearby neighbours, neighbours agreeing with each other, and the established elapsed-time/rate conditions. | Remove the individual observation before checking coverage. |
| Repeated rapid noise | Consecutive pressure-change rates, with repeated sign reversals above a fixed amplitude and rate. Count these reversals within a fixed short window and require a minimum number of closely spaced reports. | Reject a candidate year containing a qualifying noisy episode. |
| Large jump | Absolute pressure difference between consecutive reports, conditional on elapsed time. Initially retain the current limits: more than 20 hPa within three hours or more than 50 hPa within seven days. | Reject a candidate year crossing a qualifying jump. |
| Frozen pressure | Duration and report count of a consecutive exactly equal-pressure run, with a maximum permitted gap between reports. | Reject a candidate year containing a qualifying frozen run. |

For the noise rule, calculate r[i] = (p[i] - p[i-1]) / elapsed_hours[i]. A reversal requires r[i] and r[i+1] to have opposite signs, both pressure changes to exceed a fixed amplitude, and both rates to exceed a fixed rate threshold. Restrict the calculation to sufficiently close reports. Count qualifying reversals in a short moving window. The amplitude condition avoids treating fine-resolution jitter as a failure; the rate and repetition conditions distinguish rapid oscillation from a broad pressure trend. A station-wide SD is unsuitable because it combines weather variability with recording noise and can hide short bad episodes.

Do not adopt numerical noise or frozen-run thresholds before inspecting their raw-pressure examples. Evaluate a small, explicit set of candidate thresholds and choose conservative values that detect obvious failures while preserving coherent weather changes. Duration and minimum report count must both be specified so sparse reporting cannot create an apparent long frozen episode.

Keep smaller sustained shifts and short multi-report blocks outside the initial procedure unless the four rules already catch them. Add another rule only if a recurring obvious failure requires it and its raw-pressure signature can be stated simply. Timing shifts and stable offsets can remain undetected when the pressure record alone does not identify them.

## Single selection sequence

1. Apply the existing source-qualified archive failure flags and pressure plausibility limits.
2. Remove isolated spikes using the existing pressure-only rule.
3. Find the latest year satisfying coverage and the jump, repeated-noise and frozen-pressure criteria. A rejected year does not qualify through diagnostic tagging or a sensitivity sample.
4. If no year qualifies, try the next candidate in the existing frozen order within the cell.
5. Use the same accepted observations for every altitude conversion.

Compute episode metrics on the complete cached pressure history, then check each candidate year's overlap with the detected episodes. This avoids recalculating the same metrics for every possible endpoint. Preserve the existing sampling counts and coverage requirements. Retain independently documented metadata conflicts and unsuitable moving-station exclusions.

The primary selection must also stop inheriting exclusions based solely on earlier ERA5-guided curation. Reassess those records through the pressure-only procedure; retain an exclusion only when an objective pressure criterion or independent metadata evidence supports it. The earlier decisions remain useful review evidence, rather than an additional hidden selection rule. Do not automatically preserve timing-mismatch exclusions established only by ERA5 lag comparisons.

## Practical next experiment

Write one linear diagnostic script using the cached pressure records. Include known noisy/oscillating examples, large jumps, frozen runs at Tsampa and Secretary Island, and ordinary records spanning different reporting intervals and climates. Include raw pressure from previously retained difficult cases, without assuming that a previous decision is necessarily correct. Compute the four metrics and inspect a compact set of pressure plots showing exactly which reports or episodes trigger each rule.

Choose and freeze the few missing thresholds using these pressure-only checks. Verify that isolated spikes are removed, repeated rapid oscillations are rejected, a monotonic storm passage is preserved, constant values separated by long gaps do not form a frozen run, and rejection interacts correctly with year boundaries and coverage. Run the same procedure across candidates and replacements. Existing pressure caches can be reused because the proposed additional checks operate after archive intake; an intake-QC change would instead require regenerating affected derived pressure caches.

## ERA5 evaluation after filtering

After fixing the procedure and thresholds, compare its accepted and rejected records against ERA5. Report how much obvious high-noise behaviour remains and the changes in station counts, station-level median bias and robust temporal-scatter summaries. Inspect some remaining discrepancies to understand what the simple rules miss. Do not reject additional records or adjust thresholds merely because their ERA5 agreement is poor.

Accept that some faulty records will remain. Median-based summaries reduce the influence of a minority of extreme observations, but persistent faults affecting much of a station record can still change its median. Keep the aggregation and weighting explicit, and prioritise the repeated-noise, jump and frozen-record rules accordingly.

## Evidence from the previous review

The curation list contains 75 exclusions, including 26 timing mismatches, two frozen records and two reporting-hour mismatches; many other exclusions concern jumps, bad blocks or oscillations. The latest targeted QC audit contains 108 sampled large departures, none marked calculated by the source-qualified code-4 definition. These findings motivate pressure-series metrics rather than further blanket QC-code or source exclusions. They do not supply numerical thresholds for the new rules.

Sources: the chats “Show final manuscript PDF” and “Identify station quality filters”; `docs/methods/ghcnh_curation_exclusions.csv`; the manual-review notes through batch 7; `docs/methods/ground-quality-code-review-2026-10-23.md`; and the current code in `R/ghcnh_sampling.R` and `scripts/sampling/ground_selection.R`.

# GHCNh sampling design assessment — 20 October 2026

This is a pre-implementation review. The active station-selection and analysis pipeline is unchanged. The [appendix proposal](../../manuscript/ghcnh-appendix-process-proposal-2026-10-20.md) and [flowchart](../../../../paper/figures/supp_ghcnh_selection.svg) describe one retained network with direct acceptance and rejection criteria.

## Selection logic

Fix the inventory, search dates, equal-area grid, candidate order and thresholds before evaluating errors. Within each cell, assess candidates in a random order without replacement and accept the first one passing all criteria. This is uniform sampling among passing candidates, provided eligibility is independently defined for each station and there is no arbitrary limit on attempted candidates. Downloads, existing caches and processing speed must not determine candidate order. Cells can be processed independently.

The search has two distinct loops. A coverage failure shifts the 12-month window back one day for the same candidate. Once the most recent coverage-qualified window is fixed, failure of a station criterion rejects that candidate and advances to another station in the cell. Station criteria are not used to search for an older window with a smaller ERA5 discrepancy.

## Numerical conventions

Prepare each candidate's source-QC hourly pressure and matched ERA5 series once over the required search period. Daily window iteration can be a straightforward loop over those local data; repeated downloads are unnecessary. Use calendar-month arithmetic, half-open UTC intervals and distinct matched hours. Reapply window membership after rounding to the nearest hour. Construct every monthly boundary directly from the endpoint, avoiding accumulated rollback at month ends or leap days.

Within each trial window, remove gross observations once using the window median and R's scaled MAD, with the 100 m minimum discrepancy threshold. Recalculate coverage on the accepted hours with complete inputs for all three primary conversions. The proposed monthly criterion is at least 15 UTC dates with at least four accepted hours each in every one of the 12 month-long blocks. The cached-data comparison supports this monthly threshold; see [criterion recommendations](criteria-recommendations.md). Other accepted hours remain available for error summaries.

Compute the gross fraction before gross-observation removal, and the mean discrepancy after removal. ERA5-Land availability should not silently determine the primary three-conversion sample. Use Pa for conversion pressures, K for temperatures and metres for altitude discrepancies. A retrieval failure is a computation failure to resolve, not scientific evidence against the station.

## Required station criteria

A candidate must pass the frequent-gross-observation, persistent-offset and step-change criteria. A detected qualifying discontinuity rejects the candidate. Insufficient history to perform the required step check also rejects the candidate; this deliberately favors stations with enough historical support. Both outcomes take the existing next-candidate path. There is no diagnostic-only station category, separately tagged dataset or additional step-sensitivity stage.

Use up to three years ending at the selected window endpoint for the step check. Retain months with at least 60 observations and require at least 18 monthly medians spanning all calendar months. Fit calendar-month effects and a single breakpoint, restricting eligible breakpoint dates to the selected observation window and requiring three monthly medians on either side, as recommended by the cached-data assessment. Reject the fitted step when its magnitude is at least 10 m and its absolute t statistic is at least 10. Restricting the breakpoint search prevents a larger historical change outside the selected window from replacing the in-window test.

The magnitude/t thresholds define an empirical screening criterion, not a calibrated false-positive probability or proof of instrument failure. Tests near the window boundaries have limited temporal support. These are interpretation limits of the criterion, not reasons to introduce another dataset or processing branch. Detecting every possible discontinuity is not guaranteed.

## Interpretation and outputs

The ERA5-residual-based screen makes the reported errors conditional on reference plausibility. Equal-area cells balance represented locations but do not make the station network representative of unobserved areas or bird habitats. One station per represented cell permits equal station weights; divide each station's total weight equally among its accepted hours. All three conversions use the same observations.

The proposed additional companion network and common-cell comparisons are removed from this intake design. Existing manuscript sensitivity results are not deleted or changed by this planning edit. Only the retained network, the rejection counts needed for the sampling figure, and the inputs needed for the scientific analysis are required. No new diagnostic tagging or parallel sample is proposed.

## Verification

[check_design.R](../../../../docs/methods/ghcnh-sampling-review/check_design.R) exhaustively checks all 120 permutations of five hypothetical candidates: each of the three passing candidates is selected 40 times. It also verifies calendar-year lengths, monthly coverage examples and equal total station weights. Results are in [check_results.csv](../../../../docs/methods/ghcnh-sampling-review/check_results.csv) and [window_examples.csv](../../../../docs/methods/ghcnh-sampling-review/window_examples.csv). These checks validate simple selection and weighting identities, not an unimplemented GHCNh extraction or the physical screening thresholds. The first end-to-end implementation check should establish that window selection, station rejection and replacement follow this specification before starting the full run.

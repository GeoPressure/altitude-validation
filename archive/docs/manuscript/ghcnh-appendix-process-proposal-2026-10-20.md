# Proposed GHCNh appendix methods — 20 October 2026

The [combined Appendix S1 draft](appendix-s1-process-proposal-2026-10-20.md) places this agreed process first, followed by the proposed IGRA process, and specifies where results and complementary references belong.

**Author review draft; numerical criteria agreed and selection pilot implemented.** Supporting evidence is in the [criterion assessment](../methods/ghcnh-sampling-review/criteria-recommendations.md). Measured resources are in the [pilot report](../methods/ghcnh-sampling-review/pilot-report.md); runtime and restart arrangements are in the [implementation plan](../methods/ghcnh-sampling-review/implementation-plan.md).

## Proposed appendix text

### GHCNh station selection

Station pressures, coordinates and reported elevations are obtained from NOAA's Global Historical Climatology Network hourly archive (GHCNh) [@ncei_ghcnh]. One station is selected per represented equal-area cell using the process in Figure S1. Altitude discrepancies below are ERA5-standard altitude minus reported station elevation.

1. **Define candidate groups.**
   - **Domain.** Use data from 1 January 2022 to 13 October 2026 at 00:00 UTC, including the start and excluding the endpoint. Define 200 × 200 km cells in the Equal Earth projection (EPSG:8857), with grid origin (0, 0) m.
   - **Candidates.** Group inventory stations with valid coordinates, reported elevation and an available station file within the domain by cell. Randomize their order within each cell using seed 11.
2. **Assess candidates within each cell.** Proceed in the assigned order until one station is accepted or all candidates are rejected.
   - **2a. Prepare hourly observations.** Retain finite pressures strictly between 300 and 1100 hPa and apply the GHCNh pressure-quality exclusions.[^pressure-quality] Round reports to the nearest hour, assigning half-hour ties to the earlier hour, and retain the first chronological accepted report per hour. Match to ERA5, requiring finite surface pressure, 2 m temperature, dewpoint and orography at the nearest grid cell.
   - **2b. Select the observation window.** Starting at the domain endpoint, test 12-month windows in daily backwards steps. Within each window, an **extreme outlier** has an altitude discrepancy differing from the window median by both more than 100 m and more than ten median absolute deviations (MAD, scaled by 1.4826). Remove these observations, then require at least 15 UTC dates with at least four accepted hours in each of 12 consecutive calendar-month-length blocks anchored to the window endpoint. Retain the most recent passing window; reject the candidate if none passes. All accepted hours in that window contribute to the analysis.
   - **2c. Apply station checks.** Reject the candidate if extreme outliers exceed 1% of matched hours before their removal, or if the absolute mean accepted discrepancy exceeds 30 m plus 10% of the absolute station–ERA5 elevation difference. For the step-change check, use available history over up to three years ending at the selected endpoint. Apply the outlier rule in 2b using this history's median and MAD, and calculate calendar-month median discrepancies from months with at least 60 accepted hours. Require at least 18 medians spanning all 12 calendar months. Fit calendar-month effects and a single step, choosing the breakpoint with the smallest residual sum of squares among dates inside the selected window with at least three monthly medians on either side. Reject a fitted step of magnitude ≥10 m and absolute t score ≥10, or a candidate with insufficient support to fit the model. A rejection advances to the next candidate in the cell.
   - **2d. Retain station.** Accept the first candidate passing 2b–2c and retain its selected window for all three conversions. Leave the cell unrepresented if all candidates fail.
3. **Combine station summaries.** Give each retained station equal weight; for individual-observation summaries, divide that weight equally among its accepted hours.

[^pressure-quality]: Following NOAA's [pressure-quality code definitions](https://www.ncei.noaa.gov/oa/global-historical-climatology-network/hourly/doc/ghcnh_DOCUMENTATION.pdf), exclude codes 2, 3, 6 and 7 (suspect or erroneous), code 5 (removed) for sources 220, 221, 222, 223, 347 and 348, and lowercase codes (failed archive quality checks). Retain other codes and missing codes. Code meanings depend on source; code 5 denotes a passed check for other documented legacy sources.

![GHCNh station selection](../../../paper/figures/supp_ghcnh_selection.svg)

**Figure S1.** GHCNh station selection; numbered boxes correspond to the steps above. Window failures move the endpoint backwards; candidate rejections advance within the cell. Counts of represented cells, accepted stations and candidate rejections will accompany the relevant branches.

## Notes for implementation and interpretation

- Month blocks are constructed directly from the endpoint by calendar-month subtraction. A window starting on 13 October has a first block from 13 October through 12 November; month-end rollback must not accumulate between blocks.
- Window selection uses recency and accepted coverage. Failure of a station check rejects the candidate rather than searching for a different window.
- The t score is an empirical screening score, not a calibrated significance level. The minimum post-break support limits detection close to the endpoint; insufficient historical support rejects the candidate.
- The ERA5-based offset screen makes the retained errors conditional on reference plausibility. This limitation belongs in the interpretation of the resulting validation.
- The [criterion assessment](../methods/ghcnh-sampling-review/criteria-recommendations.md) and [implementation plan](../methods/ghcnh-sampling-review/implementation-plan.md) are author-facing notes. The flowchart is available as [SVG](../../../paper/figures/supp_ghcnh_selection.svg), [PNG](../../../paper/figures/supp_ghcnh_selection.png) and [Mermaid source](../../../paper/figures/supp_ghcnh_selection.mmd). The production analysis is unchanged.

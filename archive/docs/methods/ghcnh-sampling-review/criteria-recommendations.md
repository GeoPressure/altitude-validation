# GHCNh criterion values: assessment using cached data

20 October 2026. These are recommendations for the proposed rebuild, not changes to the production pipeline. The assessment uses 31,177,423 finite matched hourly observations from 2,146 GHCNh stations during 2022–2026. The latest exclusive endpoint is 13 October 2026 at 00:00 UTC, from the saved ERA5 availability file. Each station's rolling window is searched backwards daily, with gross removal and monthly coverage recalculated within trial windows.

## Recommended specification

| Criterion | Recommended value | Reason |
|---|---|---|
| Spatial sampling | One passing station per 200 × 200 km Equal Earth cell, EPSG:8857, grid origin (0, 0) m | Preserves more geographic detail than 250 km; see candidate counts below. Grid size is a design choice, not an error-minimizing parameter. |
| Candidate order | Random order without replacement, seed 11 | Defines selection independently of station errors; the particular seed has no scientific optimum. |
| Available history | 1 January 2022 through the fixed data cutoff | Retains older qualifying windows when recent coverage fails. Three-year context for the step check stays within this available history. |
| Observation window | Most recent passing 12 calendar months, endpoint moved backwards daily | Uses a full seasonal cycle without requiring the same dates at every station. |
| Monthly coverage | At least 15 UTC dates with at least 4 distinct accepted hours in each of 12 month-long blocks | Balanced retention and seasonal coverage; implies at least 720 accepted hours across the year. All other accepted hours also contribute to summaries. |
| Source QC | Retain the current source-specific exclusions and strict 300–1100 hPa pressure bounds | These are source/plausibility rules; they should not be tuned against ERA5 errors. |
| Gross observation | Absolute deviation from the window's median ERA5-standard error exceeds both 100 m and 10 scaled MAD | Removes exceptional observations without trimming the ordinary error distribution. |
| Frequent gross observations | Reject if the gross fraction exceeds 1% | A small set of stations has recurrent extreme discrepancies; results are not very sensitive around this choice. |
| Persistent offset | Reject if absolute mean error exceeds 30 m + 0.10 × absolute station–ERA5 height difference | Allows for vertical extrapolation while excluding large persistent discrepancies. |
| Step-test context | Up to 3 years ending at the selected endpoint; at least 18 monthly medians spanning all 12 calendar months, each with at least 60 accepted hours | Retains seasonal adjustment and adequate historical support without the larger losses from 24 months or 120 hours. |
| Step-test support | At least 3 monthly medians on each side of an eligible breakpoint inside the selected window | Extends the check towards the endpoint relative to six medians per side. |
| Step rejection | Fitted magnitude ≥10 m and absolute t score ≥10; reject if the required fit cannot be performed | Keeps a conservative, substantive discontinuity criterion in the single acceptance path. |

The date cutoff is a frozen analysis choice. This review establishes what the existing cache supports; it does not establish that more recent source data are unavailable. A station failing the offset, gross-frequency or step criteria is replaced by the next candidate, rather than being searched for an older window with smaller errors.

## Coverage evidence

Counts below are coverage-qualified stations before station-level screening. Each configuration searches for its own most recent passing window and applies the same 100 m / 10 MAD gross rule.

| Qualifying dates per month | Hours per qualifying date | Stations qualifying | At the latest endpoint | Median accepted hours per selected year |
|---:|---:|---:|---:|---:|
| 10 | 4 | 2,046 | 1,068 | 6,060 |
| **15** | **4** | **2,014** | **1,015** | **6,450** |
| 20 | 4 | 1,985 | 939 | 6,801 |
| 25 | 4 | 1,919 | 843 | 7,043 |
| 15 | 2 | 2,038 | 1,063 | 6,075 |
| 15 | 6 | 1,900 | 847 | 7,049 |
| 15 | 8 | 1,736 | 736 | 7,549 |

Fifteen dates retain all but 32 stations passing the ten-date rule. Requiring six or eight hours causes larger losses. Across these settings, the median of station median absolute errors varies from 3.88 to 4.08 m and the median of station 95th percentiles from 9.82 to 10.01 m. These are descriptive summaries of different selected samples, not proof that stricter coverage improves accuracy. Four distinct hours do not guarantee coverage throughout the day; no extra diurnal filter is justified by these comparisons alone.

Of the 2,014 default windows, 1,341 end in 2026, 463 in 2025, 178 in 2024 and 32 in 2023. Allowing history from 2022 preserves those oldest windows; requiring window starts in 2024 would retain only 1,804 of these selected windows. The minimum observed accepted-year count is 1,388 hours, above the theoretical 720-hour minimum.

## Gross observations and offsets

With the proposed gross rule, 388 of 2,014 stations lose at least one observation, but only 17 exceed the 1% rejection threshold. At the same 100 m floor, changing the MAD multiplier from 10 to 6 or 15 changes that count to 19 or 15. Keeping 10 MAD but changing the station rejection fraction to 0.5% or 2% gives 25 or 13 exclusions. There is no clear need to tighten these rules.

The proposed offset rule rejects 74 of the 2,014 stations. A 15 m + 5% rule rejects 169; a 60 m + 20% rule rejects 26. Independent existing checks provide a physical rationale for the middle choice: among 615 stations on flat terrain within 30 m of ERA5 elevation, the 95th percentile of absolute bias is 16.2 m. The radiosonde assessment gives 99th-percentile absolute relative extrapolation discrepancies of 3.5–9.4% across the assessed 300–3,000 m height bands. These checks support a generous 30 m baseline and 10% height allowance; they do not identify a uniquely correct threshold. The radiosonde calculation is relative to its surface reference and is not a direct distribution of annual ground-station biases.

## Step-test evidence

| Minimum monthly medians | Minimum hours per median | Medians each side | Insufficient support | Qualifying steps at 10 m / absolute t ≥10 |
|---:|---:|---:|---:|---:|
| **18** | **60** | **3** | **77** | **18** |
| 18 | 60 | 6 | 78 | 13 |
| 24 | 60 | 3 | 157 | 14 |
| 18 | 120 | 3 | 118 | 16 |

Three medians per side detect five additional qualifying changes in this cache. The latest testable breakpoint is typically 84 days before the selected endpoint, compared with 176 days for six per side. This motivates three per side while retaining the longer seasonal context. It does not eliminate the unavoidable lack of support for changes very near the endpoint or across long data gaps.

With 18 medians, 60 hours and three per side, reducing the amplitude threshold to 5 m increases exclusions from 18 to 31 at absolute t ≥10. For six per side and 10 m, changing the t threshold from 10 to 5 or 15 gives 20 or 6 exclusions instead of 13. Retain the existing 10 m / 10 score as a conservative screening convention; these data do not supply known instrument-change labels with which to estimate sensitivity or a false-positive rate. The breakpoint is selected by searching several dates, and residuals can be serially correlated, so the t score is not a calibrated significance level.

With the recommended three-per-side rule, 1,838 of the 2,146 cached stations pass coverage and all station criteria. Individual criterion failures overlap: among 2,014 coverage-qualified stations, 17 fail gross frequency, 74 fail offset, 77 lack step support and 18 have a qualifying step. These are review counts before any new spatial selection or replacement.

## Spatial spacing

The 7,886 cached candidates occupy the following cells; counts precede the new coverage and station criteria.

| Cell width | Occupied cells | Cells with only one candidate | Cells containing a station above 1,000 m |
|---:|---:|---:|---:|
| 100 km | 4,628 | 3,103 | 593 |
| 150 km | 3,407 | 1,938 | 488 |
| **200 km** | **2,563** | **1,195** | **404** |
| 250 km | 2,018 | 806 | 346 |
| 300 km | 1,601 | 530 | 303 |

Recommend 200 km as a practical geographic resolution. At this width, 47% of cached occupied cells have only one candidate, so rejection will sometimes leave a cell empty. The full direct GHCNh inventory can offer additional candidates. Neither these cell counts nor the 1,838 passing cached stations predict the size of the rebuilt network.

## Scope and reproducibility

The matched cache comes from the previous candidate frame and spatial selection, which favored high-elevation stations. It excludes candidates without cached ERA5 and is incomplete outside each station's previously downloaded years. A missing cached period is not evidence of absent observations in the archive. The source-QC and pressure bounds have already been applied, so this review cannot validate their rejected observations. Screening against ERA5 also makes the retained error distribution conditional on that screening. The comparisons support practical values; they do not establish optimal thresholds or validate station truth.

For historical step context, this assessment applies the 100 m / 10 MAD gross rule once over the available three-year context before computing calendar-month medians. The rolling year uses its own median and MAD. This convention should be stated explicitly when the pipeline is implemented. Coverage uses rolling month blocks; the step model uses calendar months, including partial boundary months if they reach 60 hours.

Run [assess_criteria.R](../../../../docs/methods/ghcnh-sampling-review/assess_criteria.R) from the repository root. It reads cached data only and writes `criteria_*.csv` in this review directory. Coverage nesting and the implied minimum support are checked with assertions. Detailed results are in [coverage](../../../../docs/methods/ghcnh-sampling-review/criteria_coverage.csv), [gross screening](../../../../docs/methods/ghcnh-sampling-review/criteria_gross.csv), [offset screening](../../../../docs/methods/ghcnh-sampling-review/criteria_offset.csv), [step screening](../../../../docs/methods/ghcnh-sampling-review/criteria_steps.csv) and [grid counts](../../../../docs/methods/ghcnh-sampling-review/criteria_grid.csv). Existing physical checks are in `output/tables/ground_screen_basis_flat.csv` and `ground_screen_basis_gap.csv`. No manuscript results, production scripts or source observations are changed.

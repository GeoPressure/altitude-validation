# Ground-reference filtering using pressure and timestamps

Author-facing implementation record, 23 October 2026. The active procedure selects station years without using ERA5 values or ERA5 error rankings. ERA5 inputs are joined after selecting a qualifying pressure window, and missing atmospheric inputs stop the rebuild instead of changing the pressure-based selection.

## Selection rules

Candidates retain the existing order within all 2,962 frozen candidate cells of 200 km. Cells are assessed regardless of whether the earlier ERA5-based workflow accepted a station there. Terrain consistency and independently documented reference exclusions are assessed first. `docs/methods/ghcnh_reference_exclusions.csv` contains documented site/elevation conflicts and moving installations without a fixed reference elevation. The initial rebuild below used nine site/elevation conflicts and two moving installations; [subsequent reference curation](reference-curation-review-2026-10-23.md) expands those independent exclusions. Historical ERA5-guided decisions in `ghcnh_curation_exclusions.csv` are review evidence and are not applied by selection.

Archive source-qualified failure flags and the existing 300–1100 hPa plausibility limits are unchanged. Reports are assigned to the nearest hour and one report is retained per hour. The following checks use station pressure in hPa and UTC timestamps only.

| Check | Fixed threshold | Action |
|---|---|---|
| Isolated spike | More than 5 hPa from both neighbours; both within three hours; neighbours agree within 2 hPa; the report lies on the same side of both. | Remove the report. |
| Sparse isolated spike | More than 10 hPa from both neighbours; both within 12 hours; neighbours agree within 3 hPa; departure and return each exceed 2 hPa/hour; the report lies on the same side of both. | Remove the report. |
| Large jump | Consecutive reports differ by more than 20 hPa within three hours, or more than 50 hPa within seven days. | Reject years containing both reports. |
| Repeated rapid noise | At least six reversal centres in a trailing 24-hour interval. Each reversal has two opposite changes, each greater than 2 hPa and 2 hPa/hour, with each adjacent gap at most three hours. | Reject years overlapping the episode from the report before the first reversal to the report after the last. |
| Frozen pressure | Exactly equal pressures across at least 24 reports spanning at least 48 hours, with no adjacent gap greater than three hours. | Reject years overlapping the run. |

Spikes are removed in one pass. Jump, noise and frozen episodes are then computed on the cleaned full candidate history. Coverage is assessed after spike removal. The latest qualifying year is sought backwards in daily steps, requiring at least 15 days with four retained hours in each of its 12 month-long intervals. If no year qualifies, the next candidate in the cell is assessed. Noise and frozen episodes crossing a year boundary remain disqualifying; a jump across the left boundary does not count because both reports must be inside the year. All altitude conversions use identical selected observations.

## Threshold inspection and verification

The noise and frozen thresholds were inspected using raw pressure from seven previously reviewed stations and 50 randomly sampled other cached stations, without evaluating ERA5 agreement. The new checks detect the alternating levels at Mataveri and Krabi and frozen runs at Tsampa and Secretary Island. None of the 50 randomly sampled other records triggers the new noise or frozen criteria; some trigger the existing jump criterion. This small diagnostic sample establishes behaviour on concrete examples, not a comprehensive estimate of error detection or false rejection.

`scripts/drafts/pressure_filter_review.R` reproduces the metric table and example plots in `output/drafts/pressure-filter/`. The diagnostic uses the same episode function as selection. `tests/check_ghcnh_pressure_spikes.R` and `tests/check_ghcnh_pressure_episodes.R` verify isolated spikes, repeated noise, constant runs, coherent pressure changes, reporting gaps, backwards year selection, insufficient coverage and boundary-crossing episodes. `scripts/checks/validate_ground_pressure.R` checks every selected year against full-history episodes, equality with cleaned pressure reports and monthly coverage; it is included in `Rscript run_all.R check`.

The implementation is in `R/ghcnh_sampling.R` and `scripts/sampling/ground_selection.R`. Rule defaults are saved in the primary selection settings. Rebuild the primary selection and dependent results with `Rscript run_all.R ground_selection prepare analysis figures check`.

## Rebuilt sample and ERA5 evaluation

The rebuild assesses all 2,962 candidate cells and retains 2,192 stations with 11,745,654 observations. Relative to the previous 2,055-station selection, 138 cells become represented and one becomes unrepresented. The lost cell contains a 49-hour frozen-pressure episode and has no qualifying alternative year or candidate. Among represented cells, 26 select a different station and 15 retain the station with a different year. Isolated-spike screening removes 1,373 reports from the retained windows. Fifty-seven identifiers from the historical curation list are selected under the objective procedure, sometimes using an earlier qualifying year.

| Metric | Previous selection | Pressure-only selection |
|---|---:|---:|
| Stations | 2,055 | 2,192 |
| Median station absolute ERA5 bias (m) | 3.10 | 3.27 |
| Median station temporal ERA5 SD (m) | 3.35 | 3.42 |
| Station-weighted median absolute ERA5 error (m) | 4.08 | 4.28 |
| Station-weighted 95th percentile absolute ERA5 error (m) | 24.54 | 31.37 |

These comparisons use the ERA5 conversion with the standard lapse rate, after fixing the pressure-only criteria. The upper tail increases more than the medians. The comparison includes changes in geographic coverage as well as station/year selection. `scripts/drafts/pressure_filter_evaluation.R` produces the comparison tables in `output/drafts/pressure-filter/` from the saved previous selection and rebuilt results.

## Completed verification

Both focused pressure tests passed. The rebuilt sample passed independent terrain/reference eligibility, shared-record and histogram-weight checks. `Rscript run_all.R check` then verified all 2,192 accepted ground years against full-history episodes, exact cleaned-record equality and monthly coverage, and passed the numerical integration checks for ground and flight inputs, station/cell balance, direct conversions and analysis weights. Updated methods, the selection diagram and the ground histogram use the new procedure and sample.

## Scope

The procedure deliberately leaves plausible-looking timing errors, stable offsets and smaller reference shifts when they do not meet a stated criterion. Its thresholds are conservative operational rules rather than universal physical bounds. ERA5 is used afterward to quantify performance and remaining discrepancies; its residuals do not determine which stations pass. Median summaries tolerate a minority of extreme errors, but faults affecting much of a record can also affect a station's median.

# IGRA selection review — 20 October 2026

**Design review, subsequently approved for implementation on 20 October 2026.** The [implementation and pilot report](implementation.md) records the implemented choices and verification. The author selected the latest qualifying 12 months within the GHCNh domain. The combined [Appendix S1 draft](../../manuscript/appendix-s1-process-proposal-2026-10-20.md) presents the processes for new readers. The assessment below retains the evidence and decisions considered before implementation.

## Recommendation

Use the same 200 × 200 km Equal Earth cells, fixed cutoff, random candidate order and daily backwards search for a qualifying 12-month window as GHCNh. Evaluate one IGRA candidate at a time through source QC, a usable sounding surface, ERA5 matching and accepted monthly launch coverage. Accept the first passing candidate in each cell; otherwise try the next candidate. Keep the scientific differences that matter: coverage counts launch dates, and errors measure height changes relative to each sounding's surface.

Use at least 15 distinct usable launch dates in every rolling month block as the starting coverage criterion. This replaces the two separate ≥100-sounding checks and the inventory's one-year record margins. The threshold must be assessed on the expanded domain after final QC before it is adopted. Having one usable airborne level is enough for a launch to count towards station coverage; height-dependent support remains visible beside the results. Do not add a requirement to reach every reporting band, which would favour particular reporting formats and exclude useful partial profiles.

## What the existing pipeline actually does

| Stage | Implemented behavior | Assessment |
|---|---|---|
| Candidate frame | Inventory record begins by 2022 and ends in 2025 or later, for a 2023–2024 analysis | Inventory spans do not establish usable or seasonal coverage. Require overlap with the analysis domain and test observations directly. |
| Extraction | Download every candidate's full period-of-record ZIP; stream 2023–2024 levels with pressure ≥400 hPa, plus surface levels | Candidate-per-cell processing avoids downloading all stations. Drop the pressure cutoff and keep the explicit 0–6 km height domain after identifying the surface. |
| Initial coverage | Count ≥100 nominal soundings before pressure/height validation and ERA5 matching | Replace with one accepted-data seasonal coverage test. |
| Spatial thinning | One random station per 2° cell, plus stations >1000 m | Use the agreed equal-area grid and first passing candidate. T06 already found no multiple stations per retained IGRA cell in its historical sample; there is no need to repeat that assessment. |
| Surface reference | Fill both missing (−9999) and quality-rejected (−8888) surface heights with inventory elevation | Substitute only a missing surface height. Reject a sounding whose surface pressure or height was removed by archive QC. A usable pressure surface is essential for surface-referenced errors. |
| Timing | Reported release plus elapsed time, with nominal-time and 5 m/s fallbacks; nearest ERA5 hour | Retain this practical convention, but distinguish missing elapsed time from a QA-removed elapsed time. Drop the latter level. Surface elapsed time is zero. Use actual level timestamps for the conversion and GPT3 date. |
| Height/temperature | Require positive pressure and valid height; interpolate sounding temperature for the explanatory layer-temperature calculation | Keep source temperature optional for conversion validation. Temperature interpolation belongs to that explanatory calculation, not the pressure/height acceptance rule. |
| Additional exclusions | ERA5-standard surface-referenced residual beyond 150 m and 10 scaled MAD from a pooled height-band median | Preserve the numerical form as a candidate-local rule, centred within station and height band, so an unrelated candidate cannot alter acceptance. Compare it with the current pooled rule before final adoption. |
| Final coverage | Another ≥100-sounding count before the last common-input and surface restrictions | Coverage should be checked after the exact final shared input selection. |
| Weights | Station weight divided among all levels, then renormalized within each height band | For the proposed analysis, equal station weight within each reported band is easier to interpret. This is a scientific weighting change, separately assessed in T06, not merely shorter wording. |

The relevant code is `scripts/04_igra_download.R`, `scripts/08_era5_extract.R`, `scripts/09_errors.R`, `R/utils.R::load_radiosondes()` and `scripts/18_three_formulas.R`. The last script replaces level timestamps with sounding-day midnight for the GPT3 date; retaining the original timestamps avoids that inconsistency in the new implementation.

## Evidence from existing inputs

Run `Rscript docs/methods/igra-sampling-review/assess_cached.R` from the project root. This is a read-only assessment of existing extracts; its outputs are confined to this review directory. It uses one computational thread to avoid competing heavily with the running GHCNh selection.

The current candidate CSV contains 772 stations in 729 equal-area cells. There are 747 cached station extracts and 702 initially selected stations. These are different stages from the final flight analysis and must not be labelled as final retained counts.

Across the cached extracts, 27,107,127 levels include 848,617 surface records. Of these, 584,734 surface heights are missing and 5,039 were removed by archive quality assurance. Missing heights are common enough to justify the documented elevation substitution; replacing QA-removed heights bypasses a real rejection decision. Four elapsed-time values were QA-removed; the implementation can omit those levels without adding a new workflow stage. The extractor has saved no non-surface levels below 400 hPa, so upper-height losses caused by that cutoff cannot be recovered from these caches.

| Minimum usable launch dates in every month | Stations qualifying in either 2023 or 2024 | Represented equal-area cells | Among the 702 initially selected stations |
|---|---:|---:|---:|
| 5 | 603 | 589 | 585 |
| 10 | 585 | 572 | 568 |
| 15 | 546 | 533 | 530 |

These counts use calendar years as two concrete 12-month windows. A usable launch has an accepted pressure surface and at least one non-surface level with positive pressure and valid height within 0–6 km. Missing surface heights use inventory elevation; QA-removed heights do not. Counts precede ERA5 matching, timing exclusions and residual exclusions. They are neither final rolling-window counts nor a prediction of the 2022–2026 sample size. The extracted data cover only 2023–2024; the expanded period requires refreshed downloads. See `cached-summary.csv`, `coverage-thresholds.csv` and the per-station/month files.

The historical T06 audit already investigated height-band coverage and weights. It found 241 of 530 contributing stations had fewer than 100 soundings in the 250–500 m band, despite their overall station eligibility. Requiring 100 soundings in every band would therefore be a substantial new restriction. Keep the support table with results, without turning every empty band into a rejected station.

T06's within-band equal-station comparison changed bird-weighted ERA5-standard MAE from 16.440 to 16.240 m and virtual/GPT3 MAE from 13.119 to 13.175 m in that historical analysis. Height-band tails can change more: virtual/GPT3 p95 at 4–5 km changed from 190.15 to 234.47 m. These numbers justify making the weighting definition explicit; they do not predict the resampled analysis. See `../T06/flight_weighting.csv`, `../T06/flight_weighting_bird.csv` and `../T06/flight_bin_support.csv`.

The additional residual diagnostic includes 11,523,948 finite-error levels at 655 cached stations, before the final common-input restrictions. Pooled-band screening removes 4,398 levels; candidate-local screening removes 639. The largest difference is at 0.5–1 km (1,966 versus 45). Thus candidate-local centring is a material change in which discrepancies are removed, even though both removal fractions are small. This diagnostic does not identify which excluded values are faulty. Before adopting it, inspect the affected profiles and compare seasonal coverage and error tails; do not treat the two rules as interchangeable. The diagnostic is in `residual-exclusions.csv` and is intentionally separate from primary results.

## Necessary differences from the ground process

The GHCNh offset criterion concerns the usefulness of a listed station height as an absolute reference. IGRA uses each sounding's height difference from its own surface. Its reported heights are geopotential heights; archive metadata do not establish independently measured geometric height at every level. Consequently, copying the ground offset and step-change thresholds onto airborne residuals would test a different quantity and could reject genuine atmospheric-conversion errors. I recommend source QC, paired-surface validity, the conservative isolated-outlier rule and seasonal coverage for this first IGRA design. A further station exclusion needs a demonstrated IGRA failure mode and a directly interpretable criterion.

Retain the reported geopotential reference and the launch-location convention consistently. Balloon drift and the provenance of each height are interpretation limits, not reasons to build new tagging or parallel samples. The primary pressure/height comparison must not depend on whether a source temperature profile is sufficiently complete for the explanatory temperature analysis.

## Numerical and implementation assessment

The existing station extracts total about 161 MiB; this is reduced 2023–2024 data, not raw download volume. The first complete raw-cache coverage assessment took about 41 seconds. Existing `errors_igra.parquet` is about 620 MiB. These local scans show that coverage evaluation is modest; they do not benchmark archive download or expanded-period ERA5 acquisition.

A roughly five-year domain needs fewer than 1,400 daily 12-month endpoints per station. Use cumulative accepted launch-date counts to skip endpoints that cannot satisfy monthly coverage; calculate the candidate-local residual exclusions only when the cheap coverage bound passes. Recheck coverage after exclusions. The median/MAD calculation must use all usable levels in that trial window, with fixed reporting-band edges. Failing coverage moves the endpoint back one day; it does not advance by a whole year. The first passing candidate completes the cell.

Use the GHCNh pattern: frozen inventory and candidate order, per-station reduced profiles and core ERA5 cache, then one checkpoint per completed candidate. Cache keys must distinguish the new extraction domain and removal of the pressure cutoff: the old extracted files are incomplete for the proposed design and cannot simply be treated as cache hits. Reuse existing ERA5 hours only for matching station coordinates and variables. Download only candidates actually reached. Fetch the optional covariates and ERA5-Land comparison after selection.

The current `curl | funzip | awk` shell pipeline does not enable `pipefail`; a failed upstream download can appear successful and create a reusable empty or partial Parquet file. The replacement should complete and validate the candidate ZIP in a temporary file before extraction, verify the ZIP integrity and sounding record counts, then atomically replace the reduced cache. Remove the successfully extracted ZIP to bound storage. Retry a technical failure on the same candidate; it is not evidence that the station fails scientifically.

Start with at most three concurrent download workers, consistent with the existing NCEI throttling precaution. Use socket workers, as in the current GHCNh sampler. A small measured pilot must establish compressed download bytes, station-file size, wall time, accepted launch/height coverage and resume equivalence before a full IGRA selection. Do not quote a global runtime from the local scan. The work is realistic as a one-off run; network transfer of full-record ZIPs is the principal uncertainty.

## Decisions before implementation

1. Confirm the proposed 15 launch dates per rolling month after assessing expanded-period data and final acceptance restrictions.
2. Compare candidate-local and pooled outlier exclusions using the existing error cache; use `residual-exclusions.csv` as an initial threshold diagnostic. The candidate-local rule is proposed, not yet numerically approved.
3. Confirm the simpler within-band equal-station weights, acknowledging the existing height-tail sensitivity. Weighting is applied after selection and must not affect candidate acceptance.

The common domain, latest-qualifying-year search, equal-area candidate groups and S1's two-section scope are established by the author's request. The points above are the remaining numerical choices; the publication draft states the proposed complete method rather than interspersing editorial questions in the process.

## Sources

NOAA's [IGRA product page](https://www.ncei.noaa.gov/products/weather-balloon/integrated-global-radiosonde-archive) identifies version 2.2 and its variables; the [format description](https://www.ncei.noaa.gov/data/integrated-global-radiosonde-archive/doc/igra2-data-format.txt), also saved in `../T05/igra2-data-format.txt`, defines missing/QA-removed values and processing flags. Blank/A/B pressure and height flags describe the checks applied; they are not equivalent to suspect-value flags in GHCNh. The [earlier sampling audit](../../../../docs/methods/T05/audit.md) and [T06 recommendations](../../../../docs/methods/T06/recommendations.md) contain the existing height-reference, timing, coverage and weighting assessments.

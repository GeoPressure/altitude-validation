# IGRA rolling-window selection: implementation and pilot

Implemented on 20 October 2026 after approval of the [design review](assessment.md). The full selection is running in the background after the pilot and numerical checks passed. Primary manuscript tables and figures have not yet been rebuilt from either new selection.

## Implemented process

- Direct, freshly frozen IGRA inventory and archive listing: **865 candidates in 801 equal-area cells**. Inventory records need only overlap the 2022–2026 domain; source observations establish actual eligibility.
- Same 200 × 200 km Equal Earth grid, seed 11, and 1 January 2022 to exclusive 13 October 2026 cutoff as GHCNh. Random candidate order is frozen before processing.
- Download candidates as reached within each cell. Validate the complete ZIP and each sounding's declared level count before caching reduced profiles. Extraction retains the full pressure range; airborne height differences must be >0 and ≤6000 m.
- Require an accepted pressure surface. Fill a missing surface height (−9999) using inventory elevation; do not refill a QA-removed height (−8888). QA-removed airborne elapsed times are excluded; missing elapsed times use the stated 5 m/s fallback. Optional source temperature availability does not determine comparison eligibility.
- Use release plus elapsed time for each airborne level, the release time for its surface, and the nearest ERA5 hour with ties earlier. Release times are wrapped within 12 h of valid nominal times. Match finite ERA5 pressure, temperature, dewpoint and orography at the fixed launch station.
- Compute all three errors against the same sounding's surface using its own matched inputs. GPT3 uses the actual level and release dates, respectively. All three conversions must be finite on the shared accepted rows.
- Search 12-month windows backwards one day at a time. Within each trial window, remove ERA5-standard surface-referenced errors beyond both 150 m and ten scaled MAD from the station/height-band median. Then require ≥15 distinct launch dates with at least one accepted airborne level in every rolling month block. Accept the latest qualifying window and the first passing candidate per cell.
- Cache paired inputs and the three conversion errors. Within each reporting band, a station's airborne-level weights sum to one. The lowest band is (0, 100] m; final result labels must reflect this boundary.

`R/igra_sampling.R` contains the scientific units and cell checkpoint loop; `scripts/sample_igra.R` is the linear executable workflow. The new sampler reuses the atomic RDS/Parquet commit helpers in `R/ghcnh_sampling.R` without changing GHCNh code or run files. It is separate from the numbered manuscript pipeline until integration.

## Pilot observations

The pilot used a fixed random ordering of cells, independent of station acceptance. Four initial cells ran serially, followed by an extension to 16 cells using three socket workers. All 16 completed: **15 stations accepted, one empty cell, 17 candidates assessed, zero pending failures**. One cell rejected its first candidate and accepted its next candidate.

| Measurement | Observed |
|---|---:|
| Initial four cells, one worker | 83.44 s selection time |
| Extend to 16 cells, three workers, first four cached | 105.62 s selection time |
| Total ZIP bytes for the 17 candidates | 673,287,851 bytes (642.1 MiB) |
| Retained run cache at pilot completion | 33,513,654 bytes (32.0 MiB) |
| Fresh serial replay of the 16 cells using frozen profile/core caches | 9.50 s selection time |

The cold-work sum is not a single all-cold parallel wall-clock benchmark: the first four cells were serial and reused in the extension. Per-candidate timings provide the projection below. Download volume measures the complete station archives actually downloaded; those ZIPs are removed after successful reduction and cache commit.

Accepted pilot stations contribute **265,458 airborne levels**. Monthly accepted launch-date minima are 15–28. At an elevated Antarctic station, 335 accepted levels have pressure below 400 hPa; these demonstrate restored height coverage that the previous extractor could not retain. Window endpoints vary by station, as intended: a station can use an older qualifying year when recent coverage fails.

The initial extractor produced column-type warnings because `fread()` applies `colClasses` before custom column names. Numeric column positions now set the requested types explicitly. Cached character metadata were normalized consistently; scientific values, selections and windows were unchanged. A fresh 17th-cell run passed without the warnings: 17 cells complete, 16 accepted, 18 attempted, no pending failures. The 16-cell measurements are preserved separately for the resource projection.

## Numerical and restart checks

Run:

```sh
Rscript docs/methods/igra-sampling-review/check_sampling.R
Rscript docs/methods/igra-sampling-review/check_pilot.R
```

The five synthetic scientific/recovery checks passed:

1. Missing versus QA-removed surface height, positive pressure below 400 hPa, missing source temperature, elapsed-time QC, midnight release alignment and an exact half-hour tie.
2. A failed endpoint moves back exactly one day; repeated profile levels cannot inflate distinct-date coverage.
3. The strict >150 m outlier boundary and coverage recalculation after removal.
4. Month-end/leap-year blocks constructed independently from their endpoint.
5. Scientific rejection advances to the next candidate; injected retrieval failure preserves that candidate; restart matches uninterrupted acceptance and accepted data. Completed cells remain unchanged on rerun.

The pilot validation checks accepted pressure/height/timing inputs, common finite conversions, monthly support and within-band weights at all 15 stations. At up to 100 sampled levels per station, the virtual conversion agrees with paired direct GeoPressureR calls to within 9.1 × 10⁻¹³ m. A fresh serial replay with empty checkpoints reproduces all candidate reasons, station choices, observation windows and every accepted input/error/weight row from the parallel pilot. This verifies selection and conversion inputs; it is not a rebuild of downstream manuscript analyses.

Results are in `sampling-checks.csv`, `pilot-input-checks.csv`, `pilot-checks.csv` and `pilot-16-serial-metrics.csv`. Scripts parse and `git diff --check` passes.

## Full-run resources and recovery

Per-cell pilot times and storage yield a rough three-worker projection of **1.50 hours**, **31.4 GiB of download traffic**, and **1.52 GiB retained storage** across 801 cells. A 2,000-resample cell bootstrap gives approximate ranges of 1.12–1.90 hours, 20.0–44.2 GiB of downloads, and 0.86–2.25 GiB retained. These ranges describe this small pilot's cell mix, not uncertainty in archive behavior or network availability. Archive throttling, large files and concurrent GHCNh work may extend runtime. The archive ZIPs and extraction CSVs occupy temporary disk space for at most the active candidates.

`pilot-resources-by-cell.csv` and `pilot-projection.csv` are reproducible with `summarise_pilot.R`. No full-run station-count claim is made from the pilot.

```sh
Rscript scripts/sample_igra.R 16 3
Rscript scripts/sample_igra.R all 3
```

The default run directory is `data/interim/igra-selection-2026-10-13/`; `IGRA_RUN_DIR` selects a separate frozen run. Files are:

- `settings.rds`, inventory/listing and `candidates.rds`: fixed design and candidate ordering.
- `profiles/{id}.rds`: prepared paired profiles plus actual download bytes and extracted level count. Historical 2023–2024 pressure-truncated extracts are not reused as complete candidate inputs.
- `core/{id}.parquet`: required ERA5 hours, reusing matching historical IGRA coordinates/hours and downloading missing values.
- `cells/{cell}.rds`: last completed scientific attempt, accepted metadata or pending technical failure.
- `accepted/{id}.parquet`: selected paired airborne/surface inputs, errors and station-within-band weights.
- `full-background.log`, `workers.log`, `full-process.pid` and `full-exit-status.txt`: background-run supervision.

The wrapper `run-full.sh` starts `scripts/sample_igra.R all 3` and writes its exit status. A technical failure keeps its candidate pending; resuming `all` reuses completed cells and cached candidate inputs. Atomic cache writes prevent interrupted files becoming cache hits. The existing hourly monitor now watches both GHCNh and IGRA, stays quiet during normal progress, and restarts a stopped unsuccessful run without changing the scientific criteria. It disables itself when both selections complete.

## Remaining integration

After the selections finish, propagate their accepted rows, windows, reference decisions and weights through the main analysis and supplementary comparisons. Fetch retained-only environmental covariates and ERA5-Land inputs then; optional analyses must not alter primary eligibility. Rebuild the affected numerical results before applying the [combined S1 text and section moves](../../manuscript/appendix-s1-process-proposal-2026-10-20.md) to the manuscript: two primary processes in S1, error distributions in S2, and GNSS/MeteoSwiss outside S1 in S4.

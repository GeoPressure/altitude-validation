# GHCNh selection: implementation and first pilot

**Hourly selection update, 20 October 2026.** Version 2 selects the accepted report closest to its assigned ERA5 hour, resolving equal-distance ties with the earlier report. The previous pressure caches, cell checkpoints and accepted series are preserved under `data/interim/ghcnh/selection-2026-10-13-first-report-v1/`. Selection decisions are recalculated with the new hourly inputs while retaining the frozen candidate order, raw downloads and ERA5 caches. A refreshed 64-cell pilot completed in 14.67 seconds with 140 candidates assessed, 53 stations accepted and zero pending cells. Fresh serial replay reproduces every accepted input and all selection decisions; results are in `pilot-nearest-hour-parallel-checks.csv` and `pilot-nearest-hour-serial-metrics.csv`. Resource measurements below describe the initial first-report pilot and remain useful as the pre-update benchmark.

20 October 2026. The direct-inventory sampler is implemented in [scripts/sample_ghcnh.R](../../../../scripts/sample_ghcnh.R), with scientific units in [R/ghcnh_sampling.R](../../../../R/ghcnh_sampling.R). The 64-cell pilot is complete and restartable. Manuscript tables and figures still use the existing sample; downstream integration has not started.

## Measured result

The frozen 2022–2026 archive catalogues contain 18,469 inventory candidates in 2,962 occupied 200 km cells. The pilot uses the first 64 cells in a fixed random ordering, with seed 11 and four socket workers. Candidate selection within each cell uses the independently frozen candidate order specified by the method.

| Result | Pilot |
|---|---:|
| Cells completed | 64 |
| Stations accepted | 53 |
| Cells exhausted without an accepted station | 11 |
| Candidates assessed | 140 |
| Candidates rejected for coverage | 81 |
| Candidates rejected for persistent offset | 3 |
| Candidates rejected for frequent extreme outliers | 2 |
| Candidates rejected for insufficient step support | 1 |
| Candidates rejected for a detected step | 0 |
| Technical failures still pending | 0 |
| Accepted observations | 310,755 distinct station-hours |
| Selected window endpoints | 17 January 2024–13 October 2026 |

Required step screening is exercised by the separate cached-data verification, which includes all 18 previously identified qualifying steps for the recommended settings. Absence of detected steps in this small pilot does not imply the criterion is inactive.

The initial 32-cell successful selection pass took 64.1 s; extending it by 32 additional cells took 83.7 s. Existing cell checkpoints and inputs were reused. The recorded candidate processing times sum to 515.4 s, across parallel workers. Frozen-catalogue setup and worker startup are additional costs. The first fork-based attempt failed at the known macOS/libcurl boundary and was replaced with socket workers; its completed checkpoints were retained. Some inputs prepared before that interruption were reused, so these are practical incremental timings rather than a controlled entirely uncached benchmark.

A fresh sequential recomputation of all 64 cells from the same prepared pressure and ERA5 inputs took 16.35 s. Every accepted station, window, rejection reason, accepted hour and input value matched the socket run. A subsequent four-worker resume of the completed cells took 4.93 s and performed no candidate work.

## Runtime and storage projection

| Quantity across all 2,962 cells | Pilot-based estimate | Cell-bootstrap range, 2.5–97.5% |
|---|---:|---:|
| Candidates assessed | 6,479 | 5,184–7,960 |
| Selection time, four workers | 1.66 h | 1.32–2.08 h |
| New candidate data stored | 9.56 GiB | 7.48–11.98 GiB |
| Stations accepted | 2,453 | 2,175–2,731 |

Budget roughly **2–3 hours for full primary selection and 8–12 GiB of new stored data** under the current cache/network conditions. These figures exclude retained-only covariates, ERA5-Land, downstream error summaries and manuscript rebuilding. Network changes, retries and unusually expensive cells can extend elapsed time. Bootstrap ranges describe variation among these 64 cells; they do not include all systematic uncertainty or guarantee the final station count.

The pilot added about 212 MiB of candidate-specific files, including new historical annual downloads outside the run directory. Its run directory occupies about 126 MiB including frozen metadata. Storage is projected from files actually added under the current cache-reuse pattern, without retaining full downloaded ERA5 chunks. Existing historical raw files and reduced observations are reused.

## Cleanup

Removed **11.43 GiB** of obsolete HadISD observations, their derived errors and ERA5 series, plus the generated 1 October code/data archive ZIPs. The active GHCNh, radiosonde, GNSS and MeteoSwiss inputs and all current analysis outputs are retained. Historical review tables are retained; recreating old HadISD raw-data comparisons would require reacquiring those superseded inputs. The grouped deletion inventory is [cleanup-2026-10-20.csv](../../../../docs/methods/ghcnh-sampling-review/cleanup-2026-10-20.csv). Available disk space after cleanup and this pilot is approximately 61 GiB. The current project data folder occupies about 28 GiB; selection alone would bring it to roughly 36–40 GiB, before retained-only covariates and other downstream additions.

## Verification and restart behavior

[check_sampling.R](../../../../docs/methods/ghcnh-sampling-review/check_sampling.R) verifies window endpoints, accepted-hour counts, mean discrepancies, outlier fractions and season-adjusted step fits against the saved criterion assessment for 62 stations. Synthetic cases check source-dependent pressure-quality codes, nearest-hour ties, chronological duplicate resolution, the strict 100 m boundary and coverage after outlier removal.

A simulated transfer failure leaves the current candidate pending, with earlier scientific rejections preserved. Restarting after an incomplete temporary-file write gives the same accepted station and window as an uninterrupted run. A completed cell remains unchanged. [check_serial_replay.R](../../../../docs/methods/ghcnh-sampling-review/check_serial_replay.R) additionally compares the fresh sequential and socket runs and checks the exact accepted hourly inputs. Weight propagation will be checked during downstream integration. Results are in [sampling_checks.csv](../../../../docs/methods/ghcnh-sampling-review/sampling_checks.csv) and [pilot_parallel_checks.csv](../../../../docs/methods/ghcnh-sampling-review/pilot_parallel_checks.csv).

The scientific settings are frozen in `data/interim/ghcnh/selection-2026-10-13/settings.rds`; cell checkpoints and pressure/core/accepted Parquet files reside in that run directory. Downloads and derived cache files are committed by temporary write and rename. A failed transfer does not advance the candidate; cells can resume independently. Full selection refuses completion while any requested cell remains pending.

## Run and remaining work

From the repository root:

```bash
# Resume the measured pilot.
Rscript scripts/sample_ghcnh.R 64 4

# Extend the same frozen selection to all cells.
Rscript scripts/sample_ghcnh.R all 4

# Recheck scientific calculations and simulated restart failures.
Rscript docs/methods/ghcnh-sampling-review/check_sampling.R
Rscript docs/methods/ghcnh-sampling-review/check_serial_replay.R
```

The resource summary uses the committed initial pilot CSVs plus the live candidate caches. `check_serial_replay.R` creates a temporary run with hard-linked frozen inputs and empty checkpoints, recomputes the same 64 cells with one worker, compares selections and complete accepted series, and removes its temporary directory. Timing and comparison results remain in this review folder.

Before publishing new manuscript results, complete retained-only covariate retrieval and replace calendar-year joins, repeated screening and old cell weights in the numbered scripts with the accepted windows and equal station weights. The independent sampler is deliberately not invoked by `run_all.R` during this pilot stage. No full selection or manuscript rebuild has been launched.

Detailed outputs: [first 64-cell metrics](../../../../docs/methods/ghcnh-sampling-review/pilot-64-initial-metrics.csv), [attempts](../../../../docs/methods/ghcnh-sampling-review/pilot-64-initial-attempts.csv), [accepted stations](../../../../docs/methods/ghcnh-sampling-review/pilot-64-initial-accepted.csv), [per-cell resources](../../../../docs/methods/ghcnh-sampling-review/pilot-64-resources-by-cell.csv), [resource projections](../../../../docs/methods/ghcnh-sampling-review/pilot-resource-projection.csv), [sequential timing](../../../../docs/methods/ghcnh-sampling-review/pilot-64-serial-metrics.csv) and [resume timing](../../../../docs/methods/ghcnh-sampling-review/pilot-64-resume-metrics.csv).

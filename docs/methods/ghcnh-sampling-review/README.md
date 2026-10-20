# GHCNh sampling

The publication methods are in [supplement.qmd](../../../paper/supplement.qmd), section S1.1. The executable workflow is [sample_ghcnh.R](../../../scripts/sample_ghcnh.R), using [ghcnh_sampling.R](../../../R/ghcnh_sampling.R).

The full selection completed: 2,962 cells evaluated, 5,318 candidates assessed and 2,130 retained stations, with no pending cells. The recorded run cache is approximately 4.7 GiB, excluding the shared annual-archive cache. The manuscript analysis now reads the accepted rolling windows directly.

```sh
Rscript scripts/sample_ghcnh.R 64 4
Rscript scripts/sample_ghcnh.R all 4
Rscript docs/methods/ghcnh-sampling-review/check_sampling.R
Rscript docs/methods/ghcnh-sampling-review/check_serial_replay.R
Rscript scripts/21_selection_sensitivity.R
```

The full run is `data/interim/ghcnh/selection-2026-10-13/`. Version 2 selects the report closest to its ERA5 hour, using the earlier report to resolve equal-distance ties. Candidate order, archive availability and scientific settings are frozen. Cell checkpoints distinguish scientific rejection from pending technical failure; rerunning the selection resumes unfinished cells. The full run's log, supervisor PID, exit status and metrics are stored in that directory. `GHCNH_RUN_DIR` selects a separate run for a different design.

The version-2 64-cell pilot assessed 140 candidates and retained 53 stations, with no pending cells. Fresh sequential replay matched every selection decision and accepted input. Source-QC, report-selection, coverage, step and recovery checks passed. Evidence is retained in the CSVs and check scripts here. Initial resource estimates were 2–3 hours and 8–12 GiB of additional stored data for full primary selection, before retained-only covariates and product comparisons.

The S5 analysis replays the same candidate order within primary represented cells, comparing primary acceptance with coverage-only acceptance. It reuses candidate pressure/ERA5 caches. A test run is `Rscript scripts/21_selection_sensitivity.R 64`; its output stays in this directory. Only the completed full selection writes `output/tables/paper_selection_sensitivity.csv`.

Earlier rationale, resource assessments and cleanup records are preserved in [the development archive](../../../archive/docs/methods/ghcnh-sampling-review/). The code, tests and numerical evidence remain here. The overall numerical-refresh status is in [docs/README.md](../../README.md).

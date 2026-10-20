# IGRA sampling

The publication methods are in [supplement.qmd](../../../paper/supplement.qmd), section S1.2. The executable workflow is [sample_igra.R](../../../scripts/sample_igra.R), using [igra_sampling.R](../../../R/igra_sampling.R).

The full selection completed: 801 cells evaluated, 828 candidates assessed and 643 retained stations, with no pending cells. Recorded ZIP download traffic was approximately 19.3 GiB; the retained run cache was approximately 0.8 GiB. The manuscript analysis now reads the accepted surface–airborne pairs directly.

```sh
Rscript scripts/sample_igra.R 16 3
Rscript scripts/sample_igra.R all 3
Rscript docs/methods/igra-sampling-review/check_sampling.R
Rscript docs/methods/igra-sampling-review/check_pilot.R
```

The full run is `data/interim/igra-selection-2026-10-13/`. It uses the same observation domain and equal-area grid as GHCNh, with 15 accepted launch dates per rolling month. Validated station ZIPs are reduced to paired surface/airborne profiles before the ZIPs are removed. Prepared profiles, required ERA5 hours, candidate order and cell checkpoints are cached. Technical failures leave the current candidate pending. `IGRA_RUN_DIR` selects a separate frozen run.

The 16-cell pilot assessed 17 candidates: 15 accepted stations, one empty cell and no pending failures. It downloaded 642 MiB and retained approximately 32 MiB. Serial replay reproduced every selection decision and accepted input; paired virtual-conversion checks agreed with GeoPressureR to numerical precision. Scientific and interrupted-retrieval tests passed. Measured per-cell resources projected approximately 1–2 hours, 20–44 GiB of download traffic and 1–2 GiB of retained storage for the full selection. ZIP download traffic is not retained disk usage.

The CSVs and scripts in this directory retain the measured pilot, QC and resource evidence. Earlier rationale is preserved in [the development archive](../../../archive/docs/methods/igra-sampling-review/). The overall numerical-refresh status is in [docs/README.md](../../README.md).

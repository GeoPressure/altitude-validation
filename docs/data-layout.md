# Data layout

The active analysis uses the curated GHCNh and frozen IGRA2 selections and the derived station caches described in the repository README. Paths are kept stable to preserve resumable sampling and atmospheric downloads.

| Location | Role |
|---|---|
| `data/raw/` | Downloaded invariant atmospheric grids, station inventories and GPT3 climatology. |
| `data/interim/ghcnh/selection-2026-10-13/` | Frozen GHCNh candidates and reusable pressure/atmosphere caches. |
| `data/interim/ghcnh/selection-curated-2026-10-22/` | Primary curated ground station years and accepted observations. |
| `data/interim/igra-selection-2026-10-13/` | IGRA2 candidates, prepared profiles and ERA5 caches. |
| `data/interim/igra-selection-curated-2026-10-23/` | IGRA2 selection decisions and accepted surface–airborne pairs. |
| `data/interim/analysis-2026-10-13/` | Additional ERA5-Land inputs, per-station errors, prepared Figure 1 examples and bird altitude/terrain-elevation records. |
| `data/interim/errors_*.parquet` | Combined current ground and radiosonde error series. |
| `data/interim/location_sensitivity/` | ERA5 queries of the horizontal-position pilot. |
| `data/interim/ghcnh/terrain-srtm-aster/` | Cached SRTM/ASTER terrain queries for the elevation check of GHCNh candidates. |
| `inputs/` | Curated exclusion lists and the bird-data release record (tracked). |
| `output/tables/` | Derived numerical summaries read by figures and manuscript sources. |
| `output/position-sensitivity/` | Samples and results of the horizontal-position pilot. |
| `paper/figures/` | Manuscript and supplementary figures (PDF and PNG). |
| `output/drafts/` | Exploratory outputs outside the build (not tracked). |

Legacy caches such as `data/interim/era5/`, `gnss/`, `meteoswiss/`, `indep/`, `swiss-ghcnh/`, `gnss-ghcnh-overlap/` and `dwd/` are retained locally but are not inputs to the active analysis. They are not moved or deleted as part of the code reorganisation. Earlier primary ERA5 caches may still be used to resume reference sampling; inspect sampler dependencies before deleting them. The Zenodo data-packaging script lists the inputs distributed for rebuilding the study.

The primary GHCNh selection is `data/interim/ghcnh/selection-curated-2026-10-22/`, built by `scripts/sampling/ground_selection.R`. Raw pressure, atmospheric inputs and frozen candidate order are reused from `selection-2026-10-13/`; accepted station years are written to the curated directory. `inputs/ghcnh_reference_exclusions.csv` supplies independent reference exclusions. The selection also rejects years containing pressure discontinuities, excessive irregularity or frozen values, after isolated-spike removal. ERA5 is matched only after selecting the pressure window. Rebuild with `Rscript run_all.R ground_selection prepare analysis figures check`. Existing additional-atmosphere caches are checked for coverage of the newly selected hours.

# Data layout

The active analysis uses the frozen GHCNh and IGRA2 selections and the derived station caches described in the repository README. Paths are kept stable to preserve resumable sampling and atmospheric downloads.

| Location | Role |
|---|---|
| `data/raw/` | Downloaded invariant atmospheric grids, station inventories and GPT3 climatology. |
| `data/interim/ghcnh/selection-2026-10-13/` | Frozen GHCNh candidate decisions, accepted observations and atmospheric inputs. |
| `data/interim/igra-selection-2026-10-13/` | Frozen IGRA2 selection and accepted surface–airborne pairs. |
| `data/interim/analysis-2026-10-13/` | Current additional ERA5-Land inputs, per-station errors, historical comparison and prepared Figure 1 examples. |
| `data/interim/errors_*.parquet` | Combined current ground and radiosonde error series. |
| `data/interim/igra/` | Soundings for the fixed horizontal-position experiment. |
| `output/tables/` | Derived numerical summaries read by figures and manuscript sources. |
| `output/figures/`, `paper/figures/` | Supplementary and manuscript artwork. |
| `output/drafts/` | Exploratory artwork outside the manuscript build. |

Legacy caches such as `data/interim/era5/`, `gnss/`, `meteoswiss/`, `indep/`, `swiss-ghcnh/`, `gnss-ghcnh-overlap/` and `dwd/` are retained locally but are not inputs to the active analysis. They are not moved or deleted as part of the code reorganisation. Earlier primary ERA5 caches may still be used to resume reference sampling; inspect sampler dependencies before deleting them. The Zenodo data-packaging script lists the inputs distributed for rebuilding the study.

# How accurate is altitude from pressure geolocators?

A global assessment of three pressure-to-altitude conversions (a standard atmosphere, ERA5 surface conditions with the standard lapse rate, and ERA5 with virtual temperature and a GPT3 lapse rate), evaluated against GHCNh weather stations on the ground and IGRA2 radiosondes up to 5 km above the surface. The ERA5 conversions are implemented in [GeoPressureR](https://github.com/GeoPressure/GeoPressureR).

**Read the [manuscript](paper/paper.pdf) and its [supplement](paper/supplement.pdf).**

## Repository layout

| Folder | Content |
|---|---|
| `R/` | Shared functions: configuration and data loading (`utils.R`), station-selection checks (`ghcnh_*.R`, `igra_sampling.R`), figure settings (`figures.R`) and colours (`palette.R`). |
| `scripts/sampling/` | Selection of GHCNh stations and IGRA2 sounding sites. |
| `scripts/preparation/` | Station covariates, ERA5-Land inputs, conversion errors, bird flight heights and Figure 1 examples. |
| `scripts/analysis/` | Numerical summaries behind the manuscript, and the horizontal-position pilot. |
| `scripts/figures/` | One script per figure (`fig*.R` for the manuscript, `supp_*.R` for Additional file 1). |
| `scripts/checks/`, `tests/` | Consistency checks of the selected samples and analysis outputs, and tests of the pressure checks. |
| `inputs/` | Curated exclusion lists and the bird-data release record. |
| `output/tables/` | Derived tables read by the figures and manuscript. |
| `output/position-sensitivity/` | Samples and results of the horizontal-position pilot. |
| `paper/` | Manuscript and supplement sources (`*.qmd`), figures, bibliography and rendered PDFs. |
| `docs/` | Author notes: method reviews, curation decisions and literature reviews ([index](docs/README.md)). |
| `literature/` | Reference inventory and evidence tables; reference PDFs stay local. |
| `archive/` | Superseded workflows, retired evaluations and exploratory scripts, kept for provenance. |
| `zenodo/` | Packaging of the data archive. |

Downloaded and intermediate data live in `data/` (not tracked); see [data layout](docs/data-layout.md).

## Rebuilding

Requirements: R with `data.table`, `arrow`, `terra`, `sf`, `kgc`, `mgcv`, `ggplot2`, `patchwork`, `rnaturalearth`, `lubridate`, `httr2`, `pkgload`, `scales`, `ragg`, `systemfonts`, `cli`, `knitr` and `jsonlite`; a local GeoPressureR clone (`GEOPRESSURER_PATH`, default `~/Documents/GitHub/GeoPressureR`); and Quarto with a TeX installation. Run all commands from the repository root.

```bash
Rscript run_all.R ground_selection     # select GHCNh stations and accepted pressure records
Rscript run_all.R sounding_selection   # select IGRA2 sounding sites and accepted profiles
Rscript run_all.R prepare              # station covariates, ERA5-Land inputs and conversion errors
Rscript run_all.R errors               # recompute conversion errors only
Rscript run_all.R birds                # bird flight heights (needs GEOLOCATOR_MASTER)
Rscript run_all.R analysis             # numerical summaries and Figure 1 examples
Rscript run_all.R position             # horizontal-position pilot (queries ERA5)
Rscript run_all.R figures              # all figures from the tables
Rscript run_all.R check                # consistency checks
Rscript run_all.R render               # PDF manuscript and supplement
```

Stages can be combined, e.g. `Rscript run_all.R analysis figures check`; `all` runs selection, preparation, analysis, figures and checks. A successful check writes `output/tables/selection_analysis_complete.json`; until then the documents show a draft notice. `N_CORES` sets the number of parallel workers (default 8).

Bird flight heights come from the [Master GeoLocator Data Package, version 2026.0](https://doi.org/10.5281/zenodo.18187093); the aggregate weights in `output/tables/` suffice for ordinary builds. To rebuild them, point `GEOLOCATOR_MASTER` to the published `pressurepaths.csv` and run `birds analysis figures check`.

## Licence and citation

Code: MIT. Tables, figures and manuscript: CC BY 4.0. GHCNh, IGRA2 and ERA5 data are available from their providers; see the manuscript's data availability statement. Citation details are in [CITATION.cff](CITATION.cff).

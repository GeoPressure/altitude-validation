# How accurate is altitude from pressure geolocators?

Code and data for a global assessment of three pressure-to-altitude conversions: a standard atmosphere, ERA5 surface conditions with the standard lapse rate, and ERA5 with virtual temperature and a GPT3 lapse rate. The conversions are evaluated against GHCNh weather stations on the ground and IGRA2 radiosondes up to 5 km above the surface. The ERA5 conversions are implemented in [GeoPressureR](https://github.com/GeoPressure/GeoPressureR).

**Manuscript:** [paper.pdf](manuscript/paper.pdf) · **Supplement:** [supplement.pdf](manuscript/supplement.pdf)

## Layout

```
R/                shared functions (utils.R, ghcnh.R, igra.R, figures.R)
analysis/         numbered pipeline scripts, and figures/ with one script per figure
data/curated/     hand-curated inputs: station exclusions, position-pilot sample, bird-data release record
data/raw/         downloaded source data (not tracked)
data/derived/     station selections, ERA5 inputs and error series (not tracked; Zenodo data archive)
results/          derived tables read by the figures, and manuscript_values.csv read by the manuscript
manuscript/       paper.qmd, supplement.qmd, bibliography, figures, cover letter and render.sh
tests/            checks of the pressure screening, the selections and the result tables
docs/             author notes: data sources, selection and curation history, analysis decisions, literature
zenodo/           packaging of the Zenodo code and data archives
```

## Pipeline

| Script | Purpose |
|---|---|
| `01_candidates.R` | Station inventories, 200 km equal-area cells and random candidate order for both networks |
| `02_select_ground.R` | GHCNh station selection with pressure-only checks; ERA5 inputs of selected stations |
| `03_select_soundings.R` | IGRA2 sounding-site selection with profile-consistency checks; ERA5 inputs |
| `04_station_covariates.R` | ERA5 orography, terrain roughness and climate zone of the selected stations |
| `05_conversion_errors.R` | Errors of the three conversions (and ERA5-Land on the ground) |
| `06_bird_heights.R` | Flight-time height distribution of tracked birds |
| `07_ground_results.R` | Ground results and their variation with terrain, climate, season and time |
| `08_flight_results.R` | Flight-height results, bird-weighted summaries and column-temperature explanation |
| `09_position_sensitivity.R` | Sensitivity to the horizontal position of the atmospheric query |
| `10_figure1_examples.R` | Example weather record and soundings shown in Figure 1 |
| `11_manuscript_values.R` | All numbers quoted in the manuscript and supplement |

Run from the repository root:

```bash
Rscript run_all.R                     # results, figures and checks from cached errors
Rscript run_all.R errors results figures check render
Rscript run_all.R all                 # everything, including selection (downloads data)
```

Stages are `selection`, `errors`, `birds`, `results`, `figures`, `check` and `render`. `render` runs `manuscript/render.sh`, which builds the PDFs and the journal upload files in `manuscript/submission/`. `N_CORES` sets the number of parallel workers (default 8).

## Requirements

R with `data.table`, `arrow`, `terra`, `sf`, `kgc`, `mgcv`, `ggplot2`, `patchwork`, `lubridate`, `httr2`, `xml2`, `pkgload`, `ragg`, `systemfonts`, `png`, `cli`, `knitr` and `jsonlite`; a local GeoPressureR clone (`GEOPRESSURER_PATH`, default `~/Documents/GitHub/GeoPressureR`); Quarto with pdfLaTeX for rendering.

## Data

Station selection downloads GHCNh and IGRA2 files from NOAA and reads ERA5 from the ARCO store through GeoPressureR. The derived data needed to rebuild the results without these downloads are in the Zenodo data archive ([zenodo/data_README.md](zenodo/data_README.md)). Bird flight heights come from the [Master GeoLocator Data Package, version 2026.0](https://doi.org/10.5281/zenodo.18187093); set `GEOLOCATOR_MASTER` to its `pressurepaths.csv` to rerun `birds`. The tables in `results/` suffice otherwise.

## Licence and citation

Code: MIT. Tables, figures and manuscript: CC BY 4.0. GHCNh, IGRA2 and ERA5 data are available from their providers. Citation details are in [CITATION.cff](CITATION.cff).

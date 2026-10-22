# How accurate is altitude from pressure geolocators?

A global assessment of the altitude that [GeoPressureR](https://github.com/GeoPressure/GeoPressureR) and [GeoPressureAPI](https://github.com/GeoPressure/GeoPressureAPI) compute from a pressure measurement with ERA5, using GHCNh as the primary ground reference and IGRA2 radiosondes up to 6 km above the sounding surface.

**Read the current [manuscript](paper/paper.pdf) and [supplement](paper/supplement.pdf).** Editable sources and HTML versions are in [`paper/`](paper). The earlier exploratory report is preserved in [`archive/report/`](archive/report).

The primary reference networks use each station's latest qualifying 12 months within 2022–2026, with one passing station per represented 200 km equal-area cell. The supplement separates processing methods, environmental patterns, selection sensitivity, bird weighting and position uncertainty.

The numerical analysis uses the accepted observation windows directly, with equal ground-station weights and equal station weights within each flight-height band. Manuscript figures, supplementary comparisons and the bird-weighted summary are regenerated from these common inputs.

## Research notes

Reviews, manuscript planning and technical audits are indexed in [`docs/`](docs/README.md). The [GPS/barometer literature report](docs/literature/gps-barometer-ecology.md) is maintained as Markdown. Reference PDFs and evidence tables remain in [`literature/`](literature/README.md).

## GHCNh rolling-window selection

The direct-inventory sampler uses 200 km equal-area cells, the most recent qualifying 12-month window per station, monthly coverage and the agreed station checks. Version 2 retains the accepted pressure report closest to each ERA5 hour, with earlier reports resolving equal-distance ties. Start or resume the fixed random pilot, or extend the same run to every cell:

```bash
Rscript scripts/sample_ghcnh.R 64 4
Rscript scripts/sample_ghcnh.R all 4
```

Arguments are the number of pilot cells (or `all`) and socket workers. The default is 32 cells and four workers. Inputs, accepted station windows and cell checkpoints are under `data/interim/ghcnh/selection-2026-10-13/`; `GHCNH_RUN_DIR` selects another run directory. Candidate order and settings are frozen, completed cells are reused, and a failed transfer leaves the same candidate pending. Changing scientific settings requires a separate run directory. The [sampling record](docs/methods/ghcnh-sampling-review/README.md) gives measured runtime, storage and restart checks.

The completed selection supplies the accepted hourly observations directly to the manuscript analysis.

## IGRA rolling-window selection

```bash
Rscript scripts/sample_igra.R 16 3
Rscript scripts/sample_igra.R all 3
```

The IGRA sampler uses the same frozen domain and equal-area grid as GHCNh, with one passing station per cell and at least 15 accepted launch dates in each rolling month. It validates the downloaded station ZIP before extraction, preserves archive QC rejections, retains airborne levels through 6 km above the sounding surface, and selects the latest qualifying 12 months in daily steps. Accepted outputs contain paired surface/airborne inputs, the three conversion errors and equal-station weights within height bands. Completed cells and candidate caches are reused; a failed transfer leaves the same candidate pending.

Run files are under `data/interim/igra-selection-2026-10-13/`; `IGRA_RUN_DIR` selects a separate run. Use a new directory when scientific settings change. The [sampling record](docs/methods/igra-sampling-review/README.md) contains measured resources and restart checks. The manuscript analysis uses these accepted surface–airborne pairs without repeating selection.

## Rebuilding the analysis and documents

The project requires R with `data.table`, `arrow`, `terra`, `sf`, `kgc`, `mgcv`, `ggplot2`, `patchwork`, `rnaturalearth`, `lubridate`, `httr2`, `pkgload`, `scales`, `ragg`, `systemfonts`, `cli`, `knitr` and `jsonlite`; a local GeoPressureR clone (`GEOPRESSURER_PATH`, default `~/Documents/GitHub/GeoPressureR`); and Quarto with a TeX installation. Optional source-data downloads use `ecmwfr`, `Rarr` and provider-specific tools. The frozen selections must be complete before rebuilding.

```bash
Rscript run_all.R          # enrich accepted inputs, recompute and render
Rscript run_all.R 12       # reuse prepared error series
Rscript run_all.R 18       # primary summaries, focused checks and figures
bash paper/render.sh      # documents only, using existing tables and figures
```

`N_CORES` sets socket workers (default 8). Additional atmosphere inputs and station error series are cached under `data/interim/analysis-2026-10-13/`; interrupted reads resume at unfinished stations. The build runs only the stages listed in `run_all.R`, in dependency order.

| Stage | Purpose |
|---|---|
| 07–09 | Attach station covariates, read ERA5-Land at accepted hours and compute error series. Primary ERA5 inputs are reused from selection. |
| 12, 15 | Summarize accepted errors and environmental variation. |
| 18, 20, 21 | Compare the three conversions, calculate bird-weighted errors, test equal-tag weights and compare station-selection rules. |
| 17, 19 | Rebuild supplementary and manuscript figures from the resulting tables. |
| 22 | Check accepted samples, windows, weights, direct GeoPressureR calculations and agreement between primary and sensitivity summaries; then render both documents. |

Step 00 builds the biological weights from the published [Master GeoLocator Data Package, version 2026.0](https://doi.org/10.5281/zenodo.18187093); committed aggregate weights suffice for ordinary builds. After changing biological weights, also regenerate the equal-tag aggregates described in [T07](docs/methods/T07/implementation.md).

The fixed historical comparison and the [S6 position-displacement experiment](docs/methods/T10/design.md) retain their documented samples. Rebuild the latter with `Rscript docs/methods/T10/run_experiment.R` and its figure with `Rscript docs/methods/T10/plot_experiment.R`. Earlier calendar-year stages are archived under `archive/scripts/calendar-year-pipeline/`, and preceding numerical outputs under `archive/analysis-before-selection-2026-10-20/`.

Tables are in `output/tables/`, supplementary artwork in `output/figures/`, and manuscript artwork in `paper/figures/`. A successful validated analysis writes `output/tables/selection_analysis_complete.json`; draft notices remain visible until that check passes. Archives predating the current selection must not be mixed with the accepted rolling-window sample.

## Licence and citation

Code: MIT. Tables, figures and manuscripts: CC BY 4.0. The data sources and their licences are listed in the manuscript's Data and code availability section. Primary surface observations, station coordinates and reported elevations come directly from GHCNh.

Please cite the Zenodo record, [doi:10.5281/zenodo.23085093](https://doi.org/10.5281/zenodo.23085093) (see [`CITATION.cff`](CITATION.cff)). The record is built with `zenodo/make_archive.R` (see `zenodo/record.md`).

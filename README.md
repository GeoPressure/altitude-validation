# How accurate is altitude from pressure geolocators?

A global assessment of the altitude that [GeoPressureR](https://github.com/GeoPressure/GeoPressureR) and [GeoPressureAPI](https://github.com/GeoPressure/GeoPressureAPI) compute from a pressure measurement with ERA5, using GHCNh as the primary ground reference and IGRA2 radiosondes up to 6 km above the sounding surface. GNSS barometers with checked height metadata and MeteoSwiss supply complementary appendix checks.

**Read the current [manuscript](paper/paper.pdf) and [supplement](paper/supplement.pdf).** Editable sources and HTML versions are in [`paper/`](paper/). The earlier exploratory report is preserved in [`archive/report/`](archive/report/).

The GHCNh analysis uses each station’s latest coverage-qualified year from 2022–2026, including partial 2026 records matched to ERA5 through 2026-10-12 23:00 UTC. Recency is a selection rule, not a claim of greater measurement accuracy; the supplement compares completed years on the same stations. The final ground screen retains 1,983 stations.

The comparison adds no tag-sensor error; uncertainty in reference measurements and heights remains:

- **At screened ground-reference stations**, a fixed standard atmosphere gives a mean absolute error of 53.8 m and a 95th percentile of absolute error of 143 m; local ERA5 conditions reduce these to 6.5 m and 22 m. Without the station screen, ground MAE is 67.4 m and 21.6 m respectively; the improvement persists, while exact errors depend on reference quality.
- **In flight**, mean absolute error weighted by the flight heights of tracked birds falls from 42.2 m with the standard atmosphere to 16.8 m with ERA5 and 13.4 m with virtual temperature and a GPT3 lapse rate.
- **ERA5-Land** is less accurate on the ground than ERA5 single-levels.

## Research notes

Reviews, manuscript planning and technical audits are indexed in [`docs/`](docs/README.md). The [GPS/barometer literature report](docs/literature/gps-barometer-ecology.md) is maintained as Markdown. Reference PDFs and evidence tables remain in [`literature/`](literature/README.md).

## Reproducing

The folder is an R project. It needs R ≥ 4.3 with `data.table`, `arrow`, `ncdf4`, `terra`, `mgcv`, `ggplot2`, `patchwork`, `sf`, `rnaturalearth`, `kgc`, `zoo`, `R.utils`, `httr2`, `ecmwfr`, `Rarr`, `pkgload`, `scales`, `ragg`, `systemfonts`, `readr`, `dplyr`, `lubridate`, `cli`, `knitr`, `rmarkdown`, `jsonlite` and `leaflet`; a local clone of GeoPressureR (`GEOPRESSURER_PATH`, default `~/Documents/GitHub/GeoPressureR`); a CDS API key registered with `ecmwfr`; `curl`, `funzip` and `awk`; and Quarto.

```bash
Rscript run_all.R
```

This runs the scripts in `scripts/` in order and renders the manuscript and supplement; `Rscript run_all.R 12` starts at step 12, `Rscript run_all.R 12 15` runs steps 12 to 15. Downloads and ERA5 extraction reuse files already on disk, so data intake can be interrupted and resumed; analyses and figures are regenerated. `N_CORES` (default 8) sets the number of parallel workers.

Archived inputs can be reused by unpacking `altitude-validation-data.zip` from the [Zenodo record](https://doi.org/10.5281/zenodo.23085093) at the root of the project. The pipeline downloads missing GHCNh annual files and ERA5 station series; an archive predating this transition does not contain the new GHCNh extraction.

| Steps | Scripts |
|---|---|
| 01–08 Data | GHCNh station frame and annual observations (`01`–`03`), IGRA2 (`04`), GNSS (`05`), MeteoSwiss (`06`), station covariates (`07`), ERA5 at every station from the ARCO archive (`08`) |
| 09–11 Errors and checks | altitude errors (`09`), GeoPressureAPI cross-check (`10`), checks of the GHCNh stations (`11`) |
| 12–16 Analysis | summaries and reference screen (`12`), bird-weighted error (`13`), GNSS and MeteoSwiss (`14`), variation of the error (`15`), formula changes (`16`) |
| 17 Exploratory figures | figures for the archived report, from `output/tables` |
| 18–20 Manuscript | three-conversion comparisons and error tails (`18`), manuscript figures (`19`), sensitivity appendix (`20`) |

Step `00` uses the published [Master GeoLocator Data Package, version 2026.0](https://doi.org/10.5281/zenodo.18187093), verifies the input checksums and excludes tags without usable classified flight. It reads `GeoLocatorMaster/data/master/pressurepaths.csv` by default (`GEOLOCATOR_MASTER` overrides the path); its aggregate output and provenance are committed. After updating these weights, rerun steps 13 and 16–20, then `Rscript docs/methods/T07/assess_flight_targets.R` for the biological sensitivity appendix, and render both documents. For an update limited to biological weights, [the T07 rebuild](docs/methods/T07/implementation.md) reuses unchanged reference-error curves. Tables (`output/tables`) and figures (`output/figures`) are prefixed `ground_`, `flight_`, `formula_` and `indep_` (GNSS and MeteoSwiss). Use `Rscript run_all.R 18` for a cached-data manuscript rebuild. The current manuscript uses the `paper_` tables and figures in `paper/figures/`. Step 20 regenerates the sensitivity appendix from the same cached inputs. Step 18 averages duplicate GNSS hours before final QC, assigns GHCNh cell weights after screening, and retains the established flight weights. Its generation provenance is recorded separately in `output/tables/paper_analysis_provenance.json`; exploratory tables retain their earlier definitions. Render the manuscript and supplement without rerunning the analysis with:

```bash
bash paper/render.sh
```

The small S6 location-displacement pilot is documented in [T10](docs/methods/T10/design.md). Regenerate its paired weather experiment with `Rscript docs/methods/T10/run_experiment.R` (network reads are cached per station); its figure can be rebuilt from the committed aggregate CSVs with `Rscript docs/methods/T10/plot_experiment.R`. This pilot is separate from the main analysis and does not rerun during ordinary cached builds.

The original annotated abstract is preserved as [`paper/paper-annotated.pdf`](paper/paper-annotated.pdf). The archived report and its retired GitHub Pages workflow are in `archive/report/`; it is no longer built by the main pipeline.

## Licence and citation

Code: MIT. Tables, figures and manuscripts: CC BY 4.0. The data sources and their licences are listed in the manuscript's Data and code availability section. The HadISD station inventory is used only to preserve the original candidate footprint for the transition; all surface pressure observations and analysis station elevations come from GHCNh.

Please cite the Zenodo record, [doi:10.5281/zenodo.23085093](https://doi.org/10.5281/zenodo.23085093) (see [`CITATION.cff`](CITATION.cff)). The record is built with `zenodo/make_archive.R` (see `zenodo/record.md`).

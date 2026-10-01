# How accurate is altitude from pressure geolocators?

A global validation of the altitude that [GeoPressureR](https://github.com/GeoPressure/GeoPressureR) and [GeoPressureAPI](https://github.com/GeoPressure/GeoPressureAPI) compute from a pressure measurement with ERA5, against HadISD weather stations, GNSS and MeteoSwiss stations with documented barometer heights, and IGRA2 radiosondes up to 6 km above the ground.

**➜ Read the report: <https://geopressure.github.io/altitude-validation/>**

In short, with ERA5 single-levels (the default) and a perfect pressure reading:

- **On the ground**, the median station has a constant bias of 2.5 m and a scatter (SD) of 3.6 m; both grow with the gap between the station and ERA5's smoothed terrain.
- **In flight**, altitude is underestimated by 1–1.5% of the height above the ground; over the heights birds fly, the mean absolute error is 16.4 m.
- **ERA5-Land** is about four times less accurate on the ground: do not use it for altitude.
- **The formula can be improved**: the virtual temperature and a lapse rate varying with season and latitude remove most of the in-flight bias.

## Reproducing

The folder is an R project. It needs R ≥ 4.3 with `data.table`, `arrow`, `ncdf4`, `terra`, `mgcv`, `ggplot2`, `patchwork`, `sf`, `rnaturalearth`, `kgc`, `zoo`, `R.utils`, `httr2`, `ecmwfr`, `Rarr`, `pkgload`, `scales`, `ragg`, `systemfonts`, `knitr`, `rmarkdown` and `leaflet`; a local clone of GeoPressureR (`GEOPRESSURER_PATH`, default `~/Documents/GitHub/GeoPressureR`); a CDS API key registered with `ecmwfr`; `curl`, `funzip` and `awk`; and Quarto.

```bash
Rscript run_all.R
```

This runs the scripts in `scripts/` in order and renders the report; `Rscript run_all.R 12` starts at step 12, `Rscript run_all.R 12 15` runs steps 12 to 15. Every step skips work already on disk, so the pipeline can be interrupted and resumed. `N_CORES` (default 8) sets the number of parallel workers.

To skip the slow downloads (several hours of ERA5 reads), first unzip `altitude-validation-data.zip` from the [Zenodo record](https://doi.org/10.5281/zenodo.XXXXXXX) at the root of the project: only HadISD (about 2 GB) is then downloaded.

| Steps | Scripts |
|---|---|
| 01–08 Data | HadISD (`01`–`03`), IGRA2 (`04`), GNSS (`05`), MeteoSwiss (`06`), station covariates (`07`), ERA5 at every station from the ARCO archive (`08`) |
| 09–11 Errors and checks | altitude errors (`09`), GeoPressureAPI cross-check (`10`), checks of the HadISD stations (`11`) |
| 12–16 Analysis | summaries and reference screen (`12`), bird-weighted error (`13`), GNSS and MeteoSwiss (`14`), variation of the error (`15`), formula changes (`16`) |
| 17 Figures | all figures, from `output/tables` |

Step `00` (flight heights of tracked birds) needs the GeoLocator master data package locally; its binned output is committed. Tables (`output/tables`) and figures (`output/figures`) are prefixed `ground_`, `flight_`, `formula_` and `indep_` (GNSS and MeteoSwiss). The report is rendered to [`report/index.md`](report/index.md) and, by a GitHub Action at every push to `main`, to the HTML page.

## Licence and citation

Code: MIT. Tables, figures and report: CC BY 4.0. The data sources and their licences are listed in the report's [Data and code availability](https://geopressure.github.io/altitude-validation/#data-and-code-availability) section. HadISD: *this product may contain data which are governed by WMO Policy following WMO Resolution 40 Annex 1 alongside additional data that may have restrictions placed on their commercial use by the data owners*; only derived statistics are published here.

Please cite the Zenodo record, [doi:10.5281/zenodo.XXXXXXX](https://doi.org/10.5281/zenodo.XXXXXXX) (see [`CITATION.cff`](CITATION.cff)). The record is built with `zenodo/make_archive.R` (see `zenodo/record.md`).

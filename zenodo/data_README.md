# Data for "How accurate is altitude from pressure geolocators?"

Downloaded and extracted data behind <https://github.com/GeoPressure/altitude-validation>. Unzip at the root of the repository (this creates `data/`) and run `Rscript run_all.R`: GHCNh annual station files are downloaded by steps 01-03, while the other inputs are read from here and every result is recomputed.

| Path | Content | Source and licence |
|---|---|---|
| `interim/era5/` | Hourly ERA5 single-levels (surface pressure, 2 m temperature, skin temperature, boundary layer height, 2 m dewpoint at the radiosondes) and ERA5-Land (surface pressure, 2 m temperature) at every GHCNh (`ghcnh_<id>`) and radiosonde (`igra_<id>`) station, read from the ECMWF ARCO archive | Generated using Copernicus Climate Change Service information 2026, CC BY 4.0. ERA5: doi:10.24381/cds.adbb2d47; ERA5-Land: doi:10.24381/cds.e2161bac |
| `interim/indep/` | Hourly pressure and altitude error (ERA5 single-levels and ERA5-Land) at every GNSS and MeteoSwiss station | IGS / EUREF or MeteoSwiss (below) and Copernicus, CC BY 4.0 |
| `interim/neighbours/` | Mean selected-year altitude error (bias) of the GHCNh stations within 50 km of each tested station, for the reference checks | Derived statistics, this study |
| `raw/era5_invariant.nc` | ERA5 sub-grid orography and land-sea mask | As above |
| `interim/igra/`, `interim/igra_*.csv`, `raw/igra2-station-list.txt` | IGRA2 soundings 2023-2024 and station lists | NOAA NCEI, IGRA v2.2, doi:10.7289/V5X63K0Q, no use restrictions |
| `interim/gnss/`, `raw/gnss_logs/` | Hourly pressure from IGS and EUREF RINEX meteorological files (BKG GNSS Data Center), file listing and station site logs | International GNSS Service and EUREF Permanent GNSS Network, CC BY 4.0 |
| `interim/meteoswiss/`, `raw/ogd-smn_meta_stations.csv` | SwissMetNet station pressure (QFE) 2022-2024 and station metadata | Source: MeteoSwiss, CC BY 4.0 |
| `raw/isd-history.csv` | NOAA ISD station history, as downloaded | NOAA NCEI, no use restrictions |
| `interim/station_dem*.csv` | DEM elevations at the station coordinates (OpenTopoData) | Mapzen terrain tiles, SRTM GL1 (NASA, public domain), ASTER GDEM v3 (NASA/METI) |
| `interim/era_ids.csv` | GHCNh stations sampled for the historical years | This study |

Not included: GHCNh annual observations (downloaded by steps 01-03 from NOAA NCEI; the HadISD station inventory is used only to preserve the previous candidate footprint), the bird tracks (available separately in the Master GeoLocator Data Package version 2026.0, doi:10.5281/zenodo.18187093; this archive includes only aggregate height weights and their input provenance), and the altitude errors (recomputed by step 09).

Files are Apache Parquet (read with the R `arrow` package), CSV and NetCDF. Times are UTC; pressure in hPa (GNSS, MeteoSwiss) or Pa (ERA5, IGRA2); heights in m.

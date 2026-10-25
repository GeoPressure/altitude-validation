# Zenodo record

Reserved DOI [10.5281/zenodo.23085093](https://doi.org/10.5281/zenodo.23085093) (draft, uploaded by hand). Build the two upload files with

```bash
Rscript zenodo/make_archive.R
```

which writes `data/zenodo/altitude-validation-code.zip` (the tracked repository and rendered PDFs) and `data/zenodo/altitude-validation-data.zip` (the derived data listed in `zenodo/data_README.md`, which is included as `data/README.md`).

## Metadata

- **Resource type:** Dataset. **Version:** v1. **Licence:** CC BY 4.0 for derived data and manuscript material; MIT for code. Third-party inputs keep their source terms.
- **Title:** How accurate is altitude from pressure geolocators? Code and data for a global assessment of three pressure-to-altitude conversions
- **Creators:** Nussbaumer, Raphaël (Swiss Ornithological Institute, Sempach, Switzerland; ORCID 0000-0002-8185-1020); Gravey, Mathieu (Institute for Interdisciplinary Mountain Research, Austrian Academy of Sciences, Innsbruck, Austria; ORCID 0000-0002-0871-1507).
- **Keywords:** geolocator; barometric altimetry; ERA5; GPT3; bird migration; flight height; GHCNh; IGRA2; validation
- **Related works:** is supplement to https://github.com/GeoPressure/altitude-validation; references https://github.com/GeoPressure/GeoPressureR, 10.25921/jp3d-3v19 (GHCNh), 10.7289/V5X63K0Q (IGRA2), 10.24381/cds.adbb2d47 (ERA5), 10.24381/cds.e2161bac (ERA5-Land), 10.1007/s00190-017-1066-2 (GPT3) and 10.5281/zenodo.18187093 (bird trajectories).

## Description

Code and data accompanying "How accurate is altitude from pressure geolocators? A global assessment of three pressure-to-altitude conversions on the ground and in flight". The study evaluates a fixed standard atmosphere, a conversion using ERA5 surface conditions with a standard lapse rate, and an ERA5 conversion with virtual temperature and a climatological lapse rate from GPT3, against NOAA GHCNh weather stations on the ground and NOAA IGRA2 radiosondes up to 5 km above the launch surface. Each network contains at most one station per 200 km equal-area cell, using the latest qualifying 12-month period within 2022–2026.

`altitude-validation-code.zip` contains the R code, derived tables, figures and manuscript sources. `altitude-validation-data.zip` contains the station candidate caches, accepted observations, ERA5 and ERA5-Land inputs, and the other derived data needed to rebuild the results; extract it inside the `altitude-validation/` directory of the code archive. Individual bird trajectories are available separately in the Master GeoLocator Data Package, version 2026.0 (https://doi.org/10.5281/zenodo.18187093). Contains modified Copernicus Climate Change Service information 2026; neither the European Commission nor ECMWF is responsible for the use made of this information.

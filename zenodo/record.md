# Zenodo record (manual upload)

One record, two files, built by `Rscript zenodo/make_archive.R` into `data/zenodo/`:

1. `altitude-validation-code.zip`: code, derived tables and figures, manuscript, supplement and archived report.
2. `altitude-validation-data.zip`: the data needed to rerun the study without the slow downloads (see `zenodo/data_README.md`, included in the archive as `data/README.md`).

DOI (reserved): [10.5281/zenodo.23085093](https://doi.org/10.5281/zenodo.23085093), already in `README.md`, `CITATION.cff` and `paper/paper.qmd`. Steps: run `Rscript zenodo/make_archive.R`, upload the two files with the metadata below, publish. For a new version, use "New version" on the record.

## Metadata

- **Resource type:** Dataset
- **Title:** How accurate is altitude from pressure geolocators? Code and data of a global validation of GeoPressureR altitude
- **Creators:**
  - Nussbaumer, Raphaël; Swiss Ornithological Institute, Sempach, Switzerland; ORCID 0000-0002-8185-1020
  - Gravey, Mathieu; Institute for Interdisciplinary Mountain Research, Austrian Academy of Sciences, Innsbruck, Austria; ORCID 0000-0002-0871-1507
- **Licence:** Creative Commons Attribution 4.0 International (code under MIT, see `LICENSE` in the code archive)
- **Keywords:** geolocator; barometric altimetry; ERA5; bird migration; flight altitude; validation
- **Community:** geolocator-dp
- **Related works:**
  - is supplement to https://github.com/GeoPressure/altitude-validation
  - is documented by https://geopressure.github.io/altitude-validation/
  - is supplement to https://github.com/GeoPressure/GeoPressureR
  - references 10.24381/cds.adbb2d47 (ERA5), 10.24381/cds.e2161bac (ERA5-Land), 10.7289/V5X63K0Q (IGRA2)

**Description:**

Code and data of a global validation of the altitude that GeoPressureR and GeoPressureAPI retrieve from a pressure measurement using the ERA5 reanalysis. The primary references are NOAA GHCNh surface stations worldwide and IGRA2 radiosondes up to 6 km above the sounding surface, each using the latest qualifying 12 months within 2022–2026 and one accepted station per represented 200 km equal-area cell. GNSS and MeteoSwiss stations with documented barometer heights provide complementary appendix checks (2022-2024). The study separates accuracy (per-site bias) from precision (temporal scatter), shows what they depend on, compares ERA5 single-levels with ERA5-Land, and tests improvements of the pressure-to-altitude formula. Manuscript and supplement: https://github.com/GeoPressure/altitude-validation/tree/main/paper.

`altitude-validation-code.zip` holds the R scripts, the derived tables and figures, the manuscript and supplement, and the archived report. `altitude-validation-data.zip` holds the hourly ERA5 and ERA5-Land series at every station, the radiosonde soundings, the GNSS and MeteoSwiss pressure series and the station lists as downloaded: unzip it at the root of the code and run `Rscript run_all.R` to recompute every result. The archive includes frozen candidate decisions and accepted rolling-window inputs; raw annual NOAA downloads are not required for the analysis rebuild.

Contains modified Copernicus Climate Change Service information 2026 (CC BY 4.0); IGRA2 (NOAA NCEI); IGS and EUREF Permanent GNSS Network data via the BKG GNSS Data Center (CC BY 4.0); Source: MeteoSwiss (CC BY 4.0).

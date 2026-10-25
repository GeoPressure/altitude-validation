# Data for “How accurate is altitude from pressure geolocators?”

Extract `altitude-validation-code.zip`, then extract `altitude-validation-data.zip` inside the resulting `altitude-validation/` directory. The data archive supplies a `data/` directory alongside `R/`, `analysis/` and `run_all.R`. All times are UTC. Vertical coordinates are in metres; IGRA2 reports geopotential height. GHCNh station pressure is in hPa, while ERA5 and IGRA2 pressure are in Pa.

## Rebuild the study

Install the R packages and system tools listed in the repository README. The analysis uses GeoPressureR 3.6.6.9000, commit `f1431bc3c49f88e3738a60e4987be29145fa34a7`, available from https://github.com/GeoPressure/GeoPressureR. Check out that revision in a local clone and set `GEOPRESSURER_PATH` to its location. The figure and document stages additionally require the fonts, Quarto and TeX installation described in the code repository.

From the extracted repository root, run:

```bash
Rscript run_all.R errors results figures check render
```

This recomputes the conversion errors from the accepted observations and atmospheric caches, then the result tables, figures, checks and PDF documents. `Rscript run_all.R selection` reruns station selection from the cached candidate records.

The bird distribution and Figure S4 can be reproduced from the derived weights and figure-input tables in the code archive. Reconstructing these inputs from individual bird trajectories instead requires the separate Master GeoLocator Data Package, version 2026.0 (https://doi.org/10.5281/zenodo.18187093), as described in the repository README. Individual bird trajectories are not redistributed here.

## Archive contents

Paths below are relative to the extracted `data/` directory.

| Path | Content | Source |
|---|---|---|
| `derived/ghcnh/candidates/` | Frozen candidate list and order, archive catalogue, pressure and reference series and ERA5 inputs of assessed candidates | NOAA GHCNh and ECMWF ERA5 |
| `derived/ghcnh/selection/` | Accepted station years with ERA5 inputs, selection settings and decisions | NOAA GHCNh and ECMWF ERA5 |
| `derived/ghcnh/terrain/` | Station-elevation checks and terrain-query responses | SRTM v3 and ASTER GDEM v3 via Open Topo Data |
| `derived/igra/candidates/` | Frozen candidate list and order, prepared sounding profiles and ERA5 inputs | NOAA IGRA2 and ECMWF ERA5 |
| `derived/igra/selection/` | Accepted surface–airborne pairs, selection settings and decisions | NOAA IGRA2 and ECMWF ERA5 |
| `derived/analysis/era5_land/` | ERA5-Land surface pressure and temperature at the accepted ground hours | Copernicus Climate Change Service |
| `derived/position_sensitivity/` | ERA5 inputs of the position-sensitivity pilot | ECMWF ERA5 |
| `raw/era5_invariant.nc` | ERA5 sub-grid orography and land–sea mask | Copernicus Climate Change Service |
| `raw/ghcnh-station-list.txt`, `raw/igra2-station-list.txt` | Station inventories used to build the candidate lists | NOAA NCEI |
| `raw/gpt3/` | GPT3 climatological lapse-rate grids | Vienna Mapping Functions Data Server |

The selections use qualifying 12-month periods within 2022–2026; the position-sensitivity pilot uses 2024 soundings. Raw GHCNh annual files and IGRA2 archives are not included; they are downloaded again when a new candidate is assessed.

## Sources and rights

Original study code is distributed under MIT. Original derived tables, figures and manuscript material are distributed under CC BY 4.0. Third-party inputs retain their source terms and attribution requirements; the record licence does not replace those terms.

- GHCNh: NOAA NCEI, https://doi.org/10.25921/jp3d-3v19.
- IGRA2: NOAA NCEI, https://doi.org/10.7289/V5X63K0Q.
- ERA5: https://doi.org/10.24381/cds.adbb2d47; ERA5-Land: https://doi.org/10.24381/cds.e2161bac. Contains modified Copernicus Climate Change Service information 2026, supplied under the CC-BY licence. Neither the European Commission nor ECMWF is responsible for the use made of this information.
- Terrain-query sources: https://www.opentopodata.org/datasets/srtm/ and https://www.opentopodata.org/datasets/aster/.
- GPT3: https://vmf.geo.tuwien.ac.at/codes/; terms: https://vmf.geo.tuwien.ac.at/terms.html. Cite Landskron and Böhm (2018), https://doi.org/10.1007/s00190-017-1066-2, and the VMF Data Server, https://doi.org/10.17616/R3RD2H.

**Later implementation:** The primary results were regenerated under T06 with separate generation provenance; see the [implementation record](../T06/implementation.md). This note retains the earlier technical-audit snapshot.

# T04: atmospheric-method verification

Checked 18 October 2026. This note records the evaluated implementation, the corresponding physics and the manuscript edits. It does not modify conversion code or recalculate the study's results.

## Findings and disposition

| Question | Verified finding | Action |
|---|---|---|
| Hydrostatic explanation, C10 | Combining dp/dz = −ρg with p = ρRTv/M gives the hypsometric integral under constant g. Hydrostatic balance does not require all horizontal motion to cease. | Replaced the opening Methods explanation. |
| Column temperature, C11 | The integral uses a log-pressure-weighted mean Tv, not an isothermal column. A linear profile is a subsequent assumption. | Added the mean definition, lapse-rate sign convention and separate linear-profile explanation. |
| Humidity, C12 | `virtual_temperature()` and package `pressure_to_altitude()` calculate vapour pressure from dewpoint, then specific humidity and Tv. They do not read an ERA5 Tv variable. | Explained the two calculation steps and added formulas in supplement S5. |
| Vertical humidity | A dry-temperature GPT3 gradient is applied to a surface virtual temperature. This approximates the virtual-temperature profile; neither vertical humidity nor an instantaneous profile is integrated. | Stated explicitly, alongside the 2 m versus surface reference approximation. |
| GPT3 cycles, C13 | All five mean/annual/semi-annual coefficients are used; K/km is converted to K/m; integer UTC day of year is used without hemisphere shift. | Replaced the ambiguous time-interpolation wording. |
| Spatial interpolation | R uses bilinear interpolation and longitude wrap, holding latitude at the edge row while retaining longitude interpolation. TU Wien switches to a single nearest neighbour for latitudes at or beyond ±89.5°. | Documented this difference; no change to the evaluated implementation. |
| Harmonic phase | TU Wien uses calendar day plus the fractional day. The evaluated R helper/package uses the calendar day alone; the flight comparison reconstructs the calendar date from the sounding identifier. | Described this approximation rather than claiming an exact full-routine reproduction. |
| Numerical lapse-rate limit | Main conversion replaces any absolute L below 10⁻⁵ K/m with −10⁻⁵ K/m. This is distinct from the −9.5 to −2 K/km bounds on the fitted season–latitude variant in script 16. | Added the main safeguard and separated the two limits in S5. |
| Geopotential/geometric height | ERA5 geopotential is divided by standard gravity, IGRA uses geopotential height, and no separate geometric correction is made. Ground heights have additional survey/geoid conventions. | Named the convention in Methods and detailed its size/limits in S5. |
| Surface-referenced flight error, C21/C23 | Script 09 subtracts the surface error from each level's error within the sounding. Script 18 uses the equivalent difference-of-height-differences for the other conversions. Weather at a level is annotated at its rounded observation hour, not necessarily the launch hour. | Rewrote the main error definition as an explicit equation. No assertion of actual terrain clearance along a track. |
| Pressure offset cancellation | An additive pressure offset does not exactly cancel from altitude differences, because dz/dp changes with height. | Corrected the pressure-sensor Discussion passage and its signed derivative; removed the blanket claim that geolocation is unaffected, since absolute-altitude constraints are a separate component. |
| Full ERA5 profiles, C14 | They are an established alternative, including ecological pressure-level lapse-rate precedents. This study has no matched accuracy/runtime/data-volume benchmark. | Discussed as an untested trade-off for year-round five-minute records; removed the categorical feasibility/performance implication. |

## Checks run

`Rscript docs/methods/T04/check_methods.R` runs a deterministic calculation against the current local GeoPressureR checkout and the existing GPT3 grid. Results are in `check-results.csv` and `height-convention.csv`.

- 54 combinations of reference temperature, pressure, lapse rate and height: closed-form retrieval and independent numerical integration of the hypsometric integral both recover the specified heights within 2 × 10⁻¹¹ m. Cases include a positive lapse rate.
- 90 combinations of position/date, including longitude wrap, polar points and leap day: the repository's corrected conversion equals the actual package calculation to the reported numerical precision (maximum difference 0 m).
- TU Wien's fractional-day treatment and polar nearest-neighbour rule differ from the R implementation. On the selected sample, the maximum half-day lapse change is 0.0794 K/km and the polar interpolation difference is 0.0500 K/km. These are sampled implementation differences, not global maxima or a recalculated effect on the paper's MAE. No claim of complete numerical equivalence to TU Wien is warranted.
- A constant +1 hPa pressure offset in a dry standard-atmosphere example leaves a −1.81 m residual error in the surface-referenced height at 2 km. This counterexample establishes why exact cancellation was an incorrect claim; it is not an empirical estimate of tag error.
- Under a 6371 km spherical approximation, geometric minus geopotential height is 0.63 m at 2 km and 5.66 m at 6 km above sea level. Actual differences also depend on gravity/latitude and the chosen reference.

## Sources and implementation record

- [TU Wien GPT3 reference implementation](https://vmf.geo.tuwien.ac.at/codes/gpt3_1_fast.m), retrieved 18 October 2026 as `gpt3_1_fast.m`. Relevant source sections: conversion from MJD to fractional day of year; harmonic factors; polar versus bilinear interpolation. The full routine returns several atmospheric quantities; only the lapse-rate field is used here.
- [Landskron & Böhm (2018)](https://doi.org/10.1007/s00190-017-1066-2), model description; local canonical PDF and bibliography already archived.
- [ECMWF height conventions](https://confluence.ecmwf.int/spaces/CKB/pages/158636068/ERA5%2Bcompute%2Bpressure%2Band%2Bgeopotential%2Bon%2Bmodel%2Blevels%2Bgeopotential%2Bheight%2Band%2Bgeometric%2Bheight), reference for geopotential/g and the spherical geometric-height approximation.
- Wallace & Hobbs (2006), atmospheric physics reference already in the manuscript bibliography, for hydrostatic and hypsometric relations; Bolton (1980) for vapour-pressure approximation.
- Repository: `R/utils.R` (`altitude_lapse`, `virtual_temperature`, `gpt3_read`, `gpt3_lapse`), `scripts/09_errors.R`, `scripts/16_formula.R`, `scripts/18_three_formulas.R`.
- GeoPressureR: local `R/pressure_to_altitude.R`, `R/gpt3_lapse_rate.R`, `R/era5_surface_elevation.R`, and `R/path2elevation.R`. Hashes/version are in `provenance.json`. Local code and online documentation may describe different package states; this audit checks the local functions used by this project.

## Remaining decisions

No mathematical-sign discrepancy was found in the evaluated conversion. The fractional-day, polar interpolation, near-zero safeguard, vertical-humidity and height-convention approximations are documented, not silently changed. Altering them would require deciding whether to change GeoPressureR, the evaluation or both, followed by a quantified result comparison. The existing `output/tables/geopressurer_version.txt` records 3.6.3.9000 while the current checkout already contains the newer corrected formula; this file alone is insufficient provenance for every later formula output. T05 should reconcile output-generation dates with package/commit provenance before submission.

T04's method audit and associated prose edits are complete. Dataset-level height provenance, radiosonde source-by-source height construction, observation independence and realised coverage remain T05; the audit does not certify those claims. Figure 1's temperature labels and approximation to the column mean remain T08. A separate location-uncertainty study is specified in `docs/manuscript/location-sensitivity-plan.md` and T10; it has not been run.

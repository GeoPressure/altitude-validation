# How accurate is altitude from pressure geolocators?
Raphaël Nussbaumer
2026-09-30

> [!NOTE]
>
> ### In short
>
> **At ground level**, GeoPressureR’s default (ERA5 single-levels)
> retrieves a geolocator’s altitude with a median per-site **bias of 3.2
> m** (90% of sites within 15.5 m) and a **temporal scatter (SD) of 4.1
> m** (919 stations worldwide, 2022–2024). Pooled over all station-hours
> the mean absolute error is **7.4 m** and 95% of errors are below 25.4
> m. Terrain roughness is the main driver: errors roughly triple from
> flat to mountainous terrain.
>
> **In flight**, altitude is **underestimated by about 1–1.5% of the
> height above the ground** (-14 m at 1–1.5 km, -35 m at 2–3 km, -91 m
> at 5–6 km), because the formula assumes a standard temperature
> profile. The error is largest in continental and polar winters
> (surface inversions). Averaged over the heights at which tracked birds
> fly, flight adds a mean absolute error of **15.6 m**.
>
> **ERA5-Land** is much worse for absolute altitude (MAE 28.9 m) and
> should not be used for it.

# Why this study

GeoPressureR (and GeoPressureAPI behind it) converts the pressure a
geolocator records into an altitude using ERA5 reanalysis: the surface
pressure $p_0$ and 2 m temperature $T_0$ at the bird’s location and
hour, the ERA5 orography $z_0$, and the barometric formula with a
standard lapse rate $L = -6.5$ K/km,

$$
z = z_0 + \frac{T_0}{L}\left[\left(\frac{p}{p_0}\right)^{-R L / (g M)} - 1\right].
$$

Users want to know how good that altitude is, where and when it is
worse, and why. An earlier check over the Alps
([GeoPressureAPI#27](https://github.com/GeoPressure/GeoPressureAPI/issues/27))
found ~9 m mean absolute error with ERA5 single-levels and led to making
single-levels the default. This study extends that check to the whole
globe, a full annual cycle, three recent years, and — using radiosondes
— to the heights at which birds fly.

# Methods

## What is validated

The exact GeoPressureR code path is evaluated: grid-cell snapping,
nearest-hour matching, the ERA5 orography files and
`pressure_to_altitude()` are taken from GeoPressureR 3.6.3.9000
(bc72cf02), reading ERA5 from the ECMWF ARCO archive
(`pressurepath_create(source = "arco")`). A cross-check against
GeoPressureAPI (Earth Engine) on 2238 station-hours found a maximum
difference of 0.09 m, so every result below applies to both entry
points.

Two ERA5 products are compared: **ERA5 single-levels** (0.25°, the
default) and **ERA5-Land** (0.1°). The mixed `"both"` option is not
evaluated separately: over land it is ERA5-Land.

## Reference data

**Tier A — surface barometers (ground level).** HadISD v3.4.3.2025f
(Dunn et al. 2012, 2016), a quality-controlled subset of NOAA ISD. Its
station-level pressure is treated as a geolocator reading and the
retrieved altitude is compared with the station elevation. Stations were
chosen for spatial balance: in every 5°×5° cell the highest, the lowest
and one random station, plus every station above 1000 m. Stations had to
report station pressure on at least half the days of each of 2022–2024,
at least 6-hourly; the set was then thinned to one random station per 5°
cell plus one per 2.5° cell above 1000 m. ERA5-Land was evaluated on a
random 200 of these stations, and a random 100 reporting in 1990, 2005
and 2015 test for changes over time.

**Tier B — radiosondes (0–6 km above ground).** IGRA2 (Durre et
al. 2006, 2018), 2023–2024. At every level the sonde reports pressure
and geopotential height; the pressure is given to the altitude formula
at the launch site and hour of that level, and the retrieved altitude is
compared with the sonde’s height. Stations: the highest and one random
active station per 10°×10° cell, plus all above 1000 m.

## Separating accuracy from precision, and handling errors in the reference

At ~5–10 m, errors in the reference itself matter. Three choices keep
them out of the headline numbers:

- **Accuracy vs precision.** Each station’s error is split into its mean
  (the *bias*: constant in time, relevant for absolute altitude) and the
  SD around that mean (*precision*: relevant for altitude changes). A
  wrong station elevation shifts only the bias, so precision is robust
  to metadata errors.
- **Trusted metadata subset.** Accuracy is also reported for stations
  whose HadISD elevation agrees within 20 m with an independent DEM
  (Mapzen terrain tiles via OpenTopoData).
- **Height relative to the surface level (Tier B).** The error at a
  level minus the error at the same sounding’s surface level cancels the
  station elevation entirely, isolating how the error grows with height.

Gross observation errors were flagged when more than 100 m (Tier A) or
150 m (Tier B) and 10 robust SD from the station’s (or height bin’s)
median error: 0.00076 of Tier A and 0.00060 of Tier B observations.

Pooled statistics give every station equal weight.

**Reference consistency screen.** 50 of 969 Tier A stations (5%) carry a
constant offset larger than any plausible extrapolation error (\|bias\|
\> 30 m + 10% of the gap between station elevation and ERA5 orography,
equivalent to a ~28 K error in the assumed layer temperature). Their
pressure tracks ERA5 hour by hour (median SD ~5 m) but at a fixed offset
of typically 75 m: the signature of a pressure reported at a different
height than the listed elevation (datum or metadata error), not of a
reanalysis error. They are included in the “all stations” row and
excluded elsewhere. A few could be genuine errors in deep valleys; this
is a limitation.

## Drivers

Candidate drivers of accuracy and precision: the difference between
station elevation and ERA5 orography, sub-grid terrain roughness (ERA5
`sdor`), latitude, Köppen-Geiger climate zone (station level); local
solar hour, season, boundary layer height, skin − 2 m temperature (a
proxy for surface inversions) and 6 h surface pressure tendency
(observation level). Their effect is estimated with GAMs (mgcv) and
ranked by the deviance explained lost when each is dropped.

For Tier B, the error expected from the temperature assumption alone is
$\Delta z \cdot (\bar T_\text{assumed} - \bar T_\text{obs}) / \bar T_\text{obs}$,
where $\bar T_\text{obs}$ is the sonde’s log-pressure-weighted mean
temperature of the layer below the level.

# Results: ground level (Tier A)

| subset | dataset | stations | obs | median \|bias\| | p90 \|bias\| | median SD | p90 SD | MAE | RMSE | p95 \|err\| |
|:---|:---|---:|:---|---:|---:|---:|---:|---:|---:|---:|
| all stations | single-levels | 969 | 13,305,349 | 3.4 | 21.7 | 4.2 | 8.8 | 16.8 | 81.3 | 43.9 |
| all stations | land | 174 | 2,370,459 | 15.4 | 72.1 | 5.7 | 12.4 | 31.4 | 51.7 | 116.9 |
| consistent reference (excl. datum/metadata errors) | single-levels | 919 | 12,796,795 | 3.2 | 15.5 | 4.1 | 8.5 | 7.4 | 11.8 | 25.4 |
| consistent reference (excl. datum/metadata errors) | land | 169 | 2,303,755 | 13.4 | 68.8 | 5.7 | 12.5 | 28.9 | 47.6 | 108.4 |
| consistent reference and elevation agrees with DEM (\<=20 m) | single-levels | 682 | 9,841,326 | 3.0 | 12.8 | 3.9 | 7.3 | 6.6 | 10.4 | 22.0 |
| consistent reference and elevation agrees with DEM (\<=20 m) | land | 119 | 1,645,491 | 11.0 | 52.3 | 5.1 | 9.3 | 22.4 | 37.6 | 72.1 |

Altitude error at ground level, 2022-2024 (m).

![Accuracy: mean error per station.](../output/figures/A_map_bias.png)

![Precision: temporal SD of the error per
station.](../output/figures/A_map_sd.png)

<img src="../output/figures/A_sl_vs_land.png" style="width:70.0%"
alt="Share of stations below a given |bias|, ERA5 single-levels vs ERA5-Land." />

## By terrain, elevation, latitude and climate

| group | subset | stations | median \|bias\| | p90 \|bias\| | median SD | p90 SD | MAE | p95 \|err\| |
|:---|:---|---:|---:|---:|---:|---:|---:|---:|
| terrain | flat (\<20 m) | 296 | 2.2 | 8.4 | 3.2 | 5.6 | 5.0 | 17.0 |
| terrain | gentle (20-50 m) | 170 | 2.3 | 9.7 | 3.5 | 5.5 | 5.0 | 15.7 |
| terrain | hilly (50-150 m) | 241 | 3.9 | 17.0 | 4.3 | 7.4 | 8.0 | 27.6 |
| terrain | rough (150-300 m) | 155 | 5.6 | 20.1 | 6.2 | 11.6 | 10.6 | 31.6 |
| terrain | mountain (\>300 m) | 57 | 7.6 | 25.9 | 9.3 | 14.3 | 15.8 | 51.2 |
| elevation | \<200 m | 437 | 2.4 | 8.8 | 3.4 | 5.9 | 5.2 | 17.5 |
| elevation | 200-500 m | 101 | 2.6 | 10.4 | 3.7 | 6.6 | 5.8 | 18.5 |
| elevation | 500-1000 m | 69 | 3.0 | 11.2 | 4.1 | 8.7 | 6.4 | 21.0 |
| elevation | 1000-2000 m | 246 | 5.5 | 21.6 | 5.2 | 10.6 | 10.4 | 32.7 |
| elevation | \>2000 m | 66 | 7.4 | 24.3 | 7.0 | 17.0 | 14.1 | 47.0 |
| latitude | tropics (0-23.5) | 193 | 3.7 | 19.8 | 3.7 | 7.0 | 8.3 | 30.2 |
| latitude | subtropics (23.5-45) | 357 | 3.7 | 17.1 | 4.6 | 9.3 | 8.4 | 26.7 |
| latitude | mid-latitude (45-66.5) | 277 | 2.4 | 11.1 | 3.9 | 8.4 | 6.2 | 21.4 |
| latitude | polar (\>66.5) | 92 | 2.5 | 7.5 | 3.9 | 7.1 | 5.2 | 15.5 |
| climate | A tropical | 114 | 3.2 | 16.1 | 3.5 | 5.4 | 7.1 | 27.9 |
| climate | B arid | 203 | 3.8 | 16.9 | 4.4 | 7.6 | 7.7 | 23.9 |
| climate | C temperate | 187 | 3.8 | 18.4 | 4.3 | 9.6 | 8.4 | 29.7 |
| climate | D continental | 275 | 2.4 | 12.9 | 4.0 | 9.6 | 6.8 | 22.8 |
| climate | E polar | 96 | 3.2 | 11.1 | 4.7 | 8.9 | 7.8 | 26.7 |

ERA5 single-levels, by station class (m). Terrain = sub-grid orography
SD in the ERA5 cell.

## Drivers

![Left: bias against the gap between station elevation and ERA5
orography. Right: precision against sub-grid terrain
roughness.](../output/figures/A_drivers.png)

| response | term | deviance explained (full) | lost when dropped | n |
|:---|:---|---:|---:|---:|
| log \|bias\| (consistent, DEM-trusted) | station elevation - ERA5 orography | 0.166 | 0.018 | 654 |
| log \|bias\| (consistent, DEM-trusted) | sub-grid terrain roughness | 0.166 | 0.007 | 654 |
| log \|bias\| (consistent, DEM-trusted) | absolute latitude | 0.166 | 0.046 | 654 |
| log \|bias\| (consistent, DEM-trusted) | Koppen climate zone | 0.166 | 0.017 | 654 |
| log SD | station elevation - ERA5 orography | 0.526 | 0.117 | 875 |
| log SD | sub-grid terrain roughness | 0.526 | 0.012 | 875 |
| log SD | absolute latitude | 0.526 | 0.018 | 875 |
| log SD | Koppen climate zone | 0.526 | 0.024 | 875 |

Station-level drivers (GAM).

| term                    | deviance explained (full) | lost when dropped |     n |
|:------------------------|--------------------------:|------------------:|------:|
| local solar hour        |                     0.353 |             0.000 | 2e+06 |
| season                  |                     0.353 |             0.001 | 2e+06 |
| boundary layer height   |                     0.353 |             0.004 | 2e+06 |
| skin - 2 m temperature  |                     0.353 |             0.000 | 2e+06 |
| 6 h pressure tendency   |                     0.353 |             0.001 | 2e+06 |
| station (random effect) |                     0.353 |             0.325 | 2e+06 |

Observation-level drivers of the de-biased absolute error (GAM with
station random effect).

![Diurnal and seasonal cycle of the de-biased error (RMS), by climate
zone.](../output/figures/A_cycles.png)

<img src="../output/figures/A_era.png" style="width:70.0%"
alt="Change over time, for stations reporting in every year." />

| year | n_stations | abs_bias_median | sd_median | sd_p90 |
|-----:|-----------:|----------------:|----------:|-------:|
| 1990 |         96 |             6.1 |       6.5 |   13.2 |
| 2005 |         96 |             5.0 |       5.1 |   13.2 |
| 2015 |         96 |             4.1 |       4.4 |   10.5 |
| 2022 |         96 |             3.1 |       4.0 |   12.3 |
| 2023 |         96 |             3.2 |       4.2 |   11.9 |
| 2024 |         96 |             2.6 |       3.9 |   12.2 |

Change over time for stations reporting in every year (m).

# Results: in flight (Tier B)

| method | height above ground | n | bias | SD | MAE | RMSE | p95 \|err\| |
|:---|:---|:---|---:|---:|---:|---:|---:|
| ERA5-Land | (-10,1\] | 80,342 | 0.1 | 2.3 | 0.1 | 2.3 | 0.0 |
| ERA5-Land | (1,100\] | 43,203 | -1.2 | 14.8 | 6.6 | 14.9 | 30.1 |
| ERA5-Land | (100,250\] | 41,944 | -3.7 | 13.0 | 6.4 | 13.5 | 29.1 |
| ERA5-Land | (250,500\] | 44,773 | -5.0 | 9.2 | 7.2 | 10.5 | 19.0 |
| ERA5-Land | (500,1e+03\] | 134,450 | -7.5 | 17.0 | 12.1 | 18.6 | 40.8 |
| ERA5-Land | (1e+03,1.5e+03\] | 121,317 | -16.5 | 20.6 | 20.2 | 26.4 | 53.5 |
| ERA5-Land | (1.5e+03,2e+03\] | 88,050 | -24.6 | 25.6 | 27.8 | 35.5 | 67.7 |
| ERA5-Land | (2e+03,3e+03\] | 194,848 | -35.9 | 43.0 | 42.8 | 56.0 | 111.0 |
| ERA5-Land | (3e+03,4e+03\] | 173,516 | -49.8 | 46.7 | 58.0 | 68.3 | 126.3 |
| ERA5-Land | (4e+03,5e+03\] | 158,090 | -63.8 | 87.5 | 84.9 | 108.3 | 211.2 |
| ERA5-Land | (5e+03,6e+03\] | 194,252 | -98.7 | 94.7 | 111.8 | 136.8 | 258.3 |
| ERA5-Land |  | 7 | 75.8 | 7.4 | 75.8 | 76.2 | 96.8 |
| GeoPressureR (ERA5 single-levels) | (-10,1\] | 365,141 | 0.0 | 1.5 | 0.0 | 1.5 | 0.0 |
| GeoPressureR (ERA5 single-levels) | (1,100\] | 199,734 | -0.8 | 9.9 | 5.2 | 9.9 | 17.1 |
| GeoPressureR (ERA5 single-levels) | (100,250\] | 200,028 | -2.7 | 9.5 | 5.3 | 9.8 | 18.5 |
| GeoPressureR (ERA5 single-levels) | (250,500\] | 213,147 | -2.6 | 14.9 | 8.0 | 15.1 | 22.6 |
| GeoPressureR (ERA5 single-levels) | (500,1e+03\] | 609,037 | -7.0 | 13.3 | 10.3 | 15.0 | 29.8 |
| GeoPressureR (ERA5 single-levels) | (1e+03,1.5e+03\] | 545,323 | -13.6 | 20.0 | 17.7 | 24.2 | 50.2 |
| GeoPressureR (ERA5 single-levels) | (1.5e+03,2e+03\] | 418,624 | -19.4 | 30.0 | 25.3 | 35.8 | 69.4 |
| GeoPressureR (ERA5 single-levels) | (2e+03,3e+03\] | 896,880 | -35.0 | 47.5 | 43.2 | 59.0 | 121.5 |
| GeoPressureR (ERA5 single-levels) | (3e+03,4e+03\] | 784,171 | -46.7 | 61.8 | 56.9 | 77.5 | 145.6 |
| GeoPressureR (ERA5 single-levels) | (4e+03,5e+03\] | 716,230 | -62.5 | 96.1 | 87.3 | 114.6 | 231.6 |
| GeoPressureR (ERA5 single-levels) | (5e+03,6e+03\] | 884,139 | -90.6 | 103.1 | 109.1 | 137.2 | 273.5 |
| GeoPressureR (ERA5 single-levels) |  | 22 | 44.9 | 21.8 | 44.9 | 49.9 | 75.6 |
| lapse rate -5 K/km | (-10,1\] | 365,141 | 0.0 | 1.5 | 0.0 | 1.5 | 0.0 |
| lapse rate -5 K/km | (1,100\] | 199,734 | -0.8 | 9.9 | 5.2 | 9.9 | 17.1 |
| lapse rate -5 K/km | (100,250\] | 200,028 | -2.7 | 9.4 | 5.2 | 9.8 | 18.5 |
| lapse rate -5 K/km | (250,500\] | 213,147 | -2.3 | 14.8 | 7.9 | 15.0 | 22.3 |
| lapse rate -5 K/km | (500,1e+03\] | 609,037 | -5.8 | 13.2 | 9.7 | 14.5 | 28.8 |
| lapse rate -5 K/km | (1e+03,1.5e+03\] | 545,323 | -9.5 | 19.9 | 15.8 | 22.1 | 46.4 |
| lapse rate -5 K/km | (1.5e+03,2e+03\] | 418,624 | -12.6 | 29.9 | 21.9 | 32.5 | 63.1 |
| lapse rate -5 K/km | (2e+03,3e+03\] | 896,880 | -17.2 | 47.2 | 35.3 | 50.3 | 103.8 |
| lapse rate -5 K/km | (3e+03,4e+03\] | 784,171 | -18.5 | 62.2 | 42.0 | 64.9 | 125.4 |
| lapse rate -5 K/km | (4e+03,5e+03\] | 716,230 | -8.4 | 95.4 | 68.2 | 95.8 | 189.7 |
| lapse rate -5 K/km | (5e+03,6e+03\] | 884,139 | -10.5 | 103.9 | 73.5 | 104.5 | 224.7 |
| lapse rate -5 K/km |  | 22 | 44.9 | 21.8 | 44.9 | 49.9 | 75.5 |
| virtual temperature | (-10,1\] | 365,141 | 0.0 | 1.5 | 0.0 | 1.5 | 0.0 |
| virtual temperature | (1,100\] | 199,734 | -0.5 | 9.9 | 5.1 | 9.9 | 17.0 |
| virtual temperature | (100,250\] | 200,028 | -2.0 | 9.5 | 5.1 | 9.7 | 18.2 |
| virtual temperature | (250,500\] | 213,147 | -1.0 | 14.7 | 7.4 | 14.8 | 20.9 |
| virtual temperature | (500,1e+03\] | 609,037 | -3.1 | 13.3 | 8.8 | 13.7 | 28.0 |
| virtual temperature | (1e+03,1.5e+03\] | 545,323 | -7.5 | 20.7 | 15.2 | 22.0 | 47.3 |
| virtual temperature | (1.5e+03,2e+03\] | 418,624 | -10.1 | 31.2 | 21.0 | 32.8 | 65.5 |
| virtual temperature | (2e+03,3e+03\] | 896,880 | -24.1 | 49.9 | 38.0 | 55.4 | 118.6 |
| virtual temperature | (3e+03,4e+03\] | 784,171 | -25.4 | 64.3 | 43.4 | 69.2 | 138.2 |
| virtual temperature | (4e+03,5e+03\] | 716,230 | -42.5 | 99.7 | 76.1 | 108.4 | 227.0 |
| virtual temperature | (5e+03,6e+03\] | 884,139 | -60.2 | 107.8 | 88.6 | 123.5 | 264.7 |
| virtual temperature |  | 22 | 45.1 | 21.9 | 45.1 | 50.1 | 75.7 |
| virtual temperature + lapse -5 K/km | (-10,1\] | 365,141 | 0.0 | 1.5 | 0.0 | 1.5 | 0.0 |
| virtual temperature + lapse -5 K/km | (1,100\] | 199,734 | -0.5 | 9.9 | 5.1 | 9.9 | 17.0 |
| virtual temperature + lapse -5 K/km | (100,250\] | 200,028 | -2.0 | 9.5 | 5.1 | 9.7 | 18.2 |
| virtual temperature + lapse -5 K/km | (250,500\] | 213,147 | -0.7 | 14.7 | 7.3 | 14.7 | 20.6 |
| virtual temperature + lapse -5 K/km | (500,1e+03\] | 609,037 | -1.9 | 13.3 | 8.7 | 13.5 | 27.0 |
| virtual temperature + lapse -5 K/km | (1e+03,1.5e+03\] | 545,323 | -3.3 | 20.7 | 14.9 | 21.0 | 43.3 |
| virtual temperature + lapse -5 K/km | (1.5e+03,2e+03\] | 418,624 | -3.3 | 31.1 | 20.9 | 31.3 | 59.4 |
| virtual temperature + lapse -5 K/km | (2e+03,3e+03\] | 896,880 | -6.3 | 49.7 | 35.7 | 50.1 | 102.0 |
| virtual temperature + lapse -5 K/km | (3e+03,4e+03\] | 784,171 | 3.0 | 64.5 | 44.0 | 64.6 | 127.7 |
| virtual temperature + lapse -5 K/km | (4e+03,5e+03\] | 716,230 | 11.9 | 99.0 | 74.2 | 99.7 | 195.8 |
| virtual temperature + lapse -5 K/km | (5e+03,6e+03\] | 884,139 | 20.4 | 109.2 | 84.8 | 111.1 | 228.7 |
| virtual temperature + lapse -5 K/km |  | 22 | 45.1 | 21.9 | 45.1 | 50.1 | 75.7 |

Error relative to the surface level of the same sounding, by height (m).

![Bias and SD of the altitude error against height above ground, for
GeoPressureR and alternative formulations, with the height distribution
of geolocator flight points (right).](../output/figures/B_height.png)

<img src="../output/figures/B_temperature.png" style="width:70.0%"
alt="The height-dependent error is almost entirely the difference between the temperature profile the formula assumes and the one the sonde observed." />

<img src="../output/figures/B_height_climate.png" style="width:80.0%"
alt="Height-dependent bias by climate zone and season (solid: summer half-year, dashed: winter half-year; southern hemisphere shifted by six months)." />

| method                              |  bias |  MAE | RMSE |
|:------------------------------------|------:|-----:|-----:|
| ERA5-Land                           | -12.4 | 16.8 | 30.1 |
| GeoPressureR (ERA5 single-levels)   | -10.7 | 15.6 | 30.6 |
| lapse rate -5 K/km                  |  -6.3 | 13.6 | 26.6 |
| virtual temperature                 |  -6.3 | 13.5 | 28.3 |
| virtual temperature + lapse -5 K/km |  -1.8 | 13.3 | 26.4 |

Error averaged over the height distribution of geolocator flight points
(m).

| hbin | day_summer half | day_winter half | night_summer half | night_winter half |
|:---|---:|---:|---:|---:|
|  | 35.1 | 62.5 | 33.2 | 26.7 |
| (-10,1\] | 0.0 | 0.0 | 0.0 | 0.1 |
| (1,100\] | -0.5 | -0.6 | -1.0 | -1.3 |
| (1.5e+03,2e+03\] | -5.0 | -11.7 | -28.4 | -33.3 |
| (100,250\] | -2.1 | -2.1 | -3.3 | -3.2 |
| (1e+03,1.5e+03\] | -5.0 | -12.0 | -18.4 | -21.6 |
| (250,500\] | -0.9 | -2.2 | -3.1 | -4.5 |
| (2e+03,3e+03\] | -8.5 | -36.4 | -41.0 | -59.5 |
| (3e+03,4e+03\] | -21.7 | -38.2 | -64.1 | -75.6 |
| (4e+03,5e+03\] | -1.0 | -67.7 | -68.7 | -117.8 |
| (500,1e+03\] | -3.0 | -5.3 | -10.2 | -11.0 |
| (5e+03,6e+03\] | -41.3 | -91.6 | -105.0 | -143.0 |

Bias by height, day/night and season (m).

# Discussion and guidance for users

## What users can expect

| Situation | Typical error | Driver |
|----|----|----|
| Absolute altitude on the ground, flat terrain | bias 2.2 m (p90 8.4 m), MAE 5 m | ERA5 surface pressure at 0.25° |
| Absolute altitude on the ground, mountains (sub-grid SD \> 300 m) | bias 7.6 m (p90 25.9 m), MAE 15.8 m | terrain the 0.25° grid cannot resolve |
| Altitude *changes* at one site (precision) | SD 3.2 m (flat) to 9.3 m (mountains) | as above; almost no diurnal or seasonal cycle |
| In flight, 1–1.5 km above ground | -14 m bias, RMSE 24 m (added to the ground-level error) | assumed temperature profile |
| In flight, 2–3 km above ground | -35 m bias, RMSE 59 m | as above; ~2x in continental/polar winter |

**On the ground, the error is mostly a fixed offset per place, not
noise.** Station identity explains almost all of the explainable
variation in the de-biased error; hour of day, season, boundary layer
height, surface inversions and pressure tendency each add less than 0.5%
of deviance. Precision (SD ~4 m) is therefore better than absolute
accuracy (MAE ~7 m), and roughly constant in time. What changes the
error is *where*: the gap between the true ground and ERA5’s smoothed
orography, and sub-grid terrain roughness.

**In flight, the error grows with height and is systematic.** The
barometric formula extrapolates the ERA5 2 m temperature upwards with a
standard lapse rate of −6.5 K/km and ignores humidity. The real
atmosphere is usually warmer than that (shallower lapse rates, surface
inversions, and the virtual-temperature effect of water vapour), so the
layer is too cold in the formula and the bird is placed too low. The
error predicted from the sonde’s own temperature profile explains 93% of
the variance (r = 0.96, slope 0.94); the remaining offset of -9 m is
consistent with humidity, which the dry-bulb comparison leaves out. It
is worst over cold continental and polar surfaces in winter, where
strong inversions sit under much warmer air, and in the humid tropics.

**Flight altitudes from GeoPressureR are therefore conservative
(slightly too low).** For a bird at 2 km above the ground, expect it
about 25–35 m too low, with a scatter (SD) of 30–50 m; roughly double
that in a continental or polar winter.

**ERA5 has improved.** For the same stations, the median ground-level
bias fell from 6.1 m in 1990 to 2.6 m in 2024, and the precision
improved by about a third. Tracks from the 1990s and earlier should be
expected to be somewhat less accurate.

**ERA5-Land vs ERA5 single-levels.** ERA5-Land’s median ground-level
bias is about four times larger. Its height-*relative* errors in flight
are similar to single-levels, because the error relative to the surface
level cancels its static orography inconsistency. This confirms that its
problem is a fixed spatial offset
([GeoPressureAPI#27](https://github.com/GeoPressure/GeoPressureAPI/issues/27)),
which matters for absolute altitude and for comparing altitudes between
places.

## Could the formula do better?

Two simple changes remove most of the average bias in flight: using the
2 m virtual temperature (from ERA5 2 m dewpoint), and a −5 K/km lapse
rate. Averaged over bird flight heights, the bias drops from -10.7 m to
-1.8 m and the RMSE from 30.6 m to 26.4 m. The scatter barely changes,
though. It comes from day-to-day and seasonal departures from any fixed
profile, mainly inversions. Removing it needs the actual temperature
profile, i.e. ERA5 pressure-level temperature or geopotential. That
would be worth evaluating as a GeoPressureR improvement for in-flight
altitude; it is not what GeoPressureR does today, and nothing here
changes its ground-level behaviour.

## Limitations

- **Not independent of ERA5.** Station surface pressure and radiosondes
  are both assimilated by ERA5, so errors *at these sites* are
  optimistic. Remote areas without observations are likely somewhat
  worse, especially for ground-level bias.
- **The sensor is not included.** Geolocator pressure sensors add their
  own offset, drift and resolution (1 hPa ≈ 8 m near the ground). The
  numbers here are the error of the retrieval method given a perfect
  pressure reading.
- **Radiosonde geometry.** The ERA5 column at the launch site is used;
  balloon drift (typically a few km below 5 km) is ignored. Sonde
  heights are themselves derived hypsometrically. The ~10 m scatter
  within the first 100 m partly reflects integer-metre reporting and
  interpolated low levels.
- **Reference screen.** 5% of surface stations were excluded as
  datum/metadata errors. A few may be genuine valley errors, so the
  mountain numbers may be slightly optimistic.
- **Sampling.** Stations are thinned for spatial balance, but coverage
  is still sparse in parts of Africa, South America and over the oceans
  (Tier A is land-only).

# Data and code availability

Code: <https://github.com/GeoPressure/altitude-validation>. ERA5 and
ERA5-Land: Copernicus Climate Change Service (Hersbach et al. 2020;
Muñoz-Sabater et al. 2021), via the ECMWF ARCO archive. HadISD: Met
Office Hadley Centre, Non-Commercial Government Licence; this product
may contain data governed by WMO Resolution 40 Annex 1. IGRA2: NOAA
NCEI. Bird heights: GeoLocator master data package
(<https://doi.org/10.5281/zenodo.18187092>).

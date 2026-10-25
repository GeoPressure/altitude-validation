# Analysis, method and presentation decisions

Author notes, condensed. The originals can be recovered from the git tag `pre-cleanup`, mainly:

- `docs/methods/T04/verification.md`
- `docs/methods/T06/recommendations.md`
- `docs/methods/T07/recommendations.md` (and `baseline/`)
- `docs/methods/T10/design.md`
- `archive/position-sensitivity-variant-T11/`
- `archive/report/index.md`
- `archive/docs/manuscript/comment-response-plan.md`
- `docs/manuscript/T08/figure-style.md`
- `docs/manuscript/discussion-plan-2026-10-20.md`
- `docs/manuscript/submission-checklist.md`

Example: `git show pre-cleanup:docs/methods/T04/verification.md`. Unless noted, numbers come from the sample in use on that date and are not the final values.

## Choice of the corrected conversion (exploratory report, before 18 Oct 2026)

The table compares radiosonde conversion variants by bird-weighted flight error. Values are means over 20 held-out 50/50 station splits (`archive/analysis-before-selection-2026-10-20/formula_cv.csv`).

| Variant | Bias (m) | MAE (m) |
|---|---:|---:|
| ERA5 T2m, −6.5 K/km (old GeoPressureR "standard") | −12.2 | 16.8 |
| Virtual temperature, −6.5 K/km | −7.0 | 14.2 |
| T2m, fitted constant −4.2 K/km | −4.6 | 13.9 |
| Tv, fitted constant −5.1 K/km | −2.3 | 13.8 |
| Tv, 4-parameter season × latitude lapse rate (bounded −9.5 to −2 K/km) | −2.3 | 13.2 |
| **Tv + GPT3 lapse rate, 1° grid** | −3.2 | 13.4 |
| Tv + GPT3, 5° grid / + fitted shift | −3.4 / −2.3 | 13.5 / 13.3 |

- **Why GPT3.** It is an established climatology, not fitted to these references. It matches the fitted variants over typical bird heights, is better above 1 km, and also varies with longitude. It became the GeoPressureR default `altitude_formula = "virtual"` (v3.7.0).
- **What the corrections remove.** About a third of the gap to −6.5 K/km comes from humidity. The corrections remove bias up to about 3 km but not scatter, because a climatology cannot follow daily profiles.
- **Effect on the ground is small.** At stations more than 500 m from the ERA5 orography, the median |bias| improved from 6.6 to 5.4 m, but the p90 worsened from 18.7 to 21.9 m because shallow winter lapse rates extrapolate poorly.
- **Column temperature.** The sonde's own column temperature explains 94% of the in-flight error variance (r = 0.97). This is partly by construction, because sonde heights are hypsometric.
- **Fitted variants removed.** The fitted variants (old supplement S5) were removed from the manuscript at the authors' request.

## Conversion verification (T04, 18 Oct)

- **Formula agreement.** The closed-form formula and numerical hypsometric integration agree within 2×10⁻¹¹ m (54 cases). The repository conversion equals GeoPressureR exactly in 90 cases, including longitude wrap, the poles and a leap day.
- **Virtual temperature.** It is computed from the 2 m dewpoint: Bolton vapour pressure → specific humidity q → Tv = T(1 + 0.608q). No ERA5 Tv variable is read. A dry GPT3 lapse rate is applied to the surface Tv; humidity aloft is not modelled.
- **GPT3 implementation.**
  - All five harmonic coefficients are used, converted from K/km to K/m.
  - The day of year is an integer UTC day, with no hemisphere shift.
  - Interpolation is bilinear in space, holding the value at the edge latitudes.
  - The TU Wien implementation instead uses fractional days and nearest-neighbour values at the poles. In the samples this changed the lapse rate by up to 0.079 and 0.050 K/km. The difference is documented and was not changed.
  - A lapse rate with |L| < 10⁻⁵ K/m is replaced by −10⁻⁵ K/m as a numerical safeguard.
- **Height definitions.** Heights are ERA5 geopotential / g₀ and IGRA geopotential height, with no geometric correction. Geometric minus geopotential height is about 0.63 m at 2 km and 5.66 m at 6 km.
- **Pressure offsets.** An additive pressure offset does not cancel in height differences: +1 hPa leaves −1.81 m at 2 km. Sensor sensitivity is about 8.4 m/hPa near sea level, 10 m/hPa at 800 hPa and 15 m/hPa at 500 hPa.
- **Flight error.** It is defined as (ẑ_level − ẑ_surface) − (z_level − z_surface). Each level is matched to its own ERA5 hour.

## Metrics

- **18 Oct (T06).** The main metrics were cut to MAE + p95 on the ground and signed bias + MAE in flight. Station bias and SD were kept to explain the mechanism.
- **19 Oct: final switch.** Results now use:
  - the median absolute error and p95 of individual errors;
  - the median absolute station bias on the ground, and the median signed station bias in flight;
  - the station SD.

  MAE and RMSE were dropped from the manuscript results. The bird-weighted median is computed over the jointly weighted distribution, not as an average of band medians.
- **Wording.** "Median station absolute bias" and "median absolute individual error" must never both be shortened to "median error". A signed bias distribution centred on zero does not show that stations have no bias.

## Spatial and flight weighting (T06, 18 Oct)

- **Ground weighting.** Median results were 6.49 m with equal station weights, 6.08 m with equal cell weights after screening, and 6.07 m with inherited cell weights. 200 one-station-per-cell draws gave 5.99–6.19 m. The question became moot with the one-station-per-cell design (20 Oct), which gives every station equal weight.
- **Flight weighting.** With the same bird weights, MAE for ERA5 / Tv+GPT3 was:
  - 16.44 / 13.12 m with the old level weights;
  - 16.24 / 13.17 m with equal stations within each band;
  - 16.42 / 13.35 m with equal stations and equal soundings.

  The ranking held, but the Tv+GPT3 p95 at 4–5 km moved from 190 to 235 m, so the upper tails depend on sampling.
- **Minimum soundings.** Requiring 1, 30 or 100 soundings per station and band left 530, 404 or 289 stations at 250–500 m, with non-monotonic tails. No height-specific filter was adopted.
- **Adopted scheme.** Equal station weight within each height band was adopted with the rolling IGRA2 selection (20 Oct).
- **Driver GAM.** The full fit (2 M rows) did not finish in more than 9 h, so it was capped at 100k observations from 200 stations. It was later removed because no result from it was presented.

## Bird flight-height weighting (T07, 18 Oct; later revised)

- **Primary weighting.** Pooled flight time: each point is weighted by the interval to the next record, capped at 60 min. Equal point weights would over-represent tags that record every 5 min. Flight is the package's non-integer `stap_id` segment, and all classified flight is retained.
- **Sensitivity tests** (MAE for standard atmosphere / ERA5 / Tv+GPT3; the ranking held in every case):

  | Subset | MAE (m) | Share of flight time |
  |---|---|---:|
  | All flight | 42.19 / 16.80 / 13.38 | 100% |
  | Flights ≥ 2 h | 42.90 / 17.04 / 13.55 | 97.3% |
  | Points ≥ 50 m | 47.61 / 18.49 / 14.57 | 86.9% |
  | Both | 48.20 / 18.71 / 14.72 | – |
  | Equal bird weight | 38.58 / 15.49 / 12.42 | – |

- **Rejected restriction.** Restricting to points ≥ 50 m was rejected because it removes the near-ground flight that matters for conservation.
- **Height method.** At T07, heights compared tag pressure with ERA5 surface conditions and used a stationary-period pressure offset. 8.5% of flight time was still below ground, and those negatives were set to the lowest band.
- **Current method** (manuscript S4). Height above the median Copernicus GLO-90 terrain along the path (`path2elevation()`). Errors are reported at the median and P90 flight heights, plus a band-weighted average. Flight time above 5 km is assigned to the top band.

## Horizontal-position sensitivity

- **T10 pilot (manuscript S5).**
  - Design: 10 IGRA2 stations (5 climates × 2 roughness strata), 8 soundings each (2 per quarter of 2024), and the level nearest 2 km.
  - Offsets of 0, 10, 25, 50, 100 and 200 km in 8 bearings. ERA5, orography and GPT3 were re-queried together at each offset.
  - Results for virtual/GPT3: at 50 km, MAE rose by 0.6 m (absolute altitude) and 0.5 m (surface-referenced height), while individual paired changes had a p95 of 21.1 and 22.6 m. At 200 km, MAE rose by 4.6 and 2.2 m.
- **T11 expansion (run, not adopted).**
  - Design: 50 stations and 200 soundings, with bootstrap confidence intervals.
  - Results for virtual:

    | Distance | Absolute-level MAE | Surface-referenced MAE |
    |---|---:|---:|
    | 0 km | 21.3 m | 22.0 m |
    | 50 km | 20.9 m | 22.3 m |
    | 200 km | 24.2 m | 24.7 m |

    The p95 of the paired change was about 26 m at 50 km and 46–50 m at 200 km.
  - It was not adopted because it would need a new estimand and figure.
- **Out of scope.** Terrain clearance under position uncertainty, and a location-based uncertainty lookup. The paper makes no "acceptable radius" claim.

## Other checks and fixes

- **Climate-label bug.** The kgc lookup returns "Climate Zone info missing", which had been read as zone "C" (93 GHCNh and 15 IGRA2 stations). It now maps to NA, which is excluded only from the climate summaries.
- **Figure 1 example rule.** The chosen sounding is the one whose three errors are jointly closest to the medians of its class. The summer example shows that the correction does not improve every sounding.

## Figures (T08, 18–23 Oct)

- **Conversion colours.** The conversions use solid lines with a fixed colour each:
  - standard atmosphere: `#C46532`
  - ERA5 with standard lapse rate: `#315B91`
  - ERA5 with virtual temperature + GPT3: `#007F86`

  The observed profile is drawn thicker. The palette is defined in `R/figures.R`.
- **Style.** No titles inside the artwork, direct labels, Helvetica Neue, figure widths of 178 or 85 mm, and no point symbols on connected curves.
- **Figure 3.** Three metric rows (hourly |error|, |station bias|, station SD) by three conversions. Linear axes are shared within each row, with median and P95 guides.
- **Figure 4.** Height bands of 250 m. The bird-weighted numbers are given in the text, not on the curves.

## Manuscript and submission decisions

- **Scope.**
  - Bird-first introduction.
  - GPS tags that carry a pressure sensor are included as context.
  - No accuracy ranking of barometer against GPS, and no novelty claim for the correction.
  - Reference pressure is treated as an exact input; sensor error is not evaluated.
- **Removed claims.**
  - "Weather explains little additional variation."
  - The generalisation to a 1–1.5% bias in flight.
  - The comparison with pressure-RMSE values in the literature.
  - Perceived complexity as the cause of low adoption.
  - Any claim that the references are independent of ERA5 or were "never assimilated".
- **Discussion plan.** Six paragraphs:
  1. Main finding.
  2. Ecology.
  3. Accessibility.
  4. Input choices, including the negative ERA5-Land result.
  5. Interpretation and calibration: surface-referenced height is not terrain clearance.
  6. Validation scope.
- **Submission** (Movement Ecology, Methodology). Open items:
  - Publish the Zenodo record 10.5281/zenodo.23085093.
  - Confirm Mathieu's approval in the cover letter.
  - Confirm the AI-use statement and the open-access arrangements.
  - Check compatibility with the journal's TeX Live 2021.

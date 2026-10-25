# Data sources considered (author notes, condensed)

Condensed on 25 October 2026 from ~200 notes in `docs/` and `archive/` (task notes T04–T11, data-source reviews, the archived exploratory report). Originals are recoverable from the git tag `pre-cleanup`, e.g. `git show pre-cleanup:docs/data-sources/transition-review.md`. Key sources: `docs/data-sources/intake.md`, `docs/data-sources/transition-review.md`, `docs/methods/T05/audit.md`, `docs/methods/T06/recommendations.md`, `archive/complementary-ground-evaluations-2026-10-22/`, `archive/report/index.md`. Numbers are as of the date given; samples changed repeatedly (see `station-selection-and-curation.md`).

## Final inputs (as of 25 Oct 2026)

| Dataset | Use |
|---|---|
| GHCNh (NOAA, replacement for ISD) | Ground reference: station pressure, reported elevation, plus SLP/altimeter/temperature for the implied-height check. 2022-01-01 to 2026-10-13 (exclusive). 1,794 stations. |
| IGRA2 (v2.2 per product page; no version marker saved at extraction) | Flight reference: pressure, temperature, reported geopotential height, 0–6 km above launch surface (analysed to 5 km). 629 stations. |
| ERA5 single levels (ARCO) | Surface pressure, 2 m T, 2 m dewpoint, orography, nearest 0.25° cell and hour. |
| ERA5-Land | Only the S3 product comparison. |
| GPT3 1° grid (TU Wien, `gpt3_1_fast.m`) | Lapse-rate climatology of the corrected conversion. |
| SRTM v3 30 m, ASTER GDEM v3 fallback | Terrain check of GHCNh reported elevations. |
| Copernicus GLO-90 via GeoPressureR `path2elevation()` | Terrain under bird tracks (flight height above terrain, S4). |
| Master GeoLocator Data Package v2026.0 (doi:10.5281/zenodo.18187093) | Bird flight-height distribution; release/checksums in `data/curated/geolocator_master_release.json`. |

## Retired or never-adopted datasets

| Dataset | What it was used for | Fate and reason |
|---|---|---|
| **HadISD v3.4.3.2025f** | Primary ground reference until ~19 Oct: 2022–2024, ≥183 reporting days and ≥4 obs/day in each year, one random station per 2° cell plus every station >1000 m. 2,502 stations after ERA5-residual screen (2,646 unscreened). Also 1990/2005/2015 historical samples. | Replaced by GHCNh (NOAA's maintained ISD successor with integrated QC; HadISD frozen). First GHCNh intake reused the HadISD footprint (GHCNh within 25 km of each HadISD station). Raw HadISD data and errors (11.43 GiB) deleted 20 Oct (`docs/methods/ghcnh-sampling-review/cleanup-2026-10-20.csv`). |
| **Historical years (1990/2005/2015)** | "Over the decades": at 97 HadISD stations reporting every year, median SD 6.3→4.1 m and median abs bias 5.9→4.1 m from 1990 to 2024 (report). | With GHCNh only 5 stations covered all four years → descriptive only; removed from Discussion 19 Oct, then from the study. Fixed inputs kept in `data/interim/analysis-2026-10-13/historical_ground.parquet`. |
| **ISD** | Never used directly. | MeteoSwiss `in_isd` flag was only an identifier match, not assimilation evidence. |
| **GNSS meteorological sensors** (IGS/EUREF RINEX met files via BKG) | Complementary ground check with documented barometer height: site-log offsets + marker/antenna height, ellipsoidal → EGM96. Keep if ≥180 file-days, ≥2160 rows, median header-minus-site-log height within ±1 m. 79 candidates → 66 → 49 stations (47 in T05/T06 era); about half in Germany. | Retired 22 Oct together with MeteoSwiss: different coverage/periods, not poolable with GHCNh, and not independent of GHCNh/ERA5 (below). |
| **MeteoSwiss** (QFE `prestas0` at full UTC hour, published barometer height used as-is, no Swiss→EGM96 transform) | 138 stations; paired height-reference test (below). | Moved to S4 on 18 Oct (T06), retired 22 Oct. The reference-height problem it demonstrated is now addressed inside selection by the GHCNh implied-height check. |
| **DWD CDC hourly pressure** | Exploratory intake (`archive/exploratory-scripts/download_dwd.R`, `review_dwd_metadata.R`). | All 283 relevant 2022–2026 instrument periods in 212 cached archives lack `Geberhoehe ueber Grund` (sensor height) → no height advantage. Importer bug found (open-ended metadata periods; dates compared in seconds instead of days): cached DWD observations predating the fix must be regenerated before any reuse. |
| **Copernicus global surface archive (CDS) and GRUAN** | Download script only (`archive/exploratory-scripts/download_copernicus.R`). | No distinct height or independence advantage over GHCNh. GRUAN can derive pressure from GNSS height (Meisei sondes have no pressure sensor), so it is not an independent pressure-vs-height test. |
| **ARM MET / MAWS** | Considered: handbooks give a 1 m barometer mounting. | Highest-priority candidate for a small pilot if deployment height and non-assimilation could be documented; needs ARM username+token. Never run. |
| **ERA5 pressure levels** | Considered for full temperature profiles. | Not in the ARCO single-levels archive; far more data. Kept as an untested Discussion trade-off (no runtime/accuracy claim). |

## Key quantitative findings from retired comparisons

- **MeteoSwiss height-only test.** HadISD era, 32 matched stations: HadISD bias vs (listed elevation − barometer height) r = 0.926; median |station bias| 7.21 m (same HadISD pressure, listed height) → 3.83 m (same pressure, published barometer height) → 3.81 m (MeteoSwiss pressure); mean 11.49 → 5.38 → 5.32 m. 12 of 31 screened stations had elevation >5 m off. GHCNh era (tighter match, 24 pairs, max separation 0.407 km): 5.99 → 2.99 → 2.73 m. Conclusion: listed station elevation, not ERA5, explains much of the persistent station offsets.
- **GNSS results** (ERA5-standard, GHCNh-era table `archive/analysis-before-selection-2026-10-20/paper_ground.csv`): 49 stations, median |bias| 2.40 m, median SD 2.95 m, MAE 5.34 m vs GHCNh 2.91 / 3.47 / 6.47 m. Site-log vs header height made no difference (median |bias| 2.64 vs 2.67 m, 66 stations). 20,252 duplicate station-hours (1.85% of rows) from daily-file merging; deduplication changed MAE ≤0.003 m (T06), median abs error ≤0.004 m.
- **GNSS–GHCNh overlap** (22 Oct, `archive/complementary-ground-evaluations-2026-10-22/gnss-ghcnh-overlap/README.md`): a GHCNh site lies within 1 km of 14 of 49 GNSS barometers (10 with 2022–2024 files). Lindenberg LDB2 site log places it at the DWD station. Median GHCNh − GNSS pressure: Helgoland +0.62 hPa, Lindenberg +1.58, Potsdam −0.90. The networks are not disjoint; the old `in_isd = FALSE` in GNSS files was hard-coded.
- **HadISD → GHCNh transition audit** (19 Oct, `review_ghcnh_transition.R`): 1,164 station pairs within 1 km in the same ERA5 cell, ≥500 common hours, 5,747,736 hours. 97.7% of pairs have median absolute pressure difference 0 hPa; median listed-elevation change 0 m; median |bias| 3.72 vs 3.75 m, median SD 4.07 vs 4.05 m. Same underlying records; existing thresholds carried over.
- **Assimilation/independence.** ERA5 assimilates conventional surface and upper-air observations; no station/date observation-feedback audit was possible. All "never assimilated"/"independent validation" claims were removed (T05, 18 Oct). Proxy evidence in the old report (GNSS flat-terrain |bias| 2.5 m vs HadISD 1.9 m; isolated vs dense stations similar; assimilation cannot create sub-grid structure, station bias correction absorbs constant offsets) was judged not to measure assimilation, and the network/terrain and neighbour-density tables were dropped (20 Oct).
- **ERA5-Land vs ERA5** (HadISD era): ground median |bias| 9.5 vs 2.5 m and SD 5.0 vs 3.6 m, at all three ground networks; flight bird-weighted MAE 17.3 vs 16.4 m (offset cancels). The report attributed it to ERA5-Land surface pressure adjusted to an orography inconsistent with the published one (GeoPressureAPI#27); the manuscript states only the observed contrast. Kept as S3; supports recommending ERA5 single levels.
- **ERA5 archive lag.** ERA5 can lag GHCNh; extraction stops at the latest hour shared by single levels and ERA5-Land, and coverage is rechecked after matching.

## GHCNh archive facts worth keeping

- Timestamps use ISO `T`; parse with `%Y-%m-%dT%H:%M:%S`. An early implicit parser silently dropped the time and all reduced extracts were rebuilt (19 Oct).
- Pressure QC codes are source-dependent (NOAA GHCNh documentation §VI Table 3). Code 4 = "calculated" only for sources 220–223, 347, 348; for 313–315, 322, 335, 343, 344, 346 it is a gross-limit pass, so blanket rejection of code 4 is wrong. Code 5 = removed for sources 220–223, 347, 348 but checked-good for legacy ISD sources. Exclude codes 2, 3, 6, 7, the source-qualified 5, and all lowercase flags; keep missing and other codes. Missing QC does not mean "checked". Old sample composition: 1.61 M checked-good hours, 3.99 M missing QC, 2.71 M other accepted flags.
- Source 412 = SYNOP/BUFR decoded by NCEI from 2026 (413 = METAR). It carries many gross 2026 blocks (Brazilian INMET stations after a late-March/April 2026 gap; Chinese stations at 2026-08-04 12 UTC). Source 393 is undocumented in the NOAA source list and carries the Météo-France overseas timing errors. Source identity alone was never used as a rejection rule.
- Of 105 sampled >100 m departures from reviewed stations, none carried code 4 for a "calculated" source; many had good (1) or missing QC (`docs/methods/reviews/ground-quality-code-review-2026-10-23.md`).

## IGRA2 archive facts worth keeping

- Missing values −9999 vs QA-removed −8888. Missing surface height → station elevation (528,832 of 770,687 surface records lacked height in the 2023–2024 extracts); QA-removed surface height or pressure → sounding rejected (an early version also refilled −8888).
- Times: release + elapsed; missing release → nominal time; missing elapsed → height / 5 m s⁻¹; QA-removed elapsed → level dropped; release wrapped within 12 h of nominal. Launch-site coordinates throughout; balloon drift ignored.
- The first extractor kept only levels ≥400 hPa, losing upper heights at elevated stations; fixed in the rolling-window sampler (20 Oct). Its `curl | funzip | awk` pipe had no `pipefail`, so failed downloads could produce partial cached Parquet; ZIPs are now validated before reduction.
- Reported heights are geopotential, mostly computed from the sonde's own p/T/humidity; the flight error therefore largely measures the assumed vs sonde column temperature.

## Bird data

- T07 (18 Oct) first used a restricted local master (`master_restricted`): 250 tags with flight, 31 species, 40,238 h. Its saved `n_tags = 274` counted all tags, including stationary-only ones, so "274 birds" was wrong.
- Adopted the published release v2026.0 (checksums match local `GeoLocatorMaster/data/master/`): 204 tags with usable pressurepaths, 1 without classified flight → 203 tags, 25 species, 5,293 flights, 128,003 points, 34,580 represented hours. Primary MAEs moved 41.20/16.44/13.12 → 42.19/16.80/13.38 m; ranking unchanged.

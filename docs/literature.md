# Literature: condensed record (author-facing)

Condensed from `literature/`, `docs/literature/`, `docs/assets/gps-barometer/`,
`docs/scripts/extract_gps_review_figures.py` and
`archive/report/literature-review-and-paper-positioning.md`. Those originals are recoverable from
the git tag `pre-cleanup`, e.g.

```sh
git show pre-cleanup:literature/conversion_evidence.csv
git show pre-cleanup:literature/biological_applications.csv
git show pre-cleanup:docs/literature/gps-barometer-ecology.md
git show pre-cleanup:archive/report/literature-review-and-paper-positioning.md
git ls-tree -r --name-only pre-cleanup literature docs/literature   # full file list
```

Citation keys below are those of `paper/references.bib` (the only bibliography used by the
manuscript build). `[cited]` = cited in `paper.qmd`/`supplement.qmd`; `[bib]` = in references.bib
but not cited; `[not in bib]` = see the final section. Reference PDFs were kept only locally
(`literature/references/`, `paper/pdfs/`, both git-ignored) and in the Zotero collection
`altitude-validation` (key GIN22L68, 77 parent records).

## 1. Searches already performed (do not redo)

| Date | Pass | Sources | Scope / outcome |
|---|---|---|---|
| 7 Oct 2026 | Initial positioning review | 4 user-supplied papers, then web search, publisher/institutional full text | ERA5 barometric validation, pressure-derived ground elevation, small-migrant flight altitude, recent biologging, atmospheric-profile benchmarks. Targeted narrative review, not systematic. |
| 16 Oct 2026 | Addendum | Schaub supplement, Simonetti accepted MS (DLR elib 202304), publisher re-checks | ERA5 vs ERA5-Land surface pressure / barometric altitude comparisons; quantitative comparison with our (then) results. |
| 18 Oct 2026 | T01–T03 review | Repo inventory, `paper/references.bib`, local Zotero, OpenAlex/Crossref DOI metadata, web discovery, publisher full texts | T01 biological applications; T02 measurement alternatives (GPS, radar, optical, drone); T03 conversion history + claim audit. No date restriction; 2024–2026 searched explicitly. Zotero collection 53 → 75 records (13 existing filed, 9 imported). |
| 18 Oct 2026 | GPS/barometer follow-up | Full texts of 10 papers + their reference lists | Targeted (not systematic); added Ross-Smith 2016 and Lempidakis 2024 (collection → 77). |
| 22 Oct 2026 | Conversion-method check | Local full-text Methods + targeted online search | Which conversion each application actually used; found Brodersen 2026. Not a prevalence estimate. |
| 23 Oct 2026 | Standard-atmosphere uncertainty | Full texts of Sjöberg 2018/2023, Liechti 2018, Lindström 2021, Dufour 2026 | Located published error statements (±100 m, ±10 %, 200 m) for the Discussion. |

Principal T01–T03 queries (Google-style web discovery; no stable hit counts, no PRISMA claim):
bird barometer/pressure logger altitude migration (ring ouzel, wheatear roosting, woodland
kingfisher, soaring raptor, condor, frigatebird, bar-headed goose, godwit, bee-eater, nightjar);
"barometric" bird altitude 2019 / 2024–2026; pressure as departure cue (white-throated sparrow,
Cooper 2023); exact-title searches for Dreelin 2018, Barras 2021, Rime 2023, Dhanjal-Adams 2018,
Williams 2020, Bishop 2015, Weimerskirch 2016, Senner 2018, Treep 2016, Thomas 2018 (avian sensor
packages), Bowlin 2015 (thrush radio-altimetry), Jensen & Werema 2025 (alethe), Rhyne 2026,
Nussbaumer 2026 (magnetic geolocation), Dufour 2026, Doniol-Valcroze 2026, Sjöberg 2025, Morey 2026.

Screening rules used: keep primary bird studies with measured/inferred vertical movement or
direct pressure use, methods needed to interpret them, and a small comparator set using other
instruments. Never classify GPS/radar altitude as pressure evidence; never equate sensor
resolution, between-sensor agreement and accuracy against an independent reference.

Access gaps: Metcalfe 2013 (abstract only; PDF attempt failed); Borkenhagen 2018 (abstract
only); Brazilian ERA5/ERA5-Land 2026 study (indexed text only); three DOI-less manuals/books
without PDFs. Rhyne 2026 and Bishop 2015 do not state their exact flight-altitude conversion in
the article text.

## 2. Conversion methods and their known errors

Reference pressure and temperature profile are separate choices; known-height anchors fix the
reference but not the temperature profile aloft.

| Approach | Examples (key) | Notes |
|---|---|---|
| Fixed ISA (1013.25 hPa, 288.15 K, −6.5 K/km) | sjoberg2018, liechti2018, norevik2021, lathouwers2022, zhao2024, lindstrom2021, barras2021 (PAMLr altitudeCALC, dhanjaladams2022), brodersen2026 (ISO 2533) [all cited] | Still used in 2024–2026. Zhao uses ERA5 for geolocation but ISA for flight altitude. Hawkes 2019 [not in bib] documents manufacturer ISA for bar-headed goose loggers. |
| Station pressure + fixed lapse | dreelin2018 (KITH airport pressure, logger T, exponent 1/5.257 — not logarithmic), jensen2025 (station 25 km away, 0.0065 K/m) | Local weather correction precedes ERA5. |
| Reanalysis sea-level pressure + ISA temperature | meier2018 (NCEP via RNCEP, 2.5°, 6 h, 288.15 K, 0.65 K/100 m) | Updates reference pressure only. |
| ERA5 surface P, T, z (model surface) | nussbaumer2023a (GeoPressureR Eq. 6), rime2023, dufour2026, doniolvalcroze2026 (`pressurepath_create()`) | Our "ERA5, standard lapse" baseline. |
| ERA5 surface + daily lapse rate from pressure level | schaub2023 (surface→950 hPa red kites, →975 hPa marsh harriers; levels ≈286 / 356 m above model terrain; supplement p. 5) | Closest ecological comparator; variable lapse rate already exists. |
| Behavioural / known-height calibration | cleasby2015 (floating, colony), johnston2023 (ERA5 MSL + floating bouts + tide), review_S095927092610063X = Miller 2026 (dynamic-soaring minima), clark2019 (48 h at nest), Lato 2022 (ground), Lempidakis 2024 (release site) | Absorbs offset; does not fix lapse rate. Cleasby: single colony reference → heights ≈40 % higher than local calibration. |
| Full ERA5 pressure-level profile | simonetti2024 (aviation; geodetic altitude) | 9 flights, ≈20 h at 10 Hz vs post-processed GNSS: mean/SD +4.6/6.4 m before, −0.1/4.1 m after pitch correction; humidity/local lapse negligible *in their profile workflow*. |
| T/humidity corrections (simulation) | review_s10291-023-01582-7 = Matyja 2024 (online 2023) | Simulated atmospheres only; calls for field validation. |
| Climatological lapse rate | landskron2018 (GPT3) [cited]; bohm2015 (GPT2w/VMF) [bib] | Source of our GPT3 lapse rate. |

Published uncertainty statements (from the 23 Oct check; used in the Discussion):

| Source | Statement | Caveat |
|---|---|---|
| sjoberg2018 | ISA deviations of several hundred m at ground, >10 % at several km; reanalysis correction → ±100 m or less | ±100 m is for corrected heights; not an empirical 95 % interval. |
| liechti2018 | Deviations of several tens of m; pressure systems rarely >200 m (~25 hPa) | Weather/reference context only. |
| lindstrom2021 | ISA underestimates ≈80 m at 3,000 m (Europe, autumn), ≈400 m at 7,200 m (Africa, spring); Table S2 | Region/season specific. |
| sjoberg2023 | ISA heights may differ ±10 % from geopotential altitude; sensor ±1 hPa ≈ ±8 m | Not a calibrated interval. |
| dufour2026 | ERA5 P+T conversion; expected error ≈±100 m (sensor + ERA5 + geolocation) | Combined, method-section statement. |
| jensen2025 | Logger ±1 hPa ≈ ±10 m | Nominal sensor accuracy only. |

Atmospheric/reanalysis quality references: huang2023 (ERA5 surface pressure bias −0.07 hPa,
RMSE 0.95 hPa ≈ 8 m over China) [bib]; munozsabater2021 (ERA5-Land adjusts P/T/q to elevation
with a daily lapse rate) [cited]; review_2019EA000984 = Dutra 2020 (constant vs climatological vs
daily lapse rates for ERA5 downscaling) [bib]; review_s41597-025-04714-5 = ERA5-SH 2025
(ERA5 + radiosonde scale-height product; shows global radiosonde validation and virtual
temperature are not novel per se) [bib]; hersbach2020, bell2021, soci2024 (ERA5) ; durre2006,
durre2018, igradocumentation (IGRA; geopotential heights are pressure-derived in traditional
soundings, height-derived pressure in GPS soundings — IGRA2 product-description supplement
§3.1.3); dunn2012/2016, smith2011 (HadISD/ISD); vasiljevic2006, cardinali2004 (assimilation);
wallace2006, icao1993/2018, bolton1980, stone1979, rolland2003, wang2017, haiden2018, minder2010
(physics, lapse rates). Brazilian regional study (Climate 14(5):98, 2026): mean pressure bias
before/after elevation correction −5.9/+0.2 hPa (ERA5) vs −4.5/−1.2 hPa (ERA5-Land) [not in bib].

## 3. GPS vs barometer in animal tracking (reported magnitudes)

Metrics differ (mean error, MAE, median AE, SD of differences); do not pool or rank.

| Study (key) | Design | Reported numbers | Evidence type |
|---|---|---|---|
| lato2022 [cited] | Drone with AxyAir barometer, CatLog and OrniTrack-25 GPS, laser altimeter; 2–60 m | Baro mean error 1.57 m (abstract); underestimates ≈2.14 m hovering, 1.0 m (±3.35) horizontal; GPS overestimates 6.5 m and 40.96 m | Independent height reference, local/low altitude. |
| schaub2023 [cited] | 194 tags, 10 models, 204 harriers/red kites, ≈11 M fixes | GPS MAE 7.4–29.9 m (low-freq) vs 1.5–7.0 m (high-freq; −72 %); baro bias −15 to −5 m, stationary MAE 6.8–15.2 m; airborne GPS–baro median AD 4.6–8.1 m | Grounded birds = zero; airborne = agreement only. |
| peron2020 [cited] | Device tests, simulations, raptor reanalyses | SD of differences: recalibrated baro vs GPS ≈22 m, vs default baro ≈14 m, vs drone ≈19 m; removing negative heights biases distributions | Error framework; disagreement, not accuracy. |
| johnston2023 [cited] | Lesser black-backed gulls, ERA5 + floating calibration | Baro exceeds GPS by 4.40 m (5-min) and 11.45 m (10-s); baro → higher collision estimates in 12 wind-farm scenarios | Inter-sensor difference; modelled risk. |
| cleasby2015 [cited] | Gannets, 16 birds/54 trips with altimeters | Median height 11.5 m commuting vs 26.5 m foraging; collision outputs differ up to ≈12× vs other height data | Calibration precedent. |
| Miller 2026, review_S095927092610063X [bib] | 3 of 11 shy albatross loggers, 1 Hz bursts | Baro mean 4.48 m (SD 2.89) vs GPS 5.10 m (SD 9.72); scenario means 3.23–5.61 m | Calibration-scenario range, not accuracy. |
| clark2019 [cited] | 3 Ascension frigatebirds, GPS + baro, HMMs | Nest-reference error baro 8.0 m (SD 5.1) vs GPS 6.9 m (SD 21.1); mean flight alt 178 m, max 1,658–1,871 m; r = 0.94; 88 % state agreement; altitude splits 59.5 % "search" into soaring 3.4 % / mid 44.7 % / low 12.2 % | Local reference; biology robust to source. |
| Ross-Smith 2016 [not in bib] | Bayesian state-space model of GPS heights, gulls/skuas | Rotor band 22–250 m overlap ≈34 % gulls, 9 % skuas | GPS-only error modelling. |
| Lempidakis 2024 [not in bib] | Pigeons, 20 Hz pressure, release-site reference | Height variation as turbulence proxy; kinematic adjustments | Biomechanics application. |
| senner2018 [cited] | GPS godwits, 4 birds/24 flights | 5 of 24 flights >5,000 m, max 5,956 m ASL | GPS altitude, no pressure. |
| poessel2018 [cited] | Methods critique | Fix quality, negative heights, ellipsoid vs geoid, circularity | Vertical datum definitions. |
| review_s00227-017-3273-z = Borkenhagen 2018 [bib] | Rangefinder (15 taxa) vs GPS (17 gulls) | Similar patterns; rangefinder undersamples low/high flight | Distribution-level only. |
| dokter2011 [bib] | Weather radar network | Population altitude distributions | Alternative observation. |

Take-home: no single pressure-vs-GPS ranking; high-frequency GPS performs well, barometers are
smooth but biased; known-height zeroing absorbs offsets but not lapse-rate error, so our
height-dependent column results also matter for calibrated GPS/barometer studies.

## 4. Biological applications of barometric altitude (condensed evidence table)

| Key | Species | Use | Conversion / reference | Status |
|---|---|---|---|---|
| sjoberg2018 | Red-backed shrike, great reed warbler | Repeated climbs; ground elevation of stopovers | Fixed ISA | cited |
| liechti2018 | Hoopoe, great reed warbler | Year-round flight heights, within-flight adjustments | ISA; station check | cited |
| meier2018 | Alpine swift | Twilight ascents year-round | NCEP SLP + fixed T | cited |
| sjoberg2021 | Great reed warbler | Dawn climbs, daytime >5 km | ISA (per Sjöberg 2018) | cited |
| lindstrom2021 | Great snipe | Day–night altitude cycles in non-stop flights | ISA; reanalysis check | cited |
| norevik2021 | European nightjar | Exploratory vertical flights | Fixed ISA | cited |
| lathouwers2022 | European nightjar | Tactics across biomes; GPS AGL separate | Fixed ISA | cited |
| zhao2024 | Siberian rubythroat | Seasonal elevation around Tibetan Plateau | ISA (GeoPressureR for position) | cited |
| dufour2026 | 17 species, 67 loggers | Barrier-crossing heights vs wing/plumage | ERA5 P+T | cited |
| barras2021 | Ring ouzel | Daily elevational commuting, snowfall response | PAMLr ISA | cited |
| rime2023 | Northern wheatear | Uphill nocturnal roosting movements | ERA5-corrected | cited |
| jensen2025 | White-chested alethe (1 bird) | Seasonal elevational migration | Station + fixed lapse | cited |
| rime2025 | Woodland kingfisher | Rainy-season tracking; ASL and AGL summaries | GeoPressureR | bib |
| rhyne2024 / rhyne2026 | Swainson's warbler | Perspective; connectivity, flight altitude | GeoPressureR/ERA5; altitude method unstated | bib |
| sjoberg2025 | Red-backed shrike | Annual flight-activity structure | Pressure for geolocation only | bib |
| dhanjaladams2018 | European bee-eater | Group cohesion from pressure synchrony | Raw pressure, no absolute altitude | cited |
| bishop2015 | Bar-headed goose | Roller-coaster terrain-following flight | Pressure altitude; exact conversion unstated | cited |
| williams2020 | Andean condor | Soaring/flapping effort (2–4 Hz pressure) | Conversion not fully specified | cited |
| weimerskirch2016 | Great frigatebird | Convective soaring | GPS-accelerometer, **not** pressure | bib |
| clark2019 | Ascension frigatebird | 3D HMM behaviour states | Nest calibration | cited |
| dreelin2018 | Swallows, martins | Foraging strata | Airport station | cited |
| doniolvalcroze2026 | Passerine-sized migrants | Offshore-wind exposure | ERA5 P+T | cited |
| bowlin2015 | Thrush (radio telemetry) | Earlier pressure/temperature flight records (pre-2018) | — | bib |
| dokter2011, morey2026, senner2018, kemp2013, jimenez2026 | various | Radar/GPS flight-height biology | Not pressure | dokter/morey bib; others cited |
| cooper2023, metcalfe2013 | Songbirds | Pressure as departure cue / experimental cue | Not altitude | bib |
| nussbaumer2023a | Mangrove kingfisher (Fig. 7) | Pressure geolocation; elevation mask + fine-terrain refinement | ERA5 surface | cited |

Pitfalls recorded: Nussbaumer 2023 Fig. 7 is a mangrove kingfisher (*Halcyon senegaloides*), not
the woodland kingfisher of rime2025; Weimerskirch 2016 is not a pressure precedent; Bishop 2015's
conversion is only inferred via Hawkes 2019; Clark 2019 is Seabird 32 (2019) though Crossref says
2020; Matyja is online 2023/vol. 28 2024; reanalysis used for geolocation (Zhao, Rhyne) does not
imply weather-corrected altitude.

## 5. Positioning of this paper

Established before us (do not claim priority): pressure-derived bird altitude and ground
elevation; ERA5 weather correction (nussbaumer2023a, dufour2026); variable ERA5 lapse rate
(schaub2023); profile-informed barometric retrieval (simonetti2024); temperature/humidity
correction physics (Matyja, GPT3); global radiosonde validation of ERA5 products (ERA5-SH);
the error framework and ecological consequences of height error (peron2020, johnston2023,
cleasby2015).

Our contribution as framed in the manuscript: a geographically broad evaluation of the
*atmospheric component* of the conversion (GHCNh ground stations, IGRA2 soundings), comparing
fixed ISA, ERA5 surface + standard lapse, and ERA5 + virtual temperature + GPT3 lapse; separating
persistent bias from temporal variability; height-resolved error relative to bird flight heights;
a correction needing only pressure, time and approximate position (GeoPressureR
`pressure_to_altitude()`). Explicit non-claims: not full deployed-tag error, not GPS vertical
accuracy, not offshore, not pressure geolocation; radiosonde heights are hypsometric, so the
flight test mainly tests the assumed column; ERA5 assimilates these observations.

How the literature is used in `paper.qmd`: Background ¶1 biological motivation (nilsson2025,
kemp2013, senner2018, shamounbaranes2017, dreelin2018, williams2020, dhanjaladams2018, meier2018,
norevik2021, sjoberg2021, lindstrom2021, dufour2026, barras2021, rime2023, jensen2025, cleasby2015,
doniolvalcroze2026, jimenez2026); ¶2 geolocators + GPS tags; ¶3 conversion history (ISA →
station → reanalysis SLP → ERA5 surface → Schaub lapse); ¶4 previous evaluations (lato2022,
schaub2023, johnston2023, nussbaumer2023a, behavioural calibration). Discussion compares with
liechti2018 (200 m), sjoberg2023 (±10 %), lindstrom2021, sjoberg2018/dufour2026 (±100 m), and
names schaub2023/simonetti2024 as costlier profile alternatives.

Unadopted suggestions from the reviews (possible future work): local known-height zeroing
sensitivity; implementing a Schaub-style pressure-level lapse comparator; horizontal-position
perturbation for geolocators; error of altitude *differences* over time; low-altitude (<100 m)
dedicated assessment. Journal-fit opinion (7 Oct): Movement Ecology or Animal Biotelemetry;
MEE if a transferable correction is the centre.

## 6. Useful references not in `paper/references.bib`

| Reference | DOI / link | Why useful |
|---|---|---|
| Ross-Smith VH et al. 2016. Modelling flight heights of lesser black-backed gulls and great skuas from GPS: a Bayesian approach. J Appl Ecol 53:1676–1685 | 10.1111/1365-2664.12760 | GPS height error modelling; rotor overlap. |
| Lempidakis E et al. 2024. Turbulence causes kinematic and behavioural adjustments in a flapping flier. J R Soc Interface 21(212) | 10.1098/rsif.2023.0591 | Fine-scale pressure height in biomechanics. |
| Hawkes LA et al. 2019. J Exp Biol (bar-headed goose loggers) | 10.1242/jeb.203695 | Documents manufacturer ISA conversion. |
| Mercker M et al. 2021. Movement Ecology | 10.1186/s40462-021-00260-y | Article-type precedent only. |
| Validation of ERA5 and ERA5-Land on the mountainous coast of NE Brazil (2026). Climate 14(5):98 | mdpi.com/2225-1154/14/5/98 | ERA5 vs ERA5-Land surface-pressure bias; authors not verified. |
| NOAA NCEI 2023. IGRA v2.2 product description supplement (§3.1.3) | ncei.noaa.gov/pub/data/igra/igra2-product-description-supplement.pdf | Pressure–height dependence in soundings (partly covered by `igradocumentation`). |
| ECMWF: ERA5 compute pressure and geopotential on model levels | confluence.ecmwf.int (CKB page 158636068) | Geopotential vs geometric height. |

In bib under non-descriptive keys (consider renaming): `review_S095927092610063X` (Miller 2026),
`review_s10291-023-01582-7` (Matyja 2024), `review_s00227-017-3273-z` (Borkenhagen 2018),
`review_s41597-025-04714-5` (ERA5-SH, Hao 2025), `review_2019EA000984` (Dutra 2020).

## 7. What the deleted folders contained (for orientation)

- `literature/`: `reference_inventory.csv` (77 entries: DOI, OA links, local PDF, Zotero path),
  `pdf_index.csv` (71 PDFs with SHA-256), `reference_crosswalk.csv` (24 review keys ↔ citation key
  ↔ DOI ↔ Zotero key), the two evidence tables condensed above, `review_additions.bib` (27 entries,
  all merged into `paper/references.bib`), `gps-barometer-additions.bib` (Ross-Smith, Lempidakis),
  `zotero_collection.bib` (raw export, incomplete authors; do not use as bibliography),
  `zotero_additions.ris`, Zotero/download/PDF-update logs, `metadata/` (Crossref JSON snapshots).
- `docs/literature/`: the reviews summarised here; `docs/assets/gps-barometer/`: six CC BY figure
  crops (Lato Fig 5, Schaub Fig 2, Péron Fig 3, Cleasby Fig 5, Johnston Fig 6, Miller Fig 3) with
  `manifest.json` (source PDF hash, page, crop); `docs/scripts/extract_gps_review_figures.py`
  regenerated them from local PDFs (needs Pillow + pdftoppm).

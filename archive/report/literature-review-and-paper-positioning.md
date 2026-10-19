# Literature review and paper positioning

Initial review 7 October 2026; reference and quantitative-comparison addendum updated 16 October 2026. Based on `report/index.qmd`, its rendered report, saved analysis tables, selected analysis scripts, and the sources linked below. This is a targeted narrative review, not a systematic review or a rerun of the validation. Literature findings and recommendations are distinguished below. The scope is principally avian biologging, matching the report; transfer to other aerial animals requires additional evidence.

## Assessment

**There is a credible methods paper here.** Its strongest contribution is a large-scale assessment of the atmospheric conversion underlying pressure-based biologging, with an explanation of when that conversion fails and a practical correction. The biological question is: **which vertical movements and differences can researchers resolve reliably, on the ground and in flight?**

The literature already establishes the usefulness of pressure sensors, the need to correct for weather, the dangers of vertical reference mismatches, and the consequences of height error. Those are motivation rather than novelty. What appears distinctive in the studies reviewed is the combination of global ground validation, documented barometer heights, radiosonde-based assessment of height-dependent error, comparison of reanalysis products, and a correction evaluated at held-out stations. This is a defensible positioning, not proof of priority over every published study.

A possible title is **“From pressure to altitude: global validation and uncertainty in avian biologging.”** A more specific alternative is **“How accurately can pressure biologgers resolve ground elevation and flight altitude?”**

## What the literature establishes

### Device validation and the interpretation of flight height

| Study | Evidence and principal contribution | Implication for this paper |
|---|---|---|
| [Cleasby et al. (2015), Journal of Applied Ecology](https://doi.org/10.1111/1365-2664.12529) | Combined GPS and pressure loggers on northern gannets, using sea-surface calibration, and showed that activity-specific flight heights affected collision predictions. | Weather correction and ecological consequences of height estimates are established. Your added value is evaluating the atmospheric conversion across environments without requiring repeated sea-surface contacts. |
| [Borkenhagen et al. (2018; online 2017), Marine Biology](https://doi.org/10.1007/s00227-017-3273-z) — supplied paper | Compared optical rangefinder measurements across 15 seabird taxa with GPS heights from 17 lesser black-backed gulls. The methods produced broadly similar patterns but had different sampling limitations. Rangefinders undersampled low and very high flight. | An apparent reference method can itself be biased. This is useful context for your careful treatment of station reference heights. This comparison concerns distributions, rather than paired validation of every GPS fix. Publisher abstract accessed; subscription full text was unavailable. |
| [Poessel et al. (2018), Journal of Applied Ecology](https://doi.org/10.1111/1365-2664.13135) — supplied paper | Methodological critique addressing fix quality, negative heights, ellipsoid versus sea-level reference surfaces, and circularity when environmental variables help construct heights and then explain those heights. | Define vertical quantities precisely and keep the conversion error distinct from the full height-above-ground error. Environmental correlations derived from corrected altitude deserve sensitivity analysis. |
| [Péron et al. (2020), Animal Biotelemetry](https://doi.org/10.1186/s40317-020-00194-z) | Controlled trials, simulations and raptor reanalyses connect vertical measurement error, terrain error and horizontal location error to distorted height distributions and ecological inference. Removing negative observations can introduce bias. | A general error taxonomy is already available. The advance should be empirical estimates of an atmospheric component and useful uncertainty guidance. Your clipping of below-model-surface bird heights needs a sensitivity check. |
| [Lato et al. (2022), PLOS ONE](https://doi.org/10.1371/journal.pone.0276098) — supplied PMC paper | Drone trials with laser-altimeter reference compared AxyAir with two GPS devices during stationary, horizontal and vertical movements. The abstract reports mean error of 1.57 m; this must not be labelled MAE or RMSE. Detailed trials show barometric underestimation of approximately 2.14 m while hovering and 1.0 m during horizontal flight. | Strong evidence for pressure sensing under local conditions, not a transferable worldwide error bound. The authors explicitly identify weather correction during long or distant deployments as a remaining requirement. Your atmospheric validation addresses that requirement. |
| [Schaub et al. (2023), Animal Biotelemetry](https://doi.org/10.1186/s40317-023-00342-1) | Compared 10 GPS tag models on 194 free-living raptors. High-frequency GPS improved accuracy markedly; barometric heights generally had less noise but more bias. Crucially, their barometric calculation already used ERA5 meteorology, including a lapse-rate input, and a DEM. | The closest field comparator. Avoid claiming the first ERA5-based barometric method or universal superiority over GPS. Compare atmospheric retrieval errors with their total field errors without equating the metrics. |
| [Johnston et al. (2023), Movement Ecology](https://doi.org/10.1186/s40462-023-00431-z) — supplied paper | Calibrated barometric heights using ERA5 and inferred floating bouts in lesser black-backed gulls. GPS and altimeter heights differed across sampling schedules, individuals, years and colonies; resulting collision estimates also differed. | Shows why calibration matters, but disagreement between two sensors does not identify which is correct. Your reference-based analysis helps isolate atmospheric conversion from calibration and device effects. |
| [Miller, Hamilton and Clarke (2026), Bird Conservation International](https://doi.org/10.1017/S095927092610063X) | Published 29 September 2026. A three-bird shy-albatross pilot uses near-surface phases of dynamic soaring to establish reference pressure. It resolves short vertical cycles and explores calibration uncertainty. | Recent evidence that behavioural calibration remains an active topic. Contrast frequent local zeroing with weather-referenced absolute altitude, and distinguish fine temporal resolution from absolute accuracy. |

These results do not support a single ranking of pressure versus GPS. Performance depends on the sensor, acquisition schedule, calibration, reference data, environment and target quantity. The paper should give pressure users a measured error budget rather than a technology contest.

### Small migrants, ground elevation and full annual cycles

The second literature stream is particularly relevant because miniature pressure loggers address birds for which continuous GPS is impractical.

- [Sjöberg et al. (2018), Journal of Avian Biology](https://doi.org/10.1111/jav.01821), demonstrated pressure-derived flight altitudes **and ground elevations during stationary periods**, using a red-backed shrike and great reed warbler. The [authors’ university record](https://www.lu.se/lup/publication/187292b8-6a63-44cf-9f3a-0aabcc3fe07a) provides the study summary. Ground elevation is therefore an established biological application.
- [Liechti et al. (2018), Movement Ecology](https://doi.org/10.1186/s40462-018-0137-1), established the use of miniature multisensor loggers to study year-round flight behaviour of small trans-Saharan migrants. This places altitude within a broader behavioural record rather than treating it as an isolated measurement.
- [Sjöberg et al. (2021), Science](https://doi.org/10.1126/science.abe7291), reported large dawn ascents and daytime cruising above 5 km in great reed warblers. Such kilometre-scale signals illustrate a different inference problem from resolving tens of metres near a turbine. The [indexed abstract](https://pubmed.ncbi.nlm.nih.gov/33958477/) supports these findings.
- [Nussbaumer et al. (2023), Methods in Ecology and Evolution](https://doi.org/10.1111/2041-210X.14043), already established global positioning from pressure, terrain-based location constraints, and subsequent altitude reconstruction. The new paper needs a clear advance beyond that method: validation of the vertical inference, its uncertainty, and a demonstrably useful improvement.
- [Rime et al. (2023), Movement Ecology](https://doi.org/10.1186/s40462-023-00381-6), used pressure and light loggers in Alpine-breeding northern wheatears to describe migration and local elevational movements, including uphill movements to roosts. This is the most directly relevant ground-elevation application in the report.
- [Rhyne et al. (2024), Ornithology](https://doi.org/10.1093/ornithology/ukae010), synthesize opportunities from pressure tags across location, phenology and behaviour, with a Swainson’s Warbler example. Their perspective supports broad demand for a validation, but is not itself an altitude accuracy benchmark.
- [Dufour et al. (2026), iScience](https://doi.org/10.1016/j.isci.2025.114466), examine barrier crossings across 17 species and 67 recovered loggers. The [coauthor institution’s summary and abstract](https://www.bto.org/our-work/science/publications/papers/ecological-barrier-crossing-strategies-small-migratory-birds-depend-wing-morphology-and-plumage) describe pronounced barrier and day/night differences. This is a strong candidate for demonstrating whether the correction changes comparative biological estimates.
- [Doniol-Valcroze et al. (2026), Conservation Letters](https://doi.org/10.1111/con4.70077), published online 22 September 2026, extend offshore-wind concerns to passerine-sized birds. The publisher’s issue listing confirms the paper and publication date, but full text could not be retrieved in this review. Treat detailed methodological comparison as pending full-text access.

An adjacent meteorological study, [ERA5-SH (2025), Scientific Data](https://doi.org/10.1038/s41597-025-04714-5), uses ERA5 profiles and radiosondes for tropospheric scale-height products. Its target variables differ from bird altitude. Nevertheless, it shows that global radiosonde validation and virtual-temperature physics are not novel in themselves; the ecological retrieval problem and its tested practical solution must carry the novelty.

## What the current report contributes

The saved report contains substantial evidence already. The following are report results, not independent confirmations from the literature:

| Existing result | Value for a paper | Necessary qualification |
|---|---|---|
| 2,502 screened HadISD stations, 47 height-checked GNSS stations, 138 MeteoSwiss stations | Strong coverage combined with better-documented reference heights | Coverage is geographically uneven; station observations are not universally independent of ERA5. |
| Median station absolute bias 2.5 m and temporal SD 3.6 m on the ground | Useful distinction between persistent site error and variability | These are distributions of station statistics, not a claim that every bird altitude is accurate to 2.5 m. |
| Ground error depends on the station–model elevation gap | Mechanistic link between surface and flight problems | This gap is not the same as the bird’s height above actual terrain. |
| 648 radiosonde stations, up to 6 km above launch-site ground | Broad evaluation of height-dependent conversion error | Published flight statistics subtract the surface retrieval error of each sounding. |
| Underestimation of approximately 1–1.5% with the standard formula | Interpretable consequence of atmospheric assumptions | It is conditional on the sampled profiles and formula; avoid a universal multiplicative correction. |
| Bird-weighted MAE approximately 16.4 → 13.0 m on held-out stations | A useful improvement, about 21% under the study’s weighting | This is surface-referenced atmospheric retrieval error, not total error of deployed tags. |
| ERA5-Land gives much larger ground biases in the evaluated workflow | A consequential practical recommendation | Establish that the cause is intrinsic to the product rather than field alignment or extraction. |
| API and R agreement within 0.08 m in the cross-check | Reproducibility and implementation consistency | Agreement between implementations does not establish physical accuracy. |

The general conceptual contribution is that **the vertical separation from the meteorological reference surface governs the atmospheric extrapolation problem**. A bird resting in a valley below model terrain and a bird flying above that terrain are related cases, although below-surface extrapolation does not have the same information content as a real atmospheric profile aloft.

The correction is useful, but the four-parameter seasonal model should not dominate the story: its gain over virtual temperature plus one fitted lapse rate is approximately 0.5 m in weighted MAE. Show where its regional or seasonal improvements matter biologically.

## Changes needed before strong publication claims

### 1. Name the quantity being validated

Use separate terms for altitude relative to a declared vertical reference, ground elevation, height above the actual terrain, and height above the ERA5 model surface. Also distinguish absolute altitude from height relative to a departure site or a sounding’s surface.

In `scripts/09_errors.R`, `err_sl_rel` is the level retrieval error minus the surface retrieval error. Consequently the reported radiosonde MAE describes an **incremental height error**. It excludes the persistent surface offset by construction. Retain that metric because it isolates the mechanism, but show absolute sounding error alongside it where reference quality permits. Do not add the ground SD and flight MAE as if they were interchangeable independent quantities.

Pressure-derived altitude is also conditional on horizontal position and time. For pressure geolocation, uncertain position affects weather annotation as well as the terrain beneath the bird. A validation at known station coordinates does not quantify that part of an animal’s uncertainty.

### 2. Complete the ground evaluation of the proposed correction

This is a concrete discrepancy between the current code and prose. The ground section of `scripts/16_formula.R` explicitly says HadISD dewpoint was not read and omits the virtual-temperature factor. It evaluates changed lapse rates with dry temperature. The report nevertheless describes the combined humidity-and-lapse correction as leaving ground performance unchanged.

Re-evaluate the complete proposed formula on ground references, including difficult elevation gaps, before making that claim. A small pooled change can conceal meaningful changes at mountain stations. Until then, describe the existing result as the ground sensitivity to the lapse-rate change alone. No source files were modified as part of this review.

### 3. Strengthen transfer assessment

The existing repeated 50/50 station splits are a useful starting point. Add spatially blocked validation and a temporal holdout. Nearby training and test stations can share atmospheric conditions, and station holdout does not remove assimilation of those observations into ERA5.

Report uncertainty by resampling spatial groups and time blocks rather than treating individual station-hours or sounding levels as independent replicates. Clearly separate split-to-split variation from confidence intervals for the performance estimates. Compare equal height-bin weights, the current bird-time weights and plausible alternative bird distributions.

### 4. Be precise about references and independence

Ground GNSS barometers provide valuable evidence, but verify the claim of non-assimilation from data provenance where possible. Being absent from ISD is evidence about a reporting route, not a definitive audit of ERA5 assimilation. Prefer “no evidence of a large assimilation advantage in the available comparisons” to “assimilation does not flatter ERA5.”

The report already acknowledges that radiosonde heights are hypsometric. Audit instrument and source metadata: some reference heights may depend on pressure and temperature, and ERA5 assimilates radiosonde observations. The strong association between temperature-profile mismatch and error is physically informative, but is not fully independent experimental proof when reference height is itself thermodynamically derived. Do not label the full reference network independent.

[NOAA’s IGRA documentation](https://www.ncei.noaa.gov/products/weather-balloon/integrated-global-radiosonde-archive) identifies geopotential height as a reported variable and provides instrument/source metadata and raw BUFR access. [ECMWF’s documentation](https://confluence.ecmwf.int/spaces/CKB/pages/158636068/ERA5+compute+pressure+and+geopotential+on+model+levels+geopotential+height+and+geometric+height) distinguishes geopotential from geometric height. Document those conventions explicitly before extending the validation to GNSS geometric altitude. A GNSS-height sounding subset would strengthen the flight benchmark if feasible; a new field campaign is not a prerequisite for a carefully bounded atmospheric-conversion paper.

### 5. Benchmark a profile-based alternative

On a manageable subset of stations, compare the standard formula, virtual temperature alone, virtual temperature with a constant fitted lapse rate, the seasonal model, and retrieval from ERA5 pressure-level or model-level profiles. Include near-surface handling and below-ground levels explicitly.

This answers why users should adopt a fitted approximation when a physical profile is available, and quantifies the accuracy–data-volume trade-off. Schaub et al. already obtained ERA5 lapse-rate information, so a fair alternative is more informative than comparing only with −6.5 K/km. A profile benchmark is still not independent of assimilated radiosondes, and should be described accordingly.

The near-perfect temperature explanation does not guarantee that ERA5 profiles will remove 94% of error: the diagnostic uses observed sounding profiles, whereas an operational retrieval would use imperfect reanalysis profiles.

### 6. Verify the ERA5-Land mechanism and comparison

Use identical station-hours and coordinates for paired product comparisons. Check pressure and orography provenance, grid registration, interpolation, units and height reference against native product fields on a small representative subset. An API/R cross-check could reproduce the same field-alignment problem in both paths.

If the mismatch persists in native fields, retain the broad scientific conclusion. If it arises in the extraction pipeline, report and fix that implementation issue. Until resolved, the defensible recommendation is that ERA5 single-levels performs better **in the evaluated retrieval workflow**.

### 7. Turn the benchmark into guidance for biological inference

Bias and SD alone are insufficient for evaluating vertical movements. Quantify the empirical error of altitude differences over relevant time intervals, preserving temporal autocorrelation. Stable local bias can cancel, whereas averaging correlated errors will not improve precision as quickly as independent-noise assumptions suggest.

For ground users, estimate how often error changes an elevation-band assignment or removes a known candidate location from a terrain mask. Include the height of the bird above terrain when relevant: roosting on cliffs, trees or structures is genuine biology, not necessarily measurement error.

For flight users, provide empirical error quantiles and interval coverage by height, season and environment. Low-altitude applications need a dedicated assessment: integer-metre reporting and coarse sounding levels limit what the present global benchmark establishes about the lowest tens of metres.

## The most valuable additions, ranked

| Priority | Addition | Purpose |
|---|---|---|
| Essential | Complete the ground test, clarify absolute versus relative errors, audit reference/height conventions | Align the claims with what was actually validated. |
| High | Spatial and temporal holdouts; uncertainty intervals; weighting and clipping sensitivity | Demonstrate transfer and robustness. |
| High | One ecological example plus error of altitude differences | Make the accuracy estimates actionable for researchers. |
| High | A limited profile-based benchmark | Establish the practical value and remaining limits of the approximation. |
| Conditional | Native-field check of the ERA5-Land explanation | Required if retaining a product-wide recommendation. |
| Optional | Independent GNSS-height soundings or paired flight experiments | Strengthen absolute flight validation; essential only for stronger end-to-end accuracy claims. |

For the biological example, choose one primary audience rather than expanding into several new studies. Two efficient options are:

1. **Ground elevation and local movements:** use an existing wheatear or similar record to show how uncertainty affects elevation changes, elevation bands and terrain-based location constraints. This strengthens the most distinctive part of the report.
2. **Migration flight altitude:** recompute selected existing tracks under the different formulas and report changes in day/night contrasts, habitat/barrier comparisons or assigned atmospheric conditions. Demonstrating that a major conclusion is robust is valuable; the correction need not overturn it.

A wind-risk example is attractive but should be secondary unless adequate marine validation and low-height resolution are available. Changing the estimated fraction inside a rotor-height band demonstrates exposure sensitivity, not a measured change in collision mortality.

The current 274-bird distribution is a useful application-specific weight, not a representative distribution of all birds. It uses the conversion under evaluation, and below-model-surface heights are placed in the lowest bin. Repeat summaries without clipping, with alternative handling of those points, and with uniform or species-balanced weights. Actual valley flight below smoothed ERA5 terrain is not necessarily an erroneous negative height above real ground.

## Manuscript structure and journal fit

Organize one paper around three questions: how large is atmospheric retrieval error; what physical and reference-data mechanisms explain it; and when do corrections or uncertainty change ecological interpretation? Keep the main paper compact and move detailed screens, implementation checks and secondary climatic summaries to supplements.

Five main figures would be sufficient: the error components and reference coverage; ground error versus elevation gap with documented-height checks; flight error versus height and season; held-out method comparisons including the profile benchmark; and the ecological example with uncertainty.

My preferred target is **Movement Ecology**, with **Animal Biotelemetry** a strong alternative for a validation-focused manuscript. Both have directly relevant methodology precedents in the studies above; their [Movement Ecology scope](https://link.springer.com/journal/40462/aims-and-scope) and [Animal Biotelemetry scope](https://link.springer.com/journal/40317/aims-and-scope) are available from the publishers. **Methods in Ecology and Evolution** becomes a stronger option if the paper delivers a transferable correction, usable uncertainty estimates and a convincing comparison with alternatives. Its [scope explicitly emphasizes new methodological approaches](https://besjournals.onlinelibrary.wiley.com/hub/journal/2041210x/aims-and-scope/read-full-aims-and-scope). These are editorial-fit judgments, not acceptance predictions. Journal of Applied Ecology would require the ecological or management consequence to become central.

A defensible central claim is:

> We quantify the atmospheric component of pressure-derived altitude error across ground stations and radiosonde profiles, identify its dependence on the separation from model terrain and atmospheric structure, and evaluate a practical correction and its implications for vertical ecological inference.

That claim fits the evidence and leaves room for a valuable paper without promising complete device validation or universal metre-scale accuracy.

## Reference compilation and comparison addendum — 16 October 2026

This addendum records the references discussed in the subsequent manuscript-positioning conversation. It qualifies the earlier assessment: there is no new barometric physics or first application to bird tracking here. The strongest potential contribution is broad evaluation of the atmospheric conversion and a measured accuracy–data-access–runtime comparison for long trajectories. The existing report does not yet include all the comparators below. A Research article is a reasonable default for a benchmark; a Methodology article remains possible if the final work demonstrates a useful improvement. These are positioning judgments, not journal decisions.

### Core references: what was evaluated and what served as truth

| Reference | Conversion and experiment | Reference height and independence | Numerical result and relevance |
|---|---|---|---|
| Péron G et al. (2020). **The challenges of estimating the distribution of flight heights from telemetry or altimetry data.** *Animal Biotelemetry* 8:5. [doi:10.1186/s40317-020-00194-z](https://doi.org/10.1186/s40317-020-00194-z). | Controlled trials, simulations and raptor reanalyses; examines GPS, barometric calibration, terrain and horizontal-position errors, filtering and state-space modelling. | References differ among experiments. Surveyed ground points anchor separate GPS tests. Comparisons between GPS, recalibrated barometric estimates and drone altitude do not isolate error of a single instrument. | SD of recalibrated barometric minus GPS estimates: 22 m; recalibrated versus default barometric estimates: 14 m. These are differences between estimates, not independent barometric RMSE. Establishes the error framework and consequences for ecological inference. |
| Lato KA, Stepanuk JEF, Heywood EI, Conners MG, Thorne LH (2022). **Assessing the accuracy of altitude estimates in avian biologging devices.** *PLOS ONE* 17:e0276098. [doi:10.1371/journal.pone.0276098](https://doi.org/10.1371/journal.pone.0276098). | Drone carries AxyAir pressure logger and two GPS devices. Pressure conversion uses tag temperature and locally measured ground pressure. Hovering at 2–50 m, horizontal flight at approximately 10 m, vertical movements to 60 m. | Drone-mounted laser altimeter over a flat field: an independent height reference, with its own measurement uncertainty. Local calibration and short flights limit transfer to annual trajectories. | Barometric estimates underestimate laser height by approximately 2.14 m while hovering and 1.0 m during horizontal movements (reported spread ±3.35 m for the latter). Abstract mean error 1.57 m is not an MAE/RMSE accuracy guarantee. |
| Schaub T et al. (2023). **How to improve the accuracy of height data from bird tracking devices? An assessment of high-frequency GPS tracking and barometric altimetry in field conditions.** *Animal Biotelemetry* 11:31. [doi:10.1186/s40317-023-00342-1](https://doi.org/10.1186/s40317-023-00342-1). | 194 tags on 204 raptors, 10 GPS models and four European study areas. Compares low/high-frequency GPS and barometric heights. Barometric retrieval uses ERA5 surface pressure and 2 m temperature, with a lapse rate derived from the surface and an ERA5 pressure level. | Grounded birds are assumed to be at approximately zero height above mapped terrain. In flight, GPS–barometer differences measure agreement, not known absolute error. Field estimates include sensor, terrain and position errors. | Ground median barometric offsets −15.0 to −4.9 m; mean absolute error 6.8–15.2 m. High-frequency airborne GPS–barometer median absolute differences 4.6–8.1 m. Closest ecological comparator; variable ERA5 lapse rates are already used. |
| Johnston DT et al. (2023). **Flight heights obtained from GPS versus altimeters influence estimates of collision risk with offshore wind turbines in Lesser Black-backed Gulls Larus fuscus.** *Movement Ecology* 11:66. [doi:10.1186/s40462-023-00431-z](https://doi.org/10.1186/s40462-023-00431-z). | Logarithmic barometric equation with tag temperature and ERA5 sea-level pressure. Floating bouts calibrate reference pressure; tidal corrections reconcile reference levels. Compares flight-height distributions and collision-model outputs. | Floating provides a sea-surface calibration anchor. Neither airborne GPS nor barometric height is an independent truth measurement. | Mean barometric heights exceed GPS by 4.40 m at five-minute sampling and 11.45 m at ten-second sampling. These differences do not establish which device is correct. Small height differences change collision estimates. |
| Simonetti M, García Crespillo O (2024). **Geodetic Altitude From Barometer and Weather Data for GNSS Integrity Monitoring in Aviation.** *NAVIGATION* 71(2):navi.637. [doi:10.33012/navi.637](https://doi.org/10.33012/navi.637); [DLR record and accepted manuscript](https://elib.dlr.de/202304/). | ERA5 pressure-level atmospheric data interpolated in space, time and height; weather-corrected barometric altitude transformed to geodetic altitude. Tests humidity/local lapse-rate effects, aircraft dynamics correction and navigation integrity models. | Precisely post-processed GNSS is the airborne reference. Nine aircraft flights during 9–13 July 2018, approximately 20 hours of pressure at 10 Hz. Worldwide navigation-availability simulations are not worldwide empirical height validation. | Mean error/SD approximately +4.6/6.4 m before pitch correction and −0.1/4.1 m after. Humidity and local lapse-rate changes were negligible in their evaluated profile-informed workflow and conditions; this does not establish negligible effects for a surface-only bird retrieval. |
| Matyja T, Stanik Z, Kubik A (2024; online 2023). **Automatic correction of barometric altimeters using additional air temperature and humidity measurements.** *GPS Solutions* 28:40. [doi:10.1007/s10291-023-01582-7](https://doi.org/10.1007/s10291-023-01582-7). | Develops corrections using pressure, temperature and humidity measurements and pre-mission calibration. Evaluates synthetic non-standard atmospheres, including simulated sensor offsets. | Known simulated atmosphere, not an independent field-height experiment. The paper calls for field verification. | Relevant prior art for atmospheric and humidity corrections, but no directly comparable empirical MAE. Their virtual-temperature experiment differs from our surface-reference hydrostatic retrieval; its unfavourable result should not be generalized to all virtual-temperature corrections. |
| Nussbaumer R, Gravey M, Briedis M, Liechti F (2023). **Global positioning with animal-borne pressure sensors.** *Methods in Ecology and Evolution* 14:1104–1117. [doi:10.1111/2041-210X.14043](https://doi.org/10.1111/2041-210X.14043). | Pressure-based positioning and terrain constraints; ERA5 surface pressure, temperature and elevation used for altitude reconstruction. Figure 6 compares standard-atmosphere and ERA5-based altitude at an equipment site. | Known equipment site provides an illustrative stationary reference; this is not a broad airborne altitude-validation experiment. | Already establishes our application and baseline workflow. New software packaging or ERA5 annotation alone cannot establish novelty for the proposed paper. |

Schaub's [supplementary methods, p. 5](https://media.springernature.com/original/springer-static/esm/art%3A10.1186%2Fs40317-023-00342-1/MediaObjects/40317_2023_342_MOESM1_ESM.pdf) specify the lapse-rate calculation: surface-to-950 hPa for the Grand Est red-kite data and surface-to-975 hPa for the Flevoland marsh-harrier data. These pressure levels averaged approximately 286 and 356 m above model terrain, respectively. This is a useful intermediate-complexity comparator between a surface-only correction and a full profile retrieval.

### Additional atmospheric references

- Huang L et al. (2023). **Evaluation of surface temperature and pressure derived from MERRA-2 and ERA5 reanalysis datasets and their applications in hourly GNSS precipitable water vapor retrieval over China.** *Geodesy and Geodynamics* 14:111–120. [doi:10.1016/j.geog.2022.08.006](https://doi.org/10.1016/j.geog.2022.08.006). ERA5 annual average pressure bias −0.07 hPa and RMSE 0.95 hPa, approximately −0.6 m and 8 m near the surface. These pressure statistics are not equivalent to our median station absolute bias or median SD; our pooled ground RMSE is the more appropriate magnitude comparison.
- Dutra E et al. (2020). **Environmental Lapse Rate for High-Resolution Land Surface Downscaling: An Application to ERA5.** *Earth and Space Science*. [doi:10.1029/2019EA000984](https://doi.org/10.1029/2019EA000984). Compares constant lapse rates with climatological and daily variable lapse rates for temperature downscaling. Adjacent prior art, not direct validation of animal altitude.
- Muñoz-Sabater J et al. (2021). **ERA5-Land: a state-of-the-art global reanalysis dataset for land applications.** *Earth System Science Data* 13:4349–4383. [doi:10.5194/essd-13-4349-2021](https://doi.org/10.5194/essd-13-4349-2021). Documents that forcing pressure, temperature and humidity are adjusted for elevation differences, using a daily lapse rate. Poor retrieval performance alone therefore does not prove intrinsic pressure–orography inconsistency.
- **Validation of ERA5 and ERA5-Land ECMWF Reanalysis on the Mountainous Coast of Northeastern Brazil** (2026). *Climate* 14(5):98. [Publisher page](https://www.mdpi.com/2225-1154/14/5/98). Relevant regional comparison of pressure and temperature in Alagoas. Publisher-indexed results report overall mean pressure biases before/after elevation correction of −5.9/+0.2 hPa for ERA5 and −4.5/−1.2 hPa for ERA5-Land. Residual magnitudes correspond roughly to 2 versus 10 m near the surface. **Access limitation:** indexed publisher text was available, but direct full-page retrieval failed; authors, detailed processing and table aggregation still need checking before adding a complete manuscript citation. This supports a regional precedent, not our global numerical ratio or causal explanation.
- NOAA NCEI (2023). **Integrated Global Radiosonde Archive V2.2: Product Description Supplement**, section 3.1.3. [Documentation](https://www.ncei.noaa.gov/pub/data/igra/igra2-product-description-supplement.pdf). Documents pressure-derived geopotential heights in traditional soundings and height-derived pressure in GPS-tracked observations. Supports the need to audit pressure–height dependence, separately from ERA5 assimilation.

### Quantitative comparison with our saved results

Numbers below come from `output/tables/ground_main.csv`, `ground_summary.csv`, `flight_height.csv`, `flight_bird_weighted.csv` and `formula_cv.csv`, inspected 16 October 2026. No validation was rerun. Ground metrics summarize station statistics unless stated otherwise; flight metrics are relative to each sounding's surface retrieval error.

| Our metric | Result | Comparison supported |
|---|---|---|
| Ground median absolute station bias, ERA5 | HadISD 2.55 m; GNSS 2.30 m; MeteoSwiss 2.90 m | Smaller offsets than Schaub's grounded-bird estimates, but different aggregation and additional field errors prevent a superiority claim. |
| Ground median temporal SD, ERA5 | HadISD 3.62 m; GNSS 2.95 m; MeteoSwiss 5.39 m | Consistent with relatively precise barometric estimates, while persistent offsets remain. |
| HadISD screened ground pooled MAE/RMSE | 6.07/9.57 m; flat-terrain RMSE 7.19 m | Broadly similar magnitude to Huang's approximately 8 m pressure-equivalent RMSE; coverage and processing differ. |
| Flight 1–100 m: bias/MAE/RMSE | −1.38/5.54/10.38 m | Signed bias resembles Lato's low-altitude underestimation; scatter and full uncertainty are not directly comparable. |
| Flight 100–250 m: bias/MAE/RMSE | −3.14/6.02/11.99 m | More relevant to low-flying birds than the pooled bird-weighted metric; still not an independent tag validation. |
| Flight 1–1.5 km: bias/MAE/RMSE | −14.68/18.82/25.47 m | Tens-of-metres error, but not the same quantity as Péron's 22 m inter-device SD. |
| Flight 2–3 km: bias/MAE/RMSE | −35.06/43.83/59.01 m | Demonstrates height-dependent baseline error, beyond the low-altitude field comparisons reviewed. |
| Held-out bird-weighted bias/MAE/RMSE, baseline | −11.88/16.43/31.14 m | Conditional atmospheric retrieval performance, not absolute end-to-end tag error. |
| Held-out bird-weighted bias/MAE/RMSE, virtual temperature plus varying lapse rate | −2.30/12.96/24.57 m | Approximately 21% MAE reduction; not directly comparable with Simonetti's aircraft mean/SD. |
| ERA5 versus ERA5-Land median absolute station bias | HadISD 2.55 versus 9.48 m; GNSS 2.30 versus 10.73 m; MeteoSwiss 2.90 versus 35.15 m | Strong product contrast in this workflow, including the same 138 MeteoSwiss stations. HadISD/GNSS availability differs between products and needs matched-station summaries. |
| Bird-weighted flight MAE, ERA5 versus ERA5-Land | 16.44 versus 17.25 m | Similar incremental flight errors after surface referencing; does not establish similar absolute flight-altitude accuracy. |

Do not conflate the pooled flight SD in `flight_height.csv` with the median per-station SD displayed in some report figures. Likewise, a signed average bias can cancel across observations, whereas median absolute station bias cannot. Approximate hPa-to-metre conversions above use about 8–8.5 m/hPa near the surface and are for scale comparison only.

### What we can conclude from these comparisons

1. Published work already establishes pressure-derived bird altitude, ERA5 weather correction, variable lapse rates and profile-informed barometric retrieval. Software and application alone are supporting contributions.
2. Our ground results broadly agree in magnitude with published pressure validation. Their smaller offsets than field-tag studies could reflect sensor calibration, terrain/reference errors, sampling or processing; those causes are not identified by cross-study comparison.
3. Our negative height-dependent bias is not independently confirmed by the bird studies reviewed. Johnston finds barometric estimates higher than GPS, and Schaub finds less negative or reversed GPS–barometer differences in flight. Different formulas and references mean this is an unresolved comparison, not a demonstrated contradiction.
4. Independent airborne validation is strongest in Lato's laser experiment and Simonetti's post-processed-GNSS aircraft experiment. Schaub and Johnston offer ground/sea-surface anchors and airborne agreement, rather than airborne truth. Our documented-height stations provide useful ground references; assimilation weakens prediction independence, not the surveyed height itself.
5. The broad ERA5–ERA5-Land contrast and evaluation of cheap atmospheric approximations remain useful possible contributions. A fair comparison should include Schaub's pressure-level-derived lapse rate and a profile-informed retrieval, with measured runtime/data access for approximately 105,000 five-minute positions per bird-year.
6. Reference dependence limits absolute flight-accuracy claims. More stations improve environmental coverage but do not remove assimilation or shared pressure–height calculations. A large benchmark remains useful if these limits are explicit; it is not automatically stronger than a smaller independent experiment.

## Search and access record

The review began with the four supplied links, followed their methodological context, and searched for ERA5 barometric validation, pressure-derived ground elevation, small-migrant flight altitude, recent biologging studies, and related atmospheric profile benchmarks. Searches were conducted on 7 October 2026; this is not a formally exhaustive database search.

Publisher full text or substantial publisher text was available for Poessel, Péron, Lato, Schaub, Johnston, Cleasby, Rime, Liechti, Nussbaumer, Rhyne and Miller. Borkenhagen was assessed from the publisher abstract. Sjöberg (2018, 2021) and Dufour were assessed from author/institutional or indexed abstracts; Doniol-Valcroze was verified in the publisher listing but full methodological assessment remains pending. Adjacent ERA5-SH methods were accessible through indexed publisher text. Quantitative comparisons should be checked against final full texts and supplements when drafting the manuscript.

The 16 October addendum additionally checked Schaub's supplementary methods and Simonetti's accepted manuscript from DLR, revisited the core publisher articles, and searched specifically for ERA5 versus ERA5-Land surface-pressure and barometric-altitude comparisons. The Brazilian regional study is recorded with an explicit access limitation. Statements in the earlier review about other studies were retained, rather than presented as newly verified in this addendum. The comparative habitat-selection paper discussed in the conversation, Mercker et al. (2021), [doi:10.1186/s40462-021-00260-y](https://doi.org/10.1186/s40462-021-00260-y), is an article-category precedent only, not a barometric-altitude benchmark.

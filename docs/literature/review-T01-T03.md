# Literature review for manuscript comments C01–C09 and C14

Scoped review prepared 18 October 2026. This covers T01 (biological applications), T02 (measurement alternatives/GPS context) and T03 (conversion history, evidence and positioning). It prepares manuscript decisions; the manuscript QMD and analyses have not been edited or rerun.

## What changes the proposed introduction

The biological motivation can be substantially broader without becoming a catalogue. The strongest additions are **foraging strata, soaring and flight effort, and local/seasonal ground-elevation movements**. Pressure records also support social-coordination inference and weather-related questions, but these should be distinguished from absolute altitude retrieval.

There is no reason to frame this as pressure versus GPS. Keep miniature pressure loggers central, introduce pressure-equipped GPS tags explicitly, and explain that the evaluated atmospheric conversion is one component of their error. Radar and optical methods establish broader biological context and alternative observations; they do not provide equivalent year-round records from known individuals.

The conversion-history paragraph needs revision. Weather-station calibration, reanalysis sea-level pressure, ERA5 surface references, pressure-level-derived lapse rates and full atmospheric profiles are overlapping choices of inputs, not three mutually exclusive technologies. In particular, **Schaub et al. already used an ERA5-derived variable lapse rate**. The manuscript should acknowledge that comparator directly. [Schaub et al. (2023)](https://doi.org/10.1186/s40317-023-00342-1)

## T01: biological applications and recommended evidence

The [biological evidence table](../../literature/biological_applications.csv) records selected studies with species, sensors, biological findings, conversion/reference information, vertical quantity, validation limits, source location, short verified excerpts where available, and intended manuscript use. It includes primary applications, methodological demonstrations and explicitly labelled context papers. The current table contains 20 selected entries; the literature corpus is broader and is listed in the search log and inventory.

| Biological motivation | Recommended sources | What can be supported |
|---|---|---|
| Migration is vertically dynamic within flights, across seasons and at barriers | [Bowlin et al. 2015](https://doi.org/10.1642/AUK-15-33.1); [Norevik et al. 2021](https://doi.org/10.1242/jeb.242836) | Repeated vertical adjustments and exploratory climbs are a stronger general example than day–night differences alone. The causes are not established simply by observing the adjustments. |
| Extreme flight heights and diel changes create physiological/atmospheric questions | [Sjöberg et al. 2021](https://doi.org/10.1126/science.abe7291); [Lindström et al. 2021](https://doi.org/10.1016/j.cub.2021.05.047) | Pressure records reveal striking vertical behaviour during prolonged migration. Proposed causes should remain hypotheses unless supported separately. |
| Birds partition aerial foraging space | [Dreelin et al. 2018](https://doi.org/10.3389/fevo.2018.00182); [Clark et al., Seabird 32](https://doi.org/10.61350/sbj.32.1) | Swallows/martins occupy different aerial strata; altitude helps distinguish frigatebird soaring from lower, putative foraging states. Neither establishes prey capture from altitude alone. |
| Vertical movement informs flight strategy and effort | [Williams et al. 2020](https://doi.org/10.1073/pnas.1907360117); [Bishop et al. 2015](https://doi.org/10.1126/science.1258732) | Pressure combined with activity/physiology supports studies of condor soaring and goose flight energetics. These broaden the taxonomic and mechanistic motivation. |
| Ground elevation describes habitat use and local movements | [Barras et al. 2021](https://doi.org/10.1111/jav.02860); [Rime et al. 2023](https://doi.org/10.1186/s40462-023-00381-6); [Jensen & Werema 2025](https://doi.org/10.2989/00306525.2025.2481468) | Daily elevational commuting in ring ouzels, likely uphill roosting movements in wheatears, and seasonal elevational migration in an alethe. The alethe study follows one individual. |
| Height distributions inform offshore-wind exposure and collision models | [Cleasby et al. 2015](https://doi.org/10.1111/1365-2664.12529); [Doniol-Valcroze et al. 2026](https://doi.org/10.1111/con4.70077) | Supports relevance to seabirds and passerine-sized migrants. Distinguish exposure/modelled risk from observed collisions or population effects. |
| Ground pressure/altitude can constrain geography | [Nussbaumer et al. 2023](https://doi.org/10.1111/2041-210X.14043) | Both the elevation mask during geolocation and a subsequent restriction using fine-resolution terrain are documented, as separate operations. |

**Suggested selection:** Use one or two migration examples, one aerial-foraging or soaring example, one conservation example, then one or two ground-movement examples. Keep the geolocation use secondary. The evidence table offers alternatives; it is not a recommendation to cite all 35 papers in the opening paragraphs.

### Ground uses: the distinction requested in C02

There are three separate statements to make:

1. **Biological ground-elevation information:** stopover elevation, seasonal elevational migration, local foraging/roosting movements and responses to snowfall. These do not require claiming that altitude uniquely identifies a geographic point.
2. **A constraint within geolocation:** compare pressure-compatible elevation ranges with terrain to exclude candidate coarse cells.
3. **Refinement after approximate positioning:** restrict possible terrain locations within the coarse cell using the inferred elevation.

The specific fine-terrain example in Nussbaumer et al. (2023), Figure 7, is a **mangrove kingfisher, Halcyon senegaloides**, not a woodland kingfisher. The separate woodland-kingfisher study concerns intra-tropical migration and seasonal environmental tracking; it should not automatically be cited as evidence for the same refinement procedure. [Nussbaumer et al. 2023](https://doi.org/10.1111/2041-210X.14043), [Rime et al. 2025](https://doi.org/10.1098/rspb.2024.2633)

### Pressure uses that should not become altitude claims

Bee-eater work uses synchrony in pressure signatures and pressure changes to infer coordinated movement. This provides a useful additional application, but is not an absolute-height validation. [Dhanjal-Adams et al. 2018](https://doi.org/10.1016/j.cub.2018.06.054)

Pressure can also be an environmental predictor or experimental cue. Cooper et al. relate departure to weather pressure using radio telemetry, while Metcalfe et al. manipulate pressure and temperature in captivity. Neither is evidence that a pressure-to-altitude conversion is accurate. If space is tight, leave this stream out of the altitude-focused introduction. [Cooper et al. 2023](https://doi.org/10.1186/s40462-022-00356-z), [Metcalfe et al. 2013](https://doi.org/10.1016/j.anbehav.2013.09.033)

The 2025 red-backed-shrike paper similarly uses pressure for geographic assignment, while its central annual-flight result comes from activity data. The evidence table labels that distinction. [Sjöberg et al. 2025](https://doi.org/10.1098/rspb.2025.0958)

## T02: alternatives and the place of GPS

| Approach | Useful scope | Limitation relevant to this manuscript | Evidence |
|---|---|---|---|
| Miniature pressure/multisensor logger | Repeated vertical records over long deployments, combined with behaviour and approximate geographic reconstruction | Pressure must be converted using an atmospheric/height reference; sensor and position errors remain | [Sjöberg et al. 2018](https://doi.org/10.1111/jav.01821); [Liechti et al. 2018](https://doi.org/10.1186/s40462-018-0137-1) |
| GPS/GNSS altitude | Geographic and vertical information from the same fixes | Results depend on tag, fix schedule, satellite geometry, processing and datum | [Schaub et al. 2023](https://doi.org/10.1186/s40317-023-00342-1); [Poessel et al. 2018](https://doi.org/10.1111/1365-2664.13135) |
| High-frequency GPS with receiver kept on | Detailed vertical tracks; improved performance relative to intermittent fixes in the field study | Greater energy demand; not interchangeable with sparse GPS fixes | [Schaub et al. 2023](https://doi.org/10.1186/s40317-023-00342-1) |
| Pressure sensor integrated in a GPS tag | Pressure-derived height plus a better-known horizontal position | Still a pressure conversion; GPS supplies location, not an independent height truth simply because it shares the housing | [Johnston et al. 2023](https://doi.org/10.1186/s40462-023-00431-z) |
| Radar | Altitude distributions and local movement without attaching tags | Coverage is tied to radar geometry/time; species and individual identity may be unresolved | [Dokter et al. 2011](https://doi.org/10.1098/rsif.2010.0116) |
| Optical rangefinding | Local observations with species identification | Sampling/detection limitations differ from tagging; distribution agreement is not paired validation of every fix | [Borkenhagen et al.](https://doi.org/10.1007/s00227-017-3273-z) |
| Laser height measurement on an experimental drone | Independent local validation of devices | Controlled low-altitude trials are not annual bird tracks or a global atmospheric benchmark | [Lato et al. 2022](https://doi.org/10.1371/journal.pone.0276098) |

**Proposed scope decision:** Discuss GPS in one clear bridge paragraph and include the GPS–barometer literature in the validation context. Do not claim that pressure is generally superior to GPS, or that small migrants categorically cannot carry GPS. The relevant restriction is the combination of mass, power, duration and sampling requirements. The present study can motivate long pressure records without asserting a fixed technological size boundary.

For wider biological context, the godwit study provides a clear GPS-based example of altitude selection in relation to atmospheric conditions. The recent storm-petrel study is also GPS-based; its discussion of altimeter errors must not cause it to be classified as pressure evidence. [Senner et al. 2018](https://doi.org/10.1098/rspb.2018.0569), [Morey et al. 2026](https://doi.org/10.1038/s41598-026-45534-w)

Magnetic and light geolocation are alternatives for geographic positioning, not direct alternatives for measuring flight altitude. The magnetic-geolocation paper is included in the reference library as scope context, not in the altitude evidence table. [Nussbaumer et al. 2026](https://doi.org/10.1111/2041-210x.70355)

## T03: conversion history and the evidence gap

The [conversion matrix](../../literature/conversion_evidence.csv) now records 24 study/model rows with reference pressure/height, temperature/profile assumptions, vertical quantity, evaluation reference and implications. “Not extracted” means the specific implementation is unresolved, not that the study omitted a correction. No software was reimplemented to fill missing details.

### A clearer classification

| Input/assumption choice | Checked examples | Consequence for the manuscript |
|---|---|---|
| Fixed standard sea-level pressure and temperature profile | Sjöberg 2018; Liechti 2018; Norevik 2021; Lathouwers 2022; Zhao 2024 | These support a documented standard-atmosphere stream, not a claim about every geolocator study. |
| Locally varying pressure with a simplified temperature assumption | Meier 2018 uses NOAA reanalysis sea-level pressure; Dreelin 2018 uses a local weather station | Reanalysis and station calibration both belong in the history. Define which input changes. |
| ERA5 reference near the model surface | GeoPressure workflow and applications | Explain reference height, pressure and temperature explicitly; package versions matter. |
| ERA5 surface plus an observed-time pressure-level-derived gradient | Schaub 2023 | A variable lapse-rate approach already exists in ecological tracking. Its supplement specifies 950 or 975 hPa, depending on dataset. |
| Repeated behavioural sea-surface calibration | Cleasby 2015; Johnston 2023; Miller 2026 | A practical reference strategy where behaviour provides sea-level anchors, rather than a separate atmospheric model family. |
| Full pressure-level atmospheric information | Simonetti & García Crespillo 2024 | Profile-informed barometric retrieval is an established comparator; its aircraft validation has different sensors, dynamics and reference data. |
| Temperature/humidity corrections in atmospheric models | Matyja et al.; GPT3/GNSS meteorology | Prior physical corrections are relevant, but simulation/geodetic evaluation is not direct bird-height validation. |

Sources: [Meier](https://doi.org/10.1007/s00265-017-2438-6), [Dreelin](https://doi.org/10.3389/fevo.2018.00182), [Schaub](https://doi.org/10.1186/s40317-023-00342-1), [Simonetti & García Crespillo](https://doi.org/10.33012/navi.637), [Matyja et al.](https://doi.org/10.1007/s10291-023-01582-7), [Landskron & Böhm](https://doi.org/10.1007/s00190-017-1066-2). Individual biological examples are linked in the evidence table.

### Claim audit and proposed answers

| Current claim or comment | Answer supported by this review | Suggested edit or follow-up |
|---|---|---|
| “Geolocator studies have converted pressure in three ways” | The proposed categories overlap in reference strategy and atmospheric inputs. | Describe the inputs along two axes: reference conditions and vertical temperature approximation. |
| Are barometric heights pressure-based, including in GPS tags? | Yes; a GPS-equipped device can contain a separate pressure sensor. | Introduce the sensor distinction before comparing measurements. |
| Have studies already corrected local weather/lapse rates? | Yes, including local-station, reanalysis, ERA5 surface and pressure-level-derived corrections. | Acknowledge specific precedents rather than implying that all earlier work used fixed lapse rates. |
| Is conversion accuracy simply “poorly known”? | Several local device/field tests and atmospheric benchmarks exist. They measure different error components. | State the narrower gap: broad assessment of the atmospheric conversion and its height-dependent errors under defined inputs/references. |
| Do GPS–barometer differences validate absolute airborne height? | Generally not without independent truth. | Separate grounded/floating anchors, inter-sensor agreement and laser/processed-GNSS truth. |
| Can height errors affect ecological conclusions? | Height distributions and collision-model outputs can change, as Johnston demonstrates. | Use conditional wording; do not infer measured mortality or universal ecological sensitivity. |
| Are the correction physics or ERA5 annotation new? | They have precedents. | Position the study around evaluation, error mechanisms and a practical correction with stated data requirements. No priority claim is established by this scoped search. |
| Is using full ERA5 profiles unrealistic? | A profile-based method exists; feasibility depends on retrieval and workload. | Discuss the trade-off. A runtime/data-volume comparison is a future analysis, not a literature-derived conclusion. |

Supporting methodological sources: [Péron et al.](https://doi.org/10.1186/s40317-020-00194-z), [Lato et al.](https://doi.org/10.1371/journal.pone.0276098), [Schaub et al.](https://doi.org/10.1186/s40317-023-00342-1), [Johnston et al.](https://doi.org/10.1186/s40462-023-00431-z), [Simonetti & García Crespillo](https://doi.org/10.33012/navi.637).

**Proposed positioning, for later drafting:** Evaluate how atmospheric reference and temperature-profile assumptions affect pressure-derived altitude across ground sites and airborne levels, distinguish this component from full deployed-device error, and quantify what a computationally simple correction improves. This is a synthesis/recommendation from the reviewed evidence, not a proof of novelty.

### Evidence and metadata issues to carry into drafting

- The original mangrove-kingfisher refinement example and the later woodland-kingfisher migration application must remain separate.
- Bowlin et al. (2015) is an earlier pressure/temperature radio-telemetry example, so 2018 miniature archival studies should not be presented as the first pressure-based bird-flight records.
- Meier's reference is NOAA reanalysis sea-level pressure, not simply “a weather model” distinct from reanalysis.
- Johnston's displayed logarithmic equation needs its sign/pressure-ratio convention checked against implementation before reproducing it. This review records the issue without diagnosing an implementation error.
- An agreement experiment using another pressure altimeter is not independent geometric-height validation.
- Article dates can differ from issue dates: Matyja is online 2023/volume 28 in 2024; Clark's PDF is Seabird 32 (2019), while Crossref records 2020. These distinctions are recorded rather than silently treating the DOI year as the publication year.
- Crossref's Rhyne 2026 author fields place some middle initials in surnames. The new local bibliography entry uses title-page names. The existing Zotero record was preserved; its metadata still needs a separate repair if desired.
- The manuscript bibliography had incorrect given names for Doniol-Valcroze and Beggs; these were corrected from the article title page, retaining the citation key.

## Coverage, access and remaining work

This is a **targeted narrative review**, not a systematic review. It started with the repository inventory, bibliography and earlier review, then used web discovery, publisher/institutional full texts, DOI metadata and the local Zotero library. The [search log](search-log-2026-10-18.md) records principal queries and the limits of the search. Discovery results were not used as substitutes for full methods where detailed conversions were extracted. Citation follow-up was selective; the review is not an exhaustive census of every bird altitude study.

Full texts were inspected at relevant passages rather than every page of every source. The evidence table records 34 locally available biological/context PDFs and one source assessed from publisher abstract/section excerpts (Metcalfe). Its short excerpts are deliberately brief, with physical PDF page numbers where matched; detailed equations are paraphrased and located by section/table. No passage should be interpreted as independent validation merely because it appears in a full text.

### T03 follow-up: resolved source-extraction gaps

The original-methods follow-up resolved the conversion details that are available in the local full texts. Jensen & Werema (2025, Methods, pp. 70–71) first corrected logger pressure for day-to-day atmospheric variation using pressure-level data from a meteorological station 25 km away, then applied a sea-level-referenced barometric formula using sea-level pressure and temperature with a 0.0065 K m⁻¹ lapse rate; the reported quantity is altitude above sea level. The authors report nominal logger accuracy of ±1 hPa (approximately ±10 m), but the paper follows one bird and does not validate its absolute altitude against an independent airborne height reference. This is a combined local-pressure plus standard-profile approach, not a pure fixed-standard conversion.

Rhyne et al. (2026, Methods, pp. 3–5) sampled pressure every 30 min and used GeoPressureR with ERA5 pressure variation and elevation masks for location inference. Their text says flight pressure drops indicate high-altitude flight, and reports flight altitude summaries, but does not state the exact flight-pressure-to-height equation, temperature profile, or datum transformation in the article text inspected. Thus this source supports pressure-derived flight behaviour and the ERA5 geolocation workflow, but it should not be used as a fully specified conversion precedent without its analysis code or supplementary material. The capture-site pressure-versus-light comparison is a location comparison, not validation of absolute altitude.

The frigatebird and goose examples can now be separated by sensor and conversion. Clark et al. (2019, Methods p. 4) smoothed barometric pressure, used a barometric formula, and calibrated sea-level pressure from mean logger temperature and air pressure during 48 h at the nest; GPS modal nest altitude supplied the reference height. Their reported mean nest-reference errors were 8.0 m (SD 5.1 m) for pressure altitude and 6.9 m (SD 21.1 m) for GPS altitude across three birds. This is a local fixed-point calibration and inter-device comparison, not independent in-flight geometric-height validation; the authors' description of pressure as the higher-accuracy stream should be bounded by this design. Weimerskirch et al. (2016) report GPS-accelerometer/physiology tracking and atmospheric/flight-height findings; the study's listed instrumentation does not establish a pressure-altimeter conversion, so its altitude results should not be cited as a barometric-conversion example. Bishop et al. (2015) report pressure-determined altitude from implanted multi-sensor loggers, but the accessible main article does not specify the conversion. A later study using the same logger programme (Hawkes et al. 2019, Methods) explicitly identifies the manufacturer international-standard-atmosphere formula and accepts daily-temperature effects; this clarifies that related goose records can represent standard-atmosphere pressure altitude, but it does not prove every earlier Bishop processing detail used exactly that implementation.

Johnston et al.'s conversion and height conventions are covered by the completed T04 source/code verification; no sign discrepancy was found in the evaluated implementation. The remaining source-level unknowns are narrower: Rhyne et al.'s exact flight-height implementation without code/supplement, the exact conversion in Bishop et al. (2015) itself, and Metcalfe et al. (2013), for which a full text was not available in the local library and the accessible record supports only the pressure-as-cue context. These unknowns do not affect the review's scope recommendations. The literature search does not establish the universal absence of any correction; avoid priority or exhaustive “first” claims.

**T03 status:** completed to the level supported by accessible sources. The conversion matrix and biological evidence table now distinguish fully specified methods from source limitations, and the claim-to-source audit supports the narrowed research gap. No new manuscript wording is required beyond the already approved edits. Any future implementation claim about Rhyne or Bishop should be checked against archived analysis code or supplementary methods first.

The literature library now has 75 inventory entries and 69 canonical local PDFs. The six without canonical PDFs include two software/data records, three manuals/book entries, and Metcalfe's article. Supplemental PDFs are stored separately and are not counted as additional publications. Canonical PDFs in `literature/references/` remain Git-ignored; `paper/pdfs/` retains its existing repository handling.

## Files and Zotero update

- `biological_applications.csv`: selected biological/context examples with evidence and limits.
- `conversion_evidence.csv`: 18 conversion-method records, including unresolved fields.
- `reference_inventory.csv`: refreshed file availability and 22 additional publication records.
- `review_additions.bib`: 27 DOI-deduplicated bibliography additions: 22 newly inventoried publications and five already in the literature inventory but missing from the manuscript bibliography. Existing manuscript citation keys were preserved in `paper/references.bib`.
- `reference_crosswalk.csv`: review keys, manuscript citation keys, DOIs and Zotero keys, including aliases for references already in the bibliography.
- `pdf_index.csv`: canonical file paths, sizes and SHA-256 hashes. `paper/pdf-manifest.csv` records the updated paper PDF folder; 24 PDFs were added there without renaming existing files.
- `download_attempts_2026-10-18.csv`: successful and failed new download attempts. Some PDFs were instead obtained from pre-existing local/Zotero copies.
- `metadata/`: DOI metadata snapshots; treat these as bibliographic evidence, not scientific full text.
- `zotero_collection.bib`: raw export of the collection after the update. It is separate from the curated manuscript bibliography because existing Zotero metadata are not uniformly complete.

The Zotero `altitude-validation` collection increased from **53 to 75 records**: **13 existing library items were filed without duplicating them**, and **9 new records were imported**. Eight new records have verified stored PDF attachments; Metcalfe has metadata and a publisher link. All 24 candidate DOI keys in the crosswalk are represented in the collection, including the two already present before this pass. The import request timed out, but subsequent API checks verified the records and attachments; it was not retried blindly.

No manuscript QMD, manuscript figures, rendered manuscript PDF or analysis outputs were changed. Bibliography corrections/additions and the local reference libraries were updated under the expanded request.


## Subsequent author decisions and implementation

On 18 October 2026 the author approved including pressure-equipped GPS tags while keeping satellite-derived height outside the evaluated scope. The manuscript now motivates the shared pressure-conversion problem without a generic accuracy ranking, cites the ecological precedents, and avoids priority claims. Local known-height calibration and time-specific ERA5 profiles are discussed as alternative workflows, without claiming a measured advantage for the tested bird records. Sea-level altitude and local ground clearance are separated, with `path2elevation()` and horizontal uncertainty explained. The 50 km sensitivity question has a predefined experiment but no result yet. See the current `docs/manuscript/comment-response-plan.md` and `docs/manuscript/location-sensitivity-plan.md`. T04 is documented in `docs/methods/T04/verification.md`; the original review status paragraphs above describe the earlier literature pass.

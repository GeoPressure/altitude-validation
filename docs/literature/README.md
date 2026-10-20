# Pressure-to-altitude literature

## GPS/barometer ecology report, 18 October 2026

Read the [Markdown report](gps-barometer-ecology.md). It covers ten primary studies, six attributed source figures, the contrast with small songbird geolocators, suggested scope wording and follow-up tasks. The author's assessment follows the paper summaries at the end. The recommendation is to include pressure-equipped GPS tags in the introduction and broader relevance while keeping the validation claim specific to atmospheric conversion. The former Quarto, HTML and PDF report copies have been removed.


Two additional full texts (Ross-Smith 2016 and Lempidakis 2024) are archived in `literature/references/` and `paper/pdfs/`, indexed in the PDF manifest and inventory, and described in [the supplementary BibTeX](../../literature/gps-barometer-additions.bib). They have not been inserted into the manuscript bibliography. The inventory now has 77 entries and 71 indexed canonical PDFs. The Zotero `altitude-validation` collection now has 77 parent records; these two additions have PDF URL links, with the actual PDF files archived locally. [The update record](../../literature/zotero_gps_review_2026-10-18.json) distinguishes linked URLs from stored attachments. The raw Zotero export has been refreshed. [Source notes](gps-barometer-sources.md) and [figure provenance](../assets/gps-barometer/manifest.json) document reproduction and attribution. The report was prepared before the subsequent author-approved manuscript edits. Those edits and the completed T04 technical audit are now recorded in [the current response plan](../../archive/docs/manuscript/comment-response-plan.md) and [the verification note](../methods/T04/verification.md). The proposed location-sensitivity appendix is specified separately and has not been run.

## T01–T03 review, 18 October 2026

Start with [the scoped review and manuscript recommendations](review-T01-T03.md). It addresses biological applications (T01), measurement alternatives/GPS context (T02), and conversion precedents and claim checking (T03), without editing the manuscript QMD or rerunning analyses.

- [Biological evidence table](../../literature/biological_applications.csv): selected publications with sensor distinctions, findings, source locations and limitations.
- [Conversion matrix](../../literature/conversion_evidence.csv): 24 studies/model references; source-level implementation limits remain explicit.
- [Search record](search-log-2026-10-18.md): principal queries, screening and access limits.
- [New bibliography entries](../../literature/review_additions.bib): 27 DOI-deduplicated additions (22 newly inventoried publications plus five previously inventoried references), also added to `paper/references.bib` with existing citation keys preserved.
- [Reference crosswalk](../../literature/reference_crosswalk.csv): review/citation keys, DOIs, Zotero keys and collection membership for the candidate additions.
- [PDF index](../../literature/pdf_index.csv): originally 69 canonical PDFs among 75 inventory entries; refreshed to 71 among 77 for the GPS/barometer follow-up, with file hashes. Supplements are stored separately.
- [Zotero export](../../literature/zotero_collection.bib): raw snapshot of the `altitude-validation` collection (initially 75 records; now 77), distinct from the curated manuscript bibliography.

The update added 13 existing Zotero items to the collection and imported 9 new records, eight with stored PDFs. Metcalfe (2013) remains abstract/metadata-only. Manuals/book and software/data entries have different access expectations from journal articles. Existing Zotero metadata were preserved, including records with incomplete authorship; this raw export should not overwrite the curated manuscript bibliography. The earlier access statuses below describe the original collection effort; `reference_inventory.csv` now records refreshed local availability, including PDFs already held in `paper/pdfs` or Zotero. New network download attempts are logged in `download_attempts_2026-10-18.csv`, and bibliographic metadata snapshots are in `metadata/`.

`reference_inventory.csv` links the manuscript bibliography to source identifiers, access information and local PDF paths. It includes references first identified in `archive/report/literature-review-and-paper-positioning.md` and the subsequent T01–T03 review. `literature/references/` contains canonical PDF copies obtained from accessible publisher/institutional sources or the user's existing local library; PDFs are ignored by Git because reuse terms differ. Zotero originals remain in the Zotero storage folder; copies and newly imported attachments are indexed separately.

## Core papers for pressure-derived altitude and validation

- **Péron et al. (2020)**, “The challenges of estimating the distribution of flight heights from telemetry or altimetry data” — measurement error, terrain, filtering and ecological inference; broad framework.
- **Lato et al. (2022)**, “Assessing the accuracy of altitude estimates in avian biologging devices” — drone and laser-altimeter validation of biologging devices.
- **Schaub et al. (2023)**, “How to improve the accuracy of height data from bird tracking devices?” — field comparison of GPS and ERA5-corrected barometric altimetry; closest ecological comparator.
- **Johnston et al. (2023)**, “Flight heights obtained from GPS versus altimeters influence estimates of collision risk…” — floating calibration and consequences for offshore-wind collision estimates.
- **Nussbaumer et al. (2023)**, “Global positioning with animal-borne pressure sensors” — pressure-derived altitude in the GeoPressure workflow.
- **Simonetti & García Crespillo (2024)**, “Geodetic Altitude From Barometer and Weather Data for GNSS Integrity Monitoring in Aviation” — profile-informed barometric retrieval benchmarked against post-processed GNSS.
- **Matyja et al. (2024)**, “Automatic correction of barometric altimeters using additional air temperature and humidity measurements” — adjacent correction methods; field validation is limited.
- **Miller, Hamilton & Clarke (2026)** — recent three-bird shy-albatross pilot using dynamic-soaring phases as a pressure reference; see the DOI entry in the inventory.
- **Poessel et al. (2018)**, “Improving estimation of flight altitude in wildlife telemetry studies” — reference-surface, GPS and inference pitfalls.
- **Borkenhagen et al. (2018; online 2017)**, “Estimating flight heights of seabirds using optical rangefinders and GPS data loggers” — comparison of flight-height measurement approaches.

## Related studies to keep for context

- Bird migration and pressure-logger applications: Liechti et al. (2018), Sjöberg et al. (2018, 2021), Meier et al. (2018), Rime et al. (2023), Rhyne et al. (2024), Norevik et al. (2021), Lindström et al. (2021), Lathouwers et al. (2022), Zhao et al. (2024), and Bäckman et al. (2017).
- Atmospheric conversion and vertical profiles: Wallace & Hobbs (2006), ICAO (1993, 2018), Bolton (1980), Stone (1979), Rolland et al. (2003), GPT/VMF3 work by Böhm et al. (2015) and Landskron & Böhm (2018), and GNSS/meteorological profile work by Wang et al. (2017), Haiden et al. (2018), Simonetti & García Crespillo (2024), and Matyja et al. (2024).
- Reanalysis and pressure reference quality: ERA5 (Hersbach et al. 2020; Bell et al. 2021; Soci et al. 2024), ERA5-Land (Muñoz-Sabater et al. 2021), IGRA (Durre et al. 2006, 2018), HadISD/ISD (Dunn et al. 2012, 2016; Smith et al. 2011), pressure-assimilation bias (Vasiljević et al. 2006; Cardinali et al. 2004), and Huang et al. (2023).
- Adjacent additions noted in the review: ERA5-SH (2025), ERA5 lapse-rate downscaling (Dutra et al. 2020), a regional ERA5/ERA5-Land pressure evaluation (2026), and NOAA's IGRA2 product documentation. These are context or data-method references rather than direct validations of bird altitude.

## Access notes

OpenAlex provided DOI metadata and repository/publisher PDF URLs. Some URLs are openly indexed but reject automated retrieval; these are marked in the CSV. A Zotero match means the record or PDF exists in the local Zotero database, not that the paper was copied into this repository. DOI-less manuals/books and records with no DOI still need a library search. Mendeley was not connected to this session.

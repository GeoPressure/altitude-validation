# T01–T03 search record — 18 October 2026

Scope: biological uses of bird altitude/pressure, measurement alternatives, and conversion/validation precedents. No date restriction was applied to broad discovery; recent 2024–2026 literature was also searched explicitly. Existing repository references and local Zotero records supplied additional leads. This log records the principal discovery/follow-up queries, not a reproducible database-wide search with stable hit counts. No PRISMA or exhaustiveness claim is made.

## Starting sources

- `literature/reference_inventory.csv` and `docs/literature/README.md`.
- `paper/references.bib`, `paper/pdf-manifest.csv`, existing PDFs and the annotated QMD.
- `archive/report/literature-review-and-paper-positioning.md`, treated as leads requiring source checks.
- Personal Zotero library and the `altitude-validation` collection; DOI/title matching was used before adding/importing records.

## Principal searches actually run

```text
bird barometer pressure logger altitude migration ring ouzel elevation
bird pressure logger altitude roosting wheatear woodland kingfisher
avian barometric altitude biologging flight wind soaring raptor pressure logger
bird barometer logger flight altitude Dreelin 2018 Dhanjal Adams twilight ascent
barometric pressure logger birds altitude migration 2024 2025 2026 wind temperature
"Complex day-to-day movements" "Alpine" Barras
"wheatears" "roosting" "2023" pressure
"Dreelin" "2018" flight behavior frontiers
"Barras" "2021" "ring ouzel" movements
"Rime" "2023" "wheatear" roost
"Dhanjal-Adams" "2018" "altitude"
"barometric" "bird" "altitude" "2019" migration
"pressure" "Dhanjal-Adams" "2018" migration
"barometric" "soaring" "condor" Williams 2020
"Barras" "Seasonal and daily movement patterns" doi
"Seasonal and daily movement patterns" "10.1111"
"Physical limits of flight performance" PMC
"bird" "pressure logger" "2025" altitude
"bird" "barometric" "2026" flight heights
"barometer" "frigatebirds" flight
"bar-headed geese" "roller coaster" pressure altitude 2015
"frigatebirds" "pressure" "2016" Science flight
"Senner" "2018" "altitude" godwit
"Dhanjal-Adams" "Spatiotemporal Group Dynamics" pressure
"bird" "barometric" "foraging" "2025"
"Ecological barrier crossing strategies" "114466"
"Multi-sensor logger tracking reveals the threats"
"Frigate birds track atmospheric conditions" "pressure"
"Solar heating may explain" "doi"
"birds" "barometric pressure" "departure" experimental study white throated sparrow
"Frigate birds track atmospheric conditions" doi
"The structure of the annual migratory flight activity"
"Predator foraging altitudes reveal"
"Ecological barrier crossing strategies in small migratory birds" pmc
"Multi-Sensor Logger Tracking" "con4.70077" Wiley
"pressure" "Woodland Kingfisher" altitude
"White-throated sparrows adjust behaviour" doi
"Small intra-tropical long-distance migratory birds track rainy seasons"
"Atmospheric pressure predicts probability of departure"
"Diel movements and flight altitudes" "GPS"
"Frigate birds track atmospheric conditions" "barometric"
"High-altitude shorebird migration" "GPS" Senner
"Avian Sensor Packages for Meteorological Measurements" authors 2018
"Using High-Resolution GPS Tracking Data of Bird Flight" Treep 2016
"Flight altitudes of a seasonally migrating bird" pressure 2015 auk808
"Seasonal altitudinal migration of White-chested Alethe"
"Rangewide connectivity and migration ecology"
"Geolocation with a magnetic sensor"
"Frigate birds track atmospheric conditions" pdf Weimerskirch
"White-throated sparrows adjust behaviour" filetype:pdf Metcalfe
"Unexplained altitude changes in a migrating thrush" pressure
```

## Screening and source use

Retain primary bird studies with measured/inferred vertical movement or direct pressure applications, methods relevant to their interpretation, and a small comparator set using other instruments. Mark perspectives and environmental-pressure studies separately. Do not classify GPS/radar altitude as pressure-derived evidence, and do not equate instrument resolution, between-sensor agreement and accuracy against an independent reference.

Publisher and author/institutional sources were preferred for scientific extraction. Index/aggregator results were discovery aids. Crossref snapshots in `metadata/` support bibliographic identifiers and authorship, with corrections checked against article title pages when conflicts were found. Within-study methods and supplements were followed where needed; Schaub's supplement was retrieved specifically to verify the variable-lapse-rate inputs.

Focused local-library screening additionally found the White-chested Alethe study, the 2026 Swainson's Warbler study and the earlier thrush radio-altimetry study. These were checked against primary sources/full texts rather than accepted from library titles alone.

## Limits and unsuccessful access

Some publisher pages returned errors or anti-bot challenges. Existing authorised local PDFs, institutional copies and publisher abstracts were used where available; no access control was bypassed. Metcalfe's publisher abstract/section excerpts were usable, but the attempted PDF response was not a PDF. Its entry remains metadata/abstract-only. Precise method gaps are retained in the evidence tables.

Crossref returned rate limits for some metadata requests; targeted retries supplied the new candidate records. Three DOI-less manuals/book references remain without canonical full PDFs. Software/data records are not treated as missing article PDFs. The exact historical implementation is not assumed from a current package merely because the paper cites that package.


## Follow-up: illustrated GPS/barometer ecology report

The follow-up report `gps-barometer-ecology.md` expands the GPS/barometer context requested by the user, with ten full-text primary-study summaries. This was targeted selection from the earlier evidence set and relevant reference lists, not a systematic database search. Core papers: Lato 2022, Schaub 2023 (including the lapse-rate implementation in its supplement), Péron 2020, Ross-Smith 2016, Cleasby 2015, Johnston 2023, Miller 2026, Clark 2019, Lempidakis 2024 and Senner 2018. DOI links accompany each summary. Source figures were checked in the original PDFs, cropped without changing scientific marks, and archived with hashes and crop coordinates.

Two further PDFs were retrieved from institutional repositories: Ross-Smith 2016 (UHI accepted manuscript) and Lempidakis 2024 (White Rose publisher PDF); exact URLs are in `docs/assets/gps-barometer/source_downloads.json`. Their Crossref metadata snapshots are archived, with cleaned citations in `literature/gps-barometer-additions.bib`. Both records were added once to the existing Zotero collection, bringing it to 77 parent records; their Zotero attachments are PDF URL links, not stored copies. The PDFs themselves are archived in both local reference folders. The manuscript bibliography, QMD, figures and rendered manuscript PDF were not modified by this follow-up.

# T05 — Dataset provenance, sampling and independence

**Later implementation:** T06 now removes repeated GNSS hours from primary summaries and regenerates current coverage; see its [implementation record](../T06/implementation.md). The counts and “current” statements below describe the earlier audit snapshot of the original inputs.

Completed 18 October 2026 for C16–C21 in the [comment response plan](../../manuscript/comment-response-plan.md). This audit reads the saved inputs and existing scripts; it does not redownload observations, change the study selections or recompute the reported error summaries. The new coverage outputs describe the inputs to the three-conversion comparison in `scripts/18_three_formulas.R`.

## Findings and implemented changes

Dataset-description publication years are distinct from observation years. The main ground window is 2022–2024, the radiosonde window 2023–2024, with separate historical HadISD samples in 1990, 2005 and 2015. These fixed selections cover recent seasonal cycles rather than the full archive or a long-term climatology. The configuration supplies these years but contains no contemporaneous explanation for choosing a shorter radiosonde window; the manuscript does not invent one.

The manuscript now identifies HadISD v3.4.3.2025f, cites its version-3 technical note, and adds BKG, RINEX, MeteoSwiss, IGRA documentation and the ERA5/ERA5-Land product citations. See [dataset provenance](dataset-provenance.csv) for versions, variables, units, height references, selection rules, cadence and provider links. Documentation was checked on 18 October 2026; that is not presented as the original data-download date.

### Realised coverage

| Ground reference | Stations | Retained rows | Unique station-hours | Median hourly availability across station-years | Median of station median intervals |
|---|---:|---:|---:|---:|---:|
| HadISD | 2,502 | 37,771,260 | 37,771,260 | 33.1% | 3 h |
| GNSS barometers | 47 | 1,097,549 | 1,077,297 | 99.4% | 1 h |
| MeteoSwiss | 138 | 3,604,509 | 3,604,509 | 100.0% | 1 h |

The denominator is all calendar hours in each selected year, including empty station-years. These are unweighted availability summaries, not the spatially weighted error metrics. Reporting schedules and gaps both affect availability. Four GNSS station-years and one MeteoSwiss station-year contain no retained rows; the coverage filters do not require all years to be represented. The largest internal interval between retained records is 9508 h for GNSS, 6692 h for HadISD and 686 h for MeteoSwiss. Intervals do not measure missing periods before the first or after the last record.

The saved airborne comparison contains 732,212 soundings and 10,779,002 levels at 648 stations. Counts are 367,032 soundings/5,015,842 levels in 2023 and 365,180/5,763,160 in 2024. Stations with airborne levels number 641 and 644 respectively. Sounding counts per nonempty station-year range from 12 to 1514 (median 686); a station qualifies across the two-year period, not separately each year. Radiosonde levels are not an hourly time series, and multiple levels can share the same ERA5 hour.

See [ground station-years](ground_station_year.csv), [ground coverage](ground_coverage.csv), [station intervals](ground_cadence.csv) and [radiosonde station-years](radiosonde_station_year.csv). These counts reproduce the selection logic rather than changing it.

### Important sampling details

- HadISD requires at least 183 reporting days and an average of four observations per reporting day in every main year. This does not guarantee a regular six-hour schedule. Times are rounded to the nearest ERA5 hour, half-hour ties go to the earlier hour, and the first report in a rounded hour is retained.
- GNSS requires at least 180 listed file-days across the whole window, followed by at least 2160 usable rows and the height check. Each daily file averages samples within ±1 min of an hour. Combining daily files leaves **20,252 extra rows with repeated station-hour timestamps**, 1.85% of the retained GNSS rows. The current error summaries retain them, so those hours can receive extra weight. Their numerical effect has not been measured; this is a concrete follow-up for the sampling/weighting work in T06. No deduplication or numerical revision was silently applied.
- MeteoSwiss uses instantaneous QFE (`prestas0`) at full UTC hours from a 10-min source, not an hourly mean. Its final 2160-row threshold is also not a per-year coverage requirement.
- IGRA uses reported release/elapsed times where available. Missing release time uses the nominal time, missing release minutes use zero, and missing elapsed time uses height divided by 5 m/s. A level and its own sounding surface can match different ERA5 hours. The fixed launch-site location is used throughout, ignoring drift.

[Input timing counts](radiosonde_input_timing.csv) cover all extracted raw levels at the 648 retained stations, before the final height/quality/input filters: 16,206,990 of 26,134,816 levels lack elapsed time, 216,119 lack release time, and 528,832 of 770,687 surface records lack height. These are **not** percentages among the final airborne levels. The script replaces missing surface heights with station elevation. Precise dependence on the fallbacks should be evaluated if timing sensitivity becomes a concern; the present task documents their use.

### Height provenance and assimilation

The GNSS height screen is a **median signed** header-minus-site-log difference within ±1 m, not agreement at every epoch and not a demonstration of millimetre absolute barometer-height accuracy. Site-log offsets are combined with marker/antenna heights, then EGM96 geoid undulation is subtracted. The [RINEX specification, Appendix A20](https://files.igs.org/pub/data/format/rinex304.pdf) defines the meteorological header height as ellipsoidal. MeteoSwiss publishes barometer height separately from station height; the code uses that sea-level height directly without a Swiss-to-EGM96 transformation. HadISD metadata supply station elevation, which can differ from the sensor height.

[IGRA format documentation](https://www.ncei.noaa.gov/data/integrated-global-radiosonde-archive/doc/igra2-data-format.txt), also [saved locally](igra2-data-format.txt), defines GPH as reported geopotential height. It does not establish independent geometric measurement at every level. The extractor does not retain the original pressure/non-pressure source codes or a per-level height-generation method. The [current IGRA product page](https://www.ncei.noaa.gov/products/weather-balloon/integrated-global-radiosonde-archive) identifies version 2.2, but no version marker was saved with the original extraction, so the historical subversion remains unverified.

[ERA5 documentation](https://confluence.ecmwf.int/pages/viewpage.action?pageId=414588701) describes hourly fields, observation assimilation and the EGM96 land reference. [Hersbach et al.](https://doi.org/10.1002/qj.3803) document the conventional surface and upper-air observing system. These sources support possible dependence of HadISD/IGRA/MeteoSwiss comparisons, not a claim that every selected record was assimilated. No selected-station/variable/date observation-feedback audit was available here. The [BKG holdings description](https://igs.bkg.bund.de/holdings) establishes distribution of RINEX meteorological records, not that their pressures never reach weather services through another route. Accordingly, all “never assimilated” and proven-independent-control claims have been removed from the manuscript and relevant script comments.

The MeteoSwiss `in_isd` flag is an identifier match to ISD history, not assimilation evidence. In GNSS derived files it is simply hard-coded `FALSE`, so interpreting it as verified absence would be incorrect. Network comparisons and station-density patterns remain descriptive corroboration, not a measurement of assimilation influence. The HadISD screen itself uses ERA5 discrepancies and cannot supply a wholly independent validation.

### MeteoSwiss decision

**Retain as corroboration, with detailed justification in S1/S4.** At 32 matched HadISD/MeteoSwiss stations, metadata height differences correlate with HadISD bias at r = 0.926. Median |bias| is 7.21 m with HadISD and 3.81 m with MeteoSwiss. These are paired station comparisons between two archives, not a controlled experiment in which only a height value was changed. They nevertheless give a specific reason to check listed station elevation against published barometer height. This cannot be supplied by adding more HadISD stations alone. We retain a short main-text result and put the sampling/metadata interpretation in the supplement. Figure/map redesign remains T08; no graphics were regenerated.

## Package and output-generation provenance

`output/tables/geopressurer_version.txt` contains `3.6.3.9000`. It is written by step 12, before steps 14, 16, 18 and 19, so it is not a version manifest for every downstream output. The audit-time checkout is GeoPressureR `3.6.5.9000`, commit `ba0a7ef5e0ebe481b9b58e62f57d6a552cfedd1f`. The original execution commit and dirty source state were not saved and cannot be established from file modification dates. The old version file has therefore been preserved, rather than overwritten with the current version.

The standard formula is now requested explicitly when the package exposes `altitude_formula`. A deterministic check of the earliest finite cached observation at each station found **zero difference** between the current standard conversion and saved standard errors at all 2646 cached HadISD stations and 655 cached IGRA stations. These counts include stations excluded from the final comparison. See [cached-formula checks](cached_formula_check.csv). This establishes numerical consistency for those sampled records, not the identity of the original software environment or full-table equality. T04 separately checked the current virtual/GPT3 formula against the package.

[Provenance manifest](provenance.json) records current script/input hashes, cached file hashes, the saved version label and the current package commit/source hashes. [Baseline table hashes](baseline-table-hashes.json) capture all pre-existing numerical output tables before T05; they were not changed by this task. Future regeneration should record software/source provenance separately for each analysis stage; the historical gap cannot be repaired by assigning today's version retroactively.

## Reproduction and remaining work

Run `Rscript docs/methods/T05/audit_sampling.R` from the project root with the existing local data and dependencies. It writes only audit CSVs in this folder and reads the current local GeoPressureR checkout. It does not call download or full-study scripts.

T05's manuscript edits and audit deliverables are complete. Remaining limitations are explicitly documented: original download/revision identifiers and execution commits, station-record assimilation status, exact IGRA height-generation methods, vertical-datum equivalence and GNSS duplicate-hour sensitivity. The concrete next task is T06: simplify metrics and audit weighting, including a paired GNSS comparison with/without duplicate hours before deciding on a numerical update. T07's bird-flight target and T08's figures remain separate tasks.

Verification: the complete audit script ran successfully; every pre-existing numerical output table retained its baseline SHA256; bibliography keys resolve without duplicates; both QMD files rendered successfully to PDF and HTML. The main reference table, supplementary coverage table, sampling methods and dependence discussion were visually checked in the PDFs.

# Quality codes and the manually reviewed pressure errors

Author-facing check, 23 October 2026. This audit checks whether source-specific archive flags explain the pressure errors found during station curation. It does not introduce a new selection criterion.

## Documentation

NOAA's [GHCNh documentation, section VI, Table 3](https://www.ncei.noaa.gov/oa/global-historical-climatology-network/hourly/doc/ghcnh_DOCUMENTATION.pdf) confirms that code 4 means calculated for sources 220, 221, 222, 223, 347 and 348. For sources 313, 314, 315, 322, 335, 343, 344 and 346 it instead denotes a gross-limit pass for data originating from an NCEI source. A blanket rejection of code 4 would therefore be incorrect. The legacy I and R codes describe inserted and NCEI-computed values; the table does not establish how code-4 pressure was calculated. A decision to require directly measured pressure would be a separate study-design criterion, not an additional documented failure flag.

The existing filter rejects the listed numeric suspect/error/removal codes with the appropriate source qualification for code 5, and all lowercase integrated failure flags, including pressure, spike, timestamp and diurnal-consistency flags. Precipitation-specific uppercase codes do not provide pressure rejection rules. The source-specific lists in Table 3 do not establish meanings for source 401's numeric codes.

The [NOAA source list](https://www.ncei.noaa.gov/oa/global-historical-climatology-network/hourly/doc/ghcnh-source-list.pdf) identifies source 412 as SYNOP/FM12 or BURF surface-land observations decoded by NOAA/NCEI, beginning in 2026; source 413 is the separate METAR decoder. Source 412 supplies many of the gross 2026 pressure blocks in this review. The source association does not identify whether an individual error arose in the sensor, encoding, decoding or reference metadata. The downloaded list does not describe sources 393 or 401.

## Overlap with reviewed problems

For each saved station-review window, we inspected the three largest departures from its own median converted height. In the evidence through batch 6, 105 distinct sampled reports depart by more than 100 m. None carries code 4 for a source where it means calculated. These examples include 49 source-412 reports with missing QC, 18 source-393 reports with missing QC, six source-388 reports with missing QC, 22 source-220 reports marked good (1), and ten source-223 reports marked good (1). This is a targeted diagnostic sample, not a count of all outliers or a claim that every large departure is faulty.

Thus, calculated-pressure flags do not explain the gross excursions or source-393 timing signals reviewed here. Several major problems survive the archive's good or missing flags. Pressure-series checks and documented curation remain necessary. The absence of an archive failure flag does not establish that a report is measured directly or otherwise correct.

## Reproduction

`scripts/drafts/review_quality_codes.R` reads the saved review evidence and current primary accepted records. Its outputs are `output/drafts/atmospheric-figures/curation_quality_codes.csv`, `curation_quality_extremes.csv`, and `current_accepted_quality_codes.csv`. The script includes batch 7, so its diagnostic total can exceed the 105 examples above. Current accepted counts are refreshed after the final selection rebuild. Cached pressure files retain their original archive-QC filtering; the audit reads their saved quality and source codes, without claiming that changing `ghcnh_pressure()` alone would invalidate an existing cache.

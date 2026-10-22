# GHCNh transition and reference choices

> Historical review: GNSS and MeteoSwiss evaluations were retired on 22 October 2026. The current study uses GHCNh and IGRA2; the manuscript sources and `run_all.R` define the active analysis.


## Main references

Use GHCNh for the global ground comparison and IGRA2 for the radiosonde comparison. Keep GNSS and MeteoSwiss as complementary checks in the supplement. Do not pool them into the primary ground score: their height metadata, geographic coverage and observation windows differ. Use one sentence in the main text to point to the height-reference corroboration and explicitly retain the assimilation limitation.

NOAA describes GHCNh as the replacement for ISD, with integrated QC and preserved source QC ([product](https://www.ncei.noaa.gov/products/global-historical-climatology-network-hourly), [documentation](https://www.ncei.noaa.gov/oa/global-historical-climatology-network/hourly/doc/ghcnh_DOCUMENTATION.pdf)). GHCNh is not a new precision survey of barometer elevations. Its station metadata are assembled from contributing sources. A station elevation cannot automatically be interpreted as the pressure sensor's surveyed height.

## Date and quality rules

Retain the previously requested rule: choose the latest year from 2022–2026 with at least 183 reporting days and an average of four accepted distinct station-hours per reporting day. Select by recency and reporting support, never by the lowest ERA5 discrepancy. Treat recent data as current, not intrinsically more accurate. Current-year data have incomplete seasonal support; compare with the latest qualifying completed calendar year on the same screened stations in the supplement. Completed calendar years can still have missing months.

NOAA dates use the ISO separator `T`; parse the complete timestamp with `%Y-%m-%dT%H:%M:%S`. The previous implicit R parser dropped the time, so all reduced extracts and screen outputs are rebuilt before using them. Raw annual files are unchanged. Coverage is counted after rounding to distinct ERA5 hours. Keep original report QC/source codes for review, exclude suspect/error and lowercase integrated QC flags, and retain missing QC without describing it as checked-good. NOAA's numeric flags are source-dependent; missing and gross-limits-only codes do not establish full QC.

Keep the original ERA5-dependent plausibility bound and gross-discrepancy rule as conditional screens, with unscreened results in the supplement. Compute gross flags per station-year. Retain up to two preceding years to support the original seasonal monthly step model; at least 18 usable monthly medians and all 12 months are required. Record `step_tested` so insufficient history is not described as demonstrated stability. Historical 1990/2005/2015 samples are excluded from that local step fit. The main statistics use only the selected year. Spatial thinning continues to preserve geographic coverage rather than selecting whichever stations happen to match ERA5 best.

ERA5's live archive can lag GHCNh. Detect the latest shared hour of ERA5 single-levels and ERA5-Land, stop extraction there and refresh incomplete caches. Verify coverage again after matching ERA5 before interpreting station-year results.

## What each complementary archive adds

| Source | Distinct value | ERA5 independence | Decision |
|:--|:--|:--|:--|
| MeteoSwiss | Published barometer height permits a paired height-only change in the same GHCNh pressure series | Not established; national meteorological observations can overlap conventional reports | Keep the existing focused appendix check; this directly tests the height-reference argument |
| GNSS met | Site-log and RINEX-header height information can be cross-checked, including sensor offsets and vertical datum | BKG/IGS provenance alone does not prove absence from meteorological exchanges | Keep height-checked results in the appendix; do not call them independent |
| ARM MET | Handbook specifies station pressure measured 1 m above ground; deployment metadata, altitude datum and QC still need checking | Not established here; do not infer exclusion from the archive name | Highest priority for a small additional pilot if it provides a documented deployment height or verified non-assimilation |
| DWD CDC | Instrument and relocation histories are useful, but instrument metadata do not automatically provide sensor height | Not established | In the 212 cached historical archives, all 283 relevant 2022–2026 instrument periods have missing `Geberhoehe ueber Grund [m]`; no demonstrated height advantage yet |
| GRUAN | Reference processing supplies per-observation uncertainties and pressure/height processing metadata | Not established; products can derive pressure partly or entirely from GNSS height | Potential targeted appendix uncertainty check, with instrument-specific pressure/height provenance; retain IGRA2 as the primary global upper-air set |
| Copernicus global surface | Integrated global archive and harmonized QC; substantial overlap in the kind of source data represented by GHCNh | Not established | No additional primary network; retain as an archive/QC comparison only if it answers a concrete question |

The DWD metadata audit is reproducible with `Rscript scripts/review_dwd_metadata.R`; outputs are in `data/interim/dwd/barometer_metadata_*.csv`. During review, the optional DWD importer also needed a correction for open-ended metadata periods and for comparing dates in days rather than POSIX seconds. Cached DWD observations created before that correction must be regenerated before any location/height comparison.

The [ARM MET handbook](https://www.arm.gov/publications/tech_reports/handbooks/met_handbook.pdf?id=70) documents the 1 m pressure measurement height. The [MAWS handbook](https://www.arm.gov/publications/tech_reports/handbooks/maws_handbook.pdf) also describes a 1 m barometer mounting. These describe sensor installation, not a universal proof of absolute site-altitude accuracy or assimilation independence. A useful ARM pilot must use raw MET observations rather than a reanalysis-driven ARM product, preserve instrument/QC metadata, and establish the reference datum and deployment period. ARM API access requires an [ARM username and access token](https://armlive.svcs.arm.gov/); account creation alone is not evidence that a token is configured.

ERA5 assimilates conventional surface and upper-air observations ([ECMWF documentation](https://confluence.ecmwf.int/pages/viewpage.action?pageId=177481858)). To claim independence, establish whether the particular station, variable and dates were used, preferably using observation feedback. Archive membership or absence from GHCNh alone is insufficient. Even unused local measurements share the larger-scale atmospheric conditions constrained by surrounding observations.

## Criteria for expanding the main text

Add a complementary result to the main text only if it materially changes the scientific conclusion, supplies a verified reference-height correction, or establishes a defensible test using records not assimilated in ERA5. Otherwise keep the comparison in the supplement. The existing MeteoSwiss height-only contrast is directly relevant to reference imprecision; it does not require making MeteoSwiss a second primary ground dataset. Do not label the global GHCNh/IGRA comparison an independent validation.

The [GRUAN RS92 processing documentation](https://www.gruan.org/documentation/gruan/td/gruan-td-4) includes pressure/height uncertainty information, but combines sensor pressure and GNSS-derived information during processing. The [Meisei documentation](https://www.gruan.org/documentation/gruan/td/gruan-td-5) states that those sondes usually have no pressure sensor. Therefore GRUAN is not automatically an independent measured-pressure versus GNSS-height test; audit the particular sonde/product before using it for that purpose.

## Matched 2024 transition audit

An optional audit (`Rscript scripts/review_ghcnh_transition.R`) uses the existing HadISD error cache and the pre-transition station summaries; the primary GHCNh build does not depend on those files. It compares 2024 hours at matched stations within 1 km that use the same ERA5 single-level grid cell, requires at least 500 common accepted hours, and excludes gross flags from both archives. The audit retained 1,164 station pairs and 5,747,736 common hours. At 97.7% of the station pairs, the median absolute hourly pressure difference is zero hPa; this is a station-level statistic, not the percentage of all observations that are identical. The median absolute listed-elevation change is zero metres. Median station absolute bias is 3.72 m with the previous inputs and 3.75 m with GHCNh; median station SD is 4.07 versus 4.05 m. These paired discrepancy statistics support continuity of the underlying pressure records and retaining the existing cleaning thresholds. They do not establish that either archive has the correct sensor height, or attribute every difference solely to the archive. Full paired outputs are in `data/interim/ghcnh/legacy_paired_2024.csv`.

## Computational scope

The observation-level explanatory GAM in step 12 is capped at 100,000 observations from 200 randomly sampled screened stations (fixed script seed), preserving the station random effect. The previous two-million-row fit with nearly 2,000 station effects did not complete after more than nine hours on this machine. Sampled IDs/counts are saved in `output/tables/ground_importance_sample.csv`. All primary error summaries, station screens and year comparisons continue to use all eligible observations.

## Updated reference checks

After ERA5 matching, 2,144 GHCNh stations retain the required coverage and 1,983 pass the station screen. The step test has enough history at 2,023 of the 2,144 stations; 107 stations in the screened set remain untested for steps. The tighter Swiss match retains 24 distinct station pairs (maximum separation 0.407 km). Changing only the reference height reduces median absolute station bias from 5.99 m to 2.99 m; the separate 2022–2024 MeteoSwiss series gives 2.73 m. This supports retaining one height-reference sentence in the main text and the full paired check in the supplement. Only five stations contribute to all four historical years (1990, 2005, 2015, 2024), so the historical result is a small appendix comparison rather than evidence for a global accuracy trend.

## Date-selection outcome

The completed-year sensitivity retains 1,912 common screened stations. The latest qualifying samples have medians of 280 reporting days and 10 months, versus 362 days and 12 months for the latest qualifying completed years. Cell-weighted ERA5-standard MAE is 6.48 m versus 6.37 m; median station absolute bias is 2.92 m versus 2.96 m. This supports the robustness of the agreed recency rule, rather than greater accuracy of recent records. The final primary selected-year counts are 35 (2022), 40 (2023), 177 (2024), 404 (2025), and 1,327 (2026). Source-QC classes remain explicit: 1,608,760 selected hours are source checked-good, 3,986,721 have missing source QC, and 2,714,052 have other accepted source flags. Missing/source-limited QC is not described as full quality assurance.

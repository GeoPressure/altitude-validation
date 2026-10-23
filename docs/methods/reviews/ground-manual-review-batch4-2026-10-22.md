# Ground-station manual review: batch 4

Author-facing review, 22 October 2026. Reviewed 38 previously unreviewed stations from the union of the 40 largest temporal SDs and 20 largest absolute biases. Exclusions below are manual curation, not an automatic ERA5-residual rule. All selected-window time-series plots and numerical diagnostics were inspected.

| Station | ID | Decision | Evidence |
|---|---|---|---|
| JAEN-INSTITUTO | SPN00005270 | Exclude | Raw source 400 identifies current Jaen 5270B while archive metadata identify historical Jaen-Instituto 5270 at 510 m; AEMET lists 5270B at 580 m. |
| DIPKARPAZ | CYM00017547 | Retain | Stable offset with small scatter; no independently established reference conflict. |
| XINYI | CHM00059456 | Retain | Stable offset with small scatter; no independently established reference conflict. |
| LITANG | CHM00056257 | Retain | Stable offset with small scatter; no independently established reference conflict. |
| PROGRESS | AYM00089574 | Retain | Stable offset; one approximately 113 m excursion is questionable but not confidently separable from polar weather and representation errors. |
| BISHKEK | KGM00038353 | Retain | Broad winter variation; no unambiguous discontinuity. |
| MORADA NOVA | BRM00081832 | Exclude | Terminal April 2026 reporting block shifts from about 94 m to 20-45 m, following a gap and change to source 412. |
| AVARE | BRM00086904 | Retain | Stable offset with small scatter; no independently established reference conflict. |
| DEVA RUMANIA | ROMU0015230 | Retain | Stable offset with small scatter; no independently established reference conflict. |
| SAN LUIS | COI0000SKIP | Retain | Scatter decreases after source 223 to 412 transition, but median height remains stable; pressure-reference or timing fault not established. |
| COLOTLAN  JAL. | MXM00076519 | Retain | Broad recurrent variation; lag improvement is modest and incomplete, not comparable to the strong source-393 timing pattern. |
| SANRAMON | BLU085109-1 | Retain | Moderate changing offset with seasonal structure; cause unresolved. |
| EMEI SHAN | CHM00056385 | Retain | Coherent variation at a high mountain station. |
| GRANITE PEAK FILLMORE AP | USW00000481 | Retain | Coherent weather-scale and seasonal variation; no clear reference discontinuity. |
| BARCELOS | BRM00081648 | Exclude | Seven terminal April 2026 reports produce heights about 490-501 m instead of the usual 35 m; pressure falls to 954-957 hPa. |
| TALAS | KGM00038345 | Retain after automatic spike removal | Isolated 887.0 hPa report on 2026-05-18 between 870.3 and 871.7 hPa reports, implying a transient approximately 160 m displacement. |
| EKEZHE | TXM00038388 | Retain | Weather-related scatter and excursions; no confidently isolated gross reporting error. |
| CUYO | RPM00098630 | Exclude | Abrupt persistent approximately 27 m reference step in November 2025, separating tight pre/post distributions. |
| TARTAGALAERO | ARU087022-1 | Retain | Seasonal variation and several excursions; no clearly established gross report or metadata conflict. |
| MATAVERI INTL | CII0000SCIP | Exclude | Repeated reporting-hour-dependent pressure-reference mismatch: heights near 38 m at three-hourly synoptic hours versus 67 m at intervening hours; raw pressure alternates by about 3-4 hPa. |
| DOMECII | AYU089828-1 | Retain | Smooth seasonal variation at a high Antarctic station; no clear recording failure. |
| BERBERATI | CTI0000FEFT | Retain after automatic spike removal | Gross isolated 900.7 hPa report on 2025-11-08 surrounded by 944-947 hPa reports, implying 1013 m at a 588 m station. |
| DOI ANG KHANG | THM00048302 | Retain | Seasonal variation and broad scatter at a mountain station, without a clear persistent reference step. |
| SERGE-FROLOW (ILE TROMELIN) | TEM00061976 | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.54 to 0.27 hPa at diagnostic lag 8 h, with 8392 of 8404 reports matched; predominantly source 393. |
| STIGLER REGIONAL AP | USW00000214 | Exclude | Sustained approximately 30 m reference step in November 2024, separating tight pre/post distributions. |
| TSAMPA | BTM00044517 | Exclude | Frozen pressure: 1048 retained reports repeat 653.5 hPa from 2025-12-10 to 2026-01-27; another 445 repeat 655.0 hPa across 19 days. |
| TAKAROA | FPU98749001 | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.83 to 0.25 hPa at diagnostic lag -20 h, with 8109 of 8214 reports matched; predominantly source 393. |
| RANGIROA | FPI0000NTTG | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.82 to 0.30 hPa at diagnostic lag -20 h, with 8388 of 8408 reports matched; predominantly source 393. |
| FURANCUNGO | MZM00067225 | Retain after automatic spike removal | Isolated 858.4 hPa report on 2025-07-17 between 879.4 and 881.0 hPa reports, with another opposite excursion in October. |
| ILES GLORIEUSES | FSM00061968 | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.80 to 0.29 hPa at diagnostic lag 6 h, with 7890 of 7929 reports matched; predominantly source 393. |
| KASHI | CHI0000ZWSH | Exclude | Isolated 922.8 hPa report at 2026-08-04 12 UTC implies 703 m versus 1380 m listed height; same timestamp/source 412 as previously identified Chinese gross reports. |
| SHIRABAD | UZM00038921 | Retain | Scattered excursions without sufficiently clear reporting failure. |
| TAIARAPU-EST | FPM00091936 | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.83 to 0.33 hPa at diagnostic lag -20 h, with 8129 of 8172 reports matched; predominantly source 393. |
| JUAN DE NOVA | FSU98403002 | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.67 to 0.27 hPa at diagnostic lag 6 h, with 8399 of 8406 reports matched; predominantly source 393. |
| DZAOUDZI PAMANDZI | MFI0000FMCZ | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.75 to 0.30 hPa at diagnostic lag 6 h, with 8401 of 8407 reports matched; predominantly source 393. |
| AK-BAJTAL | UZM00038178 | Retain | Larger winter departures and scatter without a clearly established recording failure. |
| DAMASCUSINT.AIRPO | SYU040080-1 | Exclude | Gross isolated 993.9 hPa report on 2024-10-09 surrounded by 942-947 hPa reports, implying 140 m at a 609 m station. |
| MARTINIQUE AIME CESAIRE INTL A | MBW00000404 | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.55 to 0.25 hPa at diagnostic lag -8 h, with 8410 of 8419 reports matched; predominantly source 393. |

Evidence files have prefix `output/drafts/atmospheric-figures/era5_batch4_review`: eight plot pages, retained records, archive metadata, monthly summaries, excursion diagnostics and lag sweep. Timing shifts are diagnostic comparisons only; none is applied to the observations. The 3-hour spike rule misses several gross reports because bracketing observations are too far apart. The automatic check now also removes departures greater than 10 hPa bracketed within 12 hours by pressures agreeing within 3 hPa, requiring both the departure and return to exceed 2 hPa per hour. Talas, Furancungo and Berberati are reassessed with this check rather than excluded as whole stations. Larger gaps remain unsupported; Damascus and Kashi still require manual curation.

For Jaen, raw source identifiers are 5270B throughout the reviewed annual files, whereas the archive ID/name/510 m reference correspond to historical 5270. [AEMET January 2024 station table](https://repositorio.aemet.es/bitstream/20.500.11765/15594/1/res_mens_clim_2024_01.pdf) lists 5270B at 580 m. This is a station-identity/elevation conflict, not a correction inferred from ERA5.

Post-filter review confirms that the gross excursions at Talas, Furancungo and Berberati are removed. Remaining variation does not establish a recording fault, and all three remain eligible. Furancungo selects a different latest qualifying year after pressure filtering; its retained monthly summaries and largest remaining deviations were inspected directly. The batch therefore adds 17 station exclusions and retains 21 stations, including these three.

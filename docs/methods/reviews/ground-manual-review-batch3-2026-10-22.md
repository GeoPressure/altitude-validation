# Extended ground-station manual review

Author-facing review, 22 October 2026. This batch contains the union of the twenty remaining highest-SD stations and ten largest absolute biases after the first two curation batches: 29 distinct stations. Ten are excluded for the reasons below and nineteen retained because no sufficiently clear problem was established. Automatic selection uses no ERA5-residual cutoff; these manual decisions followed diagnostic review and must be reported as curation.

| Station | ID | Decision | Reason |
|---|---|---|---|
| ISSYK | KZM00036885 | Retain | Broad scatter and negative offset; cause unresolved. |
| ALPINE CASPARIS AP | USW00003049 | Retain | Stable negative offset; NOAA independently confirms archive elevation, with no clear series failure. |
| COFFEE BAY | SFM00068677 | Retain | Stable negative offset without an independently established reference error. |
| HEYUAN | CHM00059293 | Retain | Stable positive offset; station-history explanation not verified. |
| ULSAN | KSI0000RKPU | Exclude | Airport metadata conflict with retained WMO-47152 reports and independently documented city-station elevation. |
| RUO'ERGAI | CHM00056079 | Retain | Stable positive offset; no clear recording failure. |
| WORCESTER | SFM00068821 | Retain | Negative offset and moderate variation; no clear recording failure. |
| JIULONG | CHM00056462 | Retain | Coherent seasonal variation at a mountain site; no clear recording failure. |
| FRANKFORT | SFM00068362 | Retain | Stable positive offset; no independently verified metadata conflict. |
| KIGOMA | TZI0000HTKA | Retain | Stable negative offset; no independently verified site conflict. |
| DAWU | CHM00056167 | Retain | A winter departure is visible but recording failure is not distinguishable from atmospheric representativeness. |
| DROSH PAKISTAN | PKMU0020354 | Retain | Broad scatter without a clearly identified recording failure. |
| BOONE WATAUGA CO HSP | USW00063819 | Exclude | Sustained approximately 50 m shift near May 2025. |
| ROQUE DE LOS MUCHACHOS | SPN000C101A | Retain | Coherent weather-scale variation at a high mountain station. |
| HONAVAR INDIA | INMU0020523 | Retain | Repeated lower-pressure/height regimes merit attention, but their origin is unresolved; not sufficient for exclusion. |
| CHERAT PAKISTAN | PKMU0020352 | Retain | Broad scatter without a clear recording failure. |
| DUSHANBE,AGRO | TIM00038836 | Retain | A moderate change near January 2026 is ambiguous between reference and atmospheric effects. |
| VALDEZ MUNI AP | USW00026479 | Retain | Larger winter weather-related departures, without a clear recording failure. |
| DRUZBA | KZM00036806 | Retain | Weather-related scatter and excursions without a clearly identified recording failure. |
| QU XIAN | CHM00058633 | Exclude | Isolated 872.5 hPa report on 4 August 2026 implies 1,246 m at a 71 m station. |
| ABECHE | CDU004756-1 | Exclude | Bad pressure episode near May–June 2024, including repeated rapid excursions. |
| CPREY VENG | CBM00048997 | Exclude | Several sustained shifts between distinct pressure-reference levels during 2024. |
| NUKUATAHA AERO | FPU98731007 | Exclude | Strong temporal-misalignment signal: pressure residual SD 2.12 to 0.33 hPa at diagnostic lag −19 h. |
| GARZE | CHM00056146 | Retain | Coherent seasonal variation at a mountain site. |
| TENGCHONG | CHM00056739 | Exclude | Isolated 940.3 hPa report on 4 August 2026 implies 589 m at a 1,697 m station. |
| ORIZABA  VER. | MXM00076737 | Retain | Broad recurrent scatter; a recording/timing fault is not established. |
| HAO AERO | FPU98720002 | Exclude | Strong temporal-misalignment signal: pressure residual SD 2.00 to 0.31 hPa at diagnostic lag −19 h. |
| MORUROA | FPU98755002 | Exclude | Strong temporal-misalignment signal: pressure residual SD 2.19 to 0.36 hPa at diagnostic lag −19 h. |
| ANAA | FPI0000NTGA | Exclude | Strong temporal-misalignment signal: pressure residual SD 1.85 to 0.29 hPa at diagnostic lag −20 h. |

## Independent metadata and diagnostic details

KMA documents Ulsan city station 152 at 81.14 m, 35.58237 N, 129.33469 E. Archive KSI0000RKPU instead uses airport coordinates 35.5935 N, 129.3517 E and height 13.7 m. The raw 2026 station file associates retained pressure reports with WMO-47152 after the source changes to 412, following earlier ICAO-RKPU identifiers. Converted height remains near 85 m across the source change. This supports a mixed-site association; exact barometer elevation and the full site history were not reconstructed. [KMA metadata](https://data.kma.go.kr/tmeta/stn/selectStnDetail.do?isSelectStn=Y&pgmNo=82&stdStnNo=152).

NOAA lists Alpine Casparis Airport at 4,513 feet (approximately 1,376 m), supporting its archive reference height. Its stable −77 m discrepancy is retained because the cause remains unresolved. [NOAA station information](https://www.weather.gov/maf/cli_maf_wban_alpine).

The Polynesian lag tests compare pressure at time t with the inverted ERA5 standard-lapse expected pressure at t−lag. The strongly negative lags therefore mean comparison with ERA5 19–20 hours later. Nearly the full sample remains matched. These tests are diagnostic evidence of temporal misalignment, not independently verified timestamp corrections; no empirical shift is applied. All four records use source 393. The raw timing convention remains unresolved.

Qu Xian and Tengchong each contain one grossly discordant report at exactly 2026-08-04 12:00 UTC, source 412. These reports survive the isolated-spike rule because sufficiently close bracketing observations are absent. Isolated reports separated by long gaps are drawn as short horizontal strokes in the revised diagnostic plots. Their values were also inspected directly in the saved numerical diagnostics.

Diagnostic files use prefix `output/drafts/atmospheric-figures/era5_extended_review`. Rebuild the review with `Rscript scripts/drafts/high_bias_stations.R review`, then `Rscript scripts/drafts/era5_tail_diagnostics.R review`. These outputs describe the reviewed sample before the ten exclusions, not the subsequent replacements.

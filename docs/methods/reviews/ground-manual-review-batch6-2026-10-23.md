# Ground-station manual review: batch 6

Author-facing review, 23 October 2026. Reviewed all 12 previously unreviewed records in the union of the 40 highest temporal SDs and 20 largest absolute biases after batch 5. Seven are excluded and five retained. This batch reads the actual primary accepted records; all three plot pages, archive metadata and lag diagnostics were inspected.

| Station | ID | Decision | Evidence |
|---|---|---|---|
| EVC_VZNAR | SPN0005515D | Retain | Stable positive offset with small scatter; the EMEP/CCC station inventory independently lists Viznar at 1258 m, supporting retention. |
| RIO GRANDE | BRM00086995 | Exclude | Tight pressure-reference distributions separated by a gap in November 2025: converted height shifts persistently from about 3 m to about 30 m. |
| GILLOT-AEROPORT | REU97418110 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.62 to 0.49 hPa at diagnostic lag 8 h, matching 8398 of 8407 reports. |
| SECRETARYISLANDAW | NZU093800-1 | Exclude | Terminal frozen pressure: 64 retained reports repeat exactly 1022.4 hPa from 2026-09-25 05 UTC to 2026-09-28 04 UTC. |
| SEKONG | LAM00048953 | Retain | Broad variation and scattered excursions; no clear recording fault established. |
| MEGRI | AMM00037958 | Retain | Coherent weather and seasonal variation; no clear recording fault. |
| SAINT LAURENT | FGU97311001 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 2.03 to 0.31 hPa at diagnostic lag -7 h, matching 8179 of 8200 reports. |
| GIGHBUB | LYM00062176 | Exclude | Isolated 1058.6 hPa report on 2023-03-15 after an 18-hour gap, surrounded by 1012-1016 hPa reports; implies -355 m at a near-sea-level station. |
| BASE BERNARDO O'HIGGINS | AYM00089059 | Retain | Polar weather-related scatter and excursions; no clear recording fault. |
| LE RAIZET AERO | GPU97101015 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.51 to 0.25 hPa at diagnostic lag -8 h, matching 8410 of 8419 reports. |
| KRABI | THM00048563 | Exclude | Reporting-hour-dependent pressure-reference mismatch: median height 34-35 m at three-hourly synoptic hours versus 58-59 m at intervening hours; repeated distinct levels. |
| POZO COLORADO | PAM00086128 | Retain | Weather-scale variation with sparse excursions; no sufficiently clear recording fault. |

Evidence files use prefix `output/drafts/atmospheric-figures/era5_batch6_review`. At Krabi, fewer than 0.6% of synoptic-hour heights exceed 50 m, versus roughly 73-82% at intervening hours. This repeated reporting-hour reference mismatch supports manual exclusion rather than treating the spread as atmospheric conversion error. At Secretary Island, the flat pressure sequence itself supports a frozen sensor/reporting episode. Gighbub cannot be handled by the 12-hour bracketing rule because one preceding gap is 18 hours.

Across batches 4-6, 68 additional stations were reviewed: 35 excluded and 33 retained, including the three stations recovered after pressure-only spike removal. The final rebuild adds a rate condition to the sparse-report spike check: both the departure and return must exceed 2 hPa per hour. This preserves slower coherent pressure changes. Neither the automatic spike check nor the continuity screen uses ERA5 residuals.

An independent primary inventory lists EMEP station ES0007R Viznar at 37°14′14″ N, 3°32′03″ W and 1258 m: [EMEP/CCC 2023 ozone-measurement report, station table](https://emep-ccc.nilu.no/static/reports/EMEP_CCC-Report%202_2025%20Ozone%20measurements%202023%20FINAL%2016-09-2025.pdf). This supports the archive height despite the persistent positive ERA5 discrepancy; it does not establish the exact barometer height.

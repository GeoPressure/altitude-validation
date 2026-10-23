# Ground-station manual review: batch 7

Author-facing review, 23 October 2026. Following batch 6, 49 of the 56 records in the union of the 40 largest SDs and 20 largest absolute biases had already been reviewed and retained. All seven new records were inspected across two time-series pages, with archive metadata and lag diagnostics. Three further source-393 timing mismatches are excluded; four stations with ambiguous or coherent variation are retained.

| Station | ID | Decision | Evidence |
|---|---|---|---|
| GRACIAS | HOI0000MHGS | Retain | Stable negative offset with sparse excursions; lag improvement is incomplete and based on far fewer matched reports, so a timing failure is not established. |
| HOVALING | TIM00038846 | Retain | Coherent weather-related variation at a mountain station; no clear recording fault. |
| ST PIERRE PIERREFONDS | REI0000FMEP | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.58 to 0.58 hPa at diagnostic lag 8 h, matching 8377 of 8394 reports. |
| SION | SZI0000LSGS | Retain | Broad weather-related variation in an Alpine valley, without a clear recording fault. |
| GRAND-BOURG LES BASSES AERO | GPU97112003 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.56 to 0.21 hPa at diagnostic lag -8 h, matching 7690 of 7732 reports. |
| KOUROU CSG | FGU97304003 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.92 to 0.32 hPa at diagnostic lag -7 h, matching 8026 of 8139 reports. |
| QAMDO | CHM00056137 | Retain | Coherent variation at a high mountain station; no clear recording fault. |

Evidence files use prefix `output/drafts/atmospheric-figures/era5_batch7_review`. Across batches 4-7, 75 additional stations were reviewed, with 38 excluded and 37 retained. The curation list now contains 75 identifiers including earlier reviews. No whole-source exclusion or empirical clock correction is applied.

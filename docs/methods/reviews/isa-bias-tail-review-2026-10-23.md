# Review of station biases above 150 m

The subsequent reference exclusions and further investigation are documented in [Reference curation and pressure-pattern review](reference-curation-review-2026-10-23.md). The counts and decisions below describe the sample before that curation.

Author-facing review, 23 October 2026. This investigation does not change station selection. Bias means the mean signed height error within the selected station year; the threshold is applied to its absolute value. The current sample contains 2,192 GHCNh stations. In the analysis tables, `isa` denotes the International Standard Atmosphere and `standard` denotes the standard lapse-rate conversion using ERA5 atmospheric inputs. Both interpretations of “standard atmosphere” were inspected.

## Record length

There are 47 stations with absolute ISA bias above 150 m and 17 with absolute ERA5 standard-lapse bias above 150 m. Their union contains 50 stations. Every selected record was inspected in pressure, ISA height error and ERA5 standard-lapse height error over the selected year.

The 47 ISA-tail records contain 1,375–8,455 retained reports, span 348.4–365.8 days from first to last report, and have at least 15 qualifying days in every monthly selection interval. A qualifying day has at least four retained hourly reports. They contain at least 315 distinct observed days. These are year-long records with substantial coverage, rather than short time series. The 17 ERA5-tail records similarly contain 1,412–8,362 reports and span 348.4–365.8 days, with at least 15 qualifying days per monthly interval.

## Large ISA bias does not establish a station fault

Of the 47 ISA-tail stations, 28 have absolute ERA5 standard-lapse bias below 25 m, and only 14 exceed 150 m with that conversion. Many are Antarctic stations with coherent pressure records. Examples are Vostok (ISA bias +428.8 m; ERA5 +9.1 m), Dome C II (+388.0 m; −9.5 m), and Mirny (+255.4 m; −0.7 m). This pattern is consistent with departure of the real atmosphere from ISA assumptions. It does not independently demonstrate incorrect station observations. Removing the full ISA tail would remove valid cases where the atmospheric conversion matters.

## Independent reference discrepancies

The raw report source identifiers were checked against external station inventories. The following four stations have independently documented discrepancies in the reference used for validation. These provide grounds for reference-based exclusion without an ERA5 error cutoff.

| GHCNh ID | Archive name and elevation | Independent metadata | ERA5 bias (m) |
| --- | --- | --- | ---: |
| CIM00085410 | Chorrillos, 3,200 m | Raw WMO 85410 identifies Azapa Alto, 838 m, at different coordinates in the Chilean meteorological service catalogue | −2,352.0 |
| CHM00059948 | Sanya, 7 m | CMA lists WMO 59948 at 419.4 m | +410.2 |
| CHI0000ZLYA | Yan An, 959 m | Raw WMO 53845 identifies Yanan, 1,180.4 m, in the CMA inventory | +219.4 |
| RPI0000RPUB | Baguio, 1,295.7 m | Raw WMO 98328 identifies Baguio, with barometer height 1,501 m in PAGASA metadata | +205.6 |

Sources: [Dirección Meteorológica de Chile: Azapa Alto](https://climatologia.meteochile.gob.cl/application/informacion/fichaDeEstacion/180047), [CMA station inventory](https://image.data.cma.cn/static/doc/A/A.0012.0001/SURF_CHN_MUL_HOR_STATION_EN.pdf), and [PAGASA: WMO 98328](https://wis.pagasa.dost.gov.ph/oapi/collections/stations/items/0-20000-0-98328?f=html). The CMA rows were checked against rendered PDF pages 2 and 5. For Baguio, the independent height difference is 205.3 m; for Yanan it is 221.4 m. Both closely match the observed persistent offsets. Heights from different inventories can refer to different surfaces or instruments, but these differences are substantially larger than ordinary instrument-height differences.

Four additional selected stations are explicitly labelled moving ice installations in the archive: NAU (GLU00000036), SWC (GLU00000052), KAN_L (GLU00000009), and DY2 (GLU00000003). The first three exceed the ISA threshold; all four exceed the ERA5 threshold. The existing fixed-reference exclusion rationale for moving ice installations should be applied consistently to these stations too. Their installation metadata provide the exclusion basis, independently of the numerical bias.

## Persistent offsets still requiring independent explanation

The remaining nine stations in the ERA5 tail are Limoncocha (ECM00084075, +2,183.0 m), Tehri (INM00042114, +1,123.9 m), Garmsar (IRM00040756, +1,054.8 m), Itanagar/Papumpare (INM00042308, −299.4 m), Leh (INI0000VILH, +337.4 m), Tarma (PEM00084614, −188.4 m), Kithira (GRI0000LGKC, −154.6 m), Sinan (CHM00057731, +156.5 m), and Xining (CHI0000ZLXN, +168.3 m). Their large offsets are persistent across long records; isolated pressure spikes and insufficient duration do not explain them.

Station relocation, incorrect station identity, reference elevation and pressure reporting convention are plausible explanations. However, the primary-source evidence reviewed here does not establish a complete independent explanation for these nine. Tehri is labelled New Tehri by IMD, but the accessible IMD station listing still gives 770 m, so a corrected elevation should not be asserted from the model alone. A secondary catalogue identifies WMO 40756 as Firuzkuh rather than Garmsar, but an authoritative historical source matching the selected record should be checked before treating that identity discrepancy as established. CMA lists Sinan at 416.8 m, close to the archive's 418 m, and Xining at 2,295.2 m versus the archive's 2,262 m; these elevation differences do not explain the full biases.

Visual inspection also finds faults below the ERA5 mean-bias threshold: a noisy terminal episode at Halvfarryggen and a roughly 60 m error step at La Quiaca. These show that the current pressure episode rules do not capture every problematic block or smaller sustained step. They do not justify excluding otherwise coherent polar records on ISA bias.

## Recommended curation

Exclude independently demonstrated reference conflicts and moving installations under the existing reference-validity criterion. Retain coherent stations whose large ISA errors disappear with ERA5. Resolve the nine unexplained persistent offsets through station identity and pressure-reference documentation; if they must be manually excluded without independent confirmation, describe that decision explicitly as outcome-informed curation. It would use the ERA5 validation result in selection and would therefore depart from the requested separation between filtering and ERA5 evaluation.

Smooth but incorrectly referenced pressure can pass spike, jump, noise and frozen-sensor tests. A terrain check can also pass when incorrect coordinates and an incorrect elevation describe the same wrong site. These cases require checking the identity and reference of the pressure measurement, rather than increasing the minimum record duration.

## Reproduce and inspect

Run `Rscript scripts/drafts/isa_bias_review.R` from the repository root. Outputs are in `output/drafts/isa-bias-review/`: `station_review.csv` contains all 50 station summaries, `monthly.csv` contains monthly medians, `report_metadata.csv` contains raw source identities and reported metadata, and `timeseries_01.png` through `timeseries_09.png` show the full selected records. `accepted_records.parquet` contains the plotted reports. No main selection table, exclusion list or analysis result was changed by this review.

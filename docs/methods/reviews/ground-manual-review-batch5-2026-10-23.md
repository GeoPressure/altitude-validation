# Ground-station manual review: batch 5

Author-facing review, 23 October 2026. Following batch 4 and the expanded pressure-only spike check, reviewed the 18 previously unreviewed records in the union of the 40 highest SDs and 20 largest absolute biases. Eleven are excluded and seven retained. All four time-series pages, raw metadata, monthly summaries and lag diagnostics were inspected.

| Station | ID | Decision | Evidence |
|---|---|---|---|
| DJELFA/TLETSI | AGI0000DAFI | Retain | Stable positive offset, without an independently established metadata conflict. |
| GOIANIA | BRM00086734 | Retain | Stable negative offset, without an independently established metadata conflict. |
| ANDJAR | SPU0005298X | Exclude | Successive sustained pressure-reference shifts: converted height near 195 m, then 130 m, then 110 m before returning near 195 m during 2023. |
| HUERCAL OVERA | SPM00008428 | Exclude | Abrupt sustained approximately 25 m shift coincident with the March/April 2026 source transition. |
| PUERTO CASADO | PAM00086086 | Retain | Broad scatter with individual excursions; no sufficiently clear recording fault. |
| PIRACICABA | BRM00086868 | Exclude | Terminal April 2026 pressure block shifts by about 40 hPa, implying heights near 200 m versus the usual 570 m. |
| LE PORT | REU97407520 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.51 to 0.38 hPa at lag 8 h, matching 8400 of 8408 reports. |
| ST-MARTIN GRAND-CASE | RNU97127004 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.48 to 0.24 hPa at lag -8 h, matching 8376 of 8398 reports. |
| LA DESIRADE | GPM00078890 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.53 to 0.22 hPa at lag -8 h, matching 8373 of 8390 reports. |
| PESHKOPI | ALM00013619 | Retain | Broad scatter with several excursions; no sufficiently clear recording fault. |
| PAULISTANA | BRM00081950 | Exclude | Terminal April 2026 gross pressure block contains reports near 1040 hPa, compared with the usual 970 hPa, implying physically implausible reference shifts. |
| BARRETOS | BRM00086816 | Exclude | Terminal April 2026 pressure block shifts by about 10 hPa, producing sustained approximately 100 m height displacement. |
| MANIHIKI (HUMPHREY ISLAND) | CWI0000NCMH | Retain | A 3-hour lag reduces residual SD, but improvement is less complete than the source-393 pattern; a timestamp error is not established. |
| EUROPA | FSU98403003 | Exclude | Strong source-393 temporal-misalignment signal: pressure residual SD 1.50 to 0.24 hPa at lag 6 h, matching 8399 of 8406 reports. |
| JUBILEJNAJA | RSM00021931 | Retain | Weather-scale scatter and sparse excursions; no sufficiently clear recording fault. |
| ROCHAMBEAU | FGI0000SOCA | Exclude | Source-specific temporal mismatch: source 393 residual SD 2.02 to 0.27 hPa at lag -6 h; subsequent source 223 already has 0.30 hPa SD at zero lag and worsens at -6 h. |
| MACQUARIE ISLAND | ASM00094998 | Retain | Large terminal discrepancy, but raw pressure evolves coherently near 982 hPa during a short episode; genuine storm/representation discrepancy cannot be ruled out. |
| SAO LUIZ GONZAGA | BRM00086961 | Exclude | Isolated 870.4 hPa report on 2026-04-04 after a long gap, versus 985-987 hPa before the gap; implies 1310 m at a 246 m site. |

Evidence files use prefix `output/drafts/atmospheric-figures/era5_batch5_review`. Source-specific lag diagnostics distinguish the early source-393 segment at Rochambeau from the later correctly aligned source-223 segment. Raw source-393 dates were checked as literal archive timestamps parsed in UTC; no local-time transformation is applied by the analysis. Timing comparisons remain diagnostic evidence, not independently verified corrections, and no shifts are applied.

Macquarie illustrates a retained ambiguity: its terminal hourly pressure sequence around 982 hPa implies heights up to 301 m despite a listed elevation of 8 m. The raw pressure sequence is coherent rather than an isolated gross spike, so the ERA5 disagreement alone does not establish a faulty station.

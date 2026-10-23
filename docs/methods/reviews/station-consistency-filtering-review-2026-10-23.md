# Review of ground-station filtering and proposed station-consistency checks

Author-facing review, 23 October 2026. It covers the active selection in `scripts/sampling/ground_selection.R` and the note `pressure-pattern-application-2026-10-23.md`. The proposed checks use only GHCNh fields. ERA5 is joined afterwards and used only to evaluate them. The prototype is `scripts/drafts/station_consistency_screen.R`, and its outputs are in `output/drafts/station-consistency/`.

## Diagnosis: the residual tail is mostly offsets, not noisy time series

In the current 2,179-station sample, 175 stations have absolute mean ERA5 error above 20 m, 35 above 50 m and 9 above 100 m. Of the 175 above 20 m, 148 have error SD below 10 m. These are smooth, coherent pressure records sitting at the wrong level. Every active rule (spikes, jumps, reversals, sustained irregularity, persistent steps, frozen runs and coverage) looks at the shape of the pressure series, so none of them can detect a constant offset. This is why the pattern application changed the 95th percentile only from 29.17 to 29.06 m. Shape-based filtering has reached its limit, and further tuning of those rules will not reach the 20–50 m standard.

The two independent checks that could detect offsets are both weak in their current form:
- The terrain check accepts any elevation within 50 m of the min–max range of a 1 km DEM neighbourhood. In hilly terrain, this range is often hundreds of metres wide.
- The ISA departure cannot be used. Real climate puts 26 of the 34 stations above 150 m ISA error within 25 m of ERA5.

## Key resource: GHCNh already carries each station's own reference height

Each GHCNh record also reports sea-level pressure (SLP) and, at most airports, an altimeter setting (QNH). The station computes both from its station pressure and the barometer height it actually uses. Inverting them therefore recovers that height without any reanalysis:
- **Altimeter:** the NWS/ICAO formula is fixed, so the inversion is exact. ASOS stations have a per-report IQR of about 0.5 m.
- **SLP:** the inversion uses the reported station temperature and the standard lapse rate. National reduction conventions add some uncertainty, and that uncertainty grows with elevation.

If the archive elevation differs from this implied height, the reported pressure is not the pressure at the archive elevation. This is exactly the error that produces a persistent altitude bias.

The agreement with the independent ERA5 bias is close: Sinan 159 vs 157 m, Kithira −154 vs −155 m, Sayak −127 vs −130 m, Lindong 105 vs 102 m, Cabo Lurecia 99 vs 97 m, Bam 123 (altimeter) vs 136 m, and Xining 189 vs 168 m. The four persistent-offset cases discussed in the pattern-application note therefore do have a reason for rejection that comes only from the station's own reports.

## Proposed additional acceptance criteria

All four checks are computed within the candidate year. A failure triggers the existing backwards-year search and then replacement within the cell.

| Check | Pressure-only quantity | Proposed rule | Rationale for the threshold |
|---|---|---|---|
| A. Reference-height consistency | Median implied height minus archive elevation; use the altimeter when ≥500 reports exist, otherwise SLP | Reject if \|offset\| > 20 m (altimeter) or > 20 m + 2 % of elevation (SLP) | 20 m ≈ 2.4 hPa. The median \|SLP offset\| is 2 m. The elevation term allows for differences in national SLP-reduction temperature conventions. SLP is only used when it is plausible: \|offset\| < 500 m and the per-report IQR is below the tolerance. |
| B. Reference stability | Largest change between consecutive monthly medians of SLP-implied height | Reject if > 30 m, only for stations below 500 m | A change in the barometer reference or the reporting convention moves station pressure and SLP apart. The rule is restricted to stations below 500 m because US plateau-correction stations show seasonal 15–35 m changes. |
| C. Timestamp consistency | Phase of the semi-diurnal (S2) pressure tide in local solar time | Reject if \|lag\| > 1.5 h where the S2 amplitude is > 0.5 hPa | The global S2 peak falls at about 09:47 local solar time. Among stations with a strong tide, the 95th percentile of the lag is 0.6 h. A lag of 3–6 h indicates timestamps that are not in UTC. |
| D. Gross level | Mean standard-atmosphere height error | Reject if > 500 m | The largest value in the sample caused by climate alone is 429 m, at Vostok. |

### Evaluation against ERA5 on the current selected years

These counts drop flagged stations and do not yet include their replacements.

| Set | Stations | \|bias\| > 20 m | > 50 m | > 100 m | SD > 20 m | 95th pct \|bias\| (m) | Clean stations removed |
|---|---:|---:|---:|---:|---:|---:|---:|
| Current | 2,179 | 175 | 35 | 9 | 31 | 26.6 | — |
| Kept after A–D | 2,030 | 75 | 10 | 1 | 19 | 17.4 | — |
| Flagged | 149 | 100 | 25 | 8 | 12 | 100.0 | 12 |
| Kept, verifiable by A | 1,750 | 44 | 2 | 0 | 12 | 15.5 | — |
| Kept, not verifiable by A | 280 | 31 | 8 | 1 | 7 | 38.0 | — |

"Clean" means \|ERA5 bias\| < 10 m and SD < 10 m. 137 of the 149 flagged stations are not clean.

Each check catches distinct stations:
- **A** flags 111 stations.
- **B** flags 13, mostly the Brazilian INMET reference changes: Barcelos, Valença do Piauí, Curaçá, Itaituba, Buriticupu and Dourados.
- **C** flags 28. These are the Météo-France overseas stations (Europa, Juan de Nova, Glorieuses, Mayotte, Tromelin, Martinique, Guadeloupe, Saint-Martin, Réunion), French Polynesia and the Cook Islands. Their ERA5 SD is 11–19 m, and the lag is consistent with records in local time.
- **D** flags only Limoncocha (+2,183 m).

## Recommendation

1. **Add checks A, C and D to the main accept/reject path.** They are physically motivated, use no ERA5 information, and remove 23 of the 35 stations with bias above 50 m at the cost of about 12 clean stations.
2. **Require verifiability (recommended, at the cost of sample size).** After A–D, 8 of the 10 remaining stations with bias above 50 m are among the 280 stations whose height cannot be checked (no altimeter and no usable SLP). The verifiable subset has a 95th percentile of 15.5 m, against 38.0 m for the unverifiable subset. Making "reference height can be checked" an acceptance criterion is the single most effective step towards a reliable sample. With a median of two candidates per cell, many of these cells would stay empty. The sample would fall to roughly 1,750–1,900 stations, depending on replacements.
3. **Adopt B, or the pressure-only gap-step test from the pattern-application note.** Both target the Brazilian reference changes. Check B is simpler, but it does not catch Caxias and Chapadinha, where SLP shifts together with station pressure. The gap-step test does catch them. Use one of the two rather than both, unless the rerun shows that each still contributes.
4. **Freeze the thresholds before rerunning.** The thresholds above follow from the distributions of the diagnostics themselves: the altimeter/SLP precision, the global S2 phase and the ISA climate range. They were inspected alongside the ERA5 numbers in this exploration, so fix them now and report the ERA5 statistics only after the full rerun, including replacements.

## Remaining cases not caught

These remaining cases are acknowledged as limitations:
- **High Tibetan-plateau stations** (Ruo'ergai, Litang, Dawu, Jiulong): the SLP spread is too wide for a reliable implied height. Requirement 2 would exclude them.
- **Unverifiable stations** (Qairoon Hairiti, Shillong, Worcester, Frankfort, Drosh): no altimeter or plausible SLP.
- **Buzaubaj:** the SLP is consistent with a faulty sensor.
- **Kerguelen, Crozet and Nouvelle Amsterdam:** S2 lags of −2 to −5 h suggest the same timestamp problem as the other French overseas stations, but the tide is too weak at 37–49° S for a reliable test.

## Comments on `pressure-pattern-application-2026-10-23.md`

- The residual review uses thresholds of 150 m mean bias or 20 m SD and covers 34 stations. Under the 20/50 m standard, the tail is 175/35 stations, and most of it is low-SD offsets that this note does not address.
- The statement that a large ERA5 bias "does not itself establish a pressure-only rejection reason" is correct for the station-pressure series alone. Check A provides such a reason from the station's own SLP/altimeter reports for Xining, Sinan and Kithira. Limoncocha is caught by check D.
- The "recurring error scatter at the French Southern Islands stations" is explained by check C as a timestamp problem, not as sensor noise.
- The gap-step experiment is sound and complementary to check B (see recommendation 3).

## Code notes

- `ghcnh_window`, `ghcnh_step` and `ghcnh_cell` in `R/ghcnh_sampling.R` still contain ERA5-based outlier, offset and step rejection. The primary path in `ground_selection.R` does not call them, but `sample_ghcnh.R`, `selection_sensitivity.R` and several drafts do. Remove them or move them into the drafts so that the active method cannot accidentally use ERA5.
- `ghcnh_pressure` keeps only station-pressure columns. Implementing checks A–C requires also reading `sea_level_pressure`, `altimeter`, `temperature` and their quality codes, applying the same archive-QC exclusions to each.
- One reference exclusion is based on "External metadata documentation and manual review". Confirm that the manual review was not prompted by an ERA5 diagnostic.

## Applied result (checks A, C, D and verifiability)

The main selection now applies checks A, C and D and the verifiability requirement (`R/ghcnh_consistency.R`, `scripts/sampling/ground_selection.R`). Check B and the gap-step test are not applied. The thresholds are frozen in `consistency_rules`. The reference-height check is applied to the candidate year and to the full 2022–2026 record. Without the full-record test, the backwards search could slide to a year whose median offset was just inside the tolerance. After a failed consistency check, the search moves back four weeks before checking again. Selection runs in parallel by cell without ERA5. ERA5 series are fetched afterwards for accepted stations. The selection stage takes about 6 minutes.

Candidate outcomes (each candidate's first failing reason):

| Outcome | Candidates |
|---|---:|
| Accepted | 1,907 |
| No qualifying pressure-series year | 2,830 |
| No usable height reference (unverifiable) | 474 |
| Reference-height conflict | 155 |
| Timestamp (tide phase) | 25 |
| Gross level | 1 |

There are 1,907 accepted stations (623 checked with the altimeter, 1,284 with SLP). Compared with the previous sample, 394 stations were removed and 122 new stations entered as replacements.

ERA5 evaluation (standard-lapse conversion, station level), computed after selection:

| | Stations | \|bias\| > 10 m | > 20 m | > 50 m | > 100 m | SD > 20 m | Median \|bias\| | 95th pct \|bias\| | 99th pct \|bias\| |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Previous | 2,179 | 381 | 175 | 35 | 9 | 31 | 3.23 | 26.6 | 71.8 |
| Current | 1,907 | 235 | 62 | 5 | 0 | 26 | 3.10 | 16.4 | 28.9 |
| New replacements only | 122 | 20 | 6 | 1 | 0 | 3 | 3.89 | 19.0 | 28.6 |

For the hourly standard-lapse conversion, MAE falls from 9.34 to 6.12 m and RMSE falls from 49.8 to 11.0 m. The median within-station SD is unchanged (3.41 to 3.38 m).

Five stations remain above 50 m: Barcelos, Buzaubaj, Jiulong, Valença do Piauí and Xifengzhen. Barcelos, Valença do Piauí and most of the stations that remain above 20 m SD are Brazilian INMET reference changes, which check B or the gap-step test would target. The other high-SD stations are Kerguelen, Crozet and Nouvelle Amsterdam, where the tide test lacks power.

## Visual review of the worst stations and final rules

The 48 selected stations with the largest combined ERA5 error (√(bias² + SD²)) were plotted (`scripts/drafts/worst_station_review.R`) against the daily implied reference height. Inspecting them led to four revisions:

1. **Monthly reference check.** Steps of the SLP-implied height within the year were hidden by the annual median. These included the INMET source-412 jumps after April 2026, Jarud Qi, Mengla, Wu Lu Mu Qi, Mthatha and San Pedro. Each of the 12 month-long intervals now needs ≥100 reference reports and a median within tolerance. This also rejects years with months lacking any reference (Caxias, Kitale).
2. **Tighter tolerance.** 15 m (altimeter) and 15 m + 1% of elevation (SLP), against 20 m + 2% before. Constant 25–45 m offsets mirrored by the implied height had passed the looser tolerance (Mohabad, SANAE, Jalapa, Querétaro, Caçapava).
3. **Daily excursions and persistent full-record conflicts.** A year fails if any day's median implied height departs by more than 3× the tolerance (short INMET jumps, Qu Xian, Tengchong). A station fails if its implied height is out of tolerance for ≥12 consecutive calendar months anywhere in 2022–2026. Examples are the INMET stations whose SLP later reveals a station-pressure offset: Goiânia, Querência, São Romão, Varginha, Castanhal and Valença. The April 2026 jumps last ≤7 months and are not caught by this rule. A trial on cached data (`scripts/drafts/consistency_rule_trial.R`) found the 12-month rule removes 28 clean-looking stations, against 99 for a 2-month run.
4. **Manual exclusions** (`docs/methods/ghcnh_review_exclusions.csv`, 18 stations). These have record defects that station self-consistency cannot reveal:
   - drift (Buzaubaj, San Ramón);
   - 1–5 hPa steps shared by the SLP (Boone, Pongola, Serui, Cuyo, Río Grande, Anguilla, Turkmenbashi);
   - alternating levels (Honavar, Apodi, Ekezhe);
   - irregular multi-day departures (Kerguelen, Crozet, Nouvelle Amsterdam, Druzba, Doi Ang Khang, Abamusa Island).

   These were identified with ERA5, which the supplement states.

Candidate outcomes in the final selection were:

| Outcome | Candidates |
|---|---:|
| Accepted | 1,794 |
| Pressure series | 2,980 |
| Unverifiable | 583 |
| Reference height | 287 |
| Timestamp | 21 |
| Gross level | 1 |

| | Stations | \|bias\| > 10 m | > 20 m | > 30 m | > 50 m | SD > 10 m | SD > 20 m | Median \|bias\| | 95th pct | 99th pct |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Before this review | 2,179 | 381 | 175 | 90 | 35 | 129 | 31 | 3.23 | 26.6 | 71.8 |
| Final | 1,794 | 148 | 18 | 3 | 1 | 33 | 0 | 2.88 | 12.3 | 19.8 |

Compared with the sample before this review, 567 stations left and 182 replacements entered. Hourly standard-lapse MAE falls from 9.34 to 5.17 m and RMSE from 49.8 to 7.5 m.

In the final round, all 48 worst stations passed visual inspection. No record shows steps, drift, level switching or noise episodes. The remaining large departures are of two kinds:
- **Constant offsets with a station-consistent SLP:** Pachuca −69 m, Jalo −33 m, Yampi Sound −29 m, Pium +24 m and several INMET stations near ±20 m.
- **Smooth, weather- or season-linked variation:** in continental basins and mountain valleys (Bishkek, Almaty, Guba, Turpan, Mayrhofen, Granite Peak).

Neither shows a defect in the station data, so both are retained as part of what the ERA5 comparison measures.

## IGRA sounding selection

The previous IGRA selection removed levels whose ERA5-standard error was an outlier within their station and height band. This used ERA5 in selection, although it removed almost nothing: median 0% of levels and at most 0.27%. It is replaced by an ERA5-free consistency check of each sounding (`igra_consistency` in `R/igra_sampling.R`). A sonde's reported geopotential heights derive from its own pressure and temperature, so the reported height gain above the launch surface must match the hypsometric gain of its temperature profile (`sonde_mean_temperature` in `R/utils.R`, shared with `errors.R`).

Across previously accepted levels, the mismatch has a median of +8 m, consistent with the omitted humidity correction, and a 99th percentile of 46 m. The rules are as follows:
- A sounding is consistent if every level agrees within 30 m + 3% of its height above the surface.
- Soundings without at least two temperatures are unverifiable and are not used.
- Coverage counts only consistent soundings.
- A year fails if more than 10% of its checked soundings are inconsistent.

At this tolerance, 2.1% of soundings are flagged. Station-level inconsistency is strongly bimodal: the faulty stations are 87–100% inconsistent, and their median mismatch mirrors their ERA5 bias (Naze 299 vs −295 m, Yuma −92 vs +94 m, Lumbia −92 vs +92 m, Mogocha 77 vs −110 m, New Delhi 70 vs −85 m). The selection now runs in parallel by cell in `scripts/sampling/sounding_selection.R`, and ERA5 is matched only for accepted stations.

The result is 629 stations, compared with 643. Fourteen stations failed consistency and were not replaced, because their cells had no other candidate; 185 candidates had too few soundings. Visual review of the 48 stations with the largest 1–3 km ERA5 errors (`scripts/drafts/worst_sounding_review.R`) showed no record defects. All are Arctic, Siberian, Alaskan, Antarctic-plateau or continental winter-inversion sites (and Upington, with a winter nocturnal inversion). Their ERA5 errors are large and negative in winter and near zero in summer, while their hypsometric mismatch stays small and stable. These errors are the physical signal the study measures, so no manual IGRA exclusions are needed.

The selection-flow figures (S1a, S1b) were replaced by a table of candidate outcomes for both networks (`tbl-selection`, from `ground_selection_outcomes.csv` and `sounding_selection_outcomes.csv`).

## Simplification of the GHCNh checks (2026-10-23)

The supplement had accumulated many thresholds. `scripts/drafts/check_contribution.R` reran the selection on cached data with each check disabled (results in `output/drafts/check-contribution/`). With the reference-height checks in place, persistent steps, rapid oscillations, frozen pressure and the gross-level check decided no selected station; sustained noise decided one (Campos Sales, SD 31 m) and large jumps three.

A first simplified run also dropped the daily implied-height rule. That leave-one-out comparison had only tracked which station a cell selected, not which year: without the daily rule, 15 selected stations moved to a year containing whole days with station pressure offset by 15–40 hPa (implied heights off by 100–1,200 m), raising their ERA5 SD to 25–54 m (mostly Brazilian INMET stations). The daily rule was restored.

Final GHCNh rules: archive QC, spike removal, coverage, large jumps, implied height (monthly, daily, full record, verifiability) and the tide timestamp test. Removed: persistent steps, rapid oscillations, sustained noise, frozen pressure and the gross-level check. Campos Sales was added to the visual-review exclusions (19 in total). The sample remains 1,794 stations; 21 keep a different year than before, with no change in the counts of |bias| above 20, 30 or 50 m. The candidate-outcome table was replaced by counts in the supplement text and the visual-review exclusions are listed in a table with their defects.

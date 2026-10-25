# Station selection and curation history (author notes, condensed)

Originals: git tag `pre-cleanup`, mainly `docs/methods/reviews/*.md` (dated 22–23 Oct), `archive/docs/methods/ghcnh-sampling-review/*.md`, `archive/docs/methods/igra-sampling-review/*.md`, `docs/methods/T06/recommendations.md`, and the exploratory scripts in `archive/exploratory-scripts/curation-2026-10/` (outputs were in untracked `output/drafts/`). Final rules: `manuscript/supplement.qmd` S1, `R/ghcnh_*.R`, `R/igra_sampling.R`, `analysis/02_select_ground.R`, `analysis/03_select_soundings.R`.

## Guiding principles (agreed during the process)

- One selection path with accept/reject criteria. No diagnostic tagging, parallel "flagged" samples or sensitivity-only exclusions.
- Select on recency and coverage, never on the smallest ERA5 discrepancy. After 23 Oct, **ERA5 is not used in any automatic accept/reject decision**; it is joined after selection and used only to evaluate.
- A rejected year triggers the backwards window search; a station with no qualifying window is replaced by the next candidate in its cell, in a frozen random order. A technical download failure leaves the candidate pending and is never a scientific rejection.
- Freeze thresholds before looking at final ERA5 statistics. Do not tune thresholds to make the error smaller.

## GHCNh design timeline

| Date | Design | Stations | Outcome / reason for change |
|---|---|---:|---|
| ≤18 Oct | HadISD, calendar years 2022–2024, 2° cells + all >1000 m stations, ERA5-residual station screen (offset > 30 m + 0.10·\|station−ERA5 elevation gap\|; step ≥10 m with \|t\| ≥10; >1% gross obs (>max(100 m, 10 MAD)); noise) | 2,502 | T06: unscreened 2,646 st. ERA5 MAE 11.66 m vs screened 6.07 m; p95 33.6 vs 20.5 m. Offset flags (106) drive almost all of it; step/noise alone barely matter. Strict/loose screens 5.30/7.12 m. Median station \|bias\| stable (2.75 vs 2.55 m). Screened results are conditional on an ERA5-based selection. |
| 19 Oct | GHCNh on the HadISD footprint (25 km match), latest year 2022–2026 with ≥183 days and ≥4 distinct hours/day, same ERA5 screen, step test with up to 2 preceding years | 5,202 coverage-qualified → 2,146 thinned → 1,983 screened | Completed-year sensitivity (1,912 stations): MAE 6.48 (latest year) vs 6.37 m (latest completed year) → recency rule kept. Selected years: 1,327 in 2026, 404 in 2025, 177 in 2024. |
| 20 Oct | **Rolling-window direct-inventory sampler**: 200 × 200 km Equal Earth cells (EPSG:8857, origin 0,0), candidate order randomised with seed 11, domain 2022-01-01 to 2026-10-13 (exclusive), daily backwards 12-month window, ≥15 days with ≥4 hours in each of 12 month-blocks; ERA5-based gross (100 m & 10 MAD), offset (30 m + 10%) and step (≥10 m, \|t\| ≥10, ≥3 monthly medians each side; insufficient history rejects) | 2,130 (2,962 cells, 5,318 candidates) | Pilot 64 cells: 140 candidates, 53 accepted; serial replay identical. Full run ~4.7 GiB. Hourly report rule changed from v1 "first report in hour" to v2 "report closest to the hour, earlier wins ties" (v1 caches in `selection-2026-10-13-first-report-v1/`). |
| 22 Oct | Pressure-only histogram selection + SRTM/ASTER terrain check + isolated-spike removal + manual ERA5-guided curation (batches 1–7) | ~2,055 | Curation list grew to 75 IDs (`docs/methods/ghcnh_curation_exclusions.csv`), all reviewed because of ERA5 tails. |
| 23 Oct | **ERA5-free selection**: spike removal, large jumps, repeated rapid noise, frozen pressure; historical ERA5-guided exclusions no longer applied | 2,192 | Medians barely changed (station \|bias\| 3.10 → 3.27 m) but station-weighted p95 rose 24.5 → 31.4 m. 57 previously curated IDs re-entered. |
| 23 Oct | Reference curation (documented conflicts + moving ice stations) | 2,179 | 13 cells lost; ISA tail kept. |
| 23 Oct | Pressure-pattern checks added (sustained irregularity, small persistent step) | 2,179 | 19 station-years moved back; p95 29.17 → 29.06 m only. Shape-based rules cannot detect constant offsets. |
| 23 Oct | **Station self-consistency** (implied height, tide timing, verifiability) | 1,907 → **1,794** | See below. Final. |

### Criterion evidence behind the 20 Oct sampler (cached-data assessment)

- Coverage: 15 dates × 4 h per month kept 2,014 stations (10 dates: 2,046; 25 dates: 1,919; 15 × 8 h: 1,736). Medians of station errors varied only 3.88–4.08 m across settings.
- Cell size: 200 km gave 2,563 occupied cells from cached candidates (47% with one candidate); 100 km 4,628, 300 km 1,601. Full inventory: 18,469 candidates in 2,962 cells.
- Offset rule rejected 74 of 2,014 (15 m + 5%: 169; 60 m + 20%: 26). Supporting basis: flat stations within 30 m of ERA5 elevation have p95 \|bias\| 16.2 m.
- Step test: 3 vs 6 monthly medians per side added 5 detections and moved the latest testable breakpoint from 176 to 84 days before the endpoint.
- Selection sensitivity of that design (S5 at the time, `paper_selection_sensitivity.csv`): same 2,130 cells, primary vs coverage-only, ERA5 median abs error 4.12 vs 4.22 m, p95 23.4 vs 27.4 m. **This table predates the final selection and is stale.**

## Final GHCNh rules and how each arose

| Rule (final) | Origin and evidence |
|---|---|
| Terrain check: reported elevation within 50 m of the SRTM (ASTER fallback) range within 500 m; no-DEM stations rejected (330 candidates) | Added 22 Oct. Weak in hilly terrain (wide range); cannot catch a wrong site whose coordinates and elevation are both wrong. |
| Documented reference exclusions (`data/curated/ghcnh_reference_exclusions.csv`, 59 candidates) | 39 moving ice installations (archive metadata; e.g. TAS_A, NUK_U, NAU, SWC, KAN_L, DY2) and 20 external metadata conflicts found by checking raw WMO/ICAO identifiers against national inventories: Kastamonu, Naze/Funchatoge (radar site), Karabük, Romblon, Khoy, Kokand, Campos do Jordão, Jaén (5270 vs 5270B), Chorrillos/Azapa Alto (−2,352 m bias), Sanya, Yan An, Baguio, Tehri, Leh, Itanagar, Tarma, Garmsar/Firuzkuh, Qom, Kashan, Ulsan. Rule: exclude only when independent documentation contradicts location/elevation/identity; never correct heights from ERA5. **Caveat:** Ulsan's basis says "and manual review"; it was found in ERA5-tail batch 3. |
| Archive QC + 300–1100 hPa; nearest-hour report | See `data-sources.md` for code meanings. |
| Isolated spikes removed (>5 hPa from both neighbours within 3 h that agree within 2 hPa; sparse variant >10 hPa, neighbours within 12 h agreeing within 3 hPa, departure and return >2 hPa/h) | 3 h rule (22 Oct) removed 1,166 reports from 413 stations but missed gross reports with distant neighbours (Talas, Furancungo, Berberati) → 12 h variant; the rate condition was added to protect slow coherent changes. Still misses reports after very long gaps (Gighbub 18 h, Damascus, Kashi, Qu Xian, Tengchong). |
| Coverage: ≥15 days with ≥4 hours in each month of the 12-month window | 20 Oct assessment above. |
| Large jumps: >20 hPa within 3 h or >50 hPa within 7 days (9 candidates) | Inherited from the calendar-year pipeline. In the leave-one-out run it decided 3 selected stations. |
| **Implied reference height**: invert altimeter setting (exact; ASOS IQR ~0.5 m) or SLP (station temperature + 6.5 K/km) to the barometer height the station itself uses. Tolerance 15 m (altimeter) / 15 m + 1% of elevation (SLP). Must hold for every month (≥100 reports per month), every day within 3× tolerance, over the full 2022–2026 record, and in no run of ≥12 consecutive months outside tolerance. Unverifiable stations rejected (585 candidates); conflicts rejected (231). | Key insight of 23 Oct: 148 of 175 stations with \|bias\| >20 m had SD <10 m, i.e. smooth series at the wrong level. Implied heights matched ERA5 biases closely (Sinan 159 vs 157 m, Kithira −154 vs −155, Sayak −127 vs −130, Xining 189 vs 168). First version (20 m / 20 m + 2%, annual median) → 1,907 stations. Visual review of the 48 worst stations then added the monthly check (INMET April 2026 jumps, Jarud Qi, Mengla…), the tighter tolerance (25–45 m offsets at Mohabad, SANAE, Jalapa, Querétaro, Caçapava), the daily check, and the 12-month full-record rule (the 2-month alternative removed 99 clean-looking stations vs 28). Verifiable stations had p95 \|bias\| 15.5 m vs 38.0 m for unverifiable ones, so verifiability was made mandatory at the cost of sample size. |
| **Timestamp check**: semi-diurnal tide amplitude >0.5 hPa and phase >1.5 h from 09:48 local solar time → reject (21 candidates) | Global S2 peak ≈09:47 LST; 95th percentile lag 0.6 h among strong-tide stations. Catches the Météo-France overseas / French Polynesia / Cook Islands source-393 records, which ERA5 lag sweeps had shown shifted 6–10 h (−19/−20 h in Polynesia). Too weak at 37–49° S (Kerguelen, Crozet, Nouvelle Amsterdam → manual exclusions). No time shift is ever applied. |
| Visual-review exclusions (`data/curated/ghcnh_review_exclusions.csv`, 19 stations) | Defects that self-consistency cannot see (SLP shifts with station pressure): drift (Buzaubaj, San Ramón), 1–5 hPa steps (Boone, Pongola, Serui, Cuyo, Río Grande, Anguilla, Turkmenbashi), alternating levels (Honavar, Apodi, Ekezhe), irregular multi-day departures (Kerguelen, Crozet, Nouvelle Amsterdam, Druzba, Doi Ang Khang, Abamusa Island), plus Campos Sales. Identified with ERA5 plots; the supplement says so. |

**Final candidate outcomes** (`output/tables/ground_selection_outcomes.csv`): accepted 1,794; coverage 3,025; unverifiable 585; terrain 330; reference height 231; reference exclusion 59; timestamp 21; review exclusion 19; jump 9.

**Final ERA5 evaluation** (standard lapse, vs the 2,179 sample before the consistency review): stations with \|bias\| >20 m 175 → 18, >50 m 35 → 1; SD >20 m 31 → 0; station p95 \|bias\| 26.6 → 12.3 m; hourly MAE 9.34 → 5.17 m, RMSE 49.8 → 7.5 m; median within-station SD unchanged (~3.4 m). 567 stations left, 182 replacements entered. Remaining large offsets have station-consistent SLP (Pachuca −69 m, Jalo −33, Yampi Sound −29, Pium +24) or smooth weather-linked variation in basins/valleys (Bishkek, Almaty, Guba, Turpan, Mayrhofen, Granite Peak); both retained as genuine conversion error.

## Checks tested and dropped

| Check | Result | Decision |
|---|---|---|
| ERA5-residual offset/step/gross screens (`ghcnh_window`, `ghcnh_step`, `ghcnh_cell`) | Effective but select on the evaluated quantity. | Removed from the active path 23 Oct. The review asked that this code be deleted or moved out of active R files so it cannot be reused by accident. |
| Repeated rapid noise (≥6 reversals of >2 hPa and >2 hPa/h in 24 h), frozen pressure (≥24 equal reports over ≥48 h), sustained irregularity (14-day blocks, p90 ≥1.5 hPa/h and 4× history), small persistent step (≥4 hPa, 4-week stability), gross level (standard-atmosphere error >500 m; Vostok max climate value 429 m) | Each changed some selections before the consistency checks (jumps 183, sustained irregularity 18, reversals 8, frozen 2, step 1 candidates). After the implied-height check, a leave-one-out rerun (`check_contribution.R`) showed they decided no selected station (sustained noise decided only Campos Sales, which was then excluded manually). | All dropped 23 Oct for simplicity. Frozen sensors found in review: Tsampa (653.5 hPa for 7 weeks), Secretary Island. |
| Dropping the daily implied-height rule | Leave-one-out tracked only the selected station, not the year: without it, 15 stations slid to years with whole days offset by 15–40 hPa (SD 25–54 m). | Daily rule restored. |
| Check B: monthly stability of SLP-implied height (>30 m, stations <500 m) | Caught Brazilian INMET reference changes but not Caxias/Chapadinha. US plateau-correction stations show 15–35 m seasonal swings. | Not adopted; monthly/daily rules cover the cases. |
| Gap-step test (≥10 hPa across 1–7 day gaps, 4-week stability) | Found 11 transitions at 10 Brazilian stations; the looser version also flagged weather changes. | Experiment only. |
| ISA bias as fault criterion | Of 47 stations with \|ISA bias\| >150 m, 28 had \|ERA5 bias\| <25 m (Vostok +429 vs +9 m; Dome C II; Mirny). | Rejected: removes genuine atmospheric cases. |
| Blanket QC code 4 or source-based exclusion | Code meaning is source-dependent; reviewed failures carried good/missing flags. | Rejected. |
| Longer minimum record length | ISA/ERA5 tail stations already had full-year records (≥1,375 reports, ≥348 days). | Rejected; offsets need identity/reference checks, not more data. |
| Empirical timestamp correction from ERA5 lag | Lags were diagnostic only. | Never applied. |
| Antarctic pressure-anomaly tail (33 stations below −15 hPa vs ISA) | Recomputed exactly; real low regional pressures and non-standard columns. | Kept. |

## Manual review record (22–23 Oct)

Batches covered the union of the 20–40 largest SDs and 10–20 largest absolute biases after each rebuild: ERA5 tail (11 stations, SD >30 m or bias < −100 m), ten largest biases (online metadata search), batch 3 (29 reviewed, 10 excluded), 4 (38/17), 5 (18/11), 6 (12/7), 7 (7/3). Typical exclusion causes: source-393 timing, INMET April 2026 terminal blocks (source 412), isolated gross 2026-08-04 12 UTC reports, reference steps (Stigler, Cuyo, Huércal-Overa, Andújar), reporting-hour-dependent levels (Mataveri, Krabi), frozen values, documented metadata conflicts. Retained-with-reason examples: Alpine Casparis (NOAA confirms elevation), Víznar (EMEP lists 1,258 m), Macquarie (coherent storm), Drosh, Issyk. The 75-ID list from these batches was superseded by the rules above plus the two curated lists in `data/curated/`.

## IGRA2 selection timeline

| Date | Design | Stations | Notes |
|---|---|---:|---|
| ≤20 Oct | 2023–2024, ≥100 soundings, levels ≥400 hPa only, 2° cells + >1000 m, pooled height-band gross rule (>150 m & 10 MAD of ERA5-standard error) | 648 | All 648 in distinct 2° cells, so cell = station weighting (T06). |
| 20 Oct | Rolling window, same grid/seed/cutoff as GHCNh; ≥15 launch dates with an accepted airborne level per month; candidate-local (station × band) gross rule; full pressure range to 6 km | 643 (801 cells, 828 candidates; ~19.3 GiB ZIP traffic) | Candidate-local vs pooled gross rule removed 639 vs 4,398 levels. Cached 2023–2024 counts: 5/10/15 launch dates per month → 603/585/546 stations. Pilot 16 cells: 15 accepted. |
| 23 Oct | ERA5 gross rule (removed median 0%, max 0.27% of levels) replaced by **hypsometric consistency**: recomputed height gain from the sonde's own log-p mean temperature must match reported geopotential gain within 30 m + 3% at every level; <2 temperatures → unusable; year fails if >10% of checked soundings inconsistent | **629** (185 coverage, 14 consistency, not replaceable) | Mismatch median +8 m (omitted humidity), p99 46 m; 2.1% of soundings flagged. Faulty stations are 87–100% inconsistent and their mismatch mirrors ERA5 bias (Naze 299 vs −295 m, Yuma, Lumbia, Mogocha, New Delhi). The 48 worst 1–3 km stations were winter-inversion sites with sound records → no manual IGRA exclusions. |

Rejected for IGRA: copying ground offset/step criteria (would reject genuine conversion error), requiring every height band to be reached, ≥100 soundings per band (241 of 530 stations had <100 in the 250–500 m band).

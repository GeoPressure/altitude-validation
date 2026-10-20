# Supplement review and revision — 19 October 2026

The supplement was reviewed against the current Methods and Results in `paper/paper.qmd`, the manuscript summary tables, and the code producing its figures. The main manuscript and numerical analyses were left unchanged. The Discussion remains provisional. The revised source is `paper/supplement.qmd`; PDF and HTML are rendered from that source.

## Editorial decisions

| Section | Purpose and revision |
|---|---|
| S1: reference data and distributions | Retain source identity, observation windows, matching, actual quality thresholds and reference-height limitations. Present individual ground errors once for GHCNh; put complementary GNSS/MeteoSwiss error summaries together in S4. Expand the existing height-band table to give median absolute error and p95 together with station/sounding support through 6 km. |
| S2: environmental profiles | Keep elevation-gap, climate, seasonal, local-time and flight-temperature profiles as useful descriptive context. Distinguish station summaries from pooled profile-level means. Retain the five-station historical comparison as explicitly descriptive because the manuscript still refers to it. Remove the fitted-residual map: the elevation-gap figure already carries the useful fitted relationship. Remove the unrelated observation-level GAM explanation because no result from that regression is presented here. |
| S3: ERA5 products | Keep the ground and surface-referenced flight comparisons. Replace the unsupported attribution to an inconsistent ERA5-Land pressure/orography adjustment with the observed contrast and its limited interpretation. Identify pooled flight SD separately from median within-station SD. |
| S4: reference and weighting checks | Keep the paired Swiss height-only contrast, station-screen sensitivity, alternative flight weights, biological targets, reference-dependence checks and selected-year comparison. Remove the extra Swiss locator map. Replace detailed biological-weight prose with a reproducible rules table. Replace the long 4–5 km weighting example with a compact three-conversion p95 table. Move transition/QC/duplicate processing history to the notes below. |
| S5: location pilot | Keep the ten-station experiment currently described in the manuscript. Separate design from interpretation and add a four-row paired-change table using existing results. This makes the distinction between a change in pooled error and a change for an individual query inspectable. |

The section sequence S1–S5 is preserved, so the main manuscript's section references still apply. Automatic section numbering is disabled to avoid headings such as “1 S1”. The figures retain their local supplement numbering. The supplement uses the manuscript's conversion names, median absolute error, absolute-error p95, station bias and within-station SD. “Climate zone” is retained because these classes do not measure bird habitat.

Captions now specify the conversion, reference, weighting, grain of the statistic, spread bands, and displayed height limits where material. The temperature-mechanism plot states its cropped display window and its dependence on the same profiles; the historical plot states its five-station support. These details make the figures usable independently without adding new statistical models.

## Additions implemented from existing outputs

- Full 0–6 km median-absolute-error/p95 table, with station and sounding support, extending the main figure's 0–4 km display.
- Three-conversion 4–5 km p95 sensitivity table, replacing the previous numerical paragraph.
- Biological-weight construction table, replacing the detailed procedural paragraph.
- Location-displacement table reporting both the change in pooled median absolute error and median/p95 absolute paired changes at 50 and 200 km.

No new data were downloaded and no error distributions, screens or weights were changed.

## Optional further additions, in priority order

1. **Show all three conversions in the day/night profiles.** The existing `output/tables/paper_flight_daynight.csv` supports this directly. A small day/night × half-year layout could replace the current ERA5-standard-only plot if the final manuscript discusses whether the correction specifically reduces night-time bias. The present single-conversion plot already supports the temperature-mechanism explanation, so a second figure would be redundant.
2. **Show climate-specific sample support if climate contrasts become a main finding.** A compact companion table or count annotation could use the existing `n_stations` column in `paper_flight_climate.csv`. The global height-band support is now provided in S1; climate-specific support becomes more important if the manuscript makes quantitative comparisons among climates or at upper heights.
3. **Consider the expanded location experiment only as a coordinated manuscript revision.** `docs/methods/T11/` contains a 50-station experiment, but its design emphasizes mean absolute error and percentage changes. S5 and the current manuscript describe T10 and median absolute error. Replacing the pilot needs a deliberate choice of estimand, aligned figures, uncertainty interpretation and updated manuscript wording; mixing T11 into this editorial revision would create a new mismatch.

A second global station map, additional fitted variants, and an observation-level predictor-importance analysis are not needed for the present Methods/Results narrative. Habitat-specific biological conclusions would require suitable habitat data; the existing climate profiles should not be relabelled as habitat profiles.

## Processing detail retained outside the supplement

**GNSS repeated station-hours.** The sensitivity holds the retained station selection fixed and repeats QC after hourly averaging. The maximum change in median absolute error across conversions is 0.003833491 m. Primary results use unique station-hours. Full results remain in `output/tables/paper_gnss_hour_sensitivity.csv`.

**GHCNh–HadISD transition.** The paired audit uses 1,164 station pairs within 1 km, the same ERA5 grid cell in 2024 and at least 500 common accepted hours per pair (5,747,736 shared hours). At 97.7% of pairs, median absolute hourly pressure difference is zero hPa. Median station |bias| is 3.72 m with previous inputs and 3.75 m with GHCNh; median station SD is 4.07 versus 4.05 m. This supports continuity of the pressure records and retention of cleaning thresholds, without establishing greater reference-height accuracy. See `scripts/review_ghcnh_transition.R` and `docs/data-sources/transition-review.md`.

**Retained source QC.** Missing QC and gross-limit-only checks do not imply that every quality test was passed. QC classes are descriptive, because station geography and reporting schedules differ. Numeric flags depend on source: code 5 is accepted as checked-good for legacy ISD sources but means removed for sources 220–223 and 347–348. Aggregated retained accepted station-hours are 1,608,760 source checked-good, 3,986,721 missing source QC, and 2,714,052 other accepted source flag. The source-aware rules remain in the intake code; full station/source composition remains in `output/tables/paper_ground_qc_provenance.csv`.

## Alignment items outside this edit

The repository README still summarizes mean absolute error from the preceding manuscript version, whereas the current manuscript uses median absolute error. Its pilot paragraph also calls the location appendix S6 rather than S5. Those repository-summary changes are separate from this supplement edit.

The provisional Discussion says that “weather explain[s] relatively little additional variation.” The displayed supplement supports season and local-time descriptions, but no longer describes the observation-level weather GAM without presenting its result. If that weather claim survives the Discussion revision, either narrow the wording to the displayed seasonal/local-time patterns or add a compact explanatory-result table from the existing GAM outputs. It should not be inferred from the seasonal figure alone.

**Subsequent update:** The [Discussion revision](discussion-review-2026-10-19.md) resolves the weather-claim issue above by retaining interpretations supported by the displayed profiles and removing the unsupported broader claim.

## Validation

The narrative outside tables, captions and executable chunks decreased from approximately 2,585 to 1,581 words (39%). The final supplement renders successfully to both PDF (20 pages) and HTML. All pages were reviewed in rendered overviews; the expanded error table, biological-weight tables and final location pages were also inspected at larger size. Table placement preserves numerical order and keeps the biological construction table together. The final extracted PDF has no missing-value labels or replacement glyphs, and HTML cross-references resolve. The 30 height-band/conversion medians agree between the primary flight-summary and tail outputs within 1e-8 m; the location table has the intended four outcome/distance rows. No manuscript analysis was rerun.

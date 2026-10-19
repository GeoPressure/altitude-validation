# T06 implementation and consistency pass

> Follow-up: [T07](../T07/implementation.md) replaces the biological height weights with published Master GeoLocator Data Package version 2026.0. Ground and height-specific reference results are unchanged; the bird-weighted numbers below describe the T06 snapshot.

Implemented on 18 October 2026 following the author's approval of the [T06 recommendations](recommendations.md). This record supersedes planning-only status in the earlier assessment; its diagnostic CSVs remain a historical baseline.

## Scientific and presentation changes

- Retained the existing spatial sample, reference-plausibility criteria, primary flight weights and biological height weights. No new altitude-specific station or flight filter was added.
- Consolidated repeated reference station-hours before final observation QC and coverage checks in the main three-conversion analysis. The same reusable aggregation is used by the independent-reference stage and the duplicate sensitivity. Numeric inputs are averaged and station metadata are retained; primary standard errors are recomputed from the averaged inputs.
- Assigned HadISD cell weights after the final station selection, so every retained cell sums to one. Repeated the ground screen contrasts with weights assigned separately after each selection.
- Reduced the main ground table to MAE/p95 and made all main flight-table entries signed bias/MAE. Station bias/SD remain as mechanism summaries, without equating bias with overall accuracy.
- Moved MeteoSwiss-specific methods, regional map and comparative values to S4. Retained a brief main-text pointer to the 32-station height-only check. The main station map and ground-error plot now show the primary reference networks only.
- Replaced the long S1 explanation with approximately 433 words of prose and a compact rules table (about 621 words including the rules). Product identity, coverage, flags, reference-height limitations and timing assumptions remain explicit.
- Added generated height-band support, flight weighting/coverage sensitivities and GNSS duplicate-hour sensitivity to the supplement. Reference-dependence wording remains qualified; no non-assimilation or perfectly known height claim was introduced.
- Preserved unresolved biological choices and the fuller Figure 1 redesign in the response plan rather than displaying editorial questions in the manuscript. Author-supplied declaration placeholders remain unresolved.

## Numerical changes

The primary station counts remain 2502 HadISD, 47 GNSS, 138 supplementary MeteoSwiss and 648 radiosonde stations. The GNSS primary input has 1,077,297 unique hourly records, removing the 20,252 repeated-hour rows from the old aggregation.

| Ground MAE, m | Before | After |
|---|---:|---:|
| HadISD, standard atmosphere | 59.290043 | 59.279720 |
| HadISD, ERA5 standard | 6.068577 | 6.083514 |
| HadISD, virtual + GPT3 | 6.105811 | 6.121883 |
| GNSS, standard atmosphere | 61.784401 | 61.783074 |
| GNSS, ERA5 standard | 5.362482 | 5.364418 |
| GNSS, virtual + GPT3 | 5.327277 | 5.329950 |

All existing primary `paper_flight_*` CSVs retain their pre-implementation hashes. Their bird-weighted MAEs remain 41.195414, 16.439888 and 13.118557 m. Only the three existing primary ground tables changed numerically; an outdated release-version claim was also removed from the legacy formula-table labels without changing its numeric fields; the screening, coverage, support, sensitivity and generation-provenance tables are additional outputs. MeteoSwiss comparison values are retained in the supplement.

## Reproduction and code cleanup

The cached-data manuscript rebuild is now:

```sh
Rscript run_all.R 18
```

Step 18 generates primary comparisons, screening/coverage tables and the Swiss height-only comparison; step 19 generates main/supplement figures; step 20 regenerates the sensitivity appendix; the runner then renders both documents. The stage-12 package-version file remains a historical record. Current generation is recorded separately in `output/tables/paper_analysis_provenance.json`, `paper_figures_provenance.json` and `paper_sensitivity_provenance.json`.

Three-conversion colours are defined once in `R/palette.R`. README, figure captions, table definitions and the response plan reflect the implemented protocol. Earlier exploratory tables retain their original numerical definitions and are distinguished from current `paper_` outputs. T06 diagnostic reproduction checks use the preserved tables in `docs/methods/T06/baseline/`, rather than silently comparing their historical protocol against newly updated primary numbers.

## Verification

The primary analysis, figures and sensitivity stages completed successfully. The canonical hourly aggregation was checked on repeated measurements; production record counts equal unique-hour counts; retained HadISD cell weights sum to one; the sensitivity's primary flight case reproduces the primary analysis; all active R files parse; citation keys resolve. Both documents rendered successfully to PDF and HTML. Main metric tables, the S1 rules, height-band support and S4 Swiss/sensitivity pages were visually checked; a missing label, unsupported inequality glyphs and an over-wide support table were corrected. The final files have no unresolved citation keys or missing weighting labels. No downloads, commits or external publication were performed in this implementation.

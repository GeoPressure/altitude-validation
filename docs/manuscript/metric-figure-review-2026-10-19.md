# Implemented metric and figure revision — 19 October 2026

The author approved implementation and requested fewer metrics. The accepted sources are `paper/paper.qmd` and `paper/supplement.qmd`; the earlier proposed copies have been retired.

## Shared summaries

| Question | Ground | Flight |
|---|---|---|
| Typical individual error | Median absolute hourly error | Median absolute profile-level error |
| Persistent station offset | Median absolute station bias | Median signed station bias |
| Scatter at a station | Median station SD | Median station SD within each height band |
| Upper tail | 95th percentile of absolute error | 95th percentile of absolute error |

Bias remains the mean signed error at a station. The median is taken across station summaries; it does not redefine bias. Flight bias retains its sign to show systematic underestimation. Flight station SD combines variation among soundings and levels within a height band and is not an estimate of scatter within an individual bird flight.

MAE and RMSE are no longer reported as this study's manuscript results. Existing columns remain in cached tables for continuity with earlier analyses. RMSE appears in the literature comparison only as the metric reported by the cited studies, with no direct numerical comparison to our medians. The new median calculation is also used for screening, flight-weighting, biological-target, GNSS repeated-hour, selected-year and location-displacement sensitivity summaries.

The overall biological summary is the median of the combined individual absolute-error distribution. Within band h, the level weight is its primary analysis weight divided by the sum of analysis weights in that band, multiplied by the band's share of flight time. The weighted median is calculated over all bands jointly. It is not the weighted average of the band medians. The same calculation is repeated under alternative biological weights and flight analysis weights.

## Alignment fixes

- Define individual error, station bias and station SD once and reuse them for both ground and flight analyses.
- Use median absolute error consistently in the abstract, Results, practical guidance table, Discussion, Conclusions and sensitivity tables.
- Remove the redundant 50/100/200 m exceedance columns from the supplementary ground table.
- Retain absolute-error 95th percentiles to describe consequential tails; describe them as percentiles of the same error distribution rather than introducing another accuracy metric acronym.
- Replace the previous description of RMSE as scatter: the practical flight guidance now reports median absolute error; station SD supplies the separate scatter summary.
- Distinguish primary individual-level flight weights from equal station weights within each height band.
- Separate terrain roughness from station-to-grid elevation gap in the ground Results wording, and link climate/day–night statements to S2.
- Keep surface-referenced flight-height errors distinct from terrain clearance along a bird's track.

## Figures

The implemented conversion colours are orange (`#C46532`), blue (`#315B91`) and teal (`#007F86`). Figure 3 preserves its three-row layout with IQR segments, 10–90% segments, median dots and aligned median values. Its observation weights now come from the final screened station table, matching the numerical summaries. Figure 4 uses 16 observed-height bands of 250 m through 3.875 km on a 0–4 km axis. All conversions use solid curves, distinct point shapes and translucent station IQRs. No smoothing or interpolation creates observations. Flight-time-weighted results remain in the text. Figure 5's axis identifies its pooled mean profile-level errors. The location-sensitivity figure now uses median absolute error and the shared conversion colours.

## Reproduction

Run `Rscript scripts/18_three_formulas.R`, then `Rscript scripts/20_paper_sensitivity.R`. Figure generation is `Rscript scripts/19_paper_figures.R`; the location pilot uses `docs/methods/T10/run_experiment.R` and `docs/methods/T10/plot_experiment.R`. The current location median summaries were regenerated directly from its cached paired errors without new weather queries. Render the accepted manuscript and supplement with `bash paper/render.sh`.

## Numerical verification

The rebuilt flight-time-weighted median absolute errors are 21.83330, 7.44421 and 5.86797 m (standard atmosphere, ERA5 standard lapse, virtual temperature/GPT3). The primary weighting-sensitivity calculation independently reproduces all three values within 1e-7 m. All five flight-weighting designs and all twelve biological targets retain the corrected conversion's lowest median absolute error. Ground median absolute errors remain 41.03033, 3.94302 and 3.96533 m. Screening changes the central summaries modestly but reduces ERA5's absolute-error 95th percentile from about 40 to 22 m. The selected-year sensitivity also uses pooled individual-error medians, rather than a median of station medians.

Both analysis stages completed successfully from cached inputs. The accepted main manuscript was rendered to PDF and HTML; its abstract, Methods and revised guidance-table layout were visually checked. The supplement was rendered to PDF and HTML from the same rebuilt summary tables; its ground, screening, flight-weighting, biological-target and selected-year tables were visually checked. Figure 3 and 4 revisions remain as implemented in the preceding review; the location figure was regenerated with median absolute errors and its direct labels checked for separation.

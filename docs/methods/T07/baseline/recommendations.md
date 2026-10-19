> Historical assessment using the restricted local master before the published release was adopted. See [the current implementation](../implementation.md).

# T07 — Which flights should define the bird-weighted result?

Assessment completed 18 October 2026. This is a sensitivity assessment, not a replacement of the primary manuscript data. The reference observations, three radiosonde error curves and primary manuscript outputs are unchanged.

## Recommendation

Keep all classified flight time as the principal biological weighting, with the ≥2 h and ≥50 m restrictions in a sensitivity appendix. Neither restriction is needed to preserve the main conversion result. Retaining flights lasting at least two hours hardly changes the time-weighted results; excluding low points changes the target more substantially, removing observations relevant to the near-ground conservation motivation. Do not add an altitude-specific radiosonde filter as part of this decision.

There is a separate provenance issue to resolve before replacing any primary bird weights or their stated sample size: the current local master snapshot does not reproduce the saved step-00 distribution. The current raw-data contrasts below are internally comparable and support the recommendation, but they must not be presented as recalculations of precisely the same original bird sample.

## Main comparison

All figures below use the current local master file and a common set of saved radiosonde error curves (`paper_flight_height.csv`). “≥2 h” means retaining longer flights; “≥50 m” means retaining points within flights, not selecting entire flights by their maximum or mean height. Hours are represented sampling time, including the original 60 min gap cap, rather than continuous observed flight duration. Birds are tag identifiers, with no independent check that repeated deployments correspond to distinct individuals.

| Target / weighting | Tags with flight | Species | Flights represented | Hours retained | Median height (m) | Standard-atmosphere MAE (m) | ERA5 MAE (m) | Virtual + GPT3 MAE (m) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| All classified flight | 250 | 31 | 6194 | 40,238 | 568 | 41.50 | 16.54 | 13.18 |
| Flights ≥2 h | 232 | 30 | 5188 | 39,152 | 588 | 42.21 | 16.78 | 13.36 |
| Points ≥50 m | 243 | 31 | 5918 | 34,845 | 729 | 46.96 | 18.24 | 14.37 |
| Both restrictions | 231 | 30 | 5134 | 34,104 | 746 | 47.54 | 18.45 | 14.52 |
| Equal bird, all flight | 250 | 31 | 6194 | 40,238 | 410 | 35.90 | 14.63 | 11.81 |

The ≥2 h restriction retains 97.3% of represented flight time but removes 18 tags and one species with only three hours of classified flight. The ≥50 m restriction retains 86.6% of flight time; both restrictions retain 84.8%. Excluding low points raises the weighted errors because more weight goes to heights where conversion error is larger. It does not demonstrate a deterioration of a conversion on a common biological target.

Across these five choices, virtual temperature + GPT3 reduces MAE relative to ERA5 with the standard lapse rate by approximately 19–21%, and the mean signed error remains much closer to zero. With all flight time, bias is −11.91 m for ERA5 and −3.20 m for virtual + GPT3; with both restrictions, it is −13.72 and −3.57 m. The ordering of the three MAEs is unchanged. These are height-standardised reference-error summaries: the bird observations supply weights, not independent validation errors for those birds. A pooled bird-weighted p95 cannot be obtained by averaging bin-specific p95 values; none is claimed here.

## Sampling and duration

The workflow reproduces `scripts/00_bird_heights.R`: most-likely pressurepaths, finite tag/surface pressures, discarded records excluded, and non-integer `stap_id` classified as flight. A flight is a tag × preceding stationary-period identifier. This is the movement segmentation supplied by the master package, not a fresh activity-based flight classifier.

Each point receives the interval to the next retained record of the tag, capped at 60 min; the final tag record uses the median positive interval. Available steps span 5–60 min, and longer nominal steps contribute more time than their point counts suggest. Five-minute points are 41.8% of flight records but only 12.9% of flight time. Twenty- and thirty-minute points contribute 31.2% and 31.1% of time, respectively. Equal point weighting would therefore answer a different question and should not replace interval weighting.

The primary sensitivity defines duration as the sum of represented intervals in the flight. Using elapsed first-to-last time plus the last capped interval instead changes the two-hour classification for eight flights, representing 11.1 h (0.03% of all flight time). The corresponding MAEs differ by less than 0.01 m. Ninety-five flights contain an internal gap longer than 60 min. The time cap limits their contribution but does not recover missing behaviour or exact take-off/landing times. A sharp two-hour boundary is consequently an approximate classification, not a directly observed duration threshold.

## Below-ground heights and dependence on the conversion

The original height weights use a fixed 288.15 K, −6.5 K/km conversion of tag pressure relative to ERA5 surface pressure, after interpolating a pressure offset between the preceding and following stationary periods. They do not use the full virtual-temperature/GPT3 conversion. The pressure offset is the median tag-minus-surface-pressure discrepancy in the last/first six hours of the adjacent stationary period; a single available endpoint is used if the other is absent, otherwise the offset is zero.

In the current snapshot, 12.0% of flight time is below the ERA5 surface before that correction and 8.7% afterwards. Residual negative values are put at zero for the primary height weights; they are not evidence that birds actually flew at ground level. A ≥50 m filter removes all these records plus positive low-height records, amounting to 13.4% of time. The data do not determine which negatives reflect terrain mismatch, position uncertainty, reference/sensor offsets or flight classification. Near-ground height-specific reference results should remain separately available regardless of the bird-weighting choice.

Both stationary endpoint references are available for 98.3% of flight time. A departure-only reference covers 0.85%, an arrival-only reference 0.78%, and neither 0.067%. These fractions describe available pressure references, not verified ground heights.

The following checks probe the dependence of the weights on height assumptions, always applying the same radiosonde curves to all three conversions:

- Omitting the stationary pressure-offset correction changes the weighted MAEs from 41.50/16.54/13.18 m to 40.37/16.17/12.91 m (standard atmosphere / ERA5 / virtual + GPT3).
- Moving every estimated height down or up by 100 m gives virtual + GPT3 MAEs of 12.47–14.02 m, versus 15.53–17.73 m for ERA5. This is a stress test, not a calibrated uncertainty interval or a correction for actual terrain.
- Complete weather annotations permit a paired change of the height formula for only 19 tags, three species and 5,112 h (12.7% of current flight time). On that common subset, virtual + GPT3 reference MAE is 12.63 m with original height weights, 12.95 m with 2 m-temperature weights and 13.10 m with virtual/GPT3 weights; corresponding ERA5 values are 15.92/16.32/16.50 m. This checks sensitivity on a restricted subset, not the entire sample. Existing master annotations are reused without a fresh weather query or a newly calibrated stationary offset.

The bin mapping follows the existing production convention, including folding heights ≥6 km (0.041% of current flight time) into the upper 5–6 km reference band. This is a small extrapolation of the biological weights beyond the evaluated range. None of these checks removes the dependence between conversion assumptions and estimated bird heights, but none reverses the conversion ranking.

## Bird and species representation

Pooling time gives more weight to birds with longer recorded flight exposure. The most influential tag contributes 1.73% and the ten most influential tags 13.38% of time. Great reed warblers, hoopoes and northern wheatears together contribute 45.1%. The sample is an empirical set of tracked birds, not a globally representative flight-height distribution.

Equal-bird weighting first gives each tag total weight one and then divides it by its represented flight time. It lowers the height median from 568 to 410 m and the virtual + GPT3 MAE from 13.18 to 11.81 m, but gives a tag with 15 minutes of classified flight the same total influence as one with 697 h. Keep pooled flight-time weighting for the paper's exposure-oriented interpretation, and show equal-bird weighting as a different estimand. Do not infer population-level or equal-species performance from either summary.

## Provenance discrepancy and primary numbers

The saved primary distribution contains 38,521 h of flight and a reported `n_tags = 274`. The current master yields 40,238 h, 281 retained tags overall and 250 tags with classified flight. Crucially, step 00 writes the number of all retained tags, including stationary-only tags, into `n_tags` for every bin. Therefore that column alone cannot substantiate the current manuscript wording “flight time of 274 birds”; the number of actual flight-contributing tags in the original snapshot is not recoverable from the aggregated CSV.

Using the frozen committed height weights reproduces the three primary bias/MAE values to <10⁻⁸ m, verifying the bin mapping and aggregation independently of the new raw input. Rebuilding weights from the current master instead increases MAE by 0.308/0.099/0.064 m (standard atmosphere / ERA5 / virtual + GPT3). That is small for the scientific conclusion, but it establishes a sample/provenance difference. The script, current raw input and metadata hashes are recorded in `provenance.json`; raw tracking records and tag identities are not exported.

Before a primary update, either recover the original master snapshot and verify its flight-contributing count, or deliberately adopt and document the current snapshot, regenerate step 00 and steps 18–20, the bird-height figure, tables and both documents together. A new full radiosonde/station sample or new weather downloads are not needed for the target/filter sensitivity. Extending the paired weather-formula check to all birds would require retrieving their missing annotations and is a separate optional analysis.

## Suggested manuscript changes after resolving that snapshot

Methods: “We summarised the reference errors using the empirical share of represented flight time in each height band. Flight records were defined by the tracking package's movement segmentation; sampling intervals were capped at 60 minutes. Estimated heights were corrected using pressure offsets in adjacent stationary periods, with residual negative heights assigned to the lowest band. We retained all classified flight time and assessed restrictions to flights lasting at least two hours, points at least 50 m high, and equal-bird weighting in the supplement.” Use the verified flight-contributing tag count, rather than the step-00 count of every retained tag.

Discussion: “These weighted summaries describe the height distribution of the tracked sample. They are not universal bird-flight errors. Alternative duration, low-height and individual weighting choices changed their magnitude but preserved the conversion ranking; the estimated biological height weights themselves retain uncertainty from the atmospheric conversion and terrain reference.” Qualify the restricted 19-tag paired formula check rather than replacing the existing limitation with a claim of complete independence or complete validation.

Supplement: add the five-row support/error table above and one short paragraph on negative heights, time weighting and the restricted formula check. Preserve the low-height radiosonde table. Keep the full diagnostic CSVs in this audit folder rather than expanding S1 again.

## Reproduction and outputs

Run from the project root: `Rscript docs/methods/T07/assess_flight_targets.R`. `GEOLOCATOR_MASTER` can point to the raw pressurepaths file; the corresponding `tags.csv` must be alongside it. Only aggregate outputs are written in this folder. This assessment is not a new automatically run production stage.

`target_support.csv` reports tags/species/flights/points/hours and height summaries; `weighted_errors.csv` reports the common three-conversion comparisons; `height_weights.csv` contains the actual bin weights. `species_contributions.csv`, `bird_concentration.csv`, `cadence.csv`, `duration_agreement.csv`, `offset_support.csv` and `height_and_gaps.csv` document the target. `reproduction_checks.csv` quantifies current-input differences from the primary results; `frozen_weight_checks.csv` verifies exact reproduction from the committed weights. `provenance.json` and `session-info.txt` record inputs and execution.

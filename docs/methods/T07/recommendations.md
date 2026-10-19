# T07 — Biological flight target using the published release

Updated 18 October 2026. The author approved retaining all classified flight and adopting the published [Master GeoLocator Data Package, version 2026.0](https://doi.org/10.5281/zenodo.18187093). The implementation replaces the former weights and adds the biological sensitivity appendix. See the [implementation record](implementation.md).

## Decision and sample

Retain pooled represented flight time as the primary weighting. Duration and low-height restrictions change the biological target and are supplementary contrasts. No altitude-specific radiosonde filter is added.

The public `GeoLocatorMaster/data/master/` pressurepaths, tag metadata, species table and package descriptor match Zenodo's published checksums. The previous assessment used `master_restricted`, so its numbers were a different sample; that assessment and the superseded primary weights are preserved in `baseline/`. There is no unresolved public/local snapshot discrepancy.

The published pressurepaths supply 204 tags after the existing finite-pressure/most-likely/discard-label checks. One has no classified flight. The primary distribution therefore contains 203 contributing tags, 25 species, 5,293 classified flights, 128,003 points and 34,580 represented hours. Tags without pressurepaths never enter this calculation. Step 00 now excludes tags without usable classified flight and reports the actual contributing count; it no longer copies the count of every tag into flight summaries. The master package treats a tag as a deployment on one bird; repeated deployments are not independently reconciled here.

## Main sensitivity comparison

Every row uses the same saved radiosonde error curves and the same biological weights across the three conversions. Flight records provide height weights, not independent bird-height validation errors. Hours are sums of represented sampling intervals, not continuously observed flight duration.

| Target / weighting | Tags | Species | Flights represented | Hours | Median height (m) | Standard-atmosphere MAE (m) | ERA5 MAE (m) | Virtual + GPT3 MAE (m) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| All classified flight | 203 | 25 | 5293 | 34,580 | 586 | 42.19 | 16.80 | 13.38 |
| Flights ≥2 h | 199 | 24 | 4469 | 33,661 | 607 | 42.90 | 17.04 | 13.55 |
| Points ≥50 m | 203 | 25 | 5106 | 30,058 | 748 | 47.61 | 18.49 | 14.57 |
| Both restrictions | 199 | 24 | 4423 | 29,410 | 764 | 48.20 | 18.71 | 14.72 |
| Equal bird | 203 | 25 | 5293 | 34,580 | 490 | 38.58 | 15.49 | 12.42 |

Keeping flights lasting at least two hours retains 97.3% of represented flight time. Keeping points at least 50 m high retains 86.9%; both restrictions retain 85.0%. The low-height restriction selects points within flights, not flights by maximum or mean altitude. Its larger weighted errors reflect increased emphasis on higher flight, rather than a conversion deteriorating on a common target. The virtual-temperature/GPT3 correction preserves its advantage under every contrast. The signed bias with all classified flight is −12.14 m for ERA5 and −3.22 m with virtual temperature/GPT3; with both restrictions it is −13.95 and −3.59 m.

## Duration, cadence and contributions

Flight classification remains the package's non-integer `stap_id` segmentation; a flight is a tag × preceding stationary-period identifier. We did not reprocess upstream tracks with a uniform GeoPressureR version or independently reclassify flight from activity measurements. Heights and segmentation retain those upstream processing limitations.

Intervals to the next retained tag record are capped at 60 min; the last tag record uses its median positive interval. The nominal two-hour sensitivity sums these represented intervals within a flight. An elapsed first-to-last span plus the final interval changes the classification for just one flight, representing 1.33 h; weighted MAEs change by less than 0.01 m. Thirty-two flights contain an internal gap longer than 60 min. Capping limits their influence but does not recover missing behaviour or exact take-off/landing times. Keep interval weighting; equal point weights would overrepresent densely sampled tags.

The largest contributing tag supplies 2.02% of flight time; the ten largest supply 13.58%. Represented hours per tag range from 2.33 to 697 h. Equal-bird weighting gives each tag total weight one, lowering the height median from 586 to 490 m and virtual/GPT3 MAE from 13.38 to 12.42 m. That is a different estimand, not inherently a better global estimate. The sample is an empirical set of tracked deployments, not a global or equal-species sample. Species-specific contributions are available in `species_contributions.csv`.

## Height assumptions and negative values

The biological weights use the existing fixed 288.15 K and −6.5 K/km conversion of tag pressure relative to ERA5 surface pressure. A tag-minus-ERA5 pressure offset is estimated from the last/first six hours of adjacent stationary periods and interpolated across the flight. One endpoint is used alone when necessary, otherwise the offset is zero. Both endpoints are available for 99.0% of flight time; neither is available for 0.060%.

Flight time below the ERA5 surface is 11.7% before and 8.5% after offset correction. Residual negatives enter the lowest height band; they do not establish actual ground-level flight. The ≥50 m restriction removes those records plus positive low points. The data do not establish their causes, which can involve terrain, position, sensor/reference offsets or movement classification. Keep the near-ground reference-error results separately available for conservation applications.

Omitting the pressure-offset correction, shifting all heights ±100 m, or changing the height formula on a common annotated subset all preserve the conversion ranking. The shifts are stress tests, not calibrated uncertainty intervals. Complete existing weather annotations support the paired formula check for only 18 tags, two species and 5,081 h (14.7% of primary flight time); this is not a complete-sample validation of the weights. Existing weather annotations are reused without a fresh ERA5 query or a newly estimated offset for each formula. Details and all numerical contrasts are in `weighted_errors.csv` and `target_support.csv`.

The production bin convention folds flight above 6 km (0.048% of time) into the upper 5–6 km reference band. This modest extrapolation concerns the biological weights, not validated errors above the evaluated range. Averaging height-band p95 values would not yield a pooled bird-weighted p95; none is claimed.

## Effect on the paper and reproduction

Using the published sample changes the primary MAEs from 41.20/16.44/13.12 m to 42.19/16.80/13.38 m (standard atmosphere / ERA5 / virtual + GPT3). The tagged-bird count is now 203 rather than the historical all-tag count of 274. The conversion ranking and biological interpretation remain. Ground comparisons and height-specific reference-error curves do not depend on these biological weights.

Step 00 verifies the release checksum and records its DOI/version, checksums, sample and definitions in `output/tables/bird_height_provenance.json`. `update_cached_weights.R` applies the new weights to the existing reference curves; full steps 13, 18 and 20 produce the same summaries. The supplementary fitted models in step 16 must be refitted because their objectives use biological weights; step 17 and step 19 regenerate the relevant figures.

Run `Rscript docs/methods/T07/assess_flight_targets.R` after the primary weights have been updated. Its aggregate outputs and `output/tables/paper_bird_target_sensitivity.csv` supply the appendix. Current-input and direct-bin aggregation checks reproduce the primary bias/MAE values to <10⁻⁸ m. Raw tracks and individual identifiers are not exported by this audit. See `provenance.json`, `published-release.json` and `published-file-checks.json` for the source and execution record.

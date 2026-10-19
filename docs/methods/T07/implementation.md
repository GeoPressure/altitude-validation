# T07 implementation — published bird dataset

18 October 2026. Author-approved decisions: use the published Master GeoLocator Data Package version 2026.0 (doi:10.5281/zenodo.18187093), remove noncontributing tags, retain all classified flight, and update the reference and manuscript results.

## Source and calculation

- Local public `GeoLocatorMaster/data/master/` files match the published release checksums. `published-release.json` preserves the authoritative Zenodo API metadata; `published-file-checks.json` records checks on pressurepaths, tags, species and the descriptor.
- Step 00 now defaults to the public release, validates pressurepaths and metadata checksums, excludes tags without usable flight pressurepaths, and writes `bird_height_sample.csv` plus versioned provenance. All classified flight and the existing pressure-offset, negative-height and interval-weight conventions are retained.
- The contributing sample is 203 tags, 25 species, 5,293 flights and 34,580 represented flight hours. One of the 204 tags with otherwise eligible pressurepaths has no classified flight and is excluded. No upstream tracking package is edited or reprocessed.
- `update_cached_weights.R` recomputes the main bird-weighted, ERA5/ERA5-Land and reference-weight sensitivity summaries from the unchanged height-specific reference-error tables. This is algebraically identical to the relevant aggregation in full steps 13, 18 and 20, without rereading all reference observations.
- Step 16 refits the supplementary lapse-rate models using the new biological weights. Steps 17/19 redraw figures. The T07 target audit is rerun against the same published release and generates the new supplementary target table.

## Text and reference

The main manuscript, supplement and README use the flight-contributing sample and updated weighted errors. The release-specific dataset citation is added to `paper/references.bib`, Methods and data availability. S4 describes the biological height weights and includes duration/low-height/equal-bird contrasts. The discussion qualifies the empirical sample, upstream processing and limited paired height-formula check. The scientific reference sample, station screens and low-height radiosonde reporting are retained.

The earlier restricted-data assessment and superseded primary bird tables remain in `baseline/` as historical records. The public/local provenance issue is resolved by the checksum match; historical sample-size claims are not carried forward.

## Reproduction

With the public master release available locally, run from the repository root:

```sh
Rscript scripts/00_bird_heights.R
Rscript docs/methods/T07/update_cached_weights.R
Rscript scripts/16_formula.R
Rscript scripts/17_figures.R
Rscript scripts/19_paper_figures.R
Rscript docs/methods/T07/assess_flight_targets.R
bash paper/render.sh
```

The regular full production steps 13, 18 and 20 also regenerate these summaries; step 20 uses the committed aggregate biological target weights and support to update the target sensitivity table without raw bird tracks. The raw master file is an optional local dependency for step 00 and this biological audit; committed aggregate outputs permit ordinary cached-data manuscript builds without it.

## Verification

Final verification and artifact fingerprints are recorded in `implementation-verification.json` and `implementation-provenance.json`. Numerical checks include agreement of current raw-input weights with primary weighted bias/MAE, comparison with the direct bin aggregation, and unchanged ground/height-specific reference tables. PDF and HTML builds and visual checks cover the updated count, flight-height figure, appendix table and dataset citation.

All checks passed: four document formats built successfully (main PDF 22 pages; supplement 17 pages), and updated figures, sample text, target/CV tables and bibliography entry were visually checked. The raw-input and primary-weight reconstructions agree to <10⁻⁸ m, and 17 primary ground/height-specific/support reference tables match the T06 fingerprints exactly. Standard and virtual height-specific formula checks also agree exactly. A malformed GPT3 display label in two generated formula tables was corrected without changing numeric fields.

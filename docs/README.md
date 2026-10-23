# Research documentation

Author-facing notes behind the study. The manuscript sources are [paper.qmd](../paper/paper.qmd) and [supplement.qmd](../paper/supplement.qmd); the analysis is defined by [run_all.R](../run_all.R) and described in the [repository README](../README.md). Notes are dated snapshots: they may describe thresholds, samples or datasets that were later changed or retired.

## Methods

- Station selection: [GHCNh sampling](methods/ghcnh-sampling-review/README.md) and [IGRA2 sampling](methods/igra-sampling-review/README.md).
- [Bird flight-height data](methods/T07/implementation.md): published dataset, input checksums and flight-time weighting.
- [Horizontal-position pilot](methods/T10/design.md) (Additional file 1: S5).
- Earlier implementation audits: `methods/T04`–`T07`.

## Ground-station curation reviews (October 2026)

Reviews in [`methods/reviews/`](methods/reviews/) that led to the pressure checks and exclusion lists in [`inputs/`](../inputs/README.md). The scripts they cite under `scripts/drafts/` are now in [`archive/exploratory-scripts/curation-2026-10/`](../archive/exploratory-scripts/curation-2026-10/README.md).

- [Simple pressure-only station filtering plan](methods/reviews/station-filtering-plan-2026-10-23.md) and [ground-reference filtering using pressure and timestamps](methods/reviews/pressure-only-filtering-2026-10-23.md)
- [Review of ground-station filtering and station-consistency checks](methods/reviews/station-consistency-filtering-review-2026-10-23.md)
- [Ground-series curation and isolated-spike screening](methods/reviews/ground-curation-and-spikes-2026-10-22.md)
- [Experimental pressure-only pattern checks](methods/reviews/pressure-pattern-tests-2026-10-23.md) and [their application](methods/reviews/pressure-pattern-application-2026-10-23.md)
- [Reference curation and pressure-pattern review](methods/reviews/reference-curation-review-2026-10-23.md)
- [Quality codes and the manually reviewed pressure errors](methods/reviews/ground-quality-code-review-2026-10-23.md)
- Manual reviews: batches [3](methods/reviews/ground-manual-review-batch3-2026-10-22.md), [4](methods/reviews/ground-manual-review-batch4-2026-10-22.md), [5](methods/reviews/ground-manual-review-batch5-2026-10-23.md), [6](methods/reviews/ground-manual-review-batch6-2026-10-23.md) and [7](methods/reviews/ground-manual-review-batch7-2026-10-23.md)
- Tail reviews: [ERA5 residuals](methods/reviews/era5-tail-review-2026-10-22.md), [pressure anomalies](methods/reviews/pressure-anomaly-tail-review-2026-10-22.md), [standard-atmosphere biases above 150 m](methods/reviews/isa-bias-tail-review-2026-10-23.md) and [the ten largest ERA5 biases](methods/reviews/high-bias-online-review-2026-10-22.md)

## Manuscript

- [Figure style](manuscript/T08/figure-style.md)
- [Discussion plan](manuscript/discussion-plan-2026-10-20.md)
- [Submission checklist](manuscript/submission-checklist.md)

## Literature and data sources

The [literature index](literature/README.md) and [GPS/barometer synthesis](literature/gps-barometer-ecology.md) contain the scientific reviews; [data-source notes](data-sources/intake.md) record the dataset choices. See [data layout](data-layout.md) for local inputs and caches.

Superseded proposals, retired datasets and exploratory scripts are preserved in [`archive/`](../archive/).

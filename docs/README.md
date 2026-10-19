# Research and manuscript documentation

Planning notes, literature reviews and technical audits live here. The manuscript and supplement remain in [`paper/`](../paper/), and reference PDFs, bibliographies, metadata and evidence tables remain in [`literature/`](../literature/).

## Manuscript planning

- [Discussion revision](manuscript/discussion-review-2026-10-19.md): practical bird-tracking emphasis, tighter structure, interpretation of the summary table and retained limitations.

- [Supplement review and revision](manuscript/supplement-review-2026-10-19.md): alignment with the current Methods/Results, shorter narrative, table additions and optional further figures.

- [Comment response plan and current task status](manuscript/comment-response-plan.md)
- [Planned location-sensitivity appendix](manuscript/location-sensitivity-plan.md)
- [T08 figure design standard and palette](manuscript/T08/figure-style.md), with the [Figure 1 implementation](manuscript/T08/implementation.md).

## Literature reviews

- [GPS, barometers and animal flight height](literature/gps-barometer-ecology.md): ten paper summaries, six figures and the scope assessment, maintained as Markdown only.
- [T01–T03 review and manuscript recommendations](literature/review-T01-T03.md)
- [Literature documentation index](literature/README.md)
- [Search log](literature/search-log-2026-10-18.md)
- [GPS/barometer report source and figure notes](literature/gps-barometer-sources.md)

## Technical methods

- [T04 verification](methods/T04/verification.md), with its check script, results and provenance in the same folder.
- [T05 dataset and sampling audit](methods/T05/audit.md), with dataset provenance, realised coverage, timing checks and reproducible audit script.
- [T06 implementation and verification](methods/T06/implementation.md): the current protocol, updated results and cached-data rebuild.
- [T06 sampling, metrics and reference-quality recommendations](methods/T06/recommendations.md), including filtering/weighting experiments and the MeteoSwiss appendix assessment.
- [T07 published-release implementation](methods/T07/implementation.md) and [biological flight-target assessment](methods/T07/recommendations.md): verified public inputs, contributing tag counts, duration/height restrictions, time versus bird weighting and height assumptions.
- [T10 paired location-displacement pilot](methods/T10/design.md): fixed observations, atmospheric queries at 0–200 km, and a compact S5 appendix.
- [T11 expanded location-displacement test](methods/T11/design.md): 50 stations, four seasonal launches each, percentage MAE change from exact-location queries, and station-bootstrap intervals.
- [Proposed shorter S1](manuscript/s1-simplification-proposal.md), preserving the reproducible selection rules.

The review's figures and provenance are in `assets/gps-barometer/`; their extraction script is in `scripts/`. Historical exploratory material remains in [`archive/report/`](../archive/report/).

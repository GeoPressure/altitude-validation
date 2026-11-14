# altitude-validation v1.1.0

## Main

- [Prepare the Scientific Reports submission with a shorter title, a 174-word unstructured abstract, Nature-style references, supplementary labels, cover letter, rendered PDFs and a self-contained LaTeX source archive](https://github.com/GeoPressure/altitude-validation/commit/c43ae406b5a7424653b802561304f741071ab78a).

## Minor

- [Use the standard conversion explicitly for the ARCO calculations](https://github.com/GeoPressure/altitude-validation/commit/44b2a03) and [fail the API cross-check when the API errors or returns no usable data](https://github.com/GeoPressure/altitude-validation/commit/e213110).
- [Allow N_CORES to set the station-selection worker count](https://github.com/GeoPressure/altitude-validation/commit/9a77ec8) and [avoid requiring R 4.4 for ground-station selection](https://github.com/GeoPressure/altitude-validation/commit/d694605).
- [Apply the near-zero lapse-rate safeguard to the Figure 1 sounding profiles](https://github.com/GeoPressure/altitude-validation/commit/c9ee7a5) and [stop when the GeoPressureR commit cannot be recorded](https://github.com/GeoPressure/altitude-validation/commit/f9621b4).

Validation: pressure-spike tests, all 1,794 accepted ground-station years, conversion and result checks, air formatting and jarl linting passed. PDFs were rendered and visually checked, and the manuscript source archive compiled independently.

**Full Changelog**: <https://github.com/GeoPressure/altitude-validation/compare/v1.0.0...v1.1.0>

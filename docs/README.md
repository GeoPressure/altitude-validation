# Research documentation

The authoritative manuscript sources are [paper.qmd](../paper/paper.qmd) and [supplement.qmd](../paper/supplement.qmd). The agreed supplementary structure and methods are integrated there; there are no active manuscript proposal files.

## Current analysis status

Both selections completed successfully: GHCNh retained 2,130 stations from 2,962 evaluated cells (5,318 candidate stations assessed), and IGRA retained 643 stations from 801 cells (828 candidates assessed). Neither has pending cells, and the selection monitor is disabled.

The numerical refresh is complete. The analysis uses 11,516,671 accepted GHCNh hours and 6,050,933 accepted IGRA airborne observations. Additional ERA5-Land inputs are cached for all 2,773 retained stations; paired product summaries use only hours with finite inputs for both products. Error summaries, environmental profiles, selection sensitivity, bird-weighted errors and figures have been regenerated.

Checks confirmed the accepted IDs, cell balance, observation counts and rolling windows; direct GeoPressureR conversion agreement; equal station weights within flight-height bands; and agreement between primary and sensitivity summaries. The completed generation is recorded in `output/tables/selection_analysis_complete.json`. GNSS and MeteoSwiss evaluations are retired; their scripts and dataset-specific tables are preserved in [the complementary-evaluation archive](../archive/complementary-ground-evaluations-2026-10-22/README.md). Original downloaded records remain cached locally. The active build is defined in [run_all.R](../run_all.R); preceding numerical outputs and retired stages are archived separately.

## Current methods and checks

- [GHCNh sampling](methods/ghcnh-sampling-review/README.md)
- [IGRA sampling](methods/igra-sampling-review/README.md)
- [Figure style](manuscript/T08/figure-style.md)
- [Published biological dataset](methods/T07/implementation.md), including input checksums and flight-time weighting
- [Horizontal-position experiment](methods/T10/design.md)

## Literature and historical evidence

The [literature index](literature/README.md) and [GPS/barometer synthesis](literature/gps-barometer-ecology.md) contain the scientific reviews. Data-source reviews and earlier implementation audits are historical snapshots and may describe retired datasets or methods. Earlier implementation audits remain under `methods/T04`–`T11` and retain their dated numerical definitions.

Superseded manuscript proposals and sampling-development notes are preserved in [archive/docs](../archive/docs/README.md). They are historical records, not competing specifications for the current manuscript.

# Ground-series curation and isolated-spike screening

Author-facing record, 22 October 2026. The curation list is `docs/methods/ghcnh_curation_exclusions.csv`. It distinguishes independently documented metadata conflicts from manual exclusions following inspection of ERA5 residuals and the pressure series. These manual exclusions are not an independent test of ERA5 performance and must be described as curation in the manuscript.

The eleven stations reviewed in `era5-tail-review-2026-10-22.md` are excluded as requested. Replacement candidates follow the frozen order in each represented sampling cell. The ten highest-SD stations after this curation and isolated-spike screening were then plotted and inspected. Nine showed analogous problems or lack a fixed height reference:

| Station | ID | Observed reason for manual exclusion |
|---|---|---|
| Curaçá | BRM00081984 | A sustained pressure step at the beginning of April 2026 changes the converted height from approximately 363 m to approximately 100 m. |
| Chapadinha | BRM00081749 | A short terminal block in April 2026 has pressures around 910 hPa instead of approximately 1000 hPa, giving heights hundreds of metres above the main record. |
| Caxias | BRM00081792 | A terminal bad block in April 2026 is approximately 50 hPa below the main pressure record. |
| Dourados | BRM00086858 | Terminal bad pressure blocks in April 2026 differ from the main record by tens of hPa in both directions. |
| Formoso do Araguaia | BRM00086629 | A terminal bad block in April 2026 differs from the main pressure record by approximately 50 hPa. |
| Halvfarryggen | AYM00089003 | A noisy episode near January 2026 creates pressure excursions and several hundred metres of apparent height variation absent from the preceding record. |
| La Quiaca | ARI0000SASQ | A sustained step near March 2025 shifts pressure-derived height by approximately 60 m. The cause was not independently verified. |
| NUK_U | GLU00000043 | The archive identifies a moving ice station, for which a single fixed reference elevation is not established. |
| Nouvelle Amsterdam | FSU98404002 | Source 393 has a strong temporal-misalignment signal: comparison with ERA5 ten hours earlier reduces pressure-residual SD from approximately 3.6 hPa to 0.33 hPa. This is diagnostic evidence, not independent verification of the correct timestamps. No time shift was applied. |

Drosh (PKMU0020354, SD 25.9 m) was retained. Its record shows broad scatter without a clearly identified recording failure; terrain and atmospheric representativeness remain plausible. The diagnostic outputs are `output/drafts/atmospheric-figures/era5_followup_review_*`, produced before these nine further exclusions. Several terminal Brazilian failures coincide with a pressure-source change, but source identity alone is not used as a rejection rule.

## Observation-level rule

The histogram workflow previously used archive quality flags, a plausible pressure range, hourly report selection and whole-window continuity checks; it did not delete individual observations based on the pressure series. The older `ghcnh_window()` routine includes ERA5-residual outlier removal and is not used for the new pressure-only histogram selection.

The new observation-level rule removes a report only when it differs by more than 5 hPa from each adjacent report, both neighbours lie within three hours, the neighbours agree within 2 hPa, and the report lies on the same side of both neighbours. It uses pressure and time only, before coverage and continuity checks. It is applied in a single pass to the complete candidate pressure series, leaving the raw cache unchanged. Coverage is recomputed after removal, and all three conversions use the same retained records. This rule targets isolated spikes; sustained steps, multi-report failures and timestamp problems remain subjects for station curation.

Tests in `tests/check_ghcnh_pressure_spikes.R` check removal of an isolated spike and retention of coherent pressure changes, a persistent step and an excursion lacking sufficiently close neighbours. The initial rebuild removed 1,166 observations from 413 retained stations. Final counts after further curation are available in `ground_terrain_rebuild_checks.csv`.

Rebuild with `Rscript run_all.R ground_histogram`. This updates the ground histogram comparison; the manuscript's frozen primary analysis remains separate.

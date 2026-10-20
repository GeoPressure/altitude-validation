# Supplement structure: reference height and robustness

**Recommendation for review, 20 October 2026.** The two error-summary tables have been removed from the supplementary source, and S2 is unchanged. The S4–S6 structure below is proposed; its numerical comparisons need to be rebuilt using the completed GHCNh and IGRA selections before it replaces the existing sections.

## What the supplement needs to establish

The main manuscript makes three relevant arguments: ground errors depend partly on the reference height and station selection; the corrected conversion improves flight-height estimates; and the overall bird summary depends on how flight heights and observations are weighted. Each argument needs its own supporting evidence. An appendix section should not combine these questions merely because they all involve a sensitivity analysis.

The resulting structure would be:

- **S1 Reference-station selection and processing:** GHCNh and IGRA processes, as drafted.
- **S2 How the error varies:** unchanged.
- **S3 ERA5 single-levels and ERA5-Land:** unchanged.
- **S4 Ground-reference height and selection:** the reference-height evidence and its implications for screened ground errors.
- **S5 Flight-height weighting:** the construction and robustness of the overall flight summary.
- **S6 Sensitivity to horizontal position:** the current S5, renumbered.

## S4 Ground-reference height and selection

### S4.1 How does the pressure-sensor height affect ground errors?

**Lead with the paired Swiss comparison.** It addresses a specific explanation for persistent offsets: the listed station elevation may differ from the pressure-sensor height. Retain the figure, simplified to two estimates at each matched station: the listed GHCNh elevation and the published barometer height, using exactly the same GHCNh pressure observations, ERA5 inputs and selected window. This is the strongest evidence in this section because the changed input is explicit.

Remove the MeteoSwiss-pressure series from that paired figure. Its different observation period makes the third arm harder to interpret, while the separate comparison below already describes errors using MeteoSwiss pressure. In the main Results, retain the height-only improvement and its local interpretation; remove the extra comparison with the third arm.

**Keep GNSS and MeteoSwiss as compact corroboration.** Barometers at GNSS stations add evidence outside the Swiss network, with pressure-sensor heights reconstructed from site metadata and checked against file headers. They do not measure the heights of flying birds, and archive membership does not demonstrate independence from ERA5. Their useful role is to show whether the ground-error scale is broadly consistent when pressure-sensor height is more explicitly documented.

I recommend one small table for the ERA5-standard conversion, with two rows—GNSS barometers and MeteoSwiss—and columns for station count, median station |bias|, median station SD, median individual |error| and p95. These quantities support different claims and are already defined in the main Methods. Repeating all three conversions at both networks adds little to this reference-height question.

Place their short methods immediately before this table. For GNSS, retain the observation period, hourly aggregation, site-log pressure-sensor offsets, EGM96 height conversion, height-consistency and coverage requirements. For MeteoSwiss, retain the observation period, full-hour pressure at published barometer height and coverage requirement. Describe the Swiss vertical datum as used. Parsing fields and download conventions belong in the code. The methods should distinguish the GNSS metadata-consistency check from a demonstration of absolute height accuracy.

The network table is descriptive: its stations, terrain and periods differ. The paired height-only figure supplies the controlled comparison. Neither display establishes assimilation independence, diagnoses every GHCNh offset or justifies a global numerical correction to station heights.

**Displays:** one paired height-only figure and one two-row corroboration table. A separate GNSS section, sensor-class breakdown, archive map or terrain-matched network table is unnecessary for the manuscript's current claims.

### S4.2 How much do the station checks affect the reported errors?

Retain a focused selection comparison. This is necessary because the main selection uses ERA5-standard discrepancies—the quantity being evaluated. The Swiss example supports a metadata contribution at some sites; it does not establish that every rejected station has an incorrect reference.

Use one compact table comparing the primary selection with selection based on accepted coverage alone, keeping observation-level exclusions and the three conversions' common inputs. Report median individual |error| and p95 for all three conversions. Station |bias| need not be repeated here unless it changes the interpretation.

The new candidate-replacement process changes how this comparison must be constructed. Within each cell represented by the primary sample, replay the same candidate order and choose the first coverage-qualified station for the relaxed case. The primary case chooses the first station passing all station checks. This holds the represented cells fixed and preserves one station per cell; station identities may differ. The required candidates were already assessed by the primary run, so this comparison can use cached observations and ERA5 inputs. It is an analysis of selection dependence, not another production processing stage.

Do not carry forward the old “all eligible / step-noise only / screened” table without recomputation: it was generated under a different sampling process. Retaining just the primary and coverage-only cases directly answers the manuscript's statement about relaxing station screening. The result must determine whether the current claims about central errors, tails and conversion ranking remain appropriate.

## S5 Flight-height weighting

The two existing flight-weight sections belong together here. They support the Discussion's statement that the bird-weighted result describes a particular height distribution and that some height-specific tails depend on weighting.

### S5.1 Constructing the bird-height summary

Give a short account of which tags and flight records contribute, how sampling intervals represent flight time, and how heights are estimated and assigned to bands. Retain the material pressure-offset and height-limit assumptions. The combined weighted error distribution determines the reported median; band medians are not averaged. Main Figure 4c already shows the biological height distribution, so do not add another display of those weights.

### S5.2 Dependence on weighting and coverage

Use the new within-band equal-station weighting as the primary reference. Compare equal sounding weights within stations and a minimum number of contributing soundings per station–band. For the biological target, compare pooled flight-time weighting with equal-tag weighting and longer-flight records. Keep only variants that address these named questions; combined duration/low-height filters and raw implementation stress tests can remain with the code.

Aim for one compact table of bird-weighted median absolute errors across the three conversions. If the Discussion retains a statement about height-specific tail sensitivity, give a numerical example of p95 with its contributing coverage; an overall bird-weighted median cannot demonstrate that claim. The existing 4–5 km example can be reused only after recomputation and checking that it remains informative. These tests must use the new IGRA sample and primary weights, rather than relabelling old sensitivity results.

## What to remove from the supplement

| Existing material | Recommendation and reason |
|---|---|
| Ground individual-error table | Removed. The main ground figure and Results already communicate these errors; exact numerical values remain in the data. |
| Full-height flight-error table | Removed. It contains different metrics from Figure 4, but need not repeat the quoted individual-error results in a second publication display. Full-height errors and support counts remain in the data. |
| Choice of ground observation year | Remove. The new process searches complete 12-month windows with monthly coverage; the previous partial-calendar-year comparison does not evaluate this method. Recency is explained in S1. |
| Reference-dependence network/terrain table | Remove. Cross-network similarity does not measure the effect of assimilation. |
| Nearby-station density table | Remove. Neighbour counts do not establish whether evaluated observations were assimilated. |
| Provenance/transition paragraph | Remove from publication prose. Dataset and analysis records remain with the code. |
| Repeated biological-height distribution | Do not add. Main Figure 4c provides it. |

The assimilation limitation remains in the main Discussion. Removing weak proxy analyses does not remove that limitation or turn GNSS/MeteoSwiss into independent validation datasets.

## Alignment with the main manuscript

| Manuscript statement | Supporting location |
|---|---|
| Published pressure-sensor heights explain part of the offset at matched Swiss sites | S4.1, height-only paired figure |
| Ground errors are similar in magnitude at references with more explicit sensor-height information | S4.1, compact GNSS/MeteoSwiss table; descriptive comparison |
| Ground errors depend on residual-based station selection | S4.2, primary versus coverage-only comparison |
| Alternative reference and biological weights preserve the main flight conclusion, if confirmed by the rebuild | S5.2, weighting comparison |
| The overall bird-weighted value describes the sampled flight-time height distribution | S5.1 and main Figure 4c |
| Location error can affect weather annotation and individual queries | Renumbered S6, existing position experiment |

Main-text pointers for complementary ground references and selection remain S4. Pointers for alternative flight/biological weights move to S5; the position experiment moves to S6. The obsolete S1 pointers attached to quoted flight p95 values have already been removed with the two supplementary error tables. The quoted values and their underlying CSVs remain available.

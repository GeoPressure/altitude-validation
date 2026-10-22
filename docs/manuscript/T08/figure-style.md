# T08 — Figure design standard

Established from the author's direction on 18 October 2026. This is the working standard for the main manuscript and supplement. Individual figure layouts will be reviewed next, starting with Figure 1. Figure 1 has now been implemented with this standard; the remaining main figures have the new conversion colours and retain their existing layouts pending individual review.

## Visual intent

Scientific, modern and restrained: the result is immediately visible, with the empirical variation available underneath. A white background, quiet axes and limited colour leave the data and comparison in charge. No titles, subtitles or narrative paragraphs inside the artwork. Short panel identifiers, axes with units, direct series labels and precise value annotations are welcome. A factual manuscript caption outside the artwork defines the sample, weighting, summaries and limitations; it should not be needed just to identify a curve.

## Colour and identity

The machine-readable specification is [palette.csv](palette.csv). The author subsequently requested solid lines for all three conversions, distinguished by colour, and thicker lines for reference/truth profiles. `R/palette.R` and the Figure 1 source implement this revision. The existing palette preview and exported figures still show the previous design until regenerated. Dataset/product colours in this specification remain staged for later reviews.

| Identity | Colour | Redundant encoding | Short direct label |
|---|---|---|---|
| Standard atmosphere | Burnt orange `#C46532` | Solid line | Standard atmosphere |
| ERA5, standard lapse rate | Blue `#315B91` | Solid line | ERA5 · standard lapse |
| ERA5, virtual temperature + GPT3 | Teal `#007F86` | Solid line | ERA5 · virtual + GPT3 |
| Observed radiosonde profile | Blue `#3B6FB6` | Thicker solid reference path | Observed radiosonde |

Teal identifies the evaluated virtual-temperature/GPT3 conversion; it does not mean every teal result is superior. Preserve the identity when the difference is small, absent or reversed. Use the same stroke weight for the main comparison curves; emphasis comes from selective annotations, restrained supporting marks and label placement.

Dataset colours are HadISD blue `#3B6FB6`, GNSS purple `#7E57C2`, IGRA2 ochre `#B87816` and MeteoSwiss rose `#B74763`, with distinct shapes. Blue therefore means radiosonde observations in a profile comparison and HadISD in a dataset map; these are separate encodings and need explicit labels. In a conversion comparison, colour always identifies conversion: identify datasets with facets or position, rather than mixing both colour systems. ERA5 single-levels uses charcoal and ERA5-Land burnt orange `#C46532` in product-only comparisons.

Use colour for one variable per panel. Bias and SD usually have separate panels and neutral axis labels; they should not gain additional competing colours. Climate and season should usually use facets or line style in a single-conversion plot. Existing climate palettes and secondary fitted-variant colours need a separate audit when those figures are reviewed; do not let a fitted variant inherit the teal identity of the specific GPT3 conversion. For signed maps, use a blue–light-neutral–orange diverging scale centred at zero, with symmetric limits when the comparison calls for them. Magnitudes use one sequential hue.

## Empirical detail, summaries and uncertainty

- Draw observations first, with small points and approximately 0.08–0.20 opacity; draw summaries last at full opacity. Tune opacity to the actual density and printed size. Use transparent station points behind a station summary when those are the relevant empirical units. Connected profiles and curves use lines without overlaid point symbols.
- A connected line is appropriate for an ordered height, time or temperature profile. Use points and intervals for unordered conversion/dataset categories. Do not add a fitted smoother solely for appearance; join existing height-bin summaries explicitly and retain their bin centres.
- Preserve the full observed distribution where feasible. For heavy overplotting, use density/binning or a documented deterministic display sample. A display sample must not change the numerical summaries; record the display rule, especially if sampling would obscure the tails. Raw point density is not the same as a cell-weighted distribution.
- Prefer a light empirical layer plus one central summary and, where informative, one spread band. Use approximately 0.10–0.16 fill opacity and avoid stacking several opaque bands. Use separate panels or outline bounds when bands overlap heavily.
- State what every band means: station IQR, observation quantiles or a genuine uncertainty interval. An IQR is not a confidence interval. Observed between-station spread and estimated uncertainty should not look interchangeable.
- Keep tails and sparse-height support inspectable. Do not crop extremes silently or imply equal support at all heights. Put support counts/coverage in a compact companion panel or supplement if they materially affect interpretation.

## Labels and key results

- Label a curve beside its end or in adjacent empty space. Match label colour and line identity, use a short connector only when needed, and reserve room inside the export bounds. Do not force labels onto densely overlapping curves: use a small shared key within an empty panel margin when that is clearer.
- Use at most one focal numerical comparison per panel, with a short label such as `Median |error| 5.9 m`. A thin connector, dot or bracket locates the value on the corresponding evidence. Keep all three conversions readable even when one comparison receives emphasis.
- Bind labels to the analysis table used by the plot. Report a sensible precision, keep signs for bias and give units. A reduction percentage needs an explicit baseline and denominator; an absolute value is often clearer.
- An annotation must refer to the displayed statistic and population. The primary flight-time-weighted median absolute errors are 21.8, 7.4 and 5.9 m. They describe individual errors and cannot be attached as though they were values on a median station-bias curve. The accepted revision keeps these summaries in the manuscript text.
- Do not repeatedly annotate every panel or every series. A direct label may already do the job. Put dates, site names, selection rules and detailed class counts in the caption/supplement unless essential to interpreting the panel.

## Typography, geometry and export

Use Helvetica Neue when available, otherwise a consistent sans-serif fallback. At the final manuscript size, start with 9–10 pt axis ticks/direct labels, 10–11 pt axis labels and 11 pt bold lower-case panel letters. Avoid text below 8 pt. Use short sentence-case labels, explicit units and few meaningful ticks. Keep zero visible for signed errors. Nonlinear scales must remain conspicuous and interpretable.

Use about 0.7 mm for conversion/summary curves and 1.1 mm for reference/truth profiles, 0.30 mm for annotation connectors, 0.35 mm for a zero/benchmark line and 0.20–0.25 mm for sparse major grids. These are ggplot linewidth units, not typographic points. Remove minor grids and enclosing panel borders unless they improve alignment. No decorative shadows, gradients, heavy boxes or coloured panel backgrounds.

Design around the actual placement width: approximately 178 mm for the current two-column/full-width figures and approximately 85 mm for a single column. Keep scales aligned across comparable small multiples. A map can retain a compact marker key because labelling thousands of stations directly would obscure geography. Prefer vector PDF for manuscript placement, plus a white-background 300 dpi PNG preview; use raster empirical layers only where file size requires them, retaining vector labels and summaries where practical.

## Initial audit and figure review order

This is a source-level audit of `scripts/19_paper_figures.R`, `scripts/17_figures.R` and the manuscript inclusions. Rendered final-size, grayscale and colour-vision checks are recorded per implementation.

| Figure | Main opportunity | Data and interpretation to preserve |
|---|---|---|
| 1: column temperature | Replace the large annotation block and long facet headers with direct profile labels, observed sonde points and one anchored height-error comparison. | These curves show local temperature profiles, not the pressure-weighted column mean in the equations. Explain that distinction, and the link from integrated temperature assumptions to height error, in the caption. Retain the deterministic sounding-selection rule outside the artwork. |
| 2: station coverage | Quiet map background, clear dataset markers, compact in-figure key with counts. | True coordinates, reference membership, realised station counts and geographic gaps. This figure supplies coverage rather than a forced performance takeaway. |
| 3: ground errors | Lead with a visually framed distribution of hourly observation errors; group station bias and within-station scatter beneath it. Use compact horizontal boxplots, a white median dot, and a conversion legend above. | Hourly errors describe individual reports; station summaries separate persistent offsets from temporal scatter. Explain the shared pseudo-log scale and its 1 m transition parameter; boxes show weighted IQRs and whiskers the weighted 10–90% ranges. |
| 4: flight errors and bird heights | Empirical station-by-height context, clearly separated conversion curves, numeric bird-height guides, with the flight-time-weighted median absolute error reported in the text. | Station summaries differ from pooled flight-time-weighted errors. Keep height relative to sounding surface distinct from terrain clearance. The current 0–4 km display must identify/expose the remaining tail, which enters the full-range weighted result. |
| 5: climate and season | Consistent strokes, fewer repeated labels, one targeted bias annotation if supported, and visible support where needed. | Climate/season contrasts, common scales and sparse upper-height support; do not select only the most dramatic example. |
| Supplement | Apply the same typography, identities and empirical/summary hierarchy; review each figure's question. | In particular: paired Swiss stations, a visible 1:1 temperature-error benchmark, product identity, day/night contrasts and distinct fitted-formula variants. |

## Implementation check for each figure

1. Agree on the one comparison the reader should see first and the relevant metric/reference/weighting.
2. Select empirical grain, summary and support from the existing analysis tables; identify any genuinely missing plotting data before changing analysis code.
3. Implement its layout and data-driven annotation, then update the factual caption and shared code definitions together.
4. Inspect the PDF/PNG at intended placement size; check labels, connectors, clipping, grayscale and common colour-vision deficiencies. The three conversion curves use solid lines distinguished by colour, with direct labels where possible; reference/truth profiles are thicker. Shapes can distinguish isolated estimates.
5. Verify annotation values against the same analysis rows, band meanings, weighting, axis limits and any display sampling. Preserve scientific conclusions unless the evidence justifies changing them.

**T08 status, 18 October 2026:** Closed at the author's request with no further figure work for now. The shared visual standard, palette, Figure 1 implementation and conversion-colour update to the other figures remain the completed deliverables. Figure-specific redesigns and final-size/grayscale/colour-vision checks are deferred; closing T08 records the current stopping point and does not claim those future reviews were completed.


**19 October revision:** The author requested clearer separation of standard atmosphere and ERA5: conversion colours are now orange, blue and teal. Figure 3 retains its three-panel layout with thick IQR segments and thin 10–90% segments; Figure 4 uses 250 m observed-height bands, solid curves, distinct point shapes and translucent IQRs for every conversion. Flight-time-weighted metrics remain in the text.


**22 October revision:** Connected curves and reference profiles use lines only, with no overlaid point symbols. Colour identifies conversions; reference measurements retain a thicker line. Scatterplots, station maps and isolated distribution summaries can retain their necessary points. The Figure 1 draft uses shared row and column headers, externally sourced Lucide icons, vertical arrows, and no panel letters; summer/winter labels appear once above their columns.


**22 October implementation:** The approved Figure 1 combines a stationary pressure record and inferred altitude errors with two sounding profiles and their flight-height errors. Its shared row/column headers, Lucide icons, arrows, single-row legend and line-only curves are generated by `scripts/23_figure1.R`, called from `scripts/19_paper_figures.R`. Reference lines use 0.85 mm and conversion lines 0.7 mm. Figure 4 retains its station summaries and bands with line-only curves; the caption now describes lines rather than lines and points.

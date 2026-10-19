# T08 — Figure 1 implementation

Figure 1 now separates the observed/assumed temperature profiles from the resulting surface-referenced height error at the sonde level nearest 2 km. It retains exactly the two soundings chosen by the original deterministic rule. No reference selection, conversion formula or numerical result was changed.

Observed sonde levels are open blue points with a thin translucent path. The model profiles use slate/dotted, charcoal/long-dashed and teal/solid strokes and direct labels, with common temperature/height axes. A separate aligned error strip shows each sounding's three signed height errors as isolated markers connected to zero, with values bound to the same analysis rows. These segments are not uncertainty intervals. Class labels replace the former site/date facet headers, and the selection explanation is in S5 rather than inside the artwork. The caption explicitly distinguishes measured air temperature from the effective virtual-temperature profile.

The summer errors remain −104.23, −5.90 and +16.56 m; the winter errors remain +82.84, −46.01 and −16.37 m (standard atmosphere, ERA5 standard and virtual/GPT3). The counterexample in summer is retained. The shared conversion colours also update the other main figures; their layouts remain unchanged pending individual review.

Implementation: `scripts/19_paper_figures.R`, `R/palette.R`, the main Figure 1 caption and S5. `FIGURE_ONLY=1 Rscript scripts/19_paper_figures.R` rebuilds Figure 1 alone; a normal run rebuilds all main graphics. PDF and 300 dpi PNG exports are retained. The palette specification is in `palette.csv`.

Visual verification includes the PNG, a grayscale rendering and the figure placed on the manuscript PDF page. Line styles, point shapes, labels and error values remain readable without colour. A dedicated colour-vision-deficiency simulation has not been run. The remaining figures still need the full T08 layout review.

## Subsequent author revision

The plotting source now uses solid lines for all three conversions and a thicker observed radiosonde path (1.1 mm versus 0.7 mm for conversions). The previous implementation and visual checks above describe the earlier export. Figures and the manuscript have not been rebuilt for this revision.

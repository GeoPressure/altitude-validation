# T10 — Location-displacement pilot implementation

The fixed-seed pilot is complete for a layer near 2 km at ten climate/roughness-stratified IGRA2 stations and 80 seasonal soundings. The reproducible extraction, cache, aggregate results, station/direction summaries and source fingerprints accompany the experiment. The pilot holds pressure, time and reference height fixed and shifts the atmospheric query location from 0 to 200 km.

The S6 figure reports pooled MAE and error SD separately for absolute altitude and surface-referenced height, with faint station traces and direct pooled labels. At 50 km, virtual/GPT3 MAE rises by 0.6 m and 0.5 m, respectively, while the paired-change 95th percentiles are 21.1 m and 22.6 m. At 200 km, MAE rises by 4.6 m and 2.2 m. These descriptive pilot results do not establish a generally acceptable location-error radius or quantify terrain-clearance uncertainty.

The main and supplementary manuscripts render successfully to PDF and HTML. The PDF S6 figure and caption were checked at final page size. `git diff --check` and R parsing for both experiment scripts pass. Rerun `Rscript docs/methods/T10/run_experiment.R` to refresh the cached experiment and `Rscript docs/methods/T10/plot_experiment.R` to regenerate figures from the saved summary tables.

# Run from the repository root: Rscript run_all.R analysis figures check
# Preparation reuses station caches; errors explicitly recomputes conversions.
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) args <- "analysis"
steps <- list(
  ground_selection = "sampling/ground_selection.R",
  sounding_selection = "sampling/sounding_selection.R",
  prepare = c("preparation/station_covariates.R", "preparation/era5_land.R", "preparation/errors.R"),
  errors = "preparation/errors.R",
  birds = "preparation/bird_heights.R",
  analysis = c("analysis/reference_summaries.R", "analysis/environmental_variation.R",
    "analysis/conversion_comparison.R", "analysis/bird_weighting.R",
    "preparation/figure1_examples.R"),
  position = "analysis/position_sensitivity.R",
  figures = c("figures/fig1_column.R", "figures/fig2_stations.R", "figures/fig3_ground.R",
    "figures/fig4_flight.R", "figures/fig5_conditions.R", "figures/supp_variation.R",
    "figures/supp_land.R", "figures/supp_bird_heights.R", "figures/supp_position.R"),
  check = c("checks/validate_ground_pressure.R", "checks/validate_analysis.R")
)
args <- unlist(lapply(args, function(stage) if (stage == "all") c("ground_selection", "sounding_selection", "prepare", "analysis", "figures", "check") else stage))
stopifnot(all(args %in% c(names(steps), "render")))
for (stage in args) {
  if (stage == "render") {
    if (system2("bash", "paper/render.sh") != 0) stop("Document render failed", call. = FALSE)
    next
  }
  if (stage %in% c("prepare", "errors", "birds", "analysis")) unlink("output/tables/selection_analysis_complete.json")
  for (script in steps[[stage]]) {
    cli::cli_alert_info("Running {script}")
    started <- Sys.time()
    script_args <- c(file.path("scripts", script), if (stage == "errors") "--refresh", if (stage == "ground_selection") c("terrain", "primary"))
    if (system2("Rscript", script_args) != 0) stop(script, " failed", call. = FALSE)
    cli::cli_alert_success("{script}: {round(as.numeric(difftime(Sys.time(), started, units = 'secs')))} seconds")
  }
}

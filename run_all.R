# Run from the repository root: Rscript run_all.R analysis figures check
# Preparation reuses station caches; errors explicitly recomputes conversions.
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) args <- "analysis"
steps <- list(
  prepare = c("preparation/station_covariates.R", "preparation/era5_land.R", "preparation/errors.R"),
  errors = "preparation/errors.R",
  analysis = c("analysis/reference_summaries.R", "analysis/environmental_variation.R",
    "analysis/conversion_comparison.R", "analysis/bird_weighting.R", "analysis/selection_sensitivity.R",
    "preparation/figure1_examples.R"),
  figures = c("figures/supplement.R", "figures/figure1.R", "figures/figure2.R", "figures/figures3_5.R"),
  figure1 = "figures/figure1.R", figure2 = "figures/figure2.R",
  check = "checks/validate_analysis.R"
)
if ("all" %in% args) args <- c("prepare", "analysis", "figures", "check")
stopifnot(all(args %in% c(names(steps), "render")))
for (stage in args) {
  if (stage == "render") {
    if (system2("bash", "paper/render.sh") != 0) stop("Document render failed", call. = FALSE)
    next
  }
  if (stage %in% c("prepare", "errors", "analysis")) unlink("output/tables/selection_analysis_complete.json")
  for (script in steps[[stage]]) {
    cli::cli_alert_info("Running {script}")
    started <- Sys.time()
    script_args <- c(file.path("scripts", script), if (stage == "errors") "--refresh")
    if (system2("Rscript", script_args) != 0) stop(script, " failed", call. = FALSE)
    cli::cli_alert_success("{script}: {round(as.numeric(difftime(Sys.time(), started, units = 'secs')))} seconds")
  }
}

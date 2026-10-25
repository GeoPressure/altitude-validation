# Rebuild the study. Run from the repository root, e.g.
#   Rscript run_all.R            # results, figures and checks from the cached selections
#   Rscript run_all.R all        # everything, including station selection (downloads data)
#   Rscript run_all.R figures render
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  args <- c("results", "figures", "check")
}
a <- function(x) file.path("analysis", x)
stages <- list(
  selection = a(c(
    "01_candidates.R",
    "02_select_ground.R",
    "03_select_soundings.R",
    "04_station_covariates.R"
  )),
  errors = a("05_conversion_errors.R"),
  birds = a("06_bird_heights.R"),
  results = a(c(
    "07_ground_results.R",
    "08_flight_results.R",
    "09_position_sensitivity.R",
    "10_figure1_examples.R",
    "11_manuscript_values.R"
  )),
  figures = a(file.path(
    "figures",
    c(
      "fig1_column.R",
      "fig2_stations.R",
      "fig3_ground.R",
      "fig4_flight.R",
      "fig5_conditions.R",
      "supp_variation.R",
      "supp_land.R",
      "supp_bird_heights.R",
      "supp_position.R"
    )
  )),
  check = file.path(
    "tests",
    c("test_pressure_spikes.R", "check_selection.R", "check_results.R")
  )
)
if ("all" %in% args) {
  args <- c(
    "selection",
    "errors",
    "birds",
    "results",
    "figures",
    "check",
    "render"
  )
}
stopifnot(all(args %in% c(names(stages), "render")))
for (stage in args) {
  if (stage == "render") {
    if (system2("bash", "manuscript/render.sh") != 0) {
      stop("Rendering failed", call. = FALSE)
    }
    next
  }
  for (script in stages[[stage]]) {
    cli::cli_alert_info("Running {script}")
    started <- Sys.time()
    if (
      system2("Rscript", c(script, if (stage == "errors") "--refresh")) != 0
    ) {
      stop(script, " failed", call. = FALSE)
    }
    cli::cli_alert_success(
      "{script}: {round(as.numeric(difftime(Sys.time(), started, units = 'secs')))} s"
    )
  }
}

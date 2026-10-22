# Recompute the manuscript from the frozen completed selections.
# Rscript run_all.R          # input enrichment, analysis, figures and documents
# Rscript run_all.R 12       # reuse the prepared error series
# Rscript run_all.R 18       # primary summaries, focused checks and figures
# Rscript run_all.R 19 19    # manuscript figures only
args <- as.integer(commandArgs(trailingOnly = TRUE))
from <- if (length(args)) args[1] else 7L
to <- if (length(args) >= 2) args[2] else 22L
steps <- c("07_static.R", "08_era5_extract.R", "09_errors.R", "12_analysis.R",
  "15_variation.R", "18_three_formulas.R",
  "20_paper_sensitivity.R", "21_selection_sensitivity.R", "17_figures.R",
  "19_paper_figures.R", "22_validate_analysis.R")
num <- as.integer(substr(steps, 1, 2))
if (from <= 18) unlink("output/tables/selection_analysis_complete.json")
for (s in steps[num >= from & num <= to]) {
  cli::cli_alert_info("Running {s}")
  t0 <- Sys.time()
  if (system2("Rscript", file.path("scripts", s)) != 0) stop(s, " failed", call. = FALSE)
  cli::cli_alert_success("{s}: {round(as.numeric(difftime(Sys.time(), t0, units = 'secs')))} seconds")
}
if (to >= 22) {
  if (system2("bash", "paper/render.sh") != 0) stop("Document render failed", call. = FALSE)
}

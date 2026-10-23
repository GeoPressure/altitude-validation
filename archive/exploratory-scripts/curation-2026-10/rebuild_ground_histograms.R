# Rebuild the full ground histogram comparison with independent terrain QC.
for (step in list(c("scripts/preparation/ghcnh_terrain.R"),
  c("scripts/sampling/ground_selection.R", "terrain", "primary"),
  c("scripts/drafts/ground_histograms.R", "terrain"),
  c("scripts/checks/validate_ground_histograms.R"))) {
  cli::cli_alert_info("Running {paste(step, collapse = ' ')}")
  if (system2("Rscript", step) != 0) stop("Ground histogram rebuild failed", call. = FALSE)
}

# Check whether any pressure rule can be dropped without changing selected years.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/ghcnh_pressure_patterns.R")
setDTthreads(1)
out <- "output/drafts/pattern-application"
stations <- fread(file.path(out, "previous_accepted.csv"))
settings <- readRDS("data/interim/ghcnh/selection-2026-10-13/settings.rds")
calendar <- ghcnh_pressure_calendar(settings)
results <- list()
for (i in seq_len(nrow(stations))) {
  s <- stations[i]
  d <- ghcnh_pressure_spikes(as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/pressure", paste0(s$id, ".parquet")))))
  legacy <- ghcnh_pressure_episodes(d)
  patterns <- ghcnh_pressure_patterns(d)$episodes
  episodes <- rbind(legacy, patterns)
  baseline <- ghcnh_pressure_window(d, settings, calendar = calendar, episodes = episodes)
  baseline_end <- if (is.null(baseline)) as.Date(NA) else baseline$end
  for (rule in c("noise", "irregularity", "jump", "step", "frozen")) {
    selected <- if (rule %in% episodes$reason) ghcnh_pressure_window(d, settings, calendar = calendar, episodes = episodes[reason != rule]) else baseline
    selected_end <- if (is.null(selected)) as.Date(NA) else selected$end
    results[[length(results) + 1L]] <- data.table(id = s$id, rule = rule, baseline_end = baseline_end, without_rule_end = selected_end,
      changed = is.na(baseline_end) != is.na(selected_end) || (!is.na(baseline_end) && !is.na(selected_end) && baseline_end != selected_end))
  }
  if (i %% 250 == 0) cli::cli_alert_info("Compared rule omissions for {i}/{nrow(stations)} stations")
}
d <- rbindlist(results)
fwrite(d, file.path(out, "rule_ablation_years.csv"))
fwrite(d[, .(changed_station_years = sum(changed)), by = rule], file.path(out, "rule_ablation_summary.csv"))
print(d[, .(changed_station_years = sum(changed)), by = rule])

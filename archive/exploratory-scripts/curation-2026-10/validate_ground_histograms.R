# Check terrain eligibility, sampling units and histogram weights.
source("R/utils.R")
library(lubridate)
out <- "output/drafts/atmospheric-figures"
s <- fread(file.path(out, "ground_terrain_window_selection.csv"))
s <- s[nzchar(id) & !is.na(start)]
g <- fread(file.path(out, "ground_terrain_window_stations.csv"))
t <- fread(file.path(out, "ground_terrain_candidates.csv"))
h <- fread(file.path(out, "ground_terrain_window_observation_hist.csv"))
m <- fread(file.path(out, "ground_terrain_window_observation_medians.csv"))
exclusions <- fread("docs/methods/ghcnh_reference_exclusions.csv")
stopifnot(!anyDuplicated(s$cell), !anyDuplicated(s$id), all(s$start == s$end %m-% years(1)),
  !any(s$id %in% exclusions$id),
  all(s$n_spikes >= 0),
  all(t[id %in% s$id]$terrain_ok), nrow(t[id %in% s$id]) == nrow(s),
  all(g[, .N, by = id]$N == 3), all(g[, uniqueN(n), by = id]$V1 == 1), setequal(s$id, g$id), all(g$n > 0), all(g$cw == 1),
  all(abs(h[, sum(percent), by = formula]$V1 - 100) < 1e-8),
  all(abs(h[, sum(weight), by = formula]$V1 - nrow(s)) < 1e-8), all(m$q50 >= 0))
previous <- fread(file.path(out, "ground_pressure_window_selection.csv"))
paired <- merge(previous, s, by = "cell", suffixes = c("_before", "_after"), all = TRUE)
old <- fread(file.path(out, "ground_pressure_window_stations.csv"))[formula == "standard"]
new <- g[formula == "standard"]
metrics <- data.table(stations = nrow(s), isolated_spikes_removed = sum(s$n_spikes), stations_with_spikes = sum(s$n_spikes > 0), changed_cells = paired[!is.na(id_before) & !is.na(id_after) & id_before != id_after, .N],
  former_stations_failing_terrain = t[id %in% old$id & !terrain_ok, .N],
  old_bias_above50 = old[abs(bias) > 50, .N], new_bias_above50 = new[abs(bias) > 50, .N],
  old_bias_above100 = old[abs(bias) > 100, .N], new_bias_above100 = new[abs(bias) > 100, .N])
fwrite(metrics, file.path(out, "ground_terrain_rebuild_checks.csv"))
fwrite(paired, file.path(out, "ground_terrain_selection_changes.csv"))
print(metrics)
cli::cli_alert_success("Independent reference exclusions, terrain eligibility, station/cell uniqueness, shared observations and histogram weights passed")

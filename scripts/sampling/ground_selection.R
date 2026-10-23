# Rebuild the histogram inputs using pressure-only backwards-window selection.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/ghcnh_terrain.R")
source("R/ghcnh_consistency.R")
terrain_screen <- "terrain" %in% commandArgs(trailingOnly = TRUE)
primary <- "primary" %in% commandArgs(trailingOnly = TRUE)
prefix <- if (terrain_screen) "ground_terrain_window" else "ground_pressure_window"
load_geopressurer()
setDTthreads(1)
cores <- max(1L, parallel::detectCores() - 2L)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
settings <- readRDS(file.path(run_dir, "settings.rds"))
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
catalogue <- rbindlist(lapply(list.files(file.path(run_dir, "catalogue"), full.names = TRUE), readRDS))
old_stations <- fread("output/tables/stations.csv")[network == "ghcnh"]
exclusions <- if (terrain_screen) fread("inputs/ghcnh_reference_exclusions.csv") else data.table(id = character())
review_exclusions <- if (terrain_screen) fread("inputs/ghcnh_review_exclusions.csv") else data.table(id = character())
if (terrain_screen) {
  cli::cli_alert_info("Excluding {nrow(exclusions)} stations with independent reference conflicts and {nrow(review_exclusions)} after manual review")
  cached <- tools::file_path_sans_ext(list.files(file.path(run_dir, "pressure"), pattern = "parquet$"))
  terrain <- ghcnh_terrain(candidates[id %in% cached])
}
calendar <- ghcnh_pressure_calendar(settings)

# Station-data selection of one cell; ERA5 is not consulted here.
select_cell <- function(cell_id) {
  attempts <- list()
  ids <- candidates[cell == cell_id][order(candidate_order)]$id
  for (k in seq_along(ids)) {
    s <- candidates[id == ids[k]]
    excluded <- if (s$id %in% exclusions$id) "reference_exclusion" else if (s$id %in% review_exclusions$id) "review_exclusion" else NA
    if (!is.na(excluded)) {
      attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id, reason = excluded)
      next
    }
    if (terrain_screen) {
      check <- terrain[id == s$id]
      # Terrain lookups are batched between passes; report the cell's remaining unchecked candidates.
      if (!nrow(check)) return(list(cell = cell_id, terrain_needed = setdiff(ids[k:length(ids)], c(terrain$id, exclusions$id, review_exclusions$id))))
      if (!check$terrain_ok) {
        attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id, reason = "terrain")
        next
      }
    }
    o <- ghcnh_pressure(s, settings, catalogue, run_dir)
    spike_dates <- o$date[0]
    if (terrain_screen) {
      cleaned <- ghcnh_pressure_spikes(o)
      spike_dates <- o$date[!o$date %in% cleaned$date]
      o <- cleaned
    }
    consistency_check <- NULL
    if (terrain_screen) {
      x <- ghcnh_consistency_inputs(o, ghcnh_reference(s, settings, catalogue, run_dir), s)
      # A reference-height conflict over the full record rejects every year of the station.
      full <- ghcnh_consistency(x, s)
      consistency_check <- if (full$reason == "reference_height") function(rows, bounds) full else
        function(rows, bounds) ghcnh_consistency(x[rows], s, bounds)
    }
    selected <- ghcnh_pressure_window(o, settings, calendar = calendar, check = consistency_check)
    attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id,
      reason = selected$consistency$reason %||% "accepted")
    if (is.null(selected$hours)) next
    selected$n_spikes <- sum(spike_dates >= as.POSIXct(selected$start, tz = "UTC") & spike_dates < as.POSIXct(selected$end, tz = "UTC"))
    return(list(cell = cell_id, station = s, selected = selected, attempts = rbindlist(attempts)))
  }
  list(cell = cell_id, attempts = rbindlist(attempts))
}

# Parallel passes over cells; candidates new to the terrain cache are looked up in batches between passes.
results <- list()
pending <- sort(unique(candidates$cell))
repeat {
  out <- parallel::mclapply(pending, function(cell_id) tryCatch(select_cell(cell_id), error = function(e)
    list(cell = cell_id, error = conditionMessage(e))), mc.cores = cores, mc.preschedule = FALSE)
  failed <- Filter(function(r) !is.null(r$error), out)
  if (length(failed)) stop("Selection failed in cell ", failed[[1]]$cell, ": ", failed[[1]]$error)
  waiting <- Filter(function(r) !is.null(r$terrain_needed), out)
  for (r in Filter(function(r) is.null(r$terrain_needed), out)) results[[r$cell]] <- r
  cli::cli_alert_info("Selection pass: {length(results)} cells complete, {length(waiting)} waiting for terrain checks")
  if (!length(waiting)) break
  terrain <- rbind(terrain, ghcnh_terrain(candidates[id %in% unlist(lapply(waiting, `[[`, "terrain_needed"))]))
  pending <- vapply(waiting, `[[`, "", "cell")
}
results <- results[sort(names(results))]
accepted <- Filter(function(r) !is.null(r$selected), results)
cli::cli_alert_success("Selected {length(accepted)} stations in {length(results)} cells")

# ERA5 inputs are matched only after selection; missing series are fetched in socket workers.
missing <- Filter(function(r) !file.exists(file.path(run_dir, "core", paste0(r$station$id, ".parquet"))), accepted)
cli::cli_alert_info("Fetching ERA5 inputs for {length(missing)} newly selected stations")
res <- par_map(lapply(missing, `[[`, "station"), function(s) {
  source("R/ghcnh_sampling.R")
  ghcnh_core(s, settings, run_dir, old_stations)
  TRUE
}, cores = min(cores, 6L), geopressurer = TRUE, export = c("settings", "run_dir", "old_stations"))
check_failures(res, vapply(missing, function(r) r$station$id, ""), "ERA5 series", fatal = TRUE)
core <- lapply(accepted, function(r) ghcnh_core(r$station, settings, run_dir, old_stations))

gpt3 <- gpt3_read(1)
selection_parts <- list()
station_parts <- list()
hist_parts <- list()
error_parts <- list()
accepted_parts <- list()
primary_dir <- "data/interim/ghcnh/selection-curated-2026-10-22"
if (primary) {
  unlink(file.path(primary_dir, "accepted"), recursive = TRUE)
  dir.create(file.path(primary_dir, "accepted"), recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(dir_tables, "selection_analysis_complete.json"))
}
for (r in results) {
  selected <- r$selected
  s <- r$station
  selection_parts[[length(selection_parts) + 1L]] <- data.table(cell = r$cell,
    id = if (is.null(selected)) NA_character_ else s$id,
    start = if (is.null(selected)) as.Date(NA) else selected$start,
    end = if (is.null(selected)) as.Date(NA) else selected$end,
    n_spikes = if (is.null(selected)) 0L else selected$n_spikes)
  if (is.null(selected)) next
  d <- merge(selected$hours, core[[r$cell]], by = "date", all.x = TRUE)
  stopifnot(nrow(d) == nrow(selected$hours), all(is.finite(d$sp_sl)), all(is.finite(d$t2m_sl)),
    all(is.finite(d$d2m)), all(is.finite(d$z_sl)))
  d[, err_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
  L <- gpt3_lapse(gpt3, rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), as.POSIXlt(d$date, tz = "UTC")$yday + 1)
  L <- fifelse(abs(L) < 1e-5, -1e-5, L)
  d[, err_isa := altitude_lapse(pressure * 100, 101325, 288.15, 0) - s$elev]
  d[, err_standard := err_sl]
  d[, err_virtual := altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - s$elev]
  if (primary) {
    ghcnh_write(d, file.path(primary_dir, "accepted", paste0(s$id, ".parquet")))
    accepted_parts[[length(accepted_parts) + 1L]] <- cbind(s, data.table(window_start = selected$start,
      window_end = selected$end, accepted_hours = nrow(d), n_spikes = selected$n_spikes,
      height_source = selected$consistency$height_source, height_offset = selected$consistency$height_offset,
      tide_amplitude = selected$consistency$tide_amplitude, tide_lag = selected$consistency$tide_lag))
  }
  error_parts[[length(error_parts) + 1L]] <- d[, .(err_isa, err_standard, err_virtual, w = 1 / .N)]
  for (f in c("isa", "standard", "virtual")) {
    station_parts[[length(station_parts) + 1L]] <- d[, .(id = s$id, cell = r$cell,
      formula = f, n = .N, bias = mean(get(paste0("err_", f))), sd = sd(get(paste0("err_", f))), cw = 1)]
    hist_parts[[length(hist_parts) + 1L]] <- d[, .(weight = .N / nrow(d)),
      by = .(bin = pmin(floor(abs(get(paste0("err_", f))) / 5) * 5, 450))][, formula := f]
  }
}
out <- "output/drafts/atmospheric-figures"
fwrite(rbindlist(selection_parts), file.path(out, paste0(prefix, "_selection.csv")))
fwrite(rbindlist(station_parts), file.path(out, paste0(prefix, "_stations.csv")))
h <- rbindlist(hist_parts)[, .(weight = sum(weight)), by = .(formula, bin)]
h[, percent := 100 * weight / sum(weight), by = formula]
fwrite(h, file.path(out, paste0(prefix, "_observation_hist.csv")))
if (terrain_screen) fwrite(terrain, file.path(out, "ground_terrain_candidates.csv"))
attempts <- rbindlist(lapply(results, `[[`, "attempts"))
fwrite(attempts, file.path(out, paste0(prefix, "_attempts.csv")))
cli::cli_alert_success("Prepared {length(station_parts) / 3} stations with pressure-only backwards selection")
errors <- rbindlist(error_parts)
medians <- rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
  data.table(formula = f, q50 = wquant(abs(errors[[paste0("err_", f)]]), errors$w, .5))
}))
fwrite(medians, file.path(out, paste0(prefix, "_observation_medians.csv")))
if (primary) {
  fwrite(rbindlist(accepted_parts), file.path(primary_dir, "full-accepted.csv"))
  fwrite(data.table(pending = 0L, accepted = length(accepted_parts)), file.path(primary_dir, "full-metrics.csv"))
  saveRDS(c(settings[c("start", "end", "years", "width_m", "seed", "pressure_min", "pressure_max", "days_per_month", "hours_per_day", "hourly_report", "base")],
    list(method = "Independent terrain/reference checks; isolated spikes, large jumps and coverage; reference-height and timestamp consistency from the station's own reports",
      consistency_rules = consistency_rules,
      jump_rules = as.list(formals(ghcnh_pressure_jumps))[-1L])), file.path(primary_dir, "settings.rds"))
  fwrite(rbindlist(selection_parts), file.path(dir_tables, "ground_selection.csv"))
  fwrite(exclusions, file.path(dir_tables, "ground_curation_exclusions.csv"))
  fwrite(review_exclusions, file.path(dir_tables, "ground_review_exclusions.csv"))
  fwrite(h, file.path(dir_tables, "paper_ground_observation_hist.csv"))
  fwrite(attempts[, .(candidates = .N), by = reason], file.path(dir_tables, "ground_selection_outcomes.csv"))
  cli::cli_alert_success("Primary ground selection: {length(accepted_parts)} stations")
}

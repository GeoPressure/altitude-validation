# GHCNh ground stations: in each cell, the first candidate (in random order) with a year of
# pressure that passes the station-only checks. ERA5 is matched only after selection.
source("R/utils.R")
source("R/ghcnh.R")
load_geopressurer()
setDTthreads(1)
cores <- max(1L, parallel::detectCores() - 2L)
run_dir <- network_dir("ghcnh", "candidates")
out_dir <- network_dir("ghcnh", "selection")
settings <- readRDS(file.path(run_dir, "settings.rds"))
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
catalogue <- rbindlist(lapply(settings$years, ghcnh_catalogue, run_dir = run_dir, base = settings$base))
exclusions <- rbind(fread(file.path(dir_curated, "ghcnh_reference_exclusions.csv"))[, .(id, reason = "reference_exclusion")],
  fread(file.path(dir_curated, "ghcnh_review_exclusions.csv"))[, .(id, reason = "review_exclusion")])
cached <- tools::file_path_sans_ext(list.files(file.path(run_dir, "pressure"), pattern = "parquet$"))
terrain <- ghcnh_terrain(candidates[id %in% cached])
calendar <- ghcnh_pressure_calendar(settings)

# Selection in one cell. Candidates are rejected at the first failed step: curated exclusion,
# terrain, then (in ghcnh_pressure_window) coverage, pressure jumps and station consistency.
select_cell <- function(cell_id) {
  attempts <- list()
  ids <- candidates[cell == cell_id][order(candidate_order)]$id
  for (k in seq_along(ids)) {
    s <- candidates[id == ids[k]]
    if (s$id %in% exclusions$id) {
      attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id, reason = exclusions[id == s$id, reason])
      next
    }
    check <- terrain[id == s$id]
    # Terrain lookups are batched between passes; report the cell's remaining unchecked candidates.
    if (!nrow(check)) return(list(cell = cell_id, terrain_needed = setdiff(ids[k:length(ids)], c(terrain$id, exclusions$id))))
    if (!check$terrain_ok) {
      attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id, reason = "terrain")
      next
    }
    raw <- ghcnh_pressure(s, settings, catalogue, run_dir)
    o <- ghcnh_pressure_spikes(raw)
    spike_dates <- raw$date[!raw$date %in% o$date]
    x <- ghcnh_consistency_inputs(o, ghcnh_reference(s, settings, catalogue, run_dir), s)
    # A reference-height conflict over the full record rejects every year of the station.
    full <- ghcnh_consistency(x, s)
    consistency_check <- if (full$reason == "reference_height") function(rows, bounds) full else
      function(rows, bounds) ghcnh_consistency(x[rows], s, bounds)
    selected <- ghcnh_pressure_window(o, settings, calendar = calendar, check = consistency_check)
    attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id,
      reason = selected$consistency$reason %||% "accepted")
    if (is.null(selected$hours)) next
    selected$n_spikes <- sum(spike_dates >= as.POSIXct(selected$start, tz = "UTC") & spike_dates < as.POSIXct(selected$end, tz = "UTC"))
    return(list(cell = cell_id, station = s, selected = selected, attempts = rbindlist(attempts)))
  }
  list(cell = cell_id, attempts = rbindlist(attempts))
}

# Parallel passes over cells; candidates new to the terrain cache are looked up between passes.
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

# ERA5 inputs of the selected stations; missing series are fetched in socket workers.
missing <- Filter(function(r) !file.exists(file.path(run_dir, "core", paste0(r$station$id, ".parquet"))), accepted)
res <- par_map(lapply(missing, `[[`, "station"), function(s) {
  source("R/ghcnh.R")
  ghcnh_core(s, settings, run_dir)
  TRUE
}, cores = min(cores, 6L), geopressurer = TRUE, export = c("settings", "run_dir"))
check_failures(res, vapply(missing, function(r) r$station$id, ""), "ERA5 series", fatal = TRUE)

# Accepted hours with their ERA5 inputs and the three conversion errors.
gpt3 <- gpt3_read(1)
unlink(file.path(out_dir, "accepted"), recursive = TRUE)
dir.create(file.path(out_dir, "accepted"), recursive = TRUE)
stations <- list()
for (r in accepted) {
  s <- r$station
  sel <- r$selected
  d <- merge(sel$hours, ghcnh_core(s, settings, run_dir), by = "date", all.x = TRUE)
  stopifnot(nrow(d) == nrow(sel$hours), all(is.finite(d$sp_sl)), all(is.finite(d$t2m_sl)),
    all(is.finite(d$d2m)), all(is.finite(d$z_sl)))
  d[, err_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
  ghcnh_write(d, file.path(out_dir, "accepted", paste0(s$id, ".parquet")))
  stations[[length(stations) + 1L]] <- cbind(s, data.table(window_start = sel$start,
    window_end = sel$end, accepted_hours = nrow(d), n_spikes = sel$n_spikes,
    height_source = sel$consistency$height_source, height_offset = sel$consistency$height_offset,
    tide_amplitude = sel$consistency$tide_amplitude, tide_lag = sel$consistency$tide_lag))
}
fwrite(rbindlist(stations), file.path(out_dir, "stations.csv"))
attempts <- rbindlist(lapply(results, `[[`, "attempts"))
fwrite(attempts, file.path(out_dir, "attempts.csv"))
saveRDS(c(settings, list(consistency_rules = consistency_rules,
  jump_rules = as.list(formals(ghcnh_pressure_jumps))[-1L])), file.path(out_dir, "settings.rds"))
fwrite(attempts[, .(candidates = .N), by = reason], file.path(dir_tables, "ground_selection_outcomes.csv"))
fwrite(data.table(cells = length(results), spikes_removed = sum(rbindlist(stations)$n_spikes)),
  file.path(dir_tables, "ground_selection_summary.csv"))
cli::cli_alert_success("Ground selection: {length(stations)} stations")

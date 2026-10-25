# IGRA2 sounding sites: in each cell, the first candidate (in random order) with a year of
# self-consistent soundings. ERA5 is matched only after selection.
source("R/utils.R")
source("R/ghcnh.R")
source("R/igra.R")
load_geopressurer()
setDTthreads(1)
cores <- max(1L, parallel::detectCores() - 2L)
run_dir <- network_dir("igra", "candidates")
out_dir <- network_dir("igra", "selection")
settings <- readRDS(file.path(run_dir, "settings.rds"))
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
for (part in c("profiles", "downloads", "core")) dir.create(file.path(run_dir, part), recursive = TRUE, showWarnings = FALSE)

# The first candidate per cell with a qualifying year of consistent soundings.
select_cell <- function(cell_id) {
  attempts <- list()
  for (id_value in candidates[cell == cell_id][order(candidate_order)]$id) {
    s <- candidates[id == id_value]
    o <- igra_profiles(s, settings, run_dir)$levels
    w <- igra_window(o, igra_consistency(o), settings)
    attempts[[length(attempts) + 1L]] <- data.table(cell = cell_id, id = s$id, reason = w$reason)
    if (w$reason == "accepted") return(list(cell = cell_id, station = s, profiles = o, selected = w, attempts = rbindlist(attempts)))
  }
  list(cell = cell_id, attempts = rbindlist(attempts))
}
results <- parallel::mclapply(sort(unique(candidates$cell)), function(cell_id) tryCatch(select_cell(cell_id),
  error = function(e) list(cell = cell_id, error = conditionMessage(e))), mc.cores = cores, mc.preschedule = FALSE)
failed <- Filter(function(r) !is.null(r$error), results)
if (length(failed)) stop("Sounding selection failed in cell ", failed[[1]]$cell, ": ", failed[[1]]$error)
accepted <- Filter(function(r) !is.null(r$selected), results)
cli::cli_alert_success("Selected {length(accepted)} sounding stations in {length(results)} cells")

# ERA5 inputs of the selected sites; missing series are fetched in socket workers.
missing <- Filter(function(r) !file.exists(file.path(run_dir, "core", paste0(r$station$id, ".parquet"))), accepted)
res <- par_map(missing, function(r) {
  source("R/ghcnh.R")
  source("R/igra.R")
  igra_core(r$station, c(r$profiles$date, r$profiles$date_s), run_dir)
  TRUE
}, cores = min(cores, 6L), geopressurer = TRUE, export = "run_dir")
check_failures(res, vapply(missing, function(r) r$station$id, ""), "ERA5 series", fatal = TRUE)

gpt3 <- gpt3_read(1)
unlink(file.path(out_dir, "accepted"), recursive = TRUE)
dir.create(file.path(out_dir, "accepted"), recursive = TRUE, showWarnings = FALSE)
accepted_parts <- list()
for (r in accepted) {
  s <- r$station
  e <- igra_core(s, c(r$profiles$date, r$profiles$date_s), run_dir)
  d <- igra_match(r$selected$levels, e, s, gpt3)
  stopifnot(nrow(d) == nrow(r$selected$levels))
  d[, weight := 1 / .N, by = band]
  ghcnh_write(d, file.path(out_dir, "accepted", paste0(s$id, ".parquet")))
  accepted_parts[[length(accepted_parts) + 1L]] <- cbind(s[, .(id, lat, lon, elev, name, cell, candidate_order)],
    data.table(window_start = r$selected$start, window_end = r$selected$end, accepted_levels = nrow(d),
      accepted_soundings = uniqueN(d$sounding), min_month_days = r$selected$min_month_days,
      inconsistent_fraction = r$selected$inconsistent_fraction))
}
fwrite(rbindlist(accepted_parts), file.path(out_dir, "stations.csv"))
attempts <- rbindlist(lapply(results, `[[`, "attempts"))
fwrite(attempts, file.path(out_dir, "attempts.csv"))
saveRDS(c(settings, list(sounding_rules = sounding_rules)), file.path(out_dir, "settings.rds"))
fwrite(attempts[, .(candidates = .N), by = reason], file.path(dir_tables, "sounding_selection_outcomes.csv"))
cli::cli_alert_success("Sounding selection: {length(accepted_parts)} stations")

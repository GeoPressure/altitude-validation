# Direct GHCNh sampling pilot and resumable full selection -------------------
# Rscript scripts/sampling/sample_ghcnh.R 32 4    # fixed random 32-cell pilot, four workers
# Rscript scripts/sampling/sample_ghcnh.R all 4   # resume the same frozen run across all cells
# Pilot outputs stay separate from the published analysis until integration.
source("R/utils.R")
source("R/ghcnh_sampling.R")
load_geopressurer()
setDTthreads(1)
args <- commandArgs(trailingOnly = TRUE)
limit <- if (length(args)) args[1] else "32"
workers <- if (length(args) >= 2) as.integer(args[2]) else 4L
run_dir <- Sys.getenv("GHCNH_RUN_DIR", "data/interim/ghcnh/selection-2026-10-13")
for (part in c("catalogue", "annual", "pressure", "core", "cells", "accepted")) dir.create(file.path(run_dir, part), recursive = TRUE, showWarnings = FALSE)

# Freeze scientific settings -----------------------------------------------
settings <- list(version = 2L, hourly_report = "closest", start = as.POSIXct("2022-01-01", tz = "UTC"),
  end = as.POSIXct("2026-10-13", tz = "UTC"), years = 2022:2026,
  width_m = 200000, seed = 11L, pressure_min = 300, pressure_max = 1100,
  days_per_month = 15L, hours_per_day = 4L, outlier_m = 100, outlier_mad = 10,
  outlier_fraction = .01, offset_m = 30, offset_slope = .1,
  step_years = 3L, step_months = 18L, step_hours = 60L, step_side = 3L, step_m = 10, step_score = 10,
  base = "https://www.ncei.noaa.gov/oa/global-historical-climatology-network")
config_file <- file.path(run_dir, "settings.rds")
if (file.exists(config_file)) stopifnot(identical(settings, readRDS(config_file))) else ghcnh_save(settings, config_file)
started <- Sys.time()

# Freeze inventory and archive availability --------------------------------
inventory_file <- file.path(run_dir, "inventory.rds")
if (!file.exists(inventory_file)) {
  station_file <- "data/raw/ghcnh-station-list.txt"
  if (!file.exists(station_file)) curl_download(paste0(settings$base, "/hourly/doc/ghcnh-station-list.txt"), station_file)
  x <- readLines(station_file, warn = FALSE)
  inventory <- data.table(id = trimws(substr(x, 1, 11)), lat = as.numeric(substr(x, 13, 20)),
    lon = as.numeric(substr(x, 22, 30)), elev = as.numeric(substr(x, 32, 37)), name = trimws(substr(x, 42, 71)))
  inventory <- inventory[is.finite(lat) & is.finite(lon) & abs(lat) <= 90 & abs(lon) <= 180 & is.finite(elev) & elev > -900]
  ghcnh_save(inventory, inventory_file)
}
catalogue <- rbindlist(lapply(settings$years, ghcnh_catalogue, run_dir = run_dir, base = settings$base))
candidate_file <- file.path(run_dir, "candidates.rds")
if (!file.exists(candidate_file)) {
  candidates <- readRDS(inventory_file)[id %in% catalogue$id][order(id)]
  xy <- st_coordinates(st_transform(st_as_sf(candidates, coords = c("lon", "lat"), crs = 4326), 8857))
  candidates[, cell := paste(floor(xy[, 1] / settings$width_m), floor(xy[, 2] / settings$width_m), sep = "_")]
  setorder(candidates, cell, id)
  set.seed(settings$seed)
  candidates[, candidate_order := sample.int(.N), by = cell]
  ghcnh_save(candidates, candidate_file)
}
candidates <- readRDS(candidate_file)
all_cells <- sort(unique(candidates$cell))
set.seed(settings$seed)
pilot_order <- sample(all_cells)
cells <- if (limit == "all") all_cells else head(pilot_order, as.integer(limit))
old_stations <- fread("output/tables/stations.csv")[network == "ghcnh"]
cli::cli_alert_info("{nrow(candidates)} candidates in {length(all_cells)} cells; processing {length(cells)} cells with {workers} workers")

# Process independent cells ------------------------------------------------
t0 <- Sys.time()
if (workers == 1L) {
  result <- lapply(cells, ghcnh_cell, candidates = candidates, settings = settings,
    catalogue = catalogue, run_dir = run_dir, old_stations = old_stations)
} else {
  # Socket workers avoid the macOS libcurl failures documented in R/utils.R.
  cl <- parallel::makePSOCKcluster(workers, outfile = file.path(run_dir, "workers.log"))
  parallel::clusterCall(cl, function(wd) {
    setwd(wd)
    source("R/utils.R")
    source("R/ghcnh_sampling.R")
    load_geopressurer()
    setDTthreads(1)
    NULL
  }, getwd())
  parallel::clusterExport(cl, c("candidates", "settings", "catalogue", "run_dir", "old_stations"))
  result <- tryCatch(parallel::parLapplyLB(cl, cells, function(cell) {
    ghcnh_cell(cell, candidates, settings, catalogue, run_dir, old_stations)
  }), finally = parallel::stopCluster(cl))
}
selection_seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
attempts <- rbindlist(lapply(result, function(x) data.table(cell = x$cell, x$attempts)), fill = TRUE)
accepted <- rbindlist(lapply(result, function(x) x$accepted), fill = TRUE)
summary <- data.table(cell = cells, completed = vapply(result, function(x) x$completed, logical(1)),
  accepted = vapply(result, function(x) !is.null(x$accepted), logical(1)),
  attempts = vapply(result, function(x) nrow(x$attempts), integer(1)),
  pending = vapply(result, function(x) if (is.null(x$pending)) "" else x$pending$message, character(1)))
label <- if (limit == "all") "full" else paste0("pilot-", limit)
fwrite(attempts, file.path(run_dir, paste0(label, "-attempts.csv")))
fwrite(accepted, file.path(run_dir, paste0(label, "-accepted.csv")))
fwrite(summary, file.path(run_dir, paste0(label, "-cells.csv")))
files <- list.files(run_dir, recursive = TRUE, full.names = TRUE)
annual_files <- list.files("data/interim/ghcnh/annual", full.names = TRUE, pattern = "parquet$")
new_annual <- annual_files[file.info(annual_files)$mtime >= file.info(config_file)$mtime]
metrics <- data.table(run = label, workers = workers, cells_total = length(all_cells), cells_requested = length(cells),
  cells_completed = sum(summary$completed), accepted = nrow(accepted), pending = sum(!summary$completed),
  attempted = nrow(attempts), selection_wall_s = selection_seconds,
  total_wall_s = as.numeric(difftime(Sys.time(), started, units = "secs")),
  run_cache_bytes = sum(file.size(files)), historical_added_bytes = sum(file.size(new_annual)), recorded_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
fwrite(metrics, file.path(run_dir, paste0(label, "-metrics.csv")))
print(metrics)
if (limit == "all" && any(!summary$completed)) stop("Selection is incomplete: resume pending cells before promotion.")

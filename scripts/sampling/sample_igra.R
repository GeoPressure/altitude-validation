# Direct IGRA sampling pilot and resumable full selection -------------------
# Rscript scripts/sampling/sample_igra.R 16 3   # fixed random 16-cell pilot
# Rscript scripts/sampling/sample_igra.R all 3  # resume all cells after pilot review
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/igra_sampling.R")
load_geopressurer()
setDTthreads(1)
args <- commandArgs(trailingOnly = TRUE)
limit <- if (length(args)) args[1] else "16"
workers <- if (length(args) >= 2) as.integer(args[2]) else 3L
run_dir <- Sys.getenv("IGRA_RUN_DIR", "data/interim/igra-selection-2026-10-13")
for (part in c("profiles", "downloads", "core", "cells", "accepted")) dir.create(file.path(run_dir, part), recursive = TRUE, showWarnings = FALSE)
settings <- list(version = 1L, start = as.POSIXct("2022-01-01", tz = "UTC"),
  end = as.POSIXct("2026-10-13", tz = "UTC"), years = 2022:2026,
  width_m = 200000, seed = 11L, days_per_month = 15L, max_agl = 6000,
  ascent_m_s = 5, outlier_m = 150, outlier_mad = 10,
  height_breaks = c(0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000),
  base = "https://www.ncei.noaa.gov/data/integrated-global-radiosonde-archive")
config_file <- file.path(run_dir, "settings.rds")
if (file.exists(config_file)) stopifnot(identical(settings, readRDS(config_file))) else ghcnh_save(settings, config_file)
started <- Sys.time()

# Freeze archive inventory and candidate order -----------------------------
inventory_file <- file.path(run_dir, "inventory.rds")
if (!file.exists(inventory_file)) {
  station_file <- file.path(run_dir, "igra2-station-list.txt")
  curl_download(paste0(settings$base, "/doc/igra2-station-list.txt"), paste0(station_file, ".tmp"))
  stopifnot(file.rename(paste0(station_file, ".tmp"), station_file))
  x <- readLines(station_file, warn = FALSE)
  inventory <- data.table(id = substr(x, 1, 11), lat = as.numeric(substr(x, 13, 20)), lon = as.numeric(substr(x, 22, 30)),
    elev = as.numeric(substr(x, 32, 37)), name = trimws(substr(x, 42, 71)),
    first = as.integer(substr(x, 73, 76)), last = as.integer(substr(x, 78, 81)))
  inventory <- inventory[is.finite(lat) & is.finite(lon) & abs(lat) <= 90 & abs(lon) <= 180 & is.finite(elev) & elev > -900 & first <= max(settings$years) & last >= min(settings$years)]
  ghcnh_save(inventory, inventory_file)
}
catalogue_file <- file.path(run_dir, "catalogue.rds")
if (!file.exists(catalogue_file)) {
  response <- httr2::request(paste0(settings$base, "/access/data-por/")) |>
    httr2::req_retry(max_tries = 4) |> httr2::req_timeout(120) |> httr2::req_perform()
  html <- httr2::resp_body_string(response)
  writeLines(html, file.path(run_dir, "catalogue.html"))
  rows <- xml2::xml_find_all(xml2::read_html(html), "//tr[td/a[contains(@href, '-data.txt.zip')]]")
  catalogue <- data.table(id = sub("-data.txt.zip$", "", xml2::xml_attr(xml2::xml_find_first(rows, "td/a"), "href")),
    modified = xml2::xml_text(xml2::xml_find_first(rows, "td[2]")),
    bytes = as.numeric(xml2::xml_text(xml2::xml_find_first(rows, "td[3]"))))
  stopifnot(nrow(catalogue) > 0)
  ghcnh_save(catalogue, catalogue_file)
}
candidate_file <- file.path(run_dir, "candidates.rds")
if (!file.exists(candidate_file)) {
  candidates <- merge(readRDS(inventory_file), readRDS(catalogue_file), by = "id")
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
cells <- if (limit == "all") all_cells else head(sample(all_cells), as.integer(limit))
old_stations <- fread("output/tables/stations.csv")[network == "igra"]
gpt3 <- gpt3_read(1)
cli::cli_alert_info("{nrow(candidates)} candidates in {length(all_cells)} cells; processing {length(cells)} cells with {workers} workers")

# Process independent cells ------------------------------------------------
t0 <- Sys.time()
if (workers == 1L) {
  result <- lapply(cells, igra_cell, candidates = candidates, settings = settings, run_dir = run_dir, old_stations = old_stations, gpt3 = gpt3)
} else {
  cl <- parallel::makePSOCKcluster(workers, outfile = file.path(run_dir, "workers.log"))
  parallel::clusterCall(cl, function(wd) {
    setwd(wd)
    source("R/utils.R")
    source("R/ghcnh_sampling.R")
    source("R/igra_sampling.R")
    load_geopressurer()
    setDTthreads(1)
    NULL
  }, getwd())
  parallel::clusterExport(cl, c("candidates", "settings", "run_dir", "old_stations", "gpt3"))
  result <- tryCatch(parallel::parLapplyLB(cl, cells, function(cell) {
    igra_cell(cell, candidates, settings, run_dir, old_stations, gpt3)
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
metrics <- data.table(run = label, workers = workers, cells_total = length(all_cells), cells_requested = length(cells),
  cells_completed = sum(summary$completed), accepted = nrow(accepted), pending = sum(!summary$completed),
  attempted = nrow(attempts), selection_wall_s = selection_seconds,
  total_wall_s = as.numeric(difftime(Sys.time(), started, units = "secs")),
  download_bytes = if (nrow(attempts)) sum(attempts$download_bytes) else 0,
  run_cache_bytes = sum(file.size(files)), recorded_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
fwrite(metrics, file.path(run_dir, paste0(label, "-metrics.csv")))
print(metrics)
if (any(!summary$completed)) stop("Selection is incomplete: resume pending cells before promotion.")

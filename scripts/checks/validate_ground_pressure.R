# Verify accepted records against full-history pressure-only failures.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/ghcnh_consistency.R")
setDTthreads(1)
settings <- readRDS(file.path(selection_dir("ghcnh"), "settings.rds"))
stations <- fread(file.path(selection_dir("ghcnh"), "full-accepted.csv"))
exclusions <- fread("inputs/ghcnh_reference_exclusions.csv")
selection <- fread(file.path(dir_tables, "ground_selection.csv"))
candidates <- as.data.table(readRDS("data/interim/ghcnh/selection-2026-10-13/candidates.rds"))
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
stopifnot(setequal(selection$cell, candidates$cell))
stopifnot(!any(stations$id %in% c(exclusions$id, fread("inputs/ghcnh_review_exclusions.csv")$id)))
for (i in seq_len(nrow(stations))) {
  s <- stations[i]
  raw <- as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/pressure", paste0(s$id, ".parquet")), col_select = c("date", "pressure")))
  cleaned <- ghcnh_pressure_spikes(raw)
  jumps <- ghcnh_pressure_jumps(cleaned)
  start <- as.POSIXct(s$window_start, tz = "UTC")
  end <- as.POSIXct(s$window_end, tz = "UTC")
  stopifnot(!any(jumps$start >= start & jumps$end < end))
  d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(s$id, ".parquet")), col_select = c("date", "pressure")))
  expected <- cleaned[date >= start & date < end]
  stopifnot(identical(d$date, expected$date), identical(d$pressure, expected$pressure), nrow(d) == s$accepted_hours)
  days <- d[, .N, by = .(day = as.Date(date, tz = "UTC"))][N >= settings$hours_per_day]
  bounds <- s$window_end %m-% months(0:12)
  counts <- vapply(1:12, function(m) sum(days$day >= bounds[m + 1L] & days$day < bounds[m]), integer(1))
  stopifnot(all(counts >= settings$days_per_month))
  reference <- as.data.table(read_parquet(file.path(run_dir, "reference", paste0(s$id, ".parquet"))))
  x <- ghcnh_consistency_inputs(cleaned, reference, s)
  stopifnot(ghcnh_consistency(x, s)$reason != "reference_height", ghcnh_consistency(x[date >= start & date < end], s, as.integer(s$window_end %m-% months(0:12)))$pass)
}
cli::cli_alert_success("All {nrow(stations)} accepted ground years contain no large jump, pass station-consistency checks, cleaned-record equality and monthly coverage")

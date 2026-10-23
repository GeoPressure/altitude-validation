# Trial of pressure-only backwards selection; published selection is unchanged.
source("R/utils.R")
source("R/ghcnh_sampling.R")
load_geopressurer()
setDTthreads(1)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
settings <- readRDS(file.path(run_dir, "settings.rds"))
out <- "output/drafts/atmospheric-figures"
calendar <- ghcnh_pressure_calendar(settings)

# Check boundary handling and jumps across a reporting gap ------------------
synthetic_settings <- settings
synthetic_settings$start <- as.POSIXct("2023-01-01", tz = "UTC")
synthetic_settings$end <- as.POSIXct("2025-01-01", tz = "UTC")
synthetic <- data.table(date = seq(synthetic_settings$start, synthetic_settings$end - 3600, by = "hour"), pressure = 1000)
stopifnot(ghcnh_pressure_window(synthetic, synthetic_settings)$end == as.Date("2025-01-01"))
synthetic[date == as.POSIXct("2024-07-01 12:00:00", tz = "UTC"), pressure := 1100]
stopifnot(ghcnh_pressure_window(synthetic, synthetic_settings)$end == as.Date("2024-07-01"))
synthetic[, pressure := 1000]
synthetic[date >= as.POSIXct("2024-07-01", tz = "UTC"), pressure := 1100]
stopifnot(ghcnh_pressure_window(synthetic, synthetic_settings)$end == as.Date("2024-07-01"))
synthetic <- synthetic[date < as.POSIXct("2024-06-25", tz = "UTC") | date >= as.POSIXct("2024-07-01", tz = "UTC")]
stopifnot(ghcnh_pressure_window(synthetic, synthetic_settings)$end == as.Date("2024-07-01"))
cli::cli_alert_success("Passed synthetic coverage, spike, step and reporting-gap checks")

review <- fread(file.path(out, "pressure_timeseries_filter_review.csv"))
stations <- fread(file.path(out, "ground_no_era5_screen_stations.csv"))[formula == "standard"]
candidates <- readRDS(file.path(run_dir, "candidates.rds"))
set.seed(42)
ids <- unique(c(review$id, sample(stations$id, 50)))
examples <- c("BRM00086850", "BRM00086781", "CIN00320041", "MXM00076737")
results <- list()
records <- list()

# Compare latest coverage-only and latest pressure-consistent years ----------
for (id_value in ids) {
  d <- as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(id_value, ".parquet"))))
  end_before <- ghcnh_window(d, settings, clean = FALSE)
  before <- d[as.Date(date, tz = "UTC") >= end_before %m-% years(1) & as.Date(date, tz = "UTC") < end_before]
  selected <- ghcnh_pressure_window(d, settings, calendar = calendar)
  row <- data.table(id = id_value, name = candidates[id == id_value]$name,
    end_before = end_before, end_after = as.Date(NA), n_before = nrow(before), n_after = 0L)
  if (!is.null(selected)) {
    after <- selected$hours
    stopifnot(all(abs(diff(after$pressure))[as.numeric(diff(after$date), units = "hours") <= 3] <= 20))
    stopifnot(all(abs(diff(after$pressure))[as.numeric(diff(after$date), units = "hours") <= 7 * 24] <= 50))
    bounds <- selected$end %m-% months(0:12)
    days <- after[, .N, by = .(day = as.Date(date, tz = "UTC"))][N >= settings$hours_per_day]$day
    stopifnot(all(vapply(1:12, function(m) sum(days >= bounds[m + 1L] & days < bounds[m]), integer(1)) >= settings$days_per_month))
    stopifnot(nrow(after) == d[as.Date(date, tz = "UTC") >= selected$start & as.Date(date, tz = "UTC") < selected$end, .N])
    row[, `:=`(end_after = selected$end, n_after = nrow(after))]
    # Check the optimized search against a literal daily search at four examples.
    if (id_value %in% examples) {
      for (endpoint in seq(as.Date(settings$end), as.Date(settings$start) %m+% years(1), by = "-1 day")) {
        endpoint <- as.Date(endpoint, origin = "1970-01-01")
        z <- d[as.Date(date, tz = "UTC") >= endpoint %m-% years(1) & as.Date(date, tz = "UTC") < endpoint][order(date)]
        if (any(abs(diff(z$pressure))[as.numeric(diff(z$date), units = "hours") <= 3] > 20) ||
            any(abs(diff(z$pressure))[as.numeric(diff(z$date), units = "hours") <= 7 * 24] > 50)) next
        b <- endpoint %m-% months(0:12)
        dates <- z[, .N, by = .(day = as.Date(date, tz = "UTC"))][N >= settings$hours_per_day]$day
        if (all(vapply(1:12, function(m) sum(dates >= b[m + 1L] & dates < b[m]), integer(1)) >= settings$days_per_month)) break
      }
      stopifnot(endpoint == selected$end)
      independent <- ghcnh_pressure_window(d[, .(date, pressure)], settings, calendar = calendar)
      stopifnot(independent$end == selected$end, identical(independent$hours$pressure, after$pressure))
    }
  }
  if (id_value %in% examples && !is.null(selected)) {
    e <- as.data.table(read_parquet(file.path(run_dir, "core", paste0(id_value, ".parquet"))))
    for (period in c("before", "after")) {
      z <- copy(if (period == "before") before else selected$hours)
      records[[length(records) + 1L]] <- z[, .(id = id_value, period = period, date, pressure, source_code)]
      z <- merge(z, e, by = "date")
      error <- era5_altitude(z$pressure * 100, z$sp_sl, z$t2m_sl, z$z_sl) - candidates[id == id_value]$elev
      row[, (paste0(c("sd_", "mad_"), period)) := list(sd(error), mad(error))]
    }
  }
  results[[length(results) + 1L]] <- row
  cli::cli_alert_info("Tested {length(results)}/{length(ids)} stations")
}
r <- rbindlist(results, fill = TRUE)
fwrite(r, file.path(out, "pressure_window_trial.csv"))
write_parquet(rbindlist(records), file.path(out, "pressure_window_trial_examples.parquet"))
print(r[id %in% examples])
print(r[, .(tested = .N, recovered = sum(!is.na(end_after)), shifted = sum(end_after < end_before, na.rm = TRUE),
  unchanged = sum(end_after == end_before, na.rm = TRUE))])

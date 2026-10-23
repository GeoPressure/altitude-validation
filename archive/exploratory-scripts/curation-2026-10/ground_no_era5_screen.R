# Temporary selection without ERA5-residual checks, within the primary represented cells.
source("R/utils.R")
source("R/ghcnh_sampling.R")
load_geopressurer()
setDTthreads(1)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
settings <- readRDS(file.path(run_dir, "settings.rds"))
candidates <- readRDS(file.path(run_dir, "candidates.rds"))
gpt3 <- gpt3_read(1)
station_parts <- list()
hist_parts <- list()
error_parts <- list()
for (cell_id in sort(unique(candidates$cell))) {
  state <- readRDS(file.path(run_dir, "cells", paste0(cell_id, ".rds")))
  if (is.null(state$accepted)) next
  for (id_value in state$attempts$id) {
    s <- candidates[id == id_value]
    o <- as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(id_value, ".parquet"))))
    if (!file.exists(file.path(run_dir, "core", paste0(id_value, ".parquet")))) {
      stopifnot(is.null(ghcnh_window(o, settings, clean = FALSE)))
      next
    }
    e <- as.data.table(read_parquet(file.path(run_dir, "core", paste0(id_value, ".parquet"))))
    d <- merge(o, e, by = "date")
    d <- d[is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m) & is.finite(z_sl)]
    endpoint <- as.Date(settings$end)
    bounds <- endpoint %m-% months(0:12)
    days <- d[, .N, by = .(day = as.Date(date, tz = "UTC"))][N >= settings$hours_per_day]$day
    coverage <- vapply(1:12, function(m) sum(days >= bounds[m + 1L] & days < bounds[m]), integer(1))
    if (min(coverage) < settings$days_per_month) endpoint <- ghcnh_window(d, settings, clean = FALSE)
    if (is.null(endpoint)) next
    d <- d[as.Date(date, tz = "UTC") >= endpoint %m-% years(1) & as.Date(date, tz = "UTC") < endpoint]
    break
  }
  d[, err_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
  L <- gpt3_lapse(gpt3, rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), as.POSIXlt(d$date, tz = "UTC")$yday + 1)
  L <- fifelse(abs(L) < 1e-5, -1e-5, L)
  d[, err_isa := altitude_lapse(pressure * 100, 101325, 288.15, 0) - s$elev]
  d[, err_standard := err_sl]
  d[, err_virtual := altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - s$elev]
  error_parts[[length(error_parts) + 1L]] <- d[, .(err_isa, err_standard, err_virtual, w = 1 / .N)]
  for (f in c("isa", "standard", "virtual")) {
    station_parts[[length(station_parts) + 1L]] <- d[, .(id = s$id, cell = cell_id,
      formula = f, n = .N, bias = mean(get(paste0("err_", f))), sd = sd(get(paste0("err_", f))), cw = 1)]
    hist_parts[[length(hist_parts) + 1L]] <- d[, .(weight = .N / nrow(d)),
      by = .(bin = pmin(floor(abs(get(paste0("err_", f))) / 5) * 5, 450))][, formula := f]
  }
  if (length(station_parts) %% 300 == 0) cli::cli_alert_info("Prepared {length(station_parts) / 3} stations without ERA5 screening")
}
out <- "output/drafts/atmospheric-figures"
fwrite(rbindlist(station_parts), file.path(out, "ground_no_era5_screen_stations.csv"))
h <- rbindlist(hist_parts)[, .(weight = sum(weight)), by = .(formula, bin)]
h[, percent := 100 * weight / sum(weight), by = formula]
fwrite(h, file.path(out, "ground_no_era5_screen_observation_hist.csv"))
cli::cli_alert_success("Prepared {length(station_parts) / 3} stations without ERA5 screening")
errors <- rbindlist(error_parts)
medians <- rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
  data.table(formula = f, q50 = wquant(abs(errors[[paste0("err_", f)]]), errors$w, .5))
}))
fwrite(medians, file.path(out, "ground_no_era5_screen_observation_medians.csv"))

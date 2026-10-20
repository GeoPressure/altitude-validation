# Scientific and restart checks for the new sampling implementation ----------
source("R/utils.R")
source("R/ghcnh_sampling.R")
load_geopressurer()
settings <- readRDS("data/interim/ghcnh/selection-2026-10-13/settings.rds")
out <- "docs/methods/ghcnh-sampling-review"

# Compare exact windows and steps against the cached-data assessment ---------
suppressPackageStartupMessages(library(dplyr))
previous <- fread(file.path(out, "criteria_windows.csv"))[setting == "15d_4h"]
set.seed(11)
ids <- unique(c(sample(previous$id, 40), sample(previous[is.na(end), id], 5),
  fread(file.path(out, "criteria_step_stations.csv"))[min_months == 18 & min_hours == 60 & side == 3 & abs(step) >= 10 & abs(t) >= 10, id]))
a <- open_dataset("data/interim/errors_ghcnh.parquet") |>
  filter(id %in% ids, year >= 2022) |>
  select(id, date, err_sl, pressure, t2m_sl, sp_sl, d2m) |>
  collect() |>
  as.data.table()
a <- a[date >= settings$start & date < settings$end & is.finite(err_sl) & is.finite(pressure) & is.finite(t2m_sl) & is.finite(sp_sl) & is.finite(d2m)]
step_previous <- fread(file.path(out, "criteria_step_stations.csv"))[min_months == 18 & min_hours == 60 & side == 3]
for (id_value in ids) {
  d <- a[id == id_value]
  expected <- previous[id == id_value]
  w <- ghcnh_window(d, settings)
  stopifnot(identical(is.null(w), is.na(expected$end)))
  if (is.null(w)) next
  stopifnot(w$end == expected$end, nrow(w$hours) == expected$n,
    abs(w$bias - expected$bias) < 1e-9, abs(w$outlier_fraction - expected$gross_fraction) < 1e-12)
  fit <- ghcnh_step(d, w$end, settings)
  old <- step_previous[id == id_value]
  stopifnot(fit$tested == old$tested)
  if (fit$tested) stopifnot(abs(fit$step - old$step) < 1e-8, abs(fit$score - old$t) < 1e-6, fit$at == old$at)
}

# Coverage must be recomputed after removing an extreme observation. --------
boundaries <- as.Date(settings$end) %m-% months(12:0)
sparse_days <- do.call(c, lapply(1:12, function(i) seq(boundaries[i], by = "day", length.out = 15)))
sparse <- data.table(date = as.POSIXct(rep(sparse_days, each = 4), tz = "UTC") + rep(c(0, 6, 12, 18) * 3600, length(sparse_days)), err_sl = 0)
stopifnot(nrow(ghcnh_window(sparse, settings)$hours) == 720L)
sparse[1, err_sl := 100]
stopifnot(ghcnh_window(sparse, settings)$outlier_fraction == 0)
sparse[1, err_sl := 100.01]
stopifnot(!is.null(ghcnh_window(sparse, settings, clean = FALSE)), is.null(ghcnh_window(sparse, settings)))

# Source-code meanings, nearest report selection and earlier tie resolution --
fixture <- tempfile("ghcnh-check-")
for (part in c("pressure", "annual", "accepted", "cells")) dir.create(file.path(fixture, part), recursive = TRUE)
s <- data.table(id = "TEST0000001", lat = 0, lon = 0, elev = 100)
d <- data.table(STATION = s$id,
  DATE = format(as.POSIXct("2026-01-01", tz = "UTC") + c(0:8 * 3600, 8 * 3600 + 60, 9 * 3600 + 1800), "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
  station_level_pressure = 1000, station_level_pressure_Quality_Code = c("2", "3", "6", "7", "5", "5", "s", NA, "1", "1", "1"),
  station_level_pressure_Source_Code = c(rep("313", 4), "220", "313", "313", "313", "313", "313", "313"))
extra <- d[rep(9L, 5L)]
extra[, DATE := paste0("2026-01-01T", c("07:40:00", "08:50:00", "09:10:00", "09:31:00", "10:00:00"))]
extra[, station_level_pressure := c(998, 997, 996, 995, 994)]
d <- rbind(d, extra)
write_parquet(d, file.path(fixture, "annual", paste0(s$id, "_2026.parquet")))
p <- ghcnh_pressure(s, settings, data.table(id = s$id, year = 2026), fixture)
stopifnot(nrow(p) == 5L, identical(as.integer(format(p$date, "%H", tz = "UTC")), c(5L, 7L, 8L, 9L, 10L)),
  p[format(date, "%H") == "08", pressure] == 1000,
  p[format(date, "%H") == "09", pressure] == 997,
  p[format(date, "%H") == "10", pressure] == 994)

# Restart at the same candidate after a technical failure --------------------
# Synthetic pressure/core readers isolate checkpoint behavior from the network.
original_pressure <- ghcnh_pressure
original_core <- ghcnh_core
hours <- seq(as.POSIXct("2023-01-01", tz = "UTC"), settings$end - 3600, by = "6 hours")
o <- data.table(date = hours, pressure = 1000, quality_code = "1", source_code = "313")
e <- data.table(date = hours, sp_sl = 100000, t2m_sl = 280, d2m = 275, z_sl = 100)
failed_once <- FALSE
inject <- TRUE
ghcnh_pressure <- function(s, settings, catalogue, run_dir) {
  if (s$id == "empty") return(o[0])
  if (inject && !failed_once) {
    failed_once <<- TRUE
    stop("Injected transfer failure")
  }
  o
}
ghcnh_core <- function(s, settings, run_dir, old_stations) e
candidates <- data.table(id = c("empty", "good", "unused", "other"), cell = c("test", "test", "test", "another"),
  candidate_order = c(1L, 2L, 3L, 1L), lat = 0, lon = 0, elev = 100)
state <- ghcnh_cell("test", candidates, settings, data.table(), fixture, data.table())
stopifnot(!state$completed, nrow(state$attempts) == 1L, state$next_candidate == 2L, state$pending$id == "good")
writeLines("interrupted temporary write", file.path(fixture, "cells", "test.rds.tmp"))
resumed <- ghcnh_cell("test", candidates, settings, data.table(), fixture, data.table())
stopifnot(resumed$completed, resumed$accepted$id == "good", identical(resumed$attempts$id, c("empty", "good")))
# A finished cell is unchanged on another restart.
stable <- ghcnh_cell("test", candidates, settings, data.table(), fixture, data.table())
stopifnot(isTRUE(all.equal(resumed, stable, check.attributes = FALSE)))
inject <- FALSE
fresh <- tempfile("ghcnh-uninterrupted-")
for (part in c("cells", "accepted")) dir.create(file.path(fresh, part), recursive = TRUE)
uninterrupted <- ghcnh_cell("test", candidates, settings, data.table(), fresh, data.table())
cols <- setdiff(names(resumed$attempts), "seconds")
stopifnot(isTRUE(all.equal(as.data.frame(resumed$attempts[, ..cols]), as.data.frame(uninterrupted$attempts[, ..cols]))),
  isTRUE(all.equal(as.data.frame(resumed$accepted[, !"seconds"]), as.data.frame(uninterrupted$accepted[, !"seconds"]))))
ghcnh_pressure <- original_pressure
ghcnh_core <- original_core
unlink(c(fixture, fresh), recursive = TRUE)
fwrite(data.table(check = c("Cached-data window and step agreement", "Pressure QC, closest report, earlier-distance tie and half-hour assignment",
  "Technical failure preserves candidate", "Interrupted temporary file ignored", "Restart equals uninterrupted selection", "Completed cell is stable", "Post-outlier coverage and strict 100 m boundary"),
  result = "pass", stations_compared = c(length(ids), NA, NA, NA, NA, NA, NA)), file.path(out, "sampling_checks.csv"))
cat("Scientific and restart checks passed for", length(ids), "cached stations and synthetic failures.\n")

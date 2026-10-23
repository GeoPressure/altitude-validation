# Pressure-only failures and year boundaries --------------------------------
library(data.table)
source("R/ghcnh_sampling.R")
t0 <- as.POSIXct("2025-01-01", tz = "UTC")
d <- data.table(date = t0 + 0:48 * 3600, pressure = rep(c(1000, 1003), length.out = 49))
stopifnot(any(ghcnh_pressure_episodes(ghcnh_pressure_spikes(d))$reason == "noise"))
# Five reversal centres do not reach the repetition threshold.
stopifnot(!any(ghcnh_pressure_episodes(d[1:7])$reason == "noise"))
# Large but slower reversals do not reach the rate threshold.
d[, date := t0 + 0:48 * 2 * 3600]
stopifnot(!any(ghcnh_pressure_episodes(d)$reason == "noise"))
d[, date := t0 + 0:48 * 3600]
# A single reversible excursion remains an observation-level issue.
d[, pressure := 1000 + sin(0:48 / 4)]
d[25, pressure := pressure + 12]
stopifnot(nrow(ghcnh_pressure_episodes(ghcnh_pressure_spikes(d))) == 0)
# Coherent fast weather and ordinary diurnal variation are preserved.
d[, pressure := seq(1030, 970, length.out = .N)]
stopifnot(nrow(ghcnh_pressure_episodes(d)) == 0)
d[, pressure := 1000 + 2 * sin(0:48 * 2 * pi / 24)]
stopifnot(nrow(ghcnh_pressure_episodes(d)) == 0)
d[, pressure := 1000]
stopifnot(identical(ghcnh_pressure_episodes(d)$reason, "frozen"))
# Duration alone is insufficient when too few reports support the run.
stopifnot(nrow(ghcnh_pressure_episodes(data.table(date = t0 + seq(0, 48, length.out = 23) * 3600, pressure = 1000))) == 0)
# Long gaps cannot join otherwise short constant runs or oscillations.
d[, date := t0 + c(0:23, 28:52) * 3600]
stopifnot(nrow(ghcnh_pressure_episodes(d)) == 0)
d[, `:=`(date = t0 + 0:48 * 6 * 3600, pressure = rep(c(1000, 1003), length.out = 49))]
stopifnot(nrow(ghcnh_pressure_episodes(d)) == 0)
empty <- d[0]
stopifnot(nrow(ghcnh_pressure_episodes(empty)) == 0)

# A bad year must fail; the backwards search can recover an earlier clean year.
settings <- list(start = as.POSIXct("2024-01-01", tz = "UTC"),
  end = as.POSIXct("2026-01-01", tz = "UTC"), days_per_month = 15, hours_per_day = 4)
d <- data.table(date = seq(settings$start, settings$end - 3600, by = "hour"))
d[, pressure := 1000 + sin(seq_len(.N) / 24)]
stopifnot(ghcnh_pressure_window(d, settings)$end == as.Date("2026-01-01"))
d[date >= as.POSIXct("2025-07-01", tz = "UTC") & date < as.POSIXct("2025-07-04", tz = "UTC"), pressure := 1000]
selected <- ghcnh_pressure_window(d, settings)
stopifnot(selected$end == as.Date("2025-07-01"))
settings$start <- as.POSIXct("2025-01-01", tz = "UTC")
stopifnot(is.null(ghcnh_pressure_window(d[date >= settings$start], settings)))
# Full-history frozen episodes remain disqualifying when they cross the year boundary.
episodes <- ghcnh_pressure_episodes(data.table(date = t0 + (-48:1) * 3600, pressure = 1000))
d[, pressure := 1000 + sin(seq_len(.N) / 24)]
stopifnot(is.null(ghcnh_pressure_window(d[date >= settings$start], settings, episodes = episodes)))
# A jump crossing the left boundary does not have both reports inside the year.
episodes <- data.table(start = t0 - 3600, end = t0, reason = "jump")
stopifnot(!is.null(ghcnh_pressure_window(d[date >= settings$start], settings, episodes = episodes)))
# Missing coverage remains a hard exclusion after spike removal.
d <- d[date >= settings$start & !(date >= as.POSIXct("2025-06-01", tz = "UTC") & date < as.POSIXct("2025-07-01", tz = "UTC"))]
stopifnot(is.null(ghcnh_pressure_window(d, settings)))
cli::cli_alert_success("Noise, frozen values, coherent weather, gaps, coverage and year-boundary checks passed")

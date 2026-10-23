# Experimental pressure-pattern checks and controls.
library(data.table)
source("R/ghcnh_pressure_patterns.R")
set.seed(23)
t0 <- as.POSIXct("2024-01-01", tz = "UTC")
d <- data.table(date = t0 + 0:(180 * 24 - 1) * 3600)
d[, pressure := 1000 + 2 * sin(seq_len(.N) * 2 * pi / 24) + 8 * sin(seq_len(.N) * 2 * pi / (5 * 24))]
stopifnot(!any(ghcnh_pressure_patterns(d)$blocks$noise), !any(ghcnh_pressure_patterns(d)$steps$step))
# Weather amplitude changes without developing short-term irregularity.
d[date >= t0 + 90 * 86400, pressure := pressure + 15 * sin(seq_len(.N) * 2 * pi / (3 * 24))]
stopifnot(!any(ghcnh_pressure_patterns(d)$blocks$noise))
# A cadence change alone does not constitute increased noise.
cadence <- d[date < t0 + 90 * 86400 | as.integer(difftime(date, t0, units = "hours")) %% 3 == 0]
stopifnot(!any(ghcnh_pressure_patterns(cadence)$blocks$noise))
# Repeated irregular observations in a sustained noisy interval.
noisy <- copy(d)
noisy[date < t0 + 60 * 86400, pressure := pressure + rnorm(.N, sd = 2)]
stopifnot(any(ghcnh_pressure_patterns(noisy)$blocks$noise))
# An adjacent bad period cannot contaminate a selected clean year boundary.
stopifnot(!any(ghcnh_pressure_patterns(noisy, t0 + 90 * 86400, max(d$date) + 3600)$blocks$noise))
# An isolated offset that returns immediately is not a persistent step.
spike <- copy(d)
spike[2000, pressure := pressure + 6]
stopifnot(!any(ghcnh_pressure_patterns(spike)$steps$step))
# An abrupt step is detected inside a densely sampled coherent record.
step <- copy(d)
step[, pressure := 1000 + sin(seq_len(.N) * 2 * pi / 24) + sin(seq_len(.N) * 2 * pi / (5 * 24))]
step[date >= t0 + 60 * 86400, pressure := pressure + 6]
stopifnot(any(ghcnh_pressure_patterns(step)$steps$step))
# A weather-like shift that reverses within ten days is not persistent.
temporary <- copy(step)
temporary[date >= t0 + 70 * 86400, pressure := pressure - 6]
stopifnot(!any(ghcnh_pressure_patterns(temporary)$steps$step))
# A step at the year boundary lacks within-year evidence on both sides.
stopifnot(!any(ghcnh_pressure_patterns(step, t0 + 60 * 86400, max(d$date) + 3600)$steps$step))
cli::cli_alert_success("Experimental noise, step, weather, cadence and spike controls passed")

# Full-history evidence stays valid when a selected year clips its support period.
source("R/ghcnh_sampling.R")
settings <- list(start = as.POSIXct("2024-01-01", tz = "UTC"), end = as.POSIXct("2026-01-01", tz = "UTC"), days_per_month = 15, hours_per_day = 4)
d <- data.table(date = seq(settings$start, settings$end - 3600, by = "hour"))
d[, pressure := 1000 + sin(seq_len(.N) * 2 * pi / 24) + sin(seq_len(.N) * 2 * pi / (5 * 24))]
at <- as.POSIXct("2025-07-01", tz = "UTC")
d[date >= at, pressure := pressure + 6]
episodes <- rbind(ghcnh_pressure_episodes(d), ghcnh_pressure_patterns(d)$episodes)
stopifnot(any(episodes$reason == "step"), ghcnh_pressure_window(d, settings, episodes = episodes)$end == as.Date(at))
cli::cli_alert_success("Backwards-year selection rejects a confirmed step without losing its full-history evidence")

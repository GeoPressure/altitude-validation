# Pressure-only spike removal preserves coherent changes and unsupported gaps.
library(data.table)
source("R/ghcnh.R")
d <- data.table(
  date = as.POSIXct("2025-01-01", tz = "UTC") + 0:24 * 3600,
  pressure = 1000 + sin(0:24 / 4) * 3
)
stopifnot(nrow(ghcnh_pressure_spikes(d)) == nrow(d))
d[13, pressure := pressure + 12]
stopifnot(
  nrow(ghcnh_pressure_spikes(d)) == 24,
  !d$date[13] %in% ghcnh_pressure_spikes(d)$date
)
d[, pressure := seq(1030, 970, length.out = .N)]
stopifnot(nrow(ghcnh_pressure_spikes(d)) == nrow(d))
d[, pressure := c(rep(1000, 12), rep(1010, 13))]
stopifnot(nrow(ghcnh_pressure_spikes(d)) == nrow(d))
d <- data.table(
  date = as.POSIXct("2025-01-01", tz = "UTC") + c(0, 1, 25) * 3600,
  pressure = c(1000, 1012, 1000)
)
stopifnot(nrow(ghcnh_pressure_spikes(d)) == nrow(d))
# Sparse reports can identify larger isolated departures without ERA5.
for (x in list(
  list(hours = c(0, 3, 9), pressure = c(870.3, 887.0, 871.7)),
  list(hours = c(0, 9, 15), pressure = c(879.4, 858.4, 881.0)),
  list(hours = c(0, 12, 24), pressure = c(944.1, 900.7, 945.3))
)) {
  d <- data.table(
    date = as.POSIXct("2025-01-01", tz = "UTC") + x$hours * 3600,
    pressure = x$pressure
  )
  stopifnot(nrow(ghcnh_pressure_spikes(d)) == 2)
}
d[, pressure := c(1000, 988, 1000)]
stopifnot(nrow(ghcnh_pressure_spikes(d)) == 3)
d[, pressure := c(985, 975, 982)]
stopifnot(nrow(ghcnh_pressure_spikes(d)) == 3)
d[, pressure := c(1000, 980, 960)]
stopifnot(nrow(ghcnh_pressure_spikes(d)) == 3)
cli::cli_alert_success(
  "Isolated spike, coherent weather change, persistent step and gap checks passed"
)

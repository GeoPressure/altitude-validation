# Run from the project root: Rscript docs/methods/T05/audit_sampling.R
# Summarise the saved analysis inputs without downloading or changing study results.

# Load packages -----------------------------------------------------------
library(arrow)
library(dplyr)
library(data.table)
source("R/utils.R")
out <- "docs/methods/T05"

# Ground observations used by the three-conversion comparison --------------
st <- fread("output/tables/ground_station_stats.csv")[reference == TRUE]
x <- open_dataset("data/interim/errors_hadisd.parquet") |>
  filter(year >= 2022, year <= 2024, !gross, is.finite(err_sl), is.finite(d2m), id %in% st$id) |>
  select(id, date, year) |>
  collect() |>
  as.data.table()
x[, source := "HadISD"]
parts <- list(x)
rm(x)
st <- fread("output/tables/indep_station_stats.csv")[source == "MeteoSwiss" | height_ok]
for (i in seq_len(nrow(st))) {
  x <- as.data.table(read_parquet(file.path("data/interim/indep", paste0(st$source[i], "_", st$id[i], ".parquet")), col_select = c("date", "err_sl", "d2m")))
  m <- median(x$err_sl, na.rm = TRUE)
  r <- mad(x$err_sl, na.rm = TRUE)
  x <- x[!(abs(err_sl - m) > max(100, 10 * r)) & is.finite(err_sl) & is.finite(d2m)]
  x[, `:=`(source = st$source[i], id = st$id[i], year = as.integer(format(date, "%Y")))]
  parts[[length(parts) + 1]] <- x[, .(source, id, date, year)]
}
x <- rbindlist(parts, use.names = TRUE)
rm(parts)
x[, day := as.Date(date, tz = "UTC")]
station_year <- x[, .(rows = .N, hours = uniqueN(date), days = uniqueN(day), first = min(date), last = max(date)), by = .(source, id, year)]
# Include years with no retained observations in the coverage denominator.
grid <- unique(x[, .(source, id)])[, .(year = 2022:2024), by = .(source, id)]
station_year <- merge(grid, station_year, by = c("source", "id", "year"), all.x = TRUE)
station_year[is.na(rows), `:=`(rows = 0L, hours = 0L, days = 0L)]
station_year[, `:=`(duplicate_rows = rows - hours, possible_hours = ifelse(year == 2024, 8784L, 8760L), possible_days = ifelse(year == 2024, 366L, 365L))]
station_year[, `:=`(hour_fraction = hours / possible_hours, day_fraction = days / possible_days)]
fwrite(station_year, file.path(out, "ground_station_year.csv"))
coverage <- station_year[, .(stations = uniqueN(id), rows = sum(rows), unique_hours = sum(hours), duplicate_rows = sum(duplicate_rows), median_hour_pct = 100 * median(hour_fraction), min_hour_pct = 100 * min(hour_fraction), max_hour_pct = 100 * max(hour_fraction), median_day_pct = 100 * median(day_fraction)), by = source]
fwrite(coverage, file.path(out, "ground_coverage.csv"))
cadence <- unique(x[, .(source, id, date)])
setorder(cadence, source, id, date)
cadence[, gap_hours := as.numeric(date - shift(date), units = "hours"), by = .(source, id)]
cadence <- cadence[, .(median_gap_hours = median(gap_hours, na.rm = TRUE), max_gap_hours = max(gap_hours, na.rm = TRUE)), by = .(source, id)]
fwrite(cadence, file.path(out, "ground_cadence.csv"))
print(coverage)
rm(x, station_year, cadence)
gc()

# Radiosonde selections and timing ----------------------------------------
st <- load_stations()
x <- load_radiosondes(st)
x <- x[is.finite(err_sl_rel) & is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m)]
sfc <- unique(x[surface == TRUE, .(id, sounding)])
x <- merge(x[surface == FALSE & hbin != levels(hbin)[1], .(id, sounding, year, date)], sfc, by = c("id", "sounding"))
sonde <- x[, .(levels = .N, soundings = uniqueN(sounding), launch_days = uniqueN(substr(sounding, 1, 8)), nominal_00_12 = mean(substr(sounding, 9, 10) %in% c("00", "12"))), by = .(id, year)]
fwrite(sonde, file.path(out, "radiosonde_station_year.csv"))
print(sonde[, .(stations = uniqueN(id), levels = sum(levels), soundings = sum(soundings)), by = year])
rm(x)
gc()
# Raw retained profiles expose timing fallbacks and the height/source metadata retained by extraction.
timing <- list()
for (id in unique(sonde$id)) {
  x <- as.data.table(read_parquet(file.path("data/interim/igra", paste0(id, ".parquet"))))
  timing[[id]] <- x[, .(levels = .N, missing_elapsed = sum(etime < 0), missing_release = sum(reltime == "9999"), missing_surface_height = sum(lvl2 == 1 & gph < -8000), surface_levels = sum(lvl2 == 1))]
}
fwrite(rbindlist(timing, idcol = "id"), file.path(out, "radiosonde_input_timing.csv"))

# Current standard formula against cached errors ---------------------------
# A deterministic first-finite observation per retained station checks numerical consistency;
# agreement does not recover the historical package commit.
load_geopressurer()
checks <- list()
st <- fread("output/tables/stations.csv")
for (net in c("hadisd", "igra")) {
  cached <- open_dataset(paste0("data/interim/errors_", net, ".parquet")) |>
    select(id, date, err_sl, sp_sl, t2m_sl, any_of(c("pressure", "press", "gph"))) |>
    filter(is.finite(err_sl), is.finite(sp_sl), is.finite(t2m_sl))
  first_dates <- cached |>
    group_by(id) |>
    summarise(date = min(date))
  x <- cached |>
    inner_join(first_dates, by = c("id", "date")) |>
    collect() |>
    as.data.table()
  x <- unique(x, by = "id")
  x <- merge(x, st[network == net, .(id, elev, z_sl)], by = "id")
  p <- if (net == "hadisd") x$pressure * 100 else x$press
  truth <- if (net == "hadisd") x$elev else x$gph
  x[, difference_m := era5_altitude(p, sp_sl, t2m_sl, z_sl) - truth - err_sl]
  checks[[net]] <- x[, .(network = net, id, date, difference_m)]
}
fwrite(rbindlist(checks), file.path(out, "cached_formula_check.csv"))
print(rbindlist(checks)[, .(stations = .N, max_abs_difference_m = max(abs(difference_m))), by = network])

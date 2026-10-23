# Load packages and define the paired pilot -------------------------------
source("R/utils.R")
load_geopressurer()
library(lubridate)
library(cli)

out <- "docs/methods/T11"
cache <- "data/interim/location_sensitivity_wide"
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
st <- load_stations()[network == "igra" & !is.na(climate)]
B <- load_radiosondes(st)
B <- B[year == 2024 & is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m)]
sfc <- B[surface == TRUE, .(surface_date = date[1], surface_press = press[1], surface_gph = gph[1]), by = .(id, sounding)]
levels <- merge(B[surface == FALSE & agl >= 1700 & agl <= 2300][order(abs(agl - 2000))][, .SD[1], by = .(id, sounding)], sfc, by = c("id", "sounding"))
levels[, quarter := quarter(date)]
coverage <- levels[, .N, by = .(id, quarter)][N >= 1, .(quarters = .N), by = id]
st <- merge(st, coverage[quarters == 4], by = "id")
st[, roughness := fifelse(sdor < 100, "Lower (<100 m)", "Higher (>=100 m)")]
# Fixed random sample, selected before retrieving displaced weather.
setorder(st, climate, roughness, id)
set.seed(20261019)
selected <- rbindlist(lapply(split(st, by = "climate"), function(group) group[sample.int(nrow(group), min(10, nrow(group)))]))
stopifnot(nrow(selected) == 50, uniqueN(selected$climate) == 5)
fwrite(selected[, .(id, name, lon, lat, climate, roughness, sdor, elev, z_sl)], file.path(out, "stations.csv"))
levels <- levels[id %in% selected$id]
# Select one launch nearest the middle of each quarter for every station.
levels[, target := as.POSIXct(sprintf("2024-%02d-15 12:00:00", 3 * quarter - 1), tz = "UTC")]
setorder(levels, id, quarter, sounding)
levels[, gap := abs(as.numeric(date - target, units = "secs"))]
levels <- levels[order(gap, sounding)][, .SD[1], by = .(id, quarter)]
levels <- merge(levels, selected[, .(id, lon, lat, roughness)], by = "id")
levels[, pair := .I]
fwrite(levels[, .(pair, id, sounding, quarter, daynight, date, press, gph, agl, surface_date, surface_press, surface_gph)], file.path(out, "soundings.csv"))

# Displace coordinates on a sphere; retain the nominal distance ----------
locations <- CJ(id = selected$id, distance = c(0, 10, 25, 50, 100, 200), bearing = seq(0, 315, 45))[distance > 0 | bearing == 0]
locations <- merge(selected[, .(id, lon, lat)], locations, by = "id")
locations[, phi := lat * pi / 180]
locations[, lambda := lon * pi / 180]
locations[, theta := bearing * pi / 180]
locations[, delta := distance / 6371.0088]
locations[, query_lat := asin(sin(phi) * cos(delta) + cos(phi) * sin(delta) * cos(theta)) * 180 / pi]
locations[, query_lon := ((lambda + atan2(sin(theta) * sin(delta) * cos(phi), cos(delta) - sin(phi) * sin(query_lat * pi / 180))) * 180 / pi + 180) %% 360 - 180]
grid <- era5_snap(locations$query_lon, locations$query_lat, "single-levels")
locations[, `:=`(grid_lon = grid$lon, grid_lat = grid$lat)]
locations[, location := .I]
fwrite(locations[, .(location, id, distance, bearing, lon, lat, query_lon, query_lat, grid_lon, grid_lat)], file.path(out, "locations.csv"))

# Retrieve only unique grid/hour inputs, cached independently per station -
observations <- rbind(levels[, .(pair, id, date, pressure = press, truth = gph, kind = "level")], levels[, .(pair, id, date = surface_date, pressure = surface_press, truth = surface_gph, kind = "surface")])
queries <- merge(observations, locations[, .(id, location, grid_lon, grid_lat)], by = "id", allow.cartesian = TRUE)
weather <- unique(queries[, .(id, grid_lon, grid_lat, date)])
fwrite(weather, file.path(out, "query-plan.csv"))
cli_alert_info("Expanded test: {nrow(selected)} stations, {nrow(levels)} soundings, {nrow(locations)} displaced locations, {nrow(weather)} unique grid/hour queries for three variables")
started <- Sys.time()
cached_stations <- sum(file.exists(file.path(cache, paste0(selected$id, ".parquet"))))
for (station in selected$id) {
  f <- file.path(cache, paste0(station, ".parquet"))
  q <- weather[id == station]
  if (file.exists(f)) {
    old <- as.data.table(read_parquet(f))
    q <- q[!old, on = .(grid_lon, grid_lat, date)]
  }
  if (nrow(q)) {
    cli_alert_info("Reading {station}: {nrow(q)} new grid/hour combinations")
    e <- era5_read(q$grid_lon, q$grid_lat, q$date, c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m"), "single-levels")
    old <- if (file.exists(f)) as.data.table(read_parquet(f)) else data.table()
    write_parquet(unique(rbindlist(list(old, cbind(q, e)), use.names = TRUE)), f)
  }
}
weather <- rbindlist(lapply(file.path(cache, paste0(selected$id, ".parquet")), function(f) as.data.table(read_parquet(f))))
weather <- unique(weather, by = c("id", "grid_lon", "grid_lat", "date"))
stopifnot(nrow(merge(unique(queries[, .(id, grid_lon, grid_lat, date)]), weather, by = c("id", "grid_lon", "grid_lat", "date"))) == nrow(unique(queries[, .(id, grid_lon, grid_lat, date)])))
weather <- merge(weather, unique(locations[, .(grid_lon, grid_lat)]), by = c("grid_lon", "grid_lat"))
z <- unique(weather[, .(grid_lon, grid_lat)])
z[, orography := era5_orography(grid_lon, grid_lat, "single-levels")]
weather <- merge(weather, z, by = c("grid_lon", "grid_lat"))
queries <- merge(queries, weather, by = c("id", "grid_lon", "grid_lat", "date"))
queries <- merge(queries, locations[, .(location, distance, bearing, query_lon, query_lat)], by = "location")
stopifnot(nrow(selected) == 50, all(levels[, .N, by = id]$N == 4), nrow(queries) == 2 * nrow(levels) * 41, all(is.finite(queries$surface_pressure)), all(is.finite(queries$temperature_2m)), all(is.finite(queries$dewpoint_temperature_2m)), all(is.finite(queries$orography)))

# Compute the three conversions at unchanged observation pressure ---------
gpt3 <- gpt3_read(1)
queries[, lapse := gpt3_lapse(gpt3, query_lon, query_lat, yday(date))]
queries[abs(lapse) < 1e-5, lapse := -1e-5]
queries[, isa := altitude_lapse(pressure, 101325, 288.15, 0)]
queries[, standard := altitude_lapse(pressure, surface_pressure, temperature_2m, orography)]
queries[, virtual := altitude_lapse(pressure, surface_pressure, virtual_temperature(temperature_2m, dewpoint_temperature_2m, surface_pressure), orography, lapse)]
errors <- melt(queries, id.vars = c("id", "pair", "location", "distance", "bearing", "kind", "truth"), measure.vars = c("isa", "standard", "virtual"), variable.name = "formula", value.name = "estimate")
errors[, error := estimate - truth]
relative <- dcast(errors, id + pair + location + distance + bearing + formula ~ kind, value.var = "error")
relative[, error := level - surface]
errors <- rbind(errors[, .(id, pair, location, distance, bearing, formula, metric = paste0("Absolute altitude: ", kind), error)], relative[, .(id, pair, location, distance, bearing, formula, metric = "Surface-referenced height", error)])
base <- errors[distance == 0, .(id, pair, formula, metric, baseline = error)]
errors <- merge(errors, base, by = c("id", "pair", "formula", "metric"))
errors[, change := error - baseline]
errors <- merge(errors, levels[, .(pair, climate, roughness, agl)], by = "pair")
write_parquet(errors, file.path(out, "paired_errors.parquet"))

# Pool equally over stations, launches and directions ----------------------
# Each station contributes four launches and eight directions at positive distances.
stopifnot(all(levels[, .N, by = id]$N == 4))
station_results <- errors[, .(bias = mean(error), variance = mean((error - mean(error))^2), mae = mean(abs(error)), rmse = sqrt(mean(error^2)), change_mae = mean(abs(change)), change_p95 = unname(quantile(abs(change), .95))), by = .(id, climate, roughness, formula, metric, distance)]
base_station <- station_results[distance == 0, .(id, formula, metric, baseline_mae = mae)]
station_results <- merge(station_results, base_station, by = c("id", "formula", "metric"))
station_results[, mae_percent_change := 100 * (mae / baseline_mae - 1)]
fwrite(station_results, file.path(out, "station-results.csv"))
summary <- errors[, .(bias = mean(error), sd = sqrt(mean((error - mean(error))^2)), mae = mean(abs(error)), rmse = sqrt(mean(error^2)), change_mae = mean(abs(change)), change_p95 = unname(quantile(abs(change), .95)), share_worse = mean(abs(error) > abs(baseline))), by = .(formula, metric, distance)]
summary <- merge(summary, base_station[, .(baseline_mae = mean(baseline_mae)), by = .(formula, metric)])
summary[, `:=`(mae_increment = mae - baseline_mae, mae_percent_change = 100 * (mae / baseline_mae - 1), n_stations = 50L, n_soundings = 200L)]
# Bootstrap stations as the independent sampling units, preserving paired baseline errors.
set.seed(20261020)
boot_ci <- list()
for (f in unique(station_results$formula)) for (m in unique(station_results$metric)) {
  d <- dcast(station_results[formula == f & metric == m], id ~ distance, value.var = "mae")
  b <- station_results[formula == f & metric == m & distance == 0, .(id, baseline_mae)]
  d <- merge(d, b, by = "id")
  cols <- as.character(sort(as.numeric(setdiff(names(d), c("id", "baseline_mae")))))
  draws <- replicate(2000, {ii <- sample.int(nrow(d), replace = TRUE); 100 * (colMeans(as.matrix(d[ii, ..cols])) / mean(d$baseline_mae[ii]) - 1)})
  boot_ci[[paste(f, m)]] <- data.table(formula = f, metric = m, distance = as.numeric(cols), ci_low = apply(draws, 1, quantile, .025), ci_high = apply(draws, 1, quantile, .975))
}
summary <- merge(summary, rbindlist(boot_ci), by = c("formula", "metric", "distance"))
fwrite(summary, file.path(out, "results.csv"))
fwrite(errors[, .(bias = mean(error), mae = mean(abs(error)), change_mae = mean(abs(change)), change_p95 = unname(quantile(abs(change), .95))), by = .(formula, metric, distance, bearing)], file.path(out, "direction-results.csv"))
fwrite(errors[, .(bias = mean(error), sd = sqrt(mean((error - mean(error))^2)), mae = mean(abs(error)), change_mae = mean(abs(change)), change_p95 = unname(quantile(abs(change), .95))), by = .(formula, metric, distance, roughness)], file.path(out, "terrain-results.csv"))
# Exact-location and location-independent controls must reproduce their definitions.
stopifnot(all(errors[distance == 0, change] == 0), max(abs(errors[formula == "isa", change])) == 0)
q0 <- queries[distance == 0 & kind == "level"]
central <- merge(q0, levels[, .(pair, original_error = err_sl)], by = "pair")
stopifnot(max(abs(central$standard - central$truth - central$original_error)) < 1e-7)
jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), geopressurer = geopressurer_version(), stations = nrow(selected), soundings = nrow(levels), locations = nrow(locations), grid_hours = nrow(weather), stations_reused_from_cache = cached_stations, elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")), min_height = min(levels$agl), max_height = max(levels$agl), max_central_error_difference = max(abs(central$standard - central$truth - central$original_error)), source_md5 = as.list(tools::md5sum(c("R/utils.R", "docs/methods/T11/run_experiment.R", "data/interim/errors_igra.parquet", "output/tables/stations.csv", "data/raw/gpt3/gpt3_1.grd", file.path(cache, paste0(selected$id, ".parquet")))))), file.path(out, "provenance.json"), pretty = TRUE, auto_unbox = TRUE)
cli_alert_success("Expanded paired test complete; summaries written to {out}")

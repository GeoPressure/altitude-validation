# Sensitivity to horizontal position (Additional file 1: S5): the ERA5 and GPT3 query location is
# displaced around radiosonde launches, and the errors are compared with those at the exact
# location. The pilot sample (10 sounding sites in 5 climate zones and 2 terrain-roughness strata,
# 8 soundings each, level nearest 2 km) is fixed in data/curated.
source("R/utils.R")
load_geopressurer()
library(lubridate)
library(cli)

out <- "results/position-sensitivity"
cache <- file.path(dir_derived, "position_sensitivity")
dir.create(out, showWarnings = FALSE)
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
selected <- fread(file.path(dir_curated, "position_stations.csv"))
levels <- fread(file.path(dir_curated, "position_soundings.csv"))
levels <- merge(levels, selected[, .(id, lon, lat, climate, roughness)], by = "id")

# Displaced query locations on a sphere: six distances and eight bearings ------------------
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

# ERA5 inputs at each unique grid cell and hour, cached per station ----------------------
observations <- rbind(levels[, .(pair, id, date, pressure = press, truth = gph, kind = "level")], levels[, .(pair, id, date = surface_date, pressure = surface_press, truth = surface_gph, kind = "surface")])
queries <- merge(observations, locations[, .(id, location, grid_lon, grid_lat)], by = "id", allow.cartesian = TRUE)
weather <- unique(queries[, .(id, grid_lon, grid_lat, date)])
cli_alert_info("Pilot: {nrow(selected)} stations, {nrow(levels)} soundings, {nrow(locations)} displaced locations, {nrow(weather)} unique grid/hour queries for three variables")
for (station in selected$id) {
  f <- file.path(cache, paste0(station, ".parquet"))
  q <- weather[id == station]
  if (!file.exists(f)) {
    cli_alert_info("Reading {station}: {nrow(q)} grid/hour combinations")
    e <- era5_read(q$grid_lon, q$grid_lat, q$date, c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m"), "single-levels")
    write_parquet(cbind(q, e), f)
  }
}
weather <- rbindlist(lapply(file.path(cache, paste0(selected$id, ".parquet")), function(f) as.data.table(read_parquet(f))))
stopifnot(nrow(weather) == nrow(unique(queries[, .(id, grid_lon, grid_lat, date)])), nrow(merge(unique(queries[, .(id, grid_lon, grid_lat, date)]), weather, by = c("id", "grid_lon", "grid_lat", "date"))) == nrow(weather))
weather <- merge(weather, unique(locations[, .(grid_lon, grid_lat)]), by = c("grid_lon", "grid_lat"))
z <- unique(weather[, .(grid_lon, grid_lat)])
z[, orography := era5_orography(grid_lon, grid_lat, "single-levels")]
weather <- merge(weather, z, by = c("grid_lon", "grid_lat"))
queries <- merge(queries, weather, by = c("id", "grid_lon", "grid_lat", "date"))
queries <- merge(queries, locations[, .(location, distance, bearing, query_lon, query_lat)], by = "location")
stopifnot(nrow(queries) == 2 * nrow(levels) * 41, all(is.finite(queries$surface_pressure)), all(is.finite(queries$temperature_2m)), all(is.finite(queries$dewpoint_temperature_2m)), all(is.finite(queries$orography)))

# The three conversions at unchanged observation pressure ---------------------------------
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

# Summaries pooled equally over stations, launches and directions --------------------------
# There are eight launches per station and eight directions at positive distances.
stopifnot(all(levels[, .N, by = id]$N == 8))
station_results <- errors[, .(bias = mean(error), variance = mean((error - mean(error))^2), mae = mean(abs(error)), medae = wquant(abs(error), rep(1, .N), .5), rmse = sqrt(mean(error^2)), change_mae = mean(abs(change)), change_median = wquant(abs(change), rep(1, .N), .5), change_p95 = unname(quantile(abs(change), .95))), by = .(id, climate, roughness, formula, metric, distance)]
fwrite(station_results, file.path(out, "station-results.csv"))
summary <- errors[, .(bias = mean(error), sd = sqrt(mean((error - mean(error))^2)), mae = mean(abs(error)), medae = wquant(abs(error), rep(1, .N), .5), rmse = sqrt(mean(error^2)), baseline_medae = wquant(abs(baseline), rep(1, .N), .5), medae_increment = wquant(abs(error), rep(1, .N), .5) - wquant(abs(baseline), rep(1, .N), .5), baseline_mae = mean(abs(baseline)), mae_increment = mean(abs(error)) - mean(abs(baseline)), change_mae = mean(abs(change)), change_median = wquant(abs(change), rep(1, .N), .5), change_p95 = unname(quantile(abs(change), .95)), n_stations = uniqueN(id), n_soundings = uniqueN(pair), n_rows = .N), by = .(formula, metric, distance)]
fwrite(summary, file.path(out, "results.csv"))
# Exact-location and location-independent controls must reproduce their definitions.
stopifnot(all(errors[distance == 0, change] == 0), max(abs(errors[formula == "isa", change])) == 0)
cli_alert_success("Position sensitivity written to {out}")

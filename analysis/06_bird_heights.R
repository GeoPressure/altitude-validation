# Flight heights of tracked birds from the Master GeoLocator Data Package, version 2026.0
# (https://doi.org/10.5281/zenodo.18187093). Flight records are the non-integer stap_id values of
# the most-likely pressurepaths. Sea-level altitudes are those supplied with the pressurepaths,
# completed with the ERA5 standard conversion; height above ground subtracts the median Copernicus
# DEM elevation along the reconstructed path (path2elevation). Each record is weighted by its time
# step. Negative flight heights enter the lowest height band.

source("R/utils.R")
load_geopressurer()

master <- Sys.getenv(
  "GEOLOCATOR_MASTER",
  "~/Documents/GitHub/GeoLocatorMaster/data/master/pressurepaths.csv"
)
release <- jsonlite::read_json(file.path(dir_curated, "geolocator_master_release.json"), simplifyVector = TRUE)
input_md5 <- unname(tools::md5sum(path.expand(master)))
stopifnot(paste0("md5:", input_md5) == release$files$checksum[release$files$key == "pressurepaths.csv"])
d <- fread(master, select = c(
  "tag_id", "datetime", "stap_id", "type", "pressure_tag", "surface_pressure", "label", "lon", "lat", "altitude", "temperature_2m"
))
d <- d[type == "most_likely" & is.finite(pressure_tag) & is.finite(surface_pressure) &
  (is.na(label) | label != "discard")]
d[, flight := stap_id != round(stap_id)]
n_tags_pressure <- uniqueN(d$tag_id)
d <- d[tag_id %in% d[flight == TRUE, unique(tag_id)]]
# Time step of each point (min): to the next point of the same tag, capped at 60 min; the last
# point of a tag takes the tag's median step.
d[, t := as.POSIXct(datetime, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")]
setorder(d, tag_id, t)
d[, dt := as.numeric(shift(t, -1) - t, units = "mins"), by = tag_id]
d[, dt := fifelse(is.finite(dt) & dt > 0, pmin(dt, 60), median(dt[dt > 0], na.rm = TRUE)),
  by = tag_id]
# Fill missing sea-level altitudes using the standard ERA5 conversion
# pressurepath pressures are in hPa; the conversion takes Pa.
d[, altitude_provided := is.finite(altitude)]
i <- which(!d$altitude_provided)
d[i, altitude := era5_altitude(pressure_tag * 100, surface_pressure * 100,
  temperature_2m, era5_orography(lon, lat, "single-levels"))]
d[, `:=`(prev = floor(stap_id), nxt = ceiling(stap_id))]

# Median ground elevation and terrain range along the most-likely path
paths_file <- file.path(dirname(path.expand(master)), "paths.csv")
staps_file <- file.path(dirname(path.expand(master)), "staps.csv")
for (path in c(paths_file, staps_file)) {
  stopifnot(paste0("md5:", unname(tools::md5sum(path))) == release$files$checksum[release$files$key == basename(path)])
}
paths <- fread(paths_file)[type == "most_likely" & tag_id %in% d$tag_id]
staps <- fread(staps_file, select = c("tag_id", "stap_id", "start", "end"))
paths <- merge(paths, staps, by = c("tag_id", "stap_id"))
paths[, c("start", "end") := lapply(.SD, as.POSIXct, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), .SDcols = c("start", "end")]
setorder(paths, tag_id, stap_id)
profiles <- list()
for (tag in unique(d$tag_id)) {
  e <- as.data.table(path2elevation(as.data.frame(paths[tag_id == tag]),
    scale = 4, sampling_scale = 4, percentile = c(10, 50, 90)))
  d[tag_id == tag, route_distance := approx(e$stap_id, e$distance, stap_id)$y]
  d[tag_id == tag, ground := approx(e$stap_id, e$X50, stap_id)$y]
  d[tag_id == tag, ground_low := approx(e$stap_id, e$X10, stap_id)$y]
  d[tag_id == tag, ground_high := approx(e$stap_id, e$X90, stap_id)$y]
  e[, tag_id := tag]
  profiles[[tag]] <- e
}
d[, agl := altitude - ground]
stopifnot(all(is.finite(d$altitude)), all(is.finite(d$agl)))
d[flight == TRUE, agl := pmax(agl, 0)]

breaks <- c(-Inf, 0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000, Inf)
h <- d[, .(n = .N, hours = sum(dt) / 60), by = .(flight, bin = cut(agl, breaks, right = FALSE))]
h[, prop := hours / sum(hours), by = flight]
setorder(h, flight, bin)
h <- merge(h, d[, .(n_tags = uniqueN(tag_id)), by = flight], by = "flight")
fwrite(h, file.path(dir_tables, "bird_height_distribution.csv"))

# Time-weighted quantiles of flight height
f <- d[flight == TRUE]
q <- d[, {
  o <- order(agl)
  cw <- cumsum(dt[o]) / sum(dt)
  as.list(setNames(vapply(c(0.05, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), function(p) agl[o][which(cw >= p)[1]],
    numeric(1)), paste0("p", c(5, 25, 50, 75, 90, 95, 99))))
}, by = flight]
fwrite(q, file.path(dir_tables, "bird_height_quantiles.csv"))

# Share of flight time in each radiosonde height band, pooling all flight time or giving each tag
# equal weight.
f[, hbin := cut(pmin(agl, max(hbin_breaks) - 1), hbin_breaks, right = FALSE, labels = levels(cut(0, hbin_breaks)))]
weights <- f[, .(weight = sum(dt)), by = hbin][, variant := "all_flight"]
f[, tag_weight := dt / sum(dt), by = tag_id]
weights <- rbind(weights, f[, .(weight = sum(tag_weight)), by = hbin][, variant := "equal_bird"])
weights[, prop := weight / sum(weight), by = variant]
fwrite(weights, file.path(dir_tables, "bird_target_height_weights.csv"))

# Tables for the supplementary distribution and worked example ---------------
tags <- fread(file.path(dirname(path.expand(master)), "tags.csv"), select = c("tag_id", "scientific_name"))
stopifnot(paste0("md5:", unname(tools::md5sum(file.path(dirname(path.expand(master)), "tags.csv")))) == release$files$checksum[release$files$key == "tags.csv"])
hist <- rbind(
  f[, .(hours = sum(dt) / 60), by = .(lo = floor(altitude / 100) * 100)][, quantity := "Sea-level altitude"],
  f[, .(hours = sum(dt) / 60), by = .(lo = floor(agl / 100) * 100)][, quantity := "Height above terrain"])
hist[, percent := 100 * hours / sum(hours), by = quantity]
fwrite(hist, file.path(dir_tables, "bird_height_figure_distributions.csv"))
figure_quantiles <- rbind(
  f[, .(quantity = "Sea-level altitude", percentile = c("Median", "P90"),
    value = c(wquant(altitude, dt, .5), wquant(altitude, dt, .9)))],
  f[, .(quantity = "Height above terrain", percentile = c("Median", "P90"),
    value = c(wquant(agl, dt, .5), wquant(agl, dt, .9)))])
fwrite(figure_quantiles, file.path(dir_tables, "bird_height_figure_quantiles.csv"))
e <- copy(f[tag_id == "16LF" & prev == 6])
e[, distance := route_distance - approx(profiles[[tag_id[1]]]$stap_id,
  profiles[[tag_id[1]]]$distance, prev[1])$y]
departure <- paths[tag_id == e$tag_id[1] & stap_id == e$prev[1], end]
arrival <- paths[tag_id == e$tag_id[1] & stap_id == e$nxt[1], start]
e[, hour := as.numeric(t - departure, units = "hours")]
fwrite(e[, .(distance, hour, altitude, ground_low, ground, ground_high, height = agl)],
  file.path(dir_tables, "bird_height_figure_example.csv"))
fwrite(e[, .(tag_id = tag_id[1], stationary_segment = prev[1], start = departure, end = arrival,
  duration_hours = as.numeric(arrival - departure, units = "hours"),
  route_km = approx(profiles[[tag_id[1]]]$stap_id, profiles[[tag_id[1]]]$distance, nxt[1])$y -
    approx(profiles[[tag_id[1]]]$stap_id, profiles[[tag_id[1]]]$distance, prev[1])$y,
  scientific_name = tags[tag_id == e$tag_id[1], scientific_name][1])],
  file.path(dir_tables, "bird_height_figure_example_source.csv"))

fwrite(f[, .(n_tags = uniqueN(tag_id), n_species = uniqueN(tags[tag_id %in% f$tag_id, scientific_name]), n_flights = uniqueN(paste(tag_id, prev)), n_points = .N, hours = sum(dt) / 60, n_tags_pressure = n_tags_pressure, n_tags_no_flight = n_tags_pressure - uniqueN(tag_id))], file.path(dir_tables, "bird_height_sample.csv"))

# Flight-time height weights from the published Master GeoLocator Data Package, version 2026.0.
# https://doi.org/10.5281/zenodo.18187093 (open-access release; no restricted additions).
# Flight records are non-integer stap_id values on most-likely pressurepaths.
# Keep all classified flight, weight by represented intervals capped at 60 min, and retain
# adjacent stationary records to estimate departure/arrival pressure offsets.
# Heights use a fixed 288.15 K temperature and standard lapse rate relative to ERA5 surface
# pressure. Residual negative heights enter the lowest band; these are approximate biological
# weights, not validated terrain clearances. Only aggregate outputs are written.

source("R/utils.R")

master <- Sys.getenv(
  "GEOLOCATOR_MASTER",
  "~/Documents/GitHub/GeoLocatorMaster/data/master/pressurepaths.csv"
)
release <- jsonlite::read_json("docs/methods/T07/published-release.json", simplifyVector = TRUE)
input_md5 <- unname(tools::md5sum(path.expand(master)))
stopifnot(paste0("md5:", input_md5) == release$files$checksum[release$files$key == "pressurepaths.csv"])
d <- fread(master, select = c(
  "tag_id", "datetime", "stap_id", "type", "pressure_tag", "surface_pressure", "label"
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
p2z <- function(p, p0) 288.15 / -0.0065 * ((p / p0)^(-8.31432 * -0.0065 / 9.80665 / 0.0289644) - 1)
d[, agl_raw := p2z(pressure_tag, surface_pressure)]

# Ground offset (tag - ERA5, hPa) at departure and arrival of each flight
st <- d[flight == FALSE & stap_id > 0 & (is.na(label) | label == "")]
dep <- st[, .(off_dep = median((pressure_tag - surface_pressure)[t >= max(t) - 6 * 3600])),
  by = .(tag_id, stap_id)]
arr <- st[, .(off_arr = median((pressure_tag - surface_pressure)[t <= min(t) + 6 * 3600])),
  by = .(tag_id, stap_id)]
d[, `:=`(prev = floor(stap_id), nxt = ceiling(stap_id))]
d <- merge(d, dep[, .(tag_id, prev = stap_id, off_dep)], by = c("tag_id", "prev"), all.x = TRUE)
d <- merge(d, arr[, .(tag_id, nxt = stap_id, off_arr)], by = c("tag_id", "nxt"), all.x = TRUE)
setorder(d, tag_id, t)
d[flight == TRUE, frac := {
  r <- as.numeric(range(t))
  if (r[2] > r[1]) (as.numeric(t) - r[1]) / (r[2] - r[1]) else 0.5
}, by = .(tag_id, prev)]
d[, off := fcoalesce(off_dep * (1 - frac) + off_arr * frac, off_dep, off_arr, 0)]
d[, agl := fifelse(flight, p2z(pressure_tag - off, surface_pressure), agl_raw)]
cat(sprintf("flight time below the ERA5 surface: %.1f%% raw, %.1f%% after the ground offset\n",
  100 * d[flight == TRUE, sum(dt * (agl_raw < 0)) / sum(dt)],
  100 * d[flight == TRUE, sum(dt * (agl < 0)) / sum(dt)]))
fwrite(d[flight == TRUE, .(below0_raw = sum(dt * (agl_raw < 0)) / sum(dt),
  below0 = sum(dt * (agl < 0)) / sum(dt))], file.path(dir_tables, "bird_height_below0.csv"))
# Remaining points below the ERA5 surface: flying at ground level
d[flight == TRUE, agl := pmax(agl, 0)]

breaks <- c(-Inf, 0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000, Inf)
h <- d[, .(n = .N, hours = sum(dt) / 60), by = .(flight, bin = cut(agl, breaks, right = FALSE))]
h[, prop := hours / sum(hours), by = flight]
setorder(h, flight, bin)
h <- merge(h, d[, .(n_tags = uniqueN(tag_id)), by = flight], by = "flight")
fwrite(h, file.path(dir_tables, "bird_height_distribution.csv"))

# Flight time in 100 m bins (for the figure) and time-weighted quantiles of flight height
f <- d[flight == TRUE]
fine <- f[, .(hours = sum(dt) / 60), keyby = .(lo = pmin(floor(agl / 100) * 100, 6000))]
fine[, prop := hours / sum(hours)]
fwrite(fine, file.path(dir_tables, "bird_height_hist.csv"))
q <- d[, {
  o <- order(agl)
  cw <- cumsum(dt[o]) / sum(dt)
  as.list(setNames(vapply(c(0.05, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), function(p) agl[o][which(cw >= p)[1]],
    numeric(1)), paste0("p", c(5, 25, 50, 75, 90, 95, 99))))
}, by = flight]
fwrite(q, file.path(dir_tables, "bird_height_quantiles.csv"))
print(h)
print(q)

# Contributing sample and versioned input provenance ------------------------
tags <- fread(file.path(dirname(path.expand(master)), "tags.csv"), select = c("tag_id", "scientific_name"))
stopifnot(paste0("md5:", unname(tools::md5sum(file.path(dirname(path.expand(master)), "tags.csv")))) == release$files$checksum[release$files$key == "tags.csv"])
fwrite(f[, .(n_tags = uniqueN(tag_id), n_species = uniqueN(tags[tag_id %in% f$tag_id, scientific_name]), n_flights = uniqueN(paste(tag_id, prev)), n_points = .N, hours = sum(dt) / 60, n_tags_pressure = n_tags_pressure, n_tags_no_flight = n_tags_pressure - uniqueN(tag_id))], file.path(dir_tables, "bird_height_sample.csv"))
jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), doi = release$doi, version = release$metadata$version, raw_input = path.expand(master), input_md5 = input_md5, published_checksum = release$files$checksum[release$files$key == "pressurepaths.csv"], metadata_md5 = unname(tools::md5sum(file.path(dirname(path.expand(master)), "tags.csv"))), source_md5 = as.list(tools::md5sum(c("scripts/preparation/bird_heights.R", "R/utils.R"))), sample = as.list(fread(file.path(dir_tables, "bird_height_sample.csv"))), height_formula = "288.15 K and -6.5 K/km relative to ERA5 surface pressure, interpolated adjacent-stationary pressure offsets; negative flight heights clamped to zero", flight_filter = "All classified flight; tags without usable flight pressurepaths excluded", time_weighting = "Interval to next retained tag record capped at 60 min; final record uses median positive interval"), file.path(dir_tables, "bird_height_provenance.json"), pretty = TRUE, auto_unbox = TRUE)

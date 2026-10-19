# T07: biological target and bird-height weighting; aggregate outputs only.
# Run from the project root. Primary manuscript outputs are read, never overwritten.
# Reproduce the step-00 pressure-offset and time-step calculations exactly before contrasting targets.
source("R/utils.R")

master <- Sys.getenv(
  "GEOLOCATOR_MASTER",
  "~/Documents/GitHub/GeoLocatorMaster/data/master/pressurepaths.csv"
)
release <- jsonlite::read_json("docs/methods/T07/published-release.json", simplifyVector = TRUE)
stopifnot(paste0("md5:", unname(tools::md5sum(path.expand(master)))) == release$files$checksum[release$files$key == "pressurepaths.csv"])
d <- fread(master, select = c(
  "tag_id", "datetime", "stap_id", "type", "pressure_tag", "surface_pressure", "label",
  "lat", "lon", "temperature_2m", "dewpoint_temperature_2m"
))
d <- d[type == "most_likely" & is.finite(pressure_tag) & is.finite(surface_pressure) &
  (is.na(label) | label != "discard")]
d[, flight := stap_id != round(stap_id)]
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

# Flight definitions and sampling ------------------------------------------
out <- "docs/methods/T07"
fwrite(d[, .(tags_all = uniqueN(tag_id), tags_flight = uniqueN(tag_id[flight]), tags_stationary_only = uniqueN(tag_id) - uniqueN(tag_id[flight]))], "docs/methods/T07/tag_counts.csv")
f <- d[flight == TRUE]
rm(d, st, dep, arr)
invisible(gc())
f[, flight_id := .GRP, by = .(tag_id, prev)]
f[, duration_min := sum(dt), by = flight_id]
f[, elapsed_min := as.numeric(max(t) - min(t), units = "mins") + dt[.N], by = flight_id]
f[, gap_min := as.numeric(shift(t, -1) - t, units = "mins"), by = flight_id]
tags <- fread(file.path(dirname(path.expand(master)), "tags.csv"), select = c("tag_id", "scientific_name"))
f <- merge(f, tags, by = "tag_id", all.x = TRUE)
setorder(f, tag_id, t)
f[, species := fifelse(is.na(scientific_name), "Unknown", scientific_name)]
f[, agl_primary := pmax(agl, 0)]
fwrite(f[, .(points = .N, hours = .N * dt / 60), by = dt][order(dt)], file.path(out, "cadence.csv"))
fwrite(f[, .(points = .N, hours = sum(dt) / 60), by = .(departure_reference = is.finite(off_dep), arrival_reference = is.finite(off_arr))], file.path(out, "offset_support.csv"))
fwrite(f[, .(flights = uniqueN(flight_id), hours = sum(dt) / 60), by = .(duration_ge120 = duration_min >= 120, elapsed_ge120 = elapsed_min >= 120)], file.path(out, "duration_agreement.csv"))
fwrite(f[, .(below0_raw = sum(dt * (agl_raw < 0)) / sum(dt), below0 = sum(dt * (agl < 0)) / sum(dt), below50 = sum(dt * (agl < 50)) / sum(dt), above6000 = sum(dt * (agl >= 6000)) / sum(dt), flights_with_gap_over60 = uniqueN(flight_id[gap_min > 60]), flights = uniqueN(flight_id))], file.path(out, "height_and_gaps.csv"))

# Height-assumption sensitivities, on the same flight points ----------------
f[, agl_temperature := pmax(altitude_lapse(pressure_tag - off, surface_pressure, temperature_2m, 0), 0)]
gpt3 <- gpt3_read(1)
f[, lapse := gpt3_lapse(gpt3, lon, lat, as.POSIXlt(t, tz = "UTC")$yday + 1)]
f[abs(lapse) < 1e-5, lapse := -1e-5]
f[, agl_virtual := pmax(altitude_lapse(pressure_tag - off, surface_pressure, virtual_temperature(temperature_2m, dewpoint_temperature_2m, surface_pressure * 100), 0, lapse), 0)]
# These weather variables/locations are the master-record annotations, not a fresh ERA5 lookup.
variants <- data.table(variant = c("all_flight", "duration_ge2h", "height_ge50m", "duration_ge2h_height_ge50m", "elapsed_ge2h", "equal_bird", "no_ground_offset", "weather_complete", "temperature_2m", "virtual_gpt3", "height_minus100m", "height_plus100m"),
  height = c(rep("agl_primary", 6), "agl_raw", "agl_primary", "agl_temperature", "agl_virtual", "agl_primary", "agl_primary"))
summaries <- list()
weights <- list()
species <- list()
contributions <- list()
for (i in seq_len(nrow(variants))) {
  v <- variants$variant[i]
  a <- copy(f)
  if (v %in% c("duration_ge2h", "duration_ge2h_height_ge50m")) a <- a[duration_min >= 120]
  if (v %in% c("height_ge50m", "duration_ge2h_height_ge50m")) a <- a[agl_primary >= 50]
  if (v == "elapsed_ge2h") a <- a[elapsed_min >= 120]
  if (v %in% c("weather_complete", "temperature_2m", "virtual_gpt3")) a <- a[is.finite(agl_temperature) & is.finite(agl_virtual)]
  a[, h := pmax(get(variants$height[i]), 0)]
  if (v == "height_minus100m") a[, h := pmax(h - 100, 0)]
  if (v == "height_plus100m") a[, h := h + 100]
  a[, wt := dt]
  if (v == "equal_bird") a[, wt := dt / sum(dt), by = tag_id]
  a[, bin := cut(h, c(0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, Inf), right = FALSE)]
  w <- a[, .(weight = sum(wt)), by = bin][order(bin)]
  w[, prop := weight / sum(weight)]
  w[, hbin := levels(cut(0, hbin_breaks, right = TRUE))[-1][as.integer(bin)]]
  w[, variant := v]
  weights[[v]] <- w
  o <- order(a$h)
  cw <- cumsum(a$wt[o]) / sum(a$wt)
  summaries[[v]] <- a[, .(variant = v, birds = uniqueN(tag_id), species = uniqueN(species), flights = uniqueN(flight_id), points = .N, hours = sum(dt) / 60, median_height = h[o][which(cw >= 0.5)[1]], p90_height = h[o][which(cw >= 0.9)[1]], share_below100 = sum(wt * (h < 100)) / sum(wt))]
  species[[v]] <- a[, .(birds = uniqueN(tag_id), flights = uniqueN(flight_id), hours = sum(dt) / 60, weight = sum(wt)), by = species][, `:=`(variant = v, share = weight / sum(weight))]
  # Rank summaries expose concentration without exporting individual identifiers.
  z <- a[, .(hours = sum(dt) / 60, weight = sum(wt)), by = tag_id][order(-weight)]
  contributions[[v]] <- z[, .(variant = v, max_bird_share = max(weight) / sum(weight), top10_bird_share = sum(head(weight, 10)) / sum(weight), median_hours_per_bird = median(hours), min_hours_per_bird = min(hours), max_hours_per_bird = max(hours))]
}
weights <- rbindlist(weights)
summaries <- rbindlist(summaries)
fwrite(weights, file.path(out, "height_weights.csv"))
fwrite(weights, file.path(dir_tables, "bird_target_height_weights.csv"))
fwrite(summaries, file.path(out, "target_support.csv"))
fwrite(summaries, file.path(dir_tables, "bird_target_support.csv"))
fwrite(rbindlist(species), file.path(out, "species_contributions.csv"))
fwrite(rbindlist(contributions), file.path(out, "bird_concentration.csv"))

# Apply common radiosonde error curves to every target ---------------------
curves <- fread(file.path(dir_tables, "paper_flight_height.csv"))
r <- merge(weights, curves, by = "hbin", allow.cartesian = TRUE)
r <- r[, .(bias = sum(bias * prop), mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop))), by = .(variant, formula)]
fwrite(r, file.path(out, "weighted_errors.csv"))
fwrite(merge(summaries, r, by = "variant"), file.path(dir_tables, "paper_bird_target_sensitivity.csv"))
check <- merge(r[variant == "all_flight"], fread(file.path(dir_tables, "paper_flight_bird.csv")), by = "formula")
check[, `:=`(bias_difference = bias.x - bias.y, mae_difference = mae.x - mae.y)]
fwrite(check[, .(formula, bias_difference, mae_difference)], file.path(out, "reproduction_checks.csv"))
stopifnot(max(abs(check$bias_difference)) < 1e-8, max(abs(check$mae_difference)) < 1e-8)
# Test the mapping independently against the current published-release primary bird weights.
frozen <- merge(bird_height_weights()[, .(hbin, prop)], curves, by = "hbin")
frozen <- frozen[, .(bias = sum(bias * prop), mae = sum(mae * prop)), by = formula]
frozen <- merge(frozen, fread(file.path(dir_tables, "paper_flight_bird.csv")), by = "formula")
stopifnot(max(abs(frozen$bias.x - frozen$bias.y)) < 1e-8, max(abs(frozen$mae.x - frozen$mae.y)) < 1e-8)
fwrite(frozen[, .(formula, bias_difference = bias.x - bias.y, mae_difference = mae.x - mae.y)], file.path(out, "primary_weight_checks.csv"))
stopifnot(max(abs(weights[, sum(prop), by = variant]$V1 - 1)) < 1e-12)
jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), doi = release$doi, version = release$metadata$version, raw_input = path.expand(master), raw_input_md5 = unname(tools::md5sum(path.expand(master))), metadata_md5 = unname(tools::md5sum(file.path(dirname(path.expand(master)), "tags.csv"))), source_md5 = as.list(tools::md5sum(c("R/utils.R", "scripts/00_bird_heights.R", "docs/methods/T07/assess_flight_targets.R", file.path(dir_tables, c("paper_flight_height.csv", "paper_flight_bird.csv", "bird_height_distribution.csv"))))), conventions = list(duration = "Sum of capped point intervals within tag and floor(stap_id); comparison with elapsed span plus last capped interval", weighting = "Pooled represented flight time unless equal_bird", height = "Primary uses step-00 pressure-offset-adjusted fixed 288.15 K conversion; alternatives reuse existing master weather annotations", privacy = "No tracking coordinates, individual identities or point records exported")), file.path(out, "provenance.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out, "session-info.txt"))
print(summaries)
print(r)

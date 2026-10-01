# Typical heights of birds tracked with pressure geolocators, used to weight the radiosonde results.
#
# Source: the GeoLocator master data package (https://doi.org/10.5281/zenodo.18187092), including
# its restricted tags (only aggregated distributions are written here), most-likely
# pressurepaths; flight points are those between stationary periods (non-integer stap_id). Height
# above ground is derived from tag pressure vs ERA5 surface pressure with a standard atmosphere: a
# rough estimate, enough to know at which heights the radiosonde errors matter.
#
# Raw, 13% of flight points come out below the ERA5 surface, for two reasons:
# - At rest, tags read on average a few hPa more than ERA5's surface pressure (tag calibration, and
#   resting sites lower than the ERA5 grid-cell mean): 74% of stationary time is "below ground".
#   As in GeoPressureR's `surface_pressure_norm`, each flight is referenced to the bird's own
#   ground: the tag minus ERA5 pressure offset at departure (last 6 h of the previous stationary
#   period) and at arrival (first 6 h of the next), interpolated in time over the flight.
# - The remaining 9% of flight time below 0 is either within 100 m of the ground (4%: low flight,
#   take-off and landing, 1 hPa tag resolution = 8 m) or deeper, mostly over mountains (5%; half of it
#   where ERA5's surface is above 1000 m), where the straight line between stationary periods
#   crosses ERA5's smoothed terrain while the bird flies along valleys below it. These points are
#   counted as flying at ground level (lowest bin).
# Tags sample pressure every 5 to 60 min, so each point is weighted by its time step: the
# distribution is the share of flight *time* in each height bin. Only binned values are written, so
# this step is optional: the resulting CSV is committed in output/tables/.

source("R/utils.R")

master <- Sys.getenv(
  "GEOLOCATOR_MASTER",
  "~/Documents/GitHub/GeoLocatorMaster/data/master_restricted/pressurepaths.csv"
)
d <- fread(master, select = c(
  "tag_id", "datetime", "stap_id", "type", "pressure_tag", "surface_pressure", "label"
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
h[, n_tags := uniqueN(d$tag_id)]
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

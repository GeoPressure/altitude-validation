# Typical heights of birds tracked with pressure geolocators, used to weight Tier B results.
#
# Source: the GeoLocator master data package (https://doi.org/10.5281/zenodo.18187092), most-likely
# pressurepaths. Height above the ERA5 surface is derived from tag pressure vs ERA5 surface pressure
# with a standard atmosphere. Only binned counts are written, so this step is optional: the
# resulting CSV is committed in output/tables/.

source("R/utils.R")

master <- Sys.getenv(
  "GEOLOCATOR_MASTER",
  "~/Documents/GitHub/GeoLocatorMaster/data/master/pressurepaths.csv"
)
d <- fread(master, select = c(
  "tag_id", "stap_id", "type", "pressure_tag", "surface_pressure", "label"
))
d <- d[type == "most_likely" & is.finite(pressure_tag) & is.finite(surface_pressure) &
  (is.na(label) | label != "discard")]
d[, flight := stap_id != round(stap_id)]
d[, agl := 288.15 / -0.0065 * ((pressure_tag / surface_pressure)^(-8.31432 * -0.0065 / 9.80665 /
  0.0289644) - 1)]

breaks <- c(-Inf, 0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000, Inf)
h <- d[, .(n = .N), by = .(flight, bin = cut(agl, breaks, right = FALSE))]
h[, prop := n / sum(n), by = flight]
setorder(h, flight, bin)
h[, n_tags := uniqueN(d$tag_id)]
fwrite(h, file.path(dir_tables, "bird_height_distribution.csv"))

q <- d[, as.list(quantile(agl, c(0.05, 0.25, 0.5, 0.75, 0.95, 0.99))), by = flight]
fwrite(q, file.path(dir_tables, "bird_height_quantiles.csv"))
print(h)
print(q)

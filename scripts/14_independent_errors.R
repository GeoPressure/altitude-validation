# Altitude errors at references with a documented barometer height: GNSS stations with met sensors
# (not assimilated by ERA5) and MeteoSwiss SwissMetNet (barometer height published separately).
#
# GNSS barometer height. Two independent estimates are compared:
#   - log:    marker ellipsoidal height (site log XYZ) + Marker->ARP Up + "Height Diff to Ant" of the
#             pressure sensor, each taken from the site-log entry valid on that day;
#   - header: SENSOR POS H of the daily RINEX met file (and the height of SENSOR POS XYZ when given).
# A station is height-checked when the log and header heights agree within 1 m (median over its
# days). The log height is used where the log covers the day, else the header height. Ellipsoidal heights are converted to heights above the geoid with EGM96, the geoid of
# ERA5's orography (SRTM30) south of 60N; EGM2008 is used as a sensitivity.
#
# The altitude is computed exactly as for the HadISD stations (ERA5 single-levels and ERA5-Land,
# GeoPressureR's `pressure_to_altitude()`), and gross errors are removed with the same rule.

source("R/utils.R")
load_geopressurer()

# ---- GNSS site logs --------------------------------------------------------------------------
ecef_to_geodetic <- function(x, y, z) {
  a <- 6378137
  f <- 1 / 298.257223563
  e2 <- f * (2 - f)
  lon <- atan2(y, x)
  p <- sqrt(x^2 + y^2)
  lat <- atan2(z, p * (1 - e2))
  for (i in 1:6) {
    n <- a / sqrt(1 - e2 * sin(lat)^2)
    h <- p / cos(lat) - n
    lat <- atan2(z, p * (1 - e2 * n / (n + h)))
  }
  list(lat = lat * 180 / pi, lon = lon * 180 / pi, h = h)
}

log_field <- function(block, name) {
  m <- regmatches(block, regexpr(paste0("(?m)^\\s*", name, "\\s*:[^\n]*"), block, perl = TRUE))
  if (length(m) == 0) return(NA_character_)
  trimws(sub("^[^:]*:", "", m))
}
log_num <- function(x) suppressWarnings(as.numeric(regmatches(x, regexpr("[-+]?[0-9]+(\\.[0-9]+)?", x))))
log_date <- function(x, default) {
  x <- substr(x, 1, 10)
  if (length(x) == 0 || is.na(x) || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) return(default)
  as.Date(x)
}

#' Periods of the site log: marker position, and per period the ARP height and the pressure
#' sensor (model, accuracy, height above the ARP).
parse_log <- function(path) {
  s <- paste(readLines(path, warn = FALSE), collapse = "\n")
  xyz <- vapply(c("X", "Y", "Z"), function(k) log_num(log_field(s, paste(k, "coordinate \\(m\\)"))),
    numeric(1))
  g <- ecef_to_geodetic(xyz[1], xyz[2], xyz[3])
  sec4 <- regmatches(s, regexpr("(?s)\n4\\.\\s+GNSS Antenna Information.*?\n5\\.", s, perl = TRUE))
  ant <- strsplit(sec4, "\n(?=4\\.[0-9]+\\s+Antenna Type)", perl = TRUE)[[1]][-1]
  ant <- rbindlist(lapply(ant, function(b) data.table(
    from = log_date(log_field(b, "Date Installed"), as.Date("1900-01-01")),
    to = log_date(log_field(b, "Date Removed"), as.Date("2100-01-01")),
    arp_up = log_num(log_field(b, "Marker->ARP Up Ecc\\. \\(m\\)"))
  )))
  sec8 <- regmatches(s, regexpr("(?s)\n8\\.\\s+Meteorological Instrumentation.*?\n9\\.", s,
    perl = TRUE))
  pr <- if (length(sec8)) strsplit(sec8, "\n(?=8\\.[0-9]\\.[0-9x]+ )", perl = TRUE)[[1]] else NULL
  pr <- pr[grepl("^8\\.2\\.[0-9]", pr)]
  pr <- rbindlist(lapply(pr, function(b) {
    eff <- strsplit(log_field(b, "Effective Dates"), "/", fixed = TRUE)[[1]]
    data.table(
      from = log_date(eff[1], as.Date("1900-01-01")),
      to = log_date(if (length(eff) > 1) eff[2] else NA, as.Date("2100-01-01")),
      log_model = paste(log_field(b, "Manufacturer"), trimws(sub("^[^:]*:", "",
        strsplit(b, "\n")[[1]][1]))),
      log_acc = log_num(log_field(b, "Accuracy")),
      hdiff = log_num(log_field(b, "Height Diff to Ant"))
    )
  }))
  list(lat = g$lat, lon = g$lon, h_marker = g$h, ant = ant, pr = pr)
}

gnss_dir <- file.path(dir_interim, "gnss", "hourly")
log_files <- list.files(file.path(dir_raw, "gnss_logs"), "\\.log$", full.names = TRUE)
G <- rbindlist(lapply(list.files(gnss_dir, "\\.parquet$", full.names = TRUE), function(f) {
  d <- as.data.table(read_parquet(f))
  if (nrow(d) == 0) return(NULL)
  s <- d$station[1]
  lf <- log_files[startsWith(basename(log_files), tolower(s))]
  if (length(lf) == 0) {
    message("no site log: ", s)
    return(NULL)
  }
  lg <- parse_log(lf[1])
  if (!is.finite(lg$h_marker)) return(NULL)
  day <- as.Date(d$date)
  arp <- vapply(day, function(x) {
    v <- lg$ant[from <= x & to > x, arp_up]
    if (length(v)) v[1] else NA_real_
  }, numeric(1))
  ip <- vapply(day, function(x) {
    v <- which(lg$pr$from <= x & lg$pr$to > x)
    if (length(v)) v[length(v)] else NA_integer_
  }, integer(1))
  d[, `:=`(lat = lg$lat, lon = lg$lon, h_marker = lg$h_marker, arp_up = arp,
    hdiff = lg$pr$hdiff[ip], log_model = lg$pr$log_model[ip], log_acc = lg$pr$log_acc[ip])]
  d[, h_log := h_marker + arp_up + hdiff]
  hx <- ecef_to_geodetic(d$hdr_X, d$hdr_Y, d$hdr_Z)$h
  d[, h_hdr_xyz := fifelse(abs(hdr_X) > 1, hx, NA_real_)]
  d
}), fill = TRUE)

# Geoid grids distributed with PROJ
for (g in c("us_nga_egm96_15.tif", "us_nga_egm08_25.tif")) {
  if (!file.exists(file.path(dir_raw, g))) curl_download(paste0("https://cdn.proj.org/", g), file.path(dir_raw, g))
}
egm96 <- terra::rast(file.path(dir_raw, "us_nga_egm96_15.tif"))
egm08 <- terra::rast(file.path(dir_raw, "us_nga_egm08_25.tif"))
gst <- unique(G[, .(station, lat, lon)], by = "station")
gst[, N96 := terra::extract(egm96, cbind(lon, lat), method = "bilinear")[[1]]]
gst[, N08 := terra::extract(egm08, cbind(lon, lat), method = "bilinear")[[1]]]
G <- merge(G, gst[, .(station, N96, N08)], by = "station")

# Station-level height check and sensor class
hc <- G[, .(
  d_hdr_log = median(hdr_H - h_log, na.rm = TRUE),
  d_xyz_log = median(h_hdr_xyz - h_log, na.rm = TRUE),
  sensor = names(sort(table(paste(sensor, log_model)), decreasing = TRUE))[1]
), by = station]
hc[, height_ok := is.finite(d_hdr_log) & abs(d_hdr_log) <= 1]
hc[, sensor_class := fcase(
  grepl("paro|met3|met4|met 3|met 4", sensor, ignore.case = TRUE), "barometer (Paroscientific)",
  grepl("ptb|ptu|setra|druck|aps", sensor, ignore.case = TRUE), "barometer (other)",
  grepl("wxt|wtx|weather transmitter", sensor, ignore.case = TRUE), "weather transmitter (WXT)",
  default = "other/unknown")]
G <- merge(G, hc[, .(station, height_ok, sensor_class)], by = "station")
# The site-log height is used where available (independent of the met file), else the header's.
G[, h_use := fifelse(is.finite(h_log), h_log, hdr_H)]
G[, `:=`(elev = h_use - N96, elev_08 = h_use - N08)]
G <- G[is.finite(elev) & is.finite(pressure)]
G <- G[, .(source = "GNSS", id = station, lat, lon, date, pressure, elev, elev_08,
  elev_hdr = hdr_H - N96, height_ok, sensor_class, in_isd = FALSE)]

# ---- MeteoSwiss --------------------------------------------------------------------------------
ms_st <- fread(file.path(dir_interim, "meteoswiss", "stations.csv"))
M <- rbindlist(lapply(list.files(file.path(dir_interim, "meteoswiss"), "\\.parquet$",
  full.names = TRUE), function(f) as.data.table(read_parquet(f))))
M <- merge(M, ms_st[, .(id, lat, lon, elev, in_isd)], by = "id")
M <- M[, .(source = "MeteoSwiss", id, lat, lon, date, pressure, elev, elev_08 = elev,
  elev_hdr = elev, height_ok = TRUE, sensor_class = "barometer (other)", in_isd)]

X <- rbind(G, M)
X <- X[as.integer(format(date, "%Y")) %in% years_main]
st <- unique(X[, .(source, id, lat, lon, elev, height_ok, sensor_class, in_isd)], by = c("source",
  "id"))
cat(nrow(st), "stations:", paste(names(table(st$source)), table(st$source), collapse = ", "), "\n")

# ---- ERA5 and errors ---------------------------------------------------------------------------
st[, z_sl := era5_orography(lon, lat, "single-levels")]
st[, z_land := era5_orography(lon, lat, "land")]
st[, sdor := {
  inv <- terra::rast(file.path(dir_raw, "era5_invariant.nc"))
  names(inv) <- ifelse(grepl("sdor", names(inv)), "sdor", "lsm")
  if (terra::xmax(inv) > 180) inv <- terra::rotate(inv)
  g <- era5_snap(lon, lat, "single-levels")
  terra::extract(inv[["sdor"]], cbind(g$lon, g$lat))[[1]]
}]

err_dir <- file.path(dir_interim, "indep")
dir.create(err_dir, showWarnings = FALSE)
one <- function(k) {
  s <- st[k]
  out <- file.path(err_dir, paste0(s$source, "_", s$id, ".parquet"))
  if (file.exists(out)) return(TRUE)
  d <- X[source == s$source & id == s$id]
  a <- era5_read(rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), d$date,
    c("surface_pressure", "temperature_2m"), "single-levels")
  l <- era5_read(rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), d$date,
    c("surface_pressure", "temperature_2m"), "land")
  d[, err_sl := era5_altitude(pressure * 100, a$surface_pressure, a$temperature_2m, s$z_sl) - elev]
  d[, err_land := era5_altitude(pressure * 100, l$surface_pressure, l$temperature_2m, s$z_land) -
    elev]
  write_parquet(d, out)
  TRUE
}
res <- par_map(seq_len(nrow(st)), one, cores = n_cores, geopressurer = TRUE,
  export = c("st", "X", "err_dir"))
cat(sum(vapply(res, isTRUE, logical(1))), "of", nrow(st), "stations done\n")

E <- rbindlist(lapply(list.files(err_dir, "\\.parquet$", full.names = TRUE), function(f) {
  as.data.table(read_parquet(f))
}))
# Gross errors, as for HadISD: more than 100 m and 10 robust SD from the station's median error
E[, gross := {
  m <- median(err_sl, na.rm = TRUE)
  abs(err_sl - m) > max(100, 10 * mad(err_sl, na.rm = TRUE))
}, by = .(source, id)]
gross_frac <- E[, .(gross_frac = mean(gross %in% TRUE)), by = source]
E <- E[!gross %in% TRUE & is.finite(err_sl)]

ss <- E[, .(n = .N, bias_sl = mean(err_sl), sd_sl = sd(err_sl), bias_land = mean(err_land,
  na.rm = TRUE), sd_land = sd(err_land, na.rm = TRUE),
  # Header-height and EGM2008 variants only shift the constant height of the station
  bias_hdr = mean(err_sl) + elev[1] - elev_hdr[1], bias_08 = mean(err_sl) + elev[1] - elev_08[1]),
  by = .(source, id)]
ss <- merge(st, ss, by = c("source", "id"))
ss[, dz_sl := elev - z_sl]
ss <- ss[n >= 24 * 90]
fwrite(ss, file.path(dir_tables, "indep_station_stats.csv"))

# Station counts at each selection step (for the report's selection table)
lst <- fread(file.path(dir_interim, "gnss", "listing.csv"))
ms_meta <- fread(file.path(dir_raw, "ogd-smn_meta_stations.csv"), encoding = "Latin-1")
counts <- data.table(
  source = c("GNSS", "MeteoSwiss"),
  n_raw = c(uniqueN(toupper(substr(lst$file, 1, 4))), nrow(ms_meta)),
  n_enough = c(ss[source == "GNSS", .N], ss[source == "MeteoSwiss", .N]),
  n_used = c(ss[source == "GNSS" & height_ok, .N], ss[source == "MeteoSwiss", .N])
)
counts <- merge(counts, gross_frac, by = "source")
fwrite(counts, file.path(dir_tables, "indep_counts.csv"))
print(counts)


# ---- Comparison with HadISD ------------------------------------------------------------------
# Same statistics by terrain for the HadISD reference set and the independent references, so that
# assimilated and non-assimilated stations are compared in similar terrain.
hz <- fread(file.path(dir_tables, "ground_station_stats.csv"))[reference == TRUE]
cmp <- rbind(
  hz[, .(set = "HadISD reference set", terrain = terrain_class(sdor), bias_sl, sd_sl)],
  ss[source == "GNSS" & height_ok, .(set = "GNSS, height-checked", terrain = terrain_class(sdor), bias_sl,
    sd_sl)],
  ss[source == "MeteoSwiss", .(set = fifelse(in_isd, "MeteoSwiss, in ISD", "MeteoSwiss, not in ISD"),
    terrain = terrain_class(sdor), bias_sl, sd_sl)]
)
cmp <- cmp[, .(n_stations = .N, abs_bias_median = median(abs(bias_sl)), sd_median = median(sd_sl)),
  keyby = .(set, terrain)]
fwrite(cmp, file.path(dir_tables, "indep_by_terrain.csv"))
print(cmp)

# Station density: if ERA5 fitted each assimilated station tightly, isolated stations (largest
# observation influence) would show the smallest scatter.
all_st <- fread(file.path(dir_interim, "hadisd_stations_all.csv"))
hav <- function(la1, lo1, la2, lo2) {
  r <- pi / 180
  6371 * 2 * asin(sqrt(sin((la2 - la1) * r / 2)^2 + cos(la1 * r) * cos(la2 * r) *
    sin((lo2 - lo1) * r / 2)^2))
}
hz[, nb300 := mapply(function(a, b) sum(hav(a, b, all_st$lat, all_st$lon) < 300) - 1, lat, lon)]
dens <- hz[sdor < 20, .(n_stations = .N, sd_median = median(sd_sl),
  abs_bias_median = median(abs(bias_sl))),
  keyby = .(neighbours_300km = cut(nb300, c(-1, 2, 10, 30, Inf), labels = c("0-2", "3-10", "11-30",
    ">30")))]
fwrite(dens, file.path(dir_tables, "assim_density.csv"))
print(dens)

# MeteoSwiss barometer heights vs the elevation HadISD lists for the same stations
had <- fread(file.path(dir_interim, "hadisd_stations_all.csv"))
had[, wmo := substr(id, 1, 5)]
ms <- merge(ms_st[!is.na(wmo), .(wmo = sprintf("%05d", as.integer(wmo)), id, name, elev_station,
  elev)], had[, .(wmo, hadisd_id = id, hadisd_elev = elev)], by = "wmo")
ms[, `:=`(d_station = hadisd_elev - elev_station, d_barometer = hadisd_elev - elev)]
# ERA5 bias at the same Swiss stations with HadISD's elevation and with the published barometer
# height: if HadISD's biases there come from its elevations, they follow -(HadISD - barometer).
hz_all <- fread(file.path(dir_tables, "ground_station_stats.csv"))
ms <- merge(ms, hz_all[, .(hadisd_id = id, bias_hadisd = bias_sl, reference)], by = "hadisd_id",
  all.x = TRUE)
ms <- merge(ms, ss[source == "MeteoSwiss", .(id, bias_meteoswiss = bias_sl)], by = "id", all.x = TRUE)
fwrite(ms, file.path(dir_tables, "meteoswiss_vs_hadisd.csv"))
both <- ms[is.finite(bias_hadisd) & is.finite(bias_meteoswiss)]
fwrite(both[, .(n = .N, n_diff5 = sum(abs(d_barometer) > 5),
  r_bias_vs_height = cor(bias_hadisd, -d_barometer),
  abs_bias_median_hadisd = median(abs(bias_hadisd)),
  abs_bias_median_meteoswiss = median(abs(bias_meteoswiss)),
  mean_abs_bias_hadisd = mean(abs(bias_hadisd)), mean_abs_bias_meteoswiss = mean(abs(bias_meteoswiss)),
  n_ref = sum(reference), n_ref_diff5 = sum(reference & abs(d_barometer) > 5))],
  file.path(dir_tables, "meteoswiss_vs_hadisd_summary.csv"))
cat(nrow(ms), "MeteoSwiss stations in HadISD; |HadISD elevation - barometer height| > 5 m at",
  ms[abs(d_barometer) > 5, .N], "\n")

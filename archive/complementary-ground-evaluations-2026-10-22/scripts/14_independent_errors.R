# Altitude errors at references with a documented barometer height: GNSS stations with met sensors
# (assimilation status unverified) and MeteoSwiss SwissMetNet (barometer height published separately).
#
# GNSS barometer height. Two documented estimates are compared:
#   - log:    marker ellipsoidal height (site log XYZ) + Marker->ARP Up + "Height Diff to Ant" of the
#             pressure sensor, each taken from the site-log entry valid on that day;
#   - header: SENSOR POS H of the daily RINEX met file (and the height of SENSOR POS XYZ when given).
# One height source is selected for the whole GNSS dataset by its median absolute ERA5-standard
# station bias on common accepted records. Ellipsoidal heights are converted with EGM96, the geoid of
# ERA5's orography (SRTM30) south of 60N; EGM2008 is used as a sensitivity.
#
# The altitude is computed exactly as for the GHCNh stations (ERA5 single-levels and ERA5-Land,
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
log_num <- function(x) suppressWarnings(as.numeric(regmatches(x, regexpr("[-+]?[0-9]+(\\.[0-9]+)?", x)))[1])
log_date <- function(x, default) {
  x <- substr(x, 1, 10)
  if (length(x) == 0 || is.na(x) || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) return(default)
  as.Date(x)
}

#' Periods of the site log: marker position, and per period the ARP height and the pressure
#' sensor (model, accuracy, height above the ARP).
parse_log <- function(path) {
  s <- paste(readLines(path, warn = FALSE, encoding = "latin1"), collapse = "\n")
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
    position <- ecef_to_geodetic(d$hdr_X, d$hdr_Y, d$hdr_Z)
    d[, `:=`(lat = position$lat, lon = position$lon, h_log = NA_real_,
      log_model = NA_character_, log_acc = NA_real_, h_hdr_xyz = position$h)]
    return(d)
  }
  lg <- parse_log(lf[1])
  if (!is.finite(lg$h_marker)) return(NULL)
  day <- unique(as.Date(d$date))
  arp <- vapply(day, function(x) {
    v <- lg$ant[from <= x & to > x, arp_up]
    if (length(v)) v[1] else NA_real_
  }, numeric(1))
  ip <- vapply(day, function(x) {
    v <- which(lg$pr$from <= x & lg$pr$to > x)
    if (length(v)) v[length(v)] else NA_integer_
  }, integer(1))
  arp <- arp[match(as.Date(d$date), day)]
  ip <- ip[match(as.Date(d$date), day)]
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

# Sensor class
hc <- G[, .(
  sensor = names(sort(table(paste(sensor, log_model)), decreasing = TRUE))[1]
), by = station]
hc[, sensor_class := fcase(
  grepl("paro|met3|met4|met 3|met 4", sensor, ignore.case = TRUE), "barometer (Paroscientific)",
  grepl("ptb|ptu|setra|druck|aps", sensor, ignore.case = TRUE), "barometer (other)",
  grepl("wxt|wtx|weather transmitter", sensor, ignore.case = TRUE), "weather transmitter (WXT)",
  default = "other/unknown")]
G <- merge(G, hc[, .(station, sensor_class)], by = "station")
# The site-log height is used where available (documented separately from the met file), else the header's.
G[, h_use := fifelse(is.finite(h_log), h_log, hdr_H)]
G[, `:=`(elev = h_use - N96, elev_log = h_log - N96, elev_08 = h_use - N08)]
G <- G[is.finite(elev) & is.finite(pressure)]
G <- G[, .(source = "GNSS", id = station, lat, lon, date, pressure, elev, elev_08,
  elev_hdr = hdr_H - N96, elev_log, sensor_class)]

# ---- MeteoSwiss --------------------------------------------------------------------------------
ms_st <- fread(file.path(dir_interim, "meteoswiss", "stations.csv"))
M <- rbindlist(lapply(list.files(file.path(dir_interim, "meteoswiss"), "\\.parquet$",
  full.names = TRUE), function(f) as.data.table(read_parquet(f))))
M <- merge(M, ms_st[, .(id, lat, lon, elev)], by = "id")
M <- M[, .(source = "MeteoSwiss", id, lat, lon, date, pressure, elev, elev_08 = elev,
  elev_hdr = elev, elev_log = NA_real_, sensor_class = "barometer (other)")]

X <- rbind(G, M)
X <- X[as.integer(format(date, "%Y")) %in% years_main]
X <- average_reference_hours(X)
st <- unique(X[, .(source, id, lat, lon, elev, sensor_class)], by = c("source",
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
var_sl <- c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m")
one <- function(k) {
  s <- st[k]
  out <- file.path(err_dir, paste0(s$source, "_", s$id, ".parquet"))
  d <- X[source == s$source & id == s$id]
  if (file.exists(out)) {
    previous <- as.data.table(read_parquet(out))
    if (!"altitude_land" %in% names(previous)) previous[, altitude_land := err_land + elev]
    previous <- previous[, .(sp_sl = mean(sp_sl), t2m_sl = mean(t2m_sl), d2m = mean(d2m),
      altitude_land = mean(altitude_land)), by = date]
    d <- merge(d, previous, by = "date", all.x = TRUE)
  } else {
    a <- era5_read(rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), d$date, var_sl, "single-levels")
    l <- era5_read(rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), d$date,
      c("surface_pressure", "temperature_2m"), "land")
    d[, `:=`(sp_sl = a$surface_pressure, t2m_sl = a$temperature_2m,
      d2m = a$dewpoint_temperature_2m,
      altitude_land = era5_altitude(pressure * 100, l$surface_pressure, l$temperature_2m, s$z_land))]
  }
  d[, `:=`(err_sl = era5_altitude(pressure * 100, sp_sl, t2m_sl, s$z_sl) - elev,
    err_land = altitude_land - elev)]
  write_parquet(d, out)
  TRUE
}
res <- par_map(seq_len(nrow(st)), one, cores = n_cores, geopressurer = TRUE,
  export = c("st", "X", "err_dir", "var_sl"))
check_failures(res, paste(st$source, st$id), "complementary station inputs", fatal = TRUE)

E <- rbindlist(lapply(list.files(err_dir, "\\.parquet$", full.names = TRUE), function(f) {
  as.data.table(read_parquet(f))
}), use.names = TRUE)
# Daily met files can overlap at midnight. Average repeated hours before QC and coverage.
E <- average_reference_hours(E)
stopifnot(inherits(E$date, "POSIXct"), !inherits(E$lon, "POSIXct"))
E[st, on = .(source, id), z_sl := i.z_sl]
E[, err_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - elev]
# Cached ERA5-Land errors are averaged at repeated hours; primary comparisons use single-levels.
# Gross errors, as for GHCNh: more than 100 m and 10 robust SD from the station's median error
E[, gross := {
  m <- median(err_sl, na.rm = TRUE)
  abs(err_sl - m) > max(100, 10 * mad(err_sl, na.rm = TRUE))
}, by = .(source, id)]
gross_frac <- E[, .(gross_frac = mean(gross %in% TRUE)), by = source]
# Compare the two sources on the same accepted hours and stations.
accepted <- !E$gross & is.finite(E$err_sl)
common <- E[source == "GNSS" & accepted & is.finite(elev_log) & is.finite(elev_hdr)]
choice <- common[, .(n = .N, site_log = mean(err_sl + elev - elev_log),
  header = mean(err_sl + elev - elev_hdr)), by = id][n >= 2160]
choice <- melt(choice, id.vars = c("id", "n"), variable.name = "height_source", value.name = "bias")
choice <- choice[, .(stations = .N, median_abs_bias = median(abs(bias))), by = height_source]
selected <- as.character(choice[which.min(median_abs_bias), height_source])
choice[, selected := as.character(height_source) == selected]
fwrite(choice, file.path(dir_tables, "gnss_height_reference_choice.csv"))
print(choice)
# Apply this single reference source to every GNSS station, including single-source sites.
E[, `:=`(altitude_sl = err_sl + elev, geoid_shift = elev_08 - elev,
  height_source = "published")]
E[source == "GNSS", `:=`(elev = get(if (selected == "header") "elev_hdr" else "elev_log"),
  height_source = selected)]
E[, `:=`(elev_08 = elev + geoid_shift, err_sl = altitude_sl - elev, err_land = altitude_land - elev)]
for (i in seq_len(nrow(st))) {
  d <- E[source == st$source[i] & id == st$id[i]]
  write_parquet(d, file.path(err_dir, paste0(st$source[i], "_", st$id[i], ".parquet")))
}
E <- E[accepted & is.finite(elev)]
st[E[, .(elev = median(elev), height_source = height_source[1]), by = .(source, id)],
  on = .(source, id), `:=`(elev = i.elev, height_source = i.height_source)]

ss <- E[, .(n = .N, n_land = sum(is.finite(err_land)),
  bias_sl_paired = mean(err_sl[is.finite(err_land)]), sd_sl_paired = sd(err_sl[is.finite(err_land)]),
  bias_sl = mean(err_sl), sd_sl = sd(err_sl), bias_land = mean(err_land,
  na.rm = TRUE), sd_land = sd(err_land, na.rm = TRUE),
  # Header-height and EGM2008 variants only shift the constant height of the station
  bias_hdr = mean(altitude_sl - elev_hdr), bias_08 = mean(altitude_sl - elev_08)),
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
  n_used = c(ss[source == "GNSS", .N], ss[source == "MeteoSwiss", .N])
)
counts <- merge(counts, gross_frac, by = "source")
fwrite(counts, file.path(dir_tables, "indep_counts.csv"))
print(counts)

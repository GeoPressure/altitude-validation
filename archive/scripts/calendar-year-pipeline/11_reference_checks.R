# Reference-plausibility diagnostics for GHCNh station elevation and pressure.
#
# A station's constant offset (bias) can come from ERA5 or from the station itself: a wrong listed
# elevation, a pressure reported at another datum than the listed elevation, a barometer offset, or
# a change of site or instrument. Three checks that do not use the bias itself help tell them apart, plus the basis of the bound:
#
#   1. Step changes flag possible relocation, instrument or reference-height changes;
#      the flag does not uniquely identify the cause. Monthly median errors in the selected year and up to two preceding years are fitted with a month-of-year
#      effect plus one step at the best breakpoint. Stations with a clear step (|step| >= 10 m and
#      |t| >= 10) are excluded from the reference set in 12_analysis.R.
#   2. DEM. SRTM (30 m) and ASTER GDEM (30 m) on a 5 x 5 grid covering the coordinate uncertainty
#      (+/- 0.5 arc-minute when the coordinates are whole arc-minutes, else +/- 0.0005 deg), via the
#      OpenTopoData public API. The listed elevation is "refuted" when it lies more than 15 m outside
#      the DEM range of the box in every available DEM. Used as supporting evidence only: coordinate precision
#      limits it (see the report).
#   3. Neighbours. For every station with |bias| > 15 m, and 60 random stations with |bias| <= 10 m
#      as controls, the ERA5 bias in that station-year at up to two nearby GHCNh stations with data
#      in the same year. An error of ERA5 should be shared by nearby stations; a station error should not.
#   4. The basis of the plausibility bound used in 12_analysis.R: the bias where ERA5 needs no
#      extrapolation, and the extrapolation error over a height gap measured by the radiosondes.

source("R/utils.R")
load_geopressurer()
set.seed(11)

st <- fread(file.path(dir_tables, "stations.csv"))[network == "ghcnh"]
# ---- 2. DEM in the coordinate-uncertainty box --------------------------------------------------
st[, minute_coord := abs(lat * 60 - round(lat * 60)) < 0.03 & abs(lon * 60 - round(lon * 60)) < 0.03]
st[, hw := fifelse(minute_coord, 0.5 / 60, 0.0005)]
off <- seq(-1, 1, length.out = 5)
pts <- st[, CJ(i = off, j = off), by = .(id, lat, lon, hw)]
pts[, `:=`(plat = lat + i * hw, plon = lon + j * hw / cos(lat * pi / 180))]
dem_file <- file.path(dir_interim, "station_dem_box.csv")
# Reuse legacy DEM queries only where the source and GHCNh coordinates are exactly identical.
if (file.exists(dem_file)) {
  old <- fread(dem_file)
  crosswalk <- fread(file.path(dir_interim, "ghcnh", "legacy_station_matches.csv"))
  crosswalk <- crosswalk[abs(ghcnh_lat - legacy_lat) < 1e-8 &
    abs(ghcnh_lon - legacy_lon) < 1e-8, .(id = legacy_id, new_id = ghcnh_id)]
  migrated <- merge(old, crosswalk, by = "id")
  migrated[, id := new_id]
  migrated[, new_id := NULL]
  fwrite(unique(rbind(old, migrated), by = c("id", "i", "j", "dataset")), dem_file)
}
for (ds in c("srtm30m", "aster30m")) {
  done <- if (file.exists(dem_file)) fread(dem_file)[dataset == ds, paste(id, i, j)] else character()
  q <- pts[!paste(id, i, j) %in% done]
  # If SRTM already includes the listed height, the combined DEM rule cannot refute it.
  # Query ASTER only where it can resolve an SRTM discrepancy or fill SRTM's missing coverage.
  if (ds == "aster30m") {
    sr <- fread(dem_file)[dataset == "srtm30m" & is.finite(dem)]
    sr <- sr[, .(lo = min(dem), hi = max(dem)), by = id]
    sr <- merge(st[, .(id, elev)], sr, by = "id", all.x = TRUE)
    need_aster <- sr[is.na(lo) | elev < lo - 15 | elev > hi + 15, id]
    q <- q[id %in% need_aster]
  }
  for (b in split(seq_len(nrow(q)), ceiling(seq_len(nrow(q)) / 100))) {
    request_started <- Sys.time()
    loc <- paste(sprintf("%.5f,%.5f", q$plat[b], q$plon[b]), collapse = "|")
    r <- httr2::request(paste0("https://api.opentopodata.org/v1/", ds)) |>
      httr2::req_body_form(locations = loc) |>
      httr2::req_retry(max_tries = 5) |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    el <- vapply(r$results, function(z) if (is.null(z$elevation)) NA_real_ else z$elevation, 1)
    fwrite(q[b, .(id, i, j, dataset = ds, dem = el)], dem_file, append = file.exists(dem_file))
    Sys.sleep(max(0, 1.1 - as.numeric(difftime(Sys.time(), request_started, units = "secs"))))
  }
}
d <- fread(dem_file)
d[, dem := as.numeric(dem)]
# ASTER GDEM returns 0 over sea and in voids (no SRTM beyond 60 N): treat as missing.
d[dataset == "aster30m" & dem == 0, dem := NA]
d <- d[is.finite(dem)]
box <- d[, .(centre = dem[i == 0 & j == 0][1], lo = min(dem), hi = max(dem)), by = .(id, dataset)]
box[, dataset := sub("30m$", "", dataset)]
box <- dcast(box, id ~ dataset, value.var = c("centre", "lo", "hi"))
setnames(box, names(box), sub("^(centre|lo|hi)_(.*)$", "dem_\\2_\\1", names(box)))
dem <- merge(st[, .(id, elev, minute_coord)], box, by = "id", all.x = TRUE)
outside <- function(elev, lo, hi, tol = 15) pmax(lo - tol - elev, elev - hi - tol, 0)
dem[, dem_refutes := {
  o_s <- outside(elev, dem_srtm_lo, dem_srtm_hi)
  o_a <- outside(elev, dem_aster_lo, dem_aster_hi)
  fifelse(is.finite(o_s), o_s > 0 & (is.na(o_a) | o_a > 0), o_a > 0)
}]
dem[, elev := NULL]

if (Sys.getenv("REFERENCE_CHECKS_DEM_ONLY") == "1") quit(save = "no")

A <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet")))
selected_years <- st[, .(id, year = selected_year)]
A <- A[!gross %in% TRUE & is.finite(err_sl)]
bias <- A[selected_years, on = .(id, year), nomatch = 0L][, .(bias = mean(err_sl)), by = id]

A <- merge(A, st[, .(id, selected_year)], by = "id")
A <- A[year >= selected_year - 2 & year <= selected_year]

# ---- 1. Step changes -------------------------------------------------------------------------
A[, `:=`(ym = format(date, "%Y-%m"), moy = format(date, "%m"))]
M <- A[, .(e = median(err_sl), n = .N), by = .(id, ym, moy)][n >= 60][order(id, ym)]
step_fit <- function(e, moy, ym) {
  k <- length(e)
  na <- list(step = NA_real_, step_at = NA_character_, step_t = NA_real_, step_resid_sd = NA_real_)
  if (k < 18 || uniqueN(moy) < 12) return(na)
  season <- model.matrix(~ factor(moy))
  best <- list(rss = Inf)
  for (i in 6:(k - 6)) {
    X <- cbind(season, x = as.numeric(seq_len(k) > i))
    f <- lm.fit(X, e)
    if (f$rank < ncol(X)) next
    rss <- sum(f$residuals^2)
    if (rss < best$rss) best <- list(rss = rss, i = i, X = X, step = unname(f$coefficients["x"]))
  }
  if (!is.finite(best$rss)) return(na)
  s2 <- best$rss / (k - ncol(best$X))
  se <- sqrt(s2 * solve(crossprod(best$X))["x", "x"])
  list(step = best$step, step_at = ym[best$i + 1], step_t = best$step / se,
    step_resid_sd = sqrt(s2))
}
steps <- M[, step_fit(e, moy, ym), by = id]
steps[, `:=`(step_tested = is.finite(step), step_flag = is.finite(step) & abs(step) >= 10 & abs(step_t) >= 10)]

# ---- 3. Neighbours ---------------------------------------------------------------------------
full <- fread(file.path(dir_interim, "ghcnh_stations_all.csv"))
tg <- merge(st[, .(id, lat, lon, selected_year)], bias, by = "id")
tg <- rbind(tg[abs(bias) > 15], tg[abs(bias) <= 10][sample(.N, min(.N, 60))])
km <- function(la1, lo1, la2, lo2) {
  r <- pi / 180
  a <- sin((la2 - la1) * r / 2)^2 + cos(la1 * r) * cos(la2 * r) * sin((lo2 - lo1) * r / 2)^2
  12742 * asin(sqrt(a))
}
pairs <- tg[, {
  dk <- km(lat, lon, full$lat, full$lon)
  ok <- which(dk <= 50 & full$id != id & full$selected_year == selected_year)
  o <- ok[order(dk[ok])][seq_len(min(2, length(ok)))]
  if (length(o)) list(nb = full$id[o], km = dk[o]) else NULL
}, by = id]
todo <- full[id %in% unique(pairs$nb)]
era5_last_hour <- as.POSIXct(jsonlite::fromJSON(file.path(dir_interim,
  "era5_availability.json"))$last_hour_utc, tz = "UTC")
nb_dir <- file.path(dir_interim, "neighbours")
dir.create(nb_dir, showWarnings = FALSE)
neighbour_bias <- function(i) {
  r <- todo[i]
  out <- file.path(nb_dir, paste0(r$id, ".csv"))
  if (file.exists(out) && "selected_year" %in% names(fread(out)) &&
    fread(out)$selected_year[1] == r$selected_year) return(TRUE)
  loc <- file.path(dir_interim, "ghcnh", "pressure", paste0(r$id, ".parquet"))
  o <- as.data.table(read_parquet(loc))[as.integer(format(date, "%Y")) == r$selected_year]
  res <- data.table(nb = r$id, nb_elev = r$elev, selected_year = r$selected_year, nb_n = nrow(o), nb_z_sl = NA_real_,
    nb_bias = NA_real_)
  if (nrow(o) >= 500) {
    o[, date := era5_hour(date)]
    o <- unique(o, by = "date")
    o <- o[date <= era5_last_hour]
    e <- era5_read(rep(r$lon, nrow(o)), rep(r$lat, nrow(o)), o$date,
      c("surface_pressure", "temperature_2m"), "single-levels")
    z <- era5_orography(r$lon, r$lat, "single-levels")
    err <- era5_altitude(o$pressure * 100, e$surface_pressure, e$temperature_2m, z) - r$elev
    err <- err[abs(err - median(err)) <= max(100, 10 * mad(err))]
    res[, `:=`(nb_z_sl = z, nb_bias = mean(err))]
  }
  fwrite(res, out)
  TRUE
}
invisible(par_map(seq_len(nrow(todo)), neighbour_bias, cores = min(n_cores, 6), geopressurer = TRUE,
  export = c("todo", "nb_dir", "era5_last_hour")))
nbr <- rbindlist(lapply(file.path(nb_dir, paste0(todo$id, ".csv")), function(f) {
  if (file.exists(f)) fread(f, colClasses = list(character = "nb")) else NULL
}))
pairs <- merge(pairs, nbr, by = "nb")[is.finite(nb_bias)]
pairs <- merge(pairs, tg[, .(id, bias)], by = "id")
setcolorder(pairs, c("id", "bias", "nb", "km"))
fwrite(pairs[order(id, km)], file.path(dir_tables, "ground_neighbours.csv"))
nb_sum <- pairs[, .(nb_n = .N, nb_km_min = min(km), nb_bias_median = median(nb_bias)), by = id]
nb_sum[, nb_tested := TRUE]

# ---- 4. Basis of the plausibility bound ------------------------------------------------------
# (a) Where ERA5 needs no extrapolation (flat terrain, station within 30 m of ERA5 orography), the
#     bias is the ERA5 surface pressure error plus reference noise.
flat <- merge(st[, .(id, sdor, dz_sl)], bias, by = "id")[sdor < 20 & abs(dz_sl) < 30]
basis_flat <- flat[, .(n = .N, p50 = median(abs(bias)), p90 = quantile(abs(bias), 0.9),
  p95 = quantile(abs(bias), 0.95), p99 = quantile(abs(bias), 0.99))]
fwrite(basis_flat, file.path(dir_tables, "ground_screen_basis_flat.csv"))
# (b) Extrapolating over a height gap: the radiosondes measure it directly. Per station, mean
#     error relative to the surface level divided by the height above ground.
Bx <- as.data.table(read_parquet(file.path(dir_interim, "errors_igra.parquet"),
  col_select = c("id", "surface", "agl", "err_sl_rel")))[!surface & agl > 300 & agl <= 3000]
Bx[, hbin := cut(agl, c(300, 600, 1000, 1500, 2000, 3000))]
env <- Bx[is.finite(err_sl_rel), .(n = .N, rel = median(err_sl_rel) / median(agl)),
  by = .(id, hbin)][n >= 200]
basis_gap <- env[, .(n_stations = .N, median_pct = 100 * median(rel),
  p99_abs_pct = 100 * quantile(abs(rel), 0.99), max_abs_pct = 100 * max(abs(rel))), keyby = hbin]
fwrite(basis_gap, file.path(dir_tables, "ground_screen_basis_gap.csv"))

# ---- Combine ---------------------------------------------------------------------------------
chk <- Reduce(function(a, b) merge(a, b, by = "id", all.x = TRUE), list(st[, .(id)], bias, steps,
  dem, nb_sum))
chk[is.na(nb_tested), nb_tested := id %in% tg$id]
chk[is.na(step_flag), step_flag := FALSE]
fwrite(chk, file.path(dir_tables, "ground_reference_checks.csv"))
cat(sum(chk$step_flag), "stations with a step change;", sum(chk$dem_refutes, na.rm = TRUE),
  "with elevation refuted by the DEM;", uniqueN(pairs$id), "of", nrow(tg),
  "tested stations have a neighbour within 50 km\n")

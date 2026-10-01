# Can the altitude formula be improved? Evaluate two changes to GeoPressureR's barometric formula
# against the IGRA2 radiosondes, with the lapse rate estimated from the data rather than assumed.
#
# GeoPressureR integrates the hypsometric equation for a column whose temperature starts at the
# ERA5 2 m temperature and falls linearly at L = -6.5 K/km (ICAO standard atmosphere). The
# height gained between the surface and a pressure level is proportional to the column's mean
# temperature, so an error in that temperature is the same relative error in height. Two changes
# address the two reasons the assumed column is too cold:
#   1. virtual temperature: use Tv = T (1 + 0.608 q) from ERA5 2 m dewpoint, as the hypsometric
#      equation requires (no free parameter);
#   2. lapse rate: estimate L from the radiosondes instead of using -6.5 K/km, either as one
#      constant or as a simple function of season and latitude (four parameters).
#
# L is chosen to minimise the bird-weighted mean squared error relative to the surface level (the
# same metric as `flight_bird_weighted.csv`: height bins weighted by the share of geolocator flight
# points, stations weighted by their cell weight). Its robustness is tested by repeated 50/50 station splits
# (fit on one half, evaluate on the other), by fitting separately per climate zone and season, and
# with an alternative objective (all height bins weighted equally).
#
# Only relative-to-surface errors are used, so station elevation errors play no role. The effect on
# ground-level altitude (HadISD) is evaluated with the fitted lapse rate.

source("R/utils.R")
set.seed(7)

st <- load_stations()
B <- load_radiosondes(st)
B <- B[is.finite(err_sl_rel) & is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m),
  .(id, sounding, surface, press, gph, hbin, w, climate, season, sdoy, abs_lat, t2m_sl, sp_sl,
    d2m, z_sl, err_sl_rel)]
B[, tv2m := virtual_temperature(t2m_sl, d2m, sp_sl)]
# Every level is compared with its own sounding's surface level, whose inputs are carried along.
sfc <- B[surface == TRUE, .(press_s = press[1], gph_s = gph[1], sp_s = sp_sl[1], t2m_s = t2m_sl[1],
  tv2m_s = tv2m[1]), by = .(id, sounding)]
B <- merge(B[surface == FALSE & hbin != levels(hbin)[1]], sfc, by = c("id", "sounding"))
cat(uniqueN(B$id), "stations,", nrow(B), "levels\n")

bb <- bird_height_weights()
B[, prop := bb$prop[match(as.character(hbin), bb$hbin)]]
B[is.na(prop), prop := 0]

# Error relative to the surface level for temperature `temp` (column name) and lapse rate L (K/m).
err_rel <- function(d, temp, L) {
  e <- altitude_lapse(d$press, d$sp_sl, d[[temp]], d$z_sl, L) - d$gph
  temp_s <- paste0(sub("_sl$", "", temp), "_s")
  e_s <- altitude_lapse(d$press_s, d$sp_s, d[[temp_s]], d$z_sl, L) - d$gph_s
  e - e_s
}
# Weights giving each height bin its bird share (or an equal share) and each station its cell
# weight within a bin, so that sum(wt * err^2) is the bird-weighted MSE of flight_bird_weighted.csv.
bin_weights <- function(d, equal_bins = FALSE) {
  p <- if (equal_bins) as.numeric(d$prop > 0) else d$prop
  p * d$w / ave(d$w, d$hbin, FUN = sum)
}
fit_lapse <- function(d, temp, equal_bins = FALSE) {
  wt <- bin_weights(d, equal_bins)
  optimize(function(L) sum(wt * err_rel(d, temp, L)^2), c(-0.0095, -0.002), tol = 1e-6)$minimum
}
# Bird-weighted summary as in 13_bird_weighted.R: per-bin station-weighted stats combined by bird share.
bird_summary <- function(d, e) {
  s <- data.table(hbin = d$hbin, w = d$w, prop = d$prop, e = e)[prop > 0, .(
    bias = wmean(e, w), mae = wmean(abs(e), w), mse = wmean(e^2, w), prop = prop[1]
  ), by = hbin]
  s[, .(bias = sum(bias * prop), mae = sum(mae * prop), rmse = sqrt(sum(mse * prop)))]
}

# Lapse rate varying with season and latitude:
#   L = b1 + b2 a + (b3 + b4 a) c,  a = |latitude| / 90,  c = cos(2 pi (sdoy - 15) / 365.25),
# a mean lapse rate and a seasonal cycle peaking in mid-winter (sdoy is shifted by six months in
# the southern hemisphere), both changing linearly with latitude. The four parameters minimise the
# same objective as fit_lapse(), by Gauss-Newton: at each iteration, the error of every level is
# linearised in L, which makes the update a weighted least-squares fit.
L_lim <- c(-0.0095, -0.002)
lapse_design <- function(d) {
  a <- d$abs_lat / 90
  cc <- cos(2 * pi * (d$sdoy - 15) / 365.25)
  cbind(1, a, cc, a * cc)
}
lapse_var <- function(d, theta) pmin(pmax(drop(lapse_design(d) %*% theta), L_lim[1]), L_lim[2])
fit_lapse_var <- function(d, temp, L0, iter = 4, h = 1e-5) {
  X <- lapse_design(d)
  wt <- bin_weights(d)
  theta <- c(L0, 0, 0, 0)
  for (k in seq_len(iter)) {
    L <- lapse_var(d, theta)
    e <- err_rel(d, temp, L)
    g <- (err_rel(d, temp, L + h) - err_rel(d, temp, L - h)) / (2 * h)
    # e(L') ~ e + g (X theta' - L): minimise sum(wt * (g X theta' - (g L - e))^2)
    Z <- g * X
    theta <- drop(solve(crossprod(Z, wt * Z), crossprod(Z, wt * (g * L - e))))
  }
  theta
}
# Lapse rate (scalar, or one per level) of a variant with parameters `par`
lapse_at <- function(code, d, par) if (code == "tv_lapse_var") lapse_var(d, par) else par

# ---- Fit on all stations ----------------------------------------------------------------------
L_std <- -0.0065
L_t2m <- fit_lapse(B, "t2m_sl")
L_tv <- fit_lapse(B, "tv2m")
L_t2m_eq <- fit_lapse(B, "t2m_sl", equal_bins = TRUE)
L_tv_eq <- fit_lapse(B, "tv2m", equal_bins = TRUE)
theta_var <- fit_lapse_var(B, "tv2m", L_tv)
cat(sprintf("Fitted lapse rate: T2m %.2f K/km, Tv %.2f K/km (equal bins: %.2f, %.2f)\n",
  1000 * L_t2m, 1000 * L_tv, 1000 * L_t2m_eq, 1000 * L_tv_eq))
cat("Season-latitude lapse rate (K/km):", round(1000 * theta_var, 2), "\n")

variants <- data.table(
  method = c("GeoPressureR (T2m, -6.5 K/km)", "virtual temperature (Tv, -6.5 K/km)",
    sprintf("fitted lapse rate (T2m, %.1f K/km)", 1000 * L_t2m),
    sprintf("virtual temperature + fitted lapse rate (Tv, %.1f K/km)", 1000 * L_tv),
    "virtual temperature + lapse rate by season and latitude (Tv)"),
  code = c("current", "tv", "lapse", "tv_lapse", "tv_lapse_var"),
  temp = c("t2m_sl", "tv2m", "t2m_sl", "tv2m", "tv2m")
)
Lpar <- list(current = L_std, tv = L_std, lapse = L_t2m, tv_lapse = L_tv, tv_lapse_var = theta_var)
for (i in seq_len(nrow(variants))) {
  k <- variants$code[i]
  B[, paste0("e_", k) := err_rel(B, variants$temp[i], lapse_at(k, B, Lpar[[k]]))]
}
stopifnot(isTRUE(all.equal(B$e_current, B$err_sl_rel, tolerance = 1e-6)))

# ---- Cross-validation: repeated 50/50 station splits --------------------------------------------
ids <- unique(B$id)
n_split <- 20
cv <- rbindlist(lapply(seq_len(n_split), function(k) {
  train <- sample(ids, length(ids) %/% 2)
  dtr <- B[id %in% train]
  dte <- B[!id %in% train]
  Lk <- list(current = L_std, tv = L_std, lapse = fit_lapse(dtr, "t2m_sl"),
    tv_lapse = fit_lapse(dtr, "tv2m"))
  Lk$tv_lapse_var <- fit_lapse_var(dtr, "tv2m", Lk$tv_lapse)
  rbindlist(lapply(seq_len(nrow(variants)), function(i) {
    v <- variants[i]
    p <- Lk[[v$code]]
    cbind(split = k, code = v$code, L = if (length(p) == 1) p else NA_real_,
      b1 = p[1], b2 = p[2], b3 = p[3], b4 = p[4],
      bird_summary(dte, err_rel(dte, v$temp, lapse_at(v$code, dte, p))))
  }))
}))
cv_sum <- cv[, .(L_mean = mean(L), L_sd = sd(L), bias_mean = mean(bias), bias_sd = sd(bias),
  mae_mean = mean(mae), mae_sd = sd(mae), rmse_mean = mean(rmse), rmse_sd = sd(rmse)), by = code]
# Paired improvement over the current formula on the same held-out stations
cvw <- dcast(cv, split ~ code, value.var = "mae")
cv_sum[, mae_gain_mean := sapply(code, function(k) mean(cvw$current - cvw[[k]]))]
cv_sum[, mae_gain_min := sapply(code, function(k) min(cvw$current - cvw[[k]]))]
cv_sum <- merge(variants[, .(code, method)], cv_sum, by = "code", sort = FALSE)
fwrite(cv_sum, file.path(dir_tables, "formula_cv.csv"))

# ---- Robustness of L: per climate zone and season ------------------------------------------------
grp <- B[!is.na(climate), .(n_st = uniqueN(id)), by = .(climate, season)][n_st >= 5]
L_grp <- rbindlist(lapply(seq_len(nrow(grp)), function(i) {
  d <- B[climate == grp$climate[i] & season == grp$season[i]]
  cbind(grp[i], L_t2m = 1000 * fit_lapse(d, "t2m_sl"), L_tv = 1000 * fit_lapse(d, "tv2m"))
}))[order(climate, season)]
fwrite(L_grp, file.path(dir_tables, "formula_lapse_by_group.csv"))

fit_tab <- data.table(
  temperature = c("T2m", "Tv"),
  L_fit = 1000 * c(L_t2m, L_tv),
  L_cv_mean = 1000 * cv_sum[match(c("lapse", "tv_lapse"), code), L_mean],
  L_cv_sd = 1000 * cv_sum[match(c("lapse", "tv_lapse"), code), L_sd],
  L_equal_bins = 1000 * c(L_t2m_eq, L_tv_eq),
  L_group_min = c(min(L_grp$L_t2m), min(L_grp$L_tv)),
  L_group_max = c(max(L_grp$L_t2m), max(L_grp$L_tv))
)
fwrite(fit_tab, file.path(dir_tables, "formula_fit.csv"))

# Season-latitude lapse rate: parameters (all stations, and SD over the splits) and the fitted
# surface, in K/km
fwrite(data.table(param = c("mean", "mean x |lat|/90", "winter cycle", "winter cycle x |lat|/90"),
  value = 1000 * theta_var,
  cv_sd = 1000 * unlist(cv[code == "tv_lapse_var", lapply(.SD, sd), .SDcols = c("b1", "b2", "b3",
    "b4")])), file.path(dir_tables, "formula_lapse_var.csv"))
lgrid <- CJ(abs_lat = seq(0, 80, 20), sdoy = seq(1, 365, 7))
lgrid[, L := 1000 * lapse_var(lgrid, theta_var)]
fwrite(lgrid, file.path(dir_tables, "formula_lapse_var_grid.csv"))

# ---- Error by height and bird-weighted, all stations -------------------------------------------
height_tab <- rbindlist(lapply(seq_len(nrow(variants)), function(i) {
  v <- paste0("e_", variants$code[i])
  B[, .(method = variants$method[i], code = variants$code[i], n_stations = uniqueN(id),
    bias = wmean(get(v), w), sd = sqrt(wmean((get(v) - wmean(get(v), w))^2, w)),
    mae = wmean(abs(get(v)), w), rmse = sqrt(wmean(get(v)^2, w))), by = hbin]
}))[order(code, hbin)]
height_tab[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(height_tab, file.path(dir_tables, "formula_height.csv"))
bird_tab <- rbindlist(lapply(seq_len(nrow(variants)), function(i) {
  cbind(variants[i, .(method, code)], bird_summary(B, B[[paste0("e_", variants$code[i])]]))
}))

clim_tab <- rbindlist(lapply(c("current", "tv_lapse", "tv_lapse_var"), function(k) {
  v <- paste0("e_", k)
  B[!is.na(climate), .(code = k, bias = wmean(get(v), w), n_st = uniqueN(id)),
    by = .(hbin, climate, season)]
}))
clim_tab[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(clim_tab, file.path(dir_tables, "formula_climate_season.csv"))

# Humidity: size of the virtual-temperature correction (Tv - T) by climate and season
hum <- unique(B, by = c("id", "sounding"))[!is.na(climate), .(tv_minus_t = mean(tv2m_s - t2m_s)),
  by = .(climate, season)][order(climate, season)]
fwrite(hum, file.path(dir_tables, "formula_tv_correction.csv"))

# ---- Ground level (HadISD) ------------------------------------------------------------------------
# No 2 m dewpoint was read for HadISD, so the virtual-temperature factor is left out here; its
# effect on ground-level altitude is at most ~0.7% of the station-to-orography gap.
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_hadisd.parquet"),
  col_select = c("id", "year", "sdoy", "pressure", "err_sl", "gross", "t2m_sl", "sp_sl")))
A <- A[year %in% years_main & !gross %in% TRUE & is.finite(err_sl)]
stA <- fread(file.path(dir_tables, "ground_station_stats.csv"))[reference == TRUE]
A <- merge(A, stA[, .(id, z_sl, cw, abs_lat = abs(lat))], by = "id")
A[, err_new := err_sl + altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl, L_tv) -
  altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl, L_std)]
A[, err_var := err_sl + altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl, lapse_var(A,
  theta_var)) - altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl, L_std)]
A[, w := cw / .N, by = id]
sA <- A[, .(bias = mean(err_sl), bias_new = mean(err_new), cw = cw[1]), by = id]
ground <- data.table(
  n_stations = nrow(sA),
  abs_bias_median = sA[, wquant(abs(bias), cw, 0.5)],
  abs_bias_median_new = sA[, wquant(abs(bias_new), cw, 0.5)],
  mae = A[, wmean(abs(err_sl), w)], mae_new = A[, wmean(abs(err_new), w)],
  mae_var = A[, wmean(abs(err_var), w)],
  max_abs_change = A[, max(abs(err_new - err_sl))],
  max_abs_change_var = A[, max(abs(err_var - err_sl))],
  median_abs_dz = median(abs(stA$dz_sl))
)
fwrite(ground, file.path(dir_tables, "formula_ground.csv"))

print(fit_tab)
print(cv_sum)
print(bird_tab)
print(L_grp)
print(ground)

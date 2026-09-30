# Summaries, driver models and figures for Tier A and Tier B.
#
# Vocabulary used throughout:
#   accuracy  = the per-station mean error (bias). Constant in time, so it only matters for
#               absolute altitude and for comparing altitudes across locations.
#   precision = the temporal SD of the error at a station once its bias is removed. This is what
#               limits relative altitude (e.g. flight climbs, or changes at one site).
# Pooled statistics weight every station equally (weights 1 / n_obs per station), so dense
# networks do not dominate.

source("R/utils.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(mgcv)
})
theme_set(theme_minimal(base_size = 11))
set.seed(5)

st <- fread(file.path(dir_tables, "stations.csv"))
st[, abs_lat := abs(lat)]
st[, terrain := cut(sdor, c(-Inf, 20, 50, 150, 300, Inf),
  labels = c("flat (<20 m)", "gentle (20-50 m)", "hilly (50-150 m)", "rough (150-300 m)",
    "mountain (>300 m)"))]
st[, elev_class := cut(elev, c(-Inf, 200, 500, 1000, 2000, Inf),
  labels = c("<200 m", "200-500 m", "500-1000 m", "1000-2000 m", ">2000 m"))]
st[, lat_band := cut(abs_lat, c(0, 23.5, 45, 66.5, 90), include.lowest = TRUE,
  labels = c("tropics (0-23.5)", "subtropics (23.5-45)", "mid-latitude (45-66.5)",
    "polar (>66.5)"))]
climate_names <- c(A = "A tropical", B = "B arid", C = "C temperate", D = "D continental",
  E = "E polar")
st[, climate := climate_names[koppen_main]]
# Stations whose reported elevation agrees with an independent DEM: used for accuracy statements.
st[, trusted := is.finite(dem_diff) & abs(dem_diff) <= 20]

wmean <- function(x, w) sum(x * w) / sum(w)
wquant <- function(x, w, p) {
  o <- order(x)
  cw <- cumsum(w[o]) / sum(w)
  x[o][which(cw >= p)[1]]
}

# ==== Tier A ==================================================================================
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_A.parquet")))
gross_frac <- mean(A$gross, na.rm = TRUE)
A <- A[!gross %in% TRUE]
Am <- A[year %in% years_main]

stA <- Am[, c(
  .(n = .N),
  setNames(summarise_error(err_sl)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_sl")),
  setNames(summarise_error(err_land)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_land"))
), by = id]
stA <- merge(st[tier == "A"], stA, by = "id")
# Physical consistency of the reference: a station whose constant offset is larger than any
# plausible extrapolation error (30 m + 10% of the height difference to the ERA5 surface, i.e. a
# ~28 K error in the assumed layer temperature) almost certainly reports its pressure at a different
# height than its listed elevation (datum or metadata error). Such stations track ERA5 closely with a
# fixed offset (low SD). They are kept in "all stations" and excluded from "consistent" statistics.
stA[, consistent := abs(bias_sl) <= 30 + 0.1 * abs(dz_sl)]
fwrite(stA, file.path(dir_tables, "A_station_stats.csv"))

Am <- merge(Am, stA[, .(id, bias_sl, bias_land, n, consistent)], by = "id")
Am[, e_db := err_sl - bias_sl]
Am[, w := 1 / n]

summ_A <- function(ids, label, group) {
  s <- stA[id %in% ids]
  o <- Am[id %in% ids]
  rbindlist(lapply(c("sl", "land"), function(ds) {
    b <- s[[paste0("bias_", ds)]]
    sdv <- s[[paste0("sd_", ds)]]
    e <- o[[paste0("err_", ds)]]
    ok <- is.finite(e)
    data.table(
      group = group, subset = label, dataset = ds,
      n_stations = sum(is.finite(b)), n_obs = sum(ok),
      abs_bias_median = median(abs(b), na.rm = TRUE),
      abs_bias_p90 = quantile(abs(b), 0.9, na.rm = TRUE),
      sd_median = median(sdv, na.rm = TRUE),
      sd_p90 = quantile(sdv, 0.9, na.rm = TRUE),
      mae = wmean(abs(e[ok]), o$w[ok]),
      rmse = sqrt(wmean(e[ok]^2, o$w[ok])),
      p95_abs = wquant(abs(e[ok]), o$w[ok], 0.95)
    )
  }))
}

groups <- list(
  terrain = "terrain", elevation = "elev_class", latitude = "lat_band", climate = "climate"
)
lab_cons <- "consistent reference (excl. datum/metadata errors)"
lab_cons_dem <- "consistent reference and elevation agrees with DEM (<=20 m)"
stC <- stA[consistent == TRUE]
tabA <- rbind(
  summ_A(stA$id, "all stations", "all"),
  summ_A(stC$id, lab_cons, "all"),
  summ_A(stC[trusted == TRUE]$id, lab_cons_dem, "all"),
  # Breakdowns use consistent stations: otherwise a handful of reference errors dominate MAE/RMSE.
  rbindlist(lapply(names(groups), function(g) {
    rbindlist(lapply(levels(factor(stC[[groups[[g]]]])), function(l) {
      summ_A(stC[get(groups[[g]]) == l]$id, l, g)
    }))
  }))
)
fwrite(tabA, file.path(dir_tables, "A_summary.csv"))

# Diurnal and seasonal cycle of the de-biased error (precision), by climate zone
Am[, hour_bin := floor(lsh)]
Am[, month_seas := pmin(12, floor((sdoy - 1) / 30.5) + 1)]
Am <- merge(Am, stA[, .(id, climate, terrain)], by = "id")
cyc_h <- Am[consistent == TRUE, .(mean = wmean(e_db, w), sd = sqrt(wmean(e_db^2, w)), n = .N), by = .(climate,
  hour_bin)]
cyc_m <- Am[consistent == TRUE, .(mean = wmean(e_db, w), sd = sqrt(wmean(e_db^2, w)), n = .N), by = .(climate,
  month_seas)]
fwrite(cyc_h, file.path(dir_tables, "A_cycle_hour.csv"))
fwrite(cyc_m, file.path(dir_tables, "A_cycle_month.csv"))

# Change over time (ERA5 observing system): stations with data in every era year
era_ids <- if (file.exists(file.path(dir_interim, "era_ids.csv"))) {
  fread(file.path(dir_interim, "era_ids.csv"))$id
} else character()
Ae <- A[id %in% era_ids]
if (nrow(Ae) > 0) {
  Ae <- Ae[, .(bias = mean(err_sl), sd = sd(err_sl), n = .N), by = .(id, year)][n >= 500]
  Ae <- Ae[id %in% Ae[, .N, by = id][N == max(N), id]]
  eraA <- Ae[, .(n_stations = .N, abs_bias_median = median(abs(bias)), sd_median = median(sd),
    sd_p90 = quantile(sd, 0.9)), by = year][order(year)]
  fwrite(eraA, file.path(dir_tables, "A_era.csv"))
}

# ---- Drivers: station level ------------------------------------------------------------------
dA <- stA[consistent == TRUE & is.finite(sd_sl) & is.finite(sdor) & !is.na(climate)]
dA[, climate := factor(climate)]
m_bias <- gam(log(abs(bias_sl) + 0.5) ~ s(dz_sl, k = 8) + s(log1p(sdor), k = 6) +
  s(abs_lat, k = 6) + climate, data = dA[trusted == TRUE], method = "REML")
m_sd <- gam(log(sd_sl) ~ s(dz_sl, k = 8) + s(log1p(sdor), k = 6) + s(abs_lat, k = 6) + climate,
  data = dA, method = "REML")

# Deviance explained lost when each term is dropped and the model refitted: a simple, comparable
# importance measure for smooth and parametric terms alike.
drop_importance <- function(m, data, fit = function(f) gam(f, data = data, method = "REML")) {
  labs <- attr(terms(formula(m)), "term.labels")
  full <- summary(m)$dev.expl
  pretty <- c(dz_sl = "station elevation - ERA5 orography", sdor = "sub-grid terrain roughness",
    abs_lat = "absolute latitude", climate = "Koppen climate zone", lsh = "local solar hour",
    sdoy = "season", log_blh = "boundary layer height", skt_t2m = "skin - 2 m temperature",
    abs_dsp6 = "6 h pressure tendency", id_f = "station (random effect)")
  key <- sub("^s\\((log1p\\()?([a-z0-9_]+).*$", "\\2", labs)
  data.table(
    term = ifelse(key %in% names(pretty), pretty[key], labs),
    dev_expl_full = full,
    dev_expl_drop = vapply(seq_along(labs), function(i) {
      f <- reformulate(labs[-i], response = formula(m)[[2]])
      full - summary(fit(f))$dev.expl
    }, numeric(1)),
    n = nrow(m$model)
  )
}
drivers_st <- rbind(
  cbind(response = "log |bias| (consistent, DEM-trusted)", drop_importance(m_bias, dA[trusted == TRUE])),
  cbind(response = "log SD", drop_importance(m_sd, dA))
)
fwrite(drivers_st, file.path(dir_tables, "A_drivers_station.csv"))

# ---- Drivers: observation level (precision) --------------------------------------------------
dobs <- Am[consistent == TRUE & is.finite(blh) & is.finite(skt_t2m) & is.finite(dsp6)][sample(.N, min(.N, 2e6))]
dobs[, `:=`(abs_e = abs(e_db), id_f = factor(id), log_blh = log(blh), abs_dsp6 = abs(dsp6) / 100)]
m_obs <- bam(abs_e ~ s(lsh, bs = "cc", k = 12) + s(sdoy, bs = "cc", k = 12) + s(log_blh, k = 8) +
  s(skt_t2m, k = 8) + s(abs_dsp6, k = 8) + s(id_f, bs = "re"),
  data = dobs, discrete = TRUE, nthreads = n_cores)
imp <- drop_importance(m_obs, dobs, function(f) {
  bam(f, data = dobs, discrete = TRUE, nthreads = n_cores)
})
fwrite(imp, file.path(dir_tables, "A_drivers_obs.csv"))
saveRDS(m_obs, file.path(dir_interim, "m_obs.rds"))

# ==== Tier B ==================================================================================
B <- as.data.table(read_parquet(file.path(dir_interim, "errors_B.parquet")))
B <- merge(B, st[tier == "B", .(id, climate, lat_band, terrain, trusted, abs_lat)], by = "id")
# Stations weigh equally, so require enough soundings for a station to be representative.
B <- B[id %in% B[, uniqueN(sounding), by = id][V1 >= 100, id]]
# Gross errors: levels more than 150 m (and 10 robust SD) from the median of their height bin.
B[, hbin := cut(agl, c(-10, 1, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000),
  right = TRUE)]
B[, gross := {
  m <- median(err_sl_rel, na.rm = TRUE)
  r <- mad(err_sl_rel, na.rm = TRUE)
  abs(err_sl_rel - m) > max(150, 10 * r)
}, by = hbin]
gross_frac_B <- mean(B$gross, na.rm = TRUE)
B <- B[!gross %in% TRUE]
B[, w := 1 / .N, by = id]
B[, daynight := fifelse(lsh >= 7 & lsh < 19, "day", "night")]
B[, season := fifelse(sdoy >= 80 & sdoy < 266, "summer half", "winter half")]

err_vars <- c(
  "GeoPressureR (ERA5 single-levels)" = "err_sl_rel",
  "ERA5-Land" = "err_land_rel",
  "virtual temperature" = "err_tv_rel",
  "lapse rate -5 K/km" = "err_l5_rel",
  "virtual temperature + lapse -5 K/km" = "err_tv_l5_rel"
)
err_vars <- err_vars[err_vars %in% names(B)]

height_stats <- function(d, by) {
  rbindlist(lapply(names(err_vars), function(lab) {
    v <- err_vars[[lab]]
    d[is.finite(get(v)), .(
      method = lab, n = .N, n_stations = uniqueN(id),
      bias = wmean(get(v), w), sd = sqrt(wmean((get(v) - wmean(get(v), w))^2, w)),
      mae = wmean(abs(get(v)), w), rmse = sqrt(wmean(get(v)^2, w)),
      p95_abs = wquant(abs(get(v)), w, 0.95)
    ), by = by]
  }))
}
tabB <- height_stats(B, "hbin")[order(method, hbin)]
fwrite(tabB, file.path(dir_tables, "B_height.csv"))
tabB_dn <- height_stats(B, c("hbin", "daynight", "season"))[order(method, hbin)]
fwrite(tabB_dn, file.path(dir_tables, "B_height_daynight_season.csv"))
tabB_cl <- height_stats(B[!is.na(climate)], c("hbin", "climate"))[order(method, hbin)]
fwrite(tabB_cl, file.path(dir_tables, "B_height_climate.csv"))

# Absolute error at height (not relative to the surface level): accuracy for a bird in flight
tabB_abs <- B[is.finite(err_sl), .(
  n = .N, bias = wmean(err_sl, w), mae = wmean(abs(err_sl), w), rmse = sqrt(wmean(err_sl^2, w)),
  p95_abs = wquant(abs(err_sl), w, 0.95)
), by = .(hbin, trusted)][order(trusted, hbin)]
fwrite(tabB_abs, file.path(dir_tables, "B_height_absolute.csv"))

# Bird-weighted error: height bins weighted by the share of geolocator flight points in them
bird <- fread(file.path(dir_tables, "bird_height_distribution.csv"))[flight == TRUE]
bird_bins <- data.table(
  hbin = levels(B$hbin)[-1],
  lo = c(1, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000)
)
bird[, lo := as.numeric(sub("^\\[([^,]+),.*", "\\1", bin))]
bird_bins <- merge(bird_bins, bird[, .(lo, prop)], by = "lo", all.x = TRUE)
bird_bins[lo == 1, prop := bird[lo == 0, prop]]
# below-ground flight points (<0 m) are attributed to the lowest bin; >6 km to the highest
bird_bins[lo == 1, prop := prop + bird[lo == -Inf, prop]]
bird_bins[lo == 5000, prop := prop + bird[lo == 6000, prop]]
bird_bins[, prop := prop / sum(prop)]
bw <- merge(tabB, bird_bins[, .(hbin, prop)], by = "hbin")
bird_w <- bw[, .(
  mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop)), bias = sum(bias * prop)
), by = method]
fwrite(bird_w, file.path(dir_tables, "B_bird_weighted.csv"))

# Physical explanation: layer-mean temperature assumed by the formula vs observed by the sonde
B[, pred_temp := agl * (tmean_assumed - tmean_obs) / tmean_obs]
fit_t <- B[agl > 200 & is.finite(pred_temp) & is.finite(err_sl_rel), {
  f <- lm(err_sl_rel ~ pred_temp)
  .(r = cor(err_sl_rel, pred_temp), slope = coef(f)[2], intercept = coef(f)[1],
    r2 = summary(f)$r.squared, n = .N)
}]
fwrite(fit_t, file.path(dir_tables, "B_temperature_explanation.csv"))

# ==== Headline numbers ========================================================================
g <- function(tab, sub, ds, col) tab[subset == sub & dataset == ds][[col]]
api <- if (file.exists(file.path(dir_tables, "api_crosscheck_summary.csv"))) {
  fread(file.path(dir_tables, "api_crosscheck_summary.csv"))
} else NULL
bsl <- tabB[method == names(err_vars)[1]]
tr <- lab_cons_dem
bw1 <- bird_w[method == names(err_vars)[1]]
hb <- function(bin, col) bsl[hbin == bin][[col]]
headline <- list(
  A_n_stations = uniqueN(Am$id),
  A_n_obs = nrow(Am),
  A_gross_fraction = gross_frac,
  A_abs_bias_median = g(tabA, "all stations", "sl", "abs_bias_median"),
  A_abs_bias_p90 = g(tabA, "all stations", "sl", "abs_bias_p90"),
  A_sd_median = g(tabA, "all stations", "sl", "sd_median"),
  A_sd_p90 = g(tabA, "all stations", "sl", "sd_p90"),
  A_mae = g(tabA, "all stations", "sl", "mae"),
  A_rmse = g(tabA, "all stations", "sl", "rmse"),
  A_p95 = g(tabA, "all stations", "sl", "p95_abs"),
  A_n_inconsistent = sum(!stA$consistent),
  A_cons_n_stations = g(tabA, lab_cons, "sl", "n_stations"),
  A_cons_abs_bias_median = g(tabA, lab_cons, "sl", "abs_bias_median"),
  A_cons_abs_bias_p90 = g(tabA, lab_cons, "sl", "abs_bias_p90"),
  A_cons_sd_median = g(tabA, lab_cons, "sl", "sd_median"),
  A_cons_sd_p90 = g(tabA, lab_cons, "sl", "sd_p90"),
  A_cons_mae = g(tabA, lab_cons, "sl", "mae"),
  A_cons_rmse = g(tabA, lab_cons, "sl", "rmse"),
  A_cons_p95 = g(tabA, lab_cons, "sl", "p95_abs"),
  A_cons_land_mae = g(tabA, lab_cons, "land", "mae"),
  A_cons_land_abs_bias_median = g(tabA, lab_cons, "land", "abs_bias_median"),
  A_trusted_n_stations = g(tabA, tr, "sl", "n_stations"),
  A_trusted_mae = g(tabA, tr, "sl", "mae"),
  A_trusted_abs_bias_median = g(tabA, tr, "sl", "abs_bias_median"),
  A_land_mae = g(tabA, "all stations", "land", "mae"),
  A_land_abs_bias_median = g(tabA, "all stations", "land", "abs_bias_median"),
  B_n_stations = uniqueN(B$id),
  B_n_soundings = uniqueN(B[, paste(id, sounding)]),
  B_gross_fraction = gross_frac_B,
  B_rel_bias_1000_1500 = hb("(1e+03,1.5e+03]", "bias"),
  B_rel_rmse_1000_1500 = hb("(1e+03,1.5e+03]", "rmse"),
  B_rel_bias_2000_3000 = hb("(2e+03,3e+03]", "bias"),
  B_rel_rmse_2000_3000 = hb("(2e+03,3e+03]", "rmse"),
  B_rel_bias_5000_6000 = hb("(5e+03,6e+03]", "bias"),
  B_rel_rmse_5000_6000 = hb("(5e+03,6e+03]", "rmse"),
  B_bird_weighted_bias = bw1$bias,
  B_bird_weighted_mae = bw1$mae,
  B_bird_weighted_rmse = bw1$rmse,
  B_temp_r = fit_t$r,
  api_max_abs_diff = if (is.null(api)) NA else api$max_abs_diff
)
headline <- data.table(
  metric = names(headline),
  value = vapply(headline, function(v) if (length(v)) as.numeric(v[1]) else NA_real_, 1)
)
fwrite(headline, file.path(dir_tables, "headline.csv"))
writeLines(geopressurer_version(), file.path(dir_tables, "geopressurer_version.txt"))

# ==== Figures =================================================================================
world <- rnaturalearth::ne_countries(scale = 110, returnclass = "sf")
save_fig <- function(p, name, w = 9, h = 5) {
  ggsave(file.path(dir_figures, paste0(name, ".png")), p, width = w, height = h, dpi = 150,
    bg = "white")
}
basemap <- ggplot() +
  geom_sf(data = world, fill = "grey93", colour = "grey75", linewidth = 0.2) +
  coord_sf(expand = FALSE, ylim = c(-60, 85)) +
  theme(axis.title = element_blank())

p <- basemap +
  geom_point(data = stA[order(abs(bias_sl))], aes(lon, lat, fill = pmax(pmin(bias_sl, 30), -30)),
    shape = 21, size = 1.4, stroke = 0.15, colour = "grey30") +
  scale_fill_distiller(palette = "RdBu", limits = c(-30, 30), direction = 1,
    name = "Bias (m)\nclipped at\n+/-30 m") +
  labs(title = "Accuracy: mean altitude error per station (ERA5 single-levels)")
save_fig(p, "A_map_bias")

p <- basemap +
  geom_point(data = stA[order(sd_sl)], aes(lon, lat, fill = pmin(sd_sl, 15)), shape = 21,
    size = 1.4, stroke = 0.15, colour = "grey30") +
  scale_fill_viridis_c(option = "magma", direction = -1, limits = c(0, 15),
    name = "SD (m)\nclipped\nat 15 m") +
  labs(title = "Precision: temporal SD of the altitude error per station")
save_fig(p, "A_map_sd")

dl <- melt(stA[, .(id, `ERA5 single-levels` = abs(bias_sl), `ERA5-Land` = abs(bias_land))],
  id.vars = "id", variable.name = "dataset", value.name = "abs_bias")
p <- ggplot(dl[is.finite(abs_bias)], aes(abs_bias, colour = dataset)) +
  stat_ecdf(linewidth = 0.8) +
  scale_x_log10(breaks = c(0.1, 0.3, 1, 3, 10, 30, 100, 300)) +
  scale_colour_manual(values = c("#1f77b4", "#d62728")) +
  labs(x = "|bias| per station (m, log scale)", y = "Cumulative share of stations", colour = NULL,
    title = "Station accuracy: ERA5 single-levels vs ERA5-Land") +
  theme(legend.position = "bottom")
save_fig(p, "A_sl_vs_land", 7, 4.5)

p1 <- ggplot(stA, aes(dz_sl, bias_sl, colour = consistent)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_abline(slope = c(-0.1, 0.1), intercept = 0, colour = "grey80", linetype = 2) +
  geom_point(size = 0.8, alpha = 0.6) +
  scale_colour_manual(values = c(`TRUE` = "#1f77b4", `FALSE` = "#ff7f0e"),
    labels = c(`TRUE` = "consistent", `FALSE` = "flagged: datum/metadata error")) +
  coord_cartesian(ylim = c(-80, 80)) +
  labs(x = "Station elevation - ERA5 orography (m)", y = "Bias (m)", colour = NULL) +
  theme(legend.position = "bottom")
p2 <- ggplot(stC, aes(sdor, sd_sl)) +
  geom_point(size = 0.8, alpha = 0.5, colour = "grey30") +
  geom_smooth(method = "gam", formula = y ~ s(x, k = 6), colour = "#d62728") +
  scale_x_continuous(trans = "log1p", breaks = c(0, 10, 30, 100, 300, 1000)) +
  coord_cartesian(ylim = c(0, 20)) +
  labs(x = "Sub-grid orography SD in the ERA5 cell (m)", y = "Temporal SD of error (m)")
save_fig(patchwork::wrap_plots(p1, p2), "A_drivers", 10, 4.5)

p1 <- ggplot(cyc_h[!is.na(climate)], aes(hour_bin + 0.5, sd, colour = climate)) +
  geom_line(linewidth = 0.8) +
  labs(x = "Local solar hour", y = "RMS of de-biased error (m)", colour = NULL)
p2 <- ggplot(cyc_m[!is.na(climate)], aes(month_seas, sd, colour = climate)) +
  geom_line(linewidth = 0.8) +
  scale_x_continuous(breaks = 1:12, labels = c("Jan", "", "", "Apr", "", "", "Jul", "", "",
    "Oct", "", "")) +
  labs(x = "Month (southern hemisphere shifted by 6 months)", y = NULL, colour = NULL)
save_fig(patchwork::wrap_plots(p1, p2, guides = "collect") &
  theme(legend.position = "bottom"), "A_cycles", 10, 4.5)

if (exists("eraA")) {
  p <- ggplot(melt(eraA, id.vars = c("year", "n_stations")), aes(year, value, colour = variable)) +
    geom_line() + geom_point() +
    labs(x = NULL, y = "m", colour = NULL,
      title = sprintf("Change over time (%d stations with data in every year)", eraA$n_stations[1]))
  save_fig(p, "A_era", 7, 4)
}

tabB[, agl_mid := c(0, 50, 175, 375, 750, 1250, 1750, 2500, 3500, 4500, 5500)[as.integer(hbin)]]
p1 <- ggplot(tabB, aes(agl_mid, bias, colour = method)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_line(linewidth = 0.8) + geom_point(size = 1) +
  coord_flip() +
  labs(x = "Height above ground (m)", y = "Bias (m)", colour = NULL)
p2 <- ggplot(tabB, aes(agl_mid, sd, colour = method)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1) +
  coord_flip() +
  labs(x = NULL, y = "SD (m)", colour = NULL)
bb <- bird_bins[, .(lo = pmax(lo, 0), hi = c(100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000,
  6000)[match(lo, c(1, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000))], prop)]
p3 <- ggplot(bb) +
  geom_rect(aes(xmin = 0, xmax = prop / (hi - lo) * 1000, ymin = lo, ymax = hi), fill = "grey60",
    colour = "white") +
  labs(y = NULL, x = "Flight points\n(share per km)")
save_fig(patchwork::wrap_plots(p1, p2, p3, widths = c(2, 2, 1), guides = "collect") &
  theme(legend.position = "bottom", legend.direction = "vertical"), "B_height", 11, 6)

bc <- B[!is.na(climate) & is.finite(err_sl_rel) & !is.na(hbin), .(bias = wmean(err_sl_rel, w),
  sd = sqrt(wmean((err_sl_rel - wmean(err_sl_rel, w))^2, w)), n_st = uniqueN(id)),
  by = .(hbin, climate, season)]
bc[, agl_mid := c(0, 50, 175, 375, 750, 1250, 1750, 2500, 3500, 4500, 5500)[as.integer(hbin)]]
fwrite(bc, file.path(dir_tables, "B_height_climate_season.csv"))
p <- ggplot(bc[n_st >= 3], aes(agl_mid, bias, colour = climate, linetype = season)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_line(linewidth = 0.7) +
  coord_flip() +
  labs(x = "Height above ground (m)", y = "Bias vs surface level (m)", colour = NULL,
    linetype = NULL, title = "Tier B: height-dependent bias by climate zone and season")
save_fig(p, "B_height_climate", 8, 5.5)

bs <- B[agl > 200 & is.finite(pred_temp)][sample(.N, min(.N, 50000))]
p <- ggplot(bs, aes(pred_temp, err_sl_rel)) +
  geom_bin_2d(bins = 80) +
  geom_abline(slope = 1, intercept = 0, colour = "#d62728") +
  scale_fill_viridis_c(trans = "log10") +
  coord_cartesian(xlim = c(-150, 100), ylim = c(-150, 100)) +
  labs(x = "Predicted from temperature profile: height x (T assumed - T observed) / T (m)",
    y = "Observed error vs surface level (m)",
    title = sprintf("Tier B: error explained by the assumed temperature profile (r = %.2f)",
      fit_t$r))
save_fig(p, "B_temperature", 7, 6)

cat("Analysis done.\n")
print(tabA[group == "all"])
print(tabB[method == names(err_vars)[1]])
print(bird_w)

# How accuracy and precision vary with terrain, place, climate and time (figures: 17_figures.R).
#
# Every summary here is a distribution over stations of the two quantities defined in
# 12_analysis.R: the bias (accuracy) and the SD of the error (precision), computed per station and
# per class (month, hour, year, height bin). Distributions are given by cell-weighted quantiles
# (HadISD) or unweighted ones (GNSS, MeteoSwiss, era stations).

source("R/utils.R")
suppressPackageStartupMessages(library(mgcv))

qs <- c(0.1, 0.25, 0.5, 0.75, 0.9)
wq <- function(x, w = rep(1, length(x))) {
  ok <- is.finite(x)
  setNames(as.list(vapply(qs, function(p) wquant(x[ok], w[ok], p), 1)), paste0("q", 100 * qs))
}
stA <- fread(file.path(dir_tables, "ground_station_stats.csv"))
ref <- stA[reference == TRUE]

# ---- Main table: reference stations of the three ground references, both products -------------
ind <- fread(file.path(dir_tables, "indep_station_stats.csv"))
sets <- list(
  HadISD = ref[, .(bias_sl, sd_sl, bias_land, sd_land, w = cw)],
  GNSS = ind[source == "GNSS" & height_ok == TRUE, .(bias_sl, sd_sl, bias_land, sd_land, w = 1)],
  MeteoSwiss = ind[source == "MeteoSwiss", .(bias_sl, sd_sl, bias_land, sd_land, w = 1)]
)
main <- rbindlist(lapply(names(sets), function(k) {
  s <- sets[[k]]
  rbindlist(lapply(c("sl", "land"), function(ds) {
    b <- s[[paste0("bias_", ds)]]
    v <- s[[paste0("sd_", ds)]]
    ok <- is.finite(b) & is.finite(v)
    data.table(reference = k, dataset = ds, n_stations = sum(ok),
      abs_bias_median = wquant(abs(b[ok]), s$w[ok], 0.5),
      abs_bias_p90 = wquant(abs(b[ok]), s$w[ok], 0.9),
      sd_median = wquant(v[ok], s$w[ok], 0.5), sd_p90 = wquant(v[ok], s$w[ok], 0.9))
  }))
}))
fwrite(main, file.path(dir_tables, "ground_main.csv"))

# ---- Elevation gap: expected |bias| and SD, and what is left per station ---------------------
# The gap |station elevation - ERA5 orography| explains more of the station-to-station variation
# than station elevation or terrain roughness (with which it is strongly correlated).
d <- ref[is.finite(sd_sl)]
d[, adz := abs(dz_sl)]
m_b <- gam(log(abs(bias_sl) + 0.5) ~ s(log1p(adz), k = 6), data = d, weights = cw / mean(cw))
m_s <- gam(log(sd_sl) ~ s(log1p(adz), k = 6), data = d, weights = cw / mean(cw))
d[, `:=`(abs_bias_fit = exp(fitted(m_b)) - 0.5, sd_fit = exp(fitted(m_s)))]
d[, `:=`(abs_bias_ratio = (abs(bias_sl) + 0.5) / exp(fitted(m_b)), sd_ratio = sd_sl / sd_fit)]
fwrite(d[, .(id, lon, lat, adz, bias_sl, sd_sl, abs_bias_fit, sd_fit, abs_bias_ratio, sd_ratio)],
  file.path(dir_tables, "ground_gap_residual.csv"))
grid <- data.table(adz = c(0, exp(seq(log(1), log(max(d$adz)), length.out = 80))))
grid[, `:=`(abs_bias = exp(predict(m_b, grid)) - 0.5, sd = exp(predict(m_s, grid)))]
fwrite(grid, file.path(dir_tables, "ground_gap_fit.csv"))
fwrite(data.table(response = c("|bias|", "SD"),
  dev_expl = c(summary(m_b)$dev.expl, summary(m_s)$dev.expl)),
  file.path(dir_tables, "ground_gap_dev_expl.csv"))

# ---- Climate zone ----------------------------------------------------------------------------
clim <- ref[!is.na(climate) & climate != "", c(.(n = .N), wq(bias_sl, cw)), by = climate]
clim <- rbind(
  cbind(metric = "bias", clim),
  cbind(metric = "sd", ref[!is.na(climate) & climate != "", c(.(n = .N), wq(sd_sl, cw)),
    by = climate])
)
fwrite(clim, file.path(dir_tables, "ground_var_climate.csv"))

# ---- Season and hour of day: bias and SD per station and class ---------------------------------
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_hadisd.parquet"),
  col_select = c("id", "year", "lsh", "sdoy", "err_sl", "gross")))
A <- A[year %in% years_main & !gross %in% TRUE & is.finite(err_sl) & id %in% ref$id]
A[, month := pmin(12, floor((sdoy - 1) / 30.5) + 1)]
# Most stations report 3-hourly, so hourly classes alternate between station subsets: 3 h classes.
A[, hour := 3 * floor(lsh / 3) + 1.5]
by_class <- function(cl) {
  s <- A[, .(bias = mean(err_sl), sd = sd(err_sl), n = .N), by = c("id", cl)][n >= 30]
  s <- merge(s, ref[, .(id, cw)], by = "id")
  rbind(
    cbind(metric = "bias", s[, c(.(n = .N), wq(bias, cw)), by = cl]),
    cbind(metric = "sd", s[, c(.(n = .N), wq(sd, cw)), by = cl])
  )
}
fwrite(by_class("month"), file.path(dir_tables, "ground_var_month.csv"))
fwrite(by_class("hour"), file.path(dir_tables, "ground_var_hour.csv"))
rm(A)
gc()

# ---- Change over time: the stations reporting in every era year -------------------------------
era_ids <- if (file.exists(file.path(dir_interim, "era_ids.csv"))) {
  fread(file.path(dir_interim, "era_ids.csv"))$id
} else character()
if (length(era_ids)) {
  Ae <- as.data.table(read_parquet(file.path(dir_interim, "errors_hadisd.parquet"),
    col_select = c("id", "year", "err_sl", "gross")))[id %in% era_ids & !gross %in% TRUE]
  Ae <- Ae[, .(bias = mean(err_sl), sd = sd(err_sl), n = .N), by = .(id, year)][n >= 500]
  Ae <- Ae[id %in% Ae[, .N, by = id][N == max(N), id]]
  fwrite(Ae[, .(n_stations = .N, abs_bias_median = median(abs(bias)), sd_median = median(sd),
    sd_p90 = quantile(sd, 0.9)), by = year][order(year)], file.path(dir_tables, "ground_era.csv"))
  fwrite(rbind(cbind(metric = "bias", Ae[, c(.(n = .N), wq(bias)), by = year]),
    cbind(metric = "sd", Ae[, c(.(n = .N), wq(sd)), by = year])),
    file.path(dir_tables, "ground_var_year.csv"))
}

# ---- In flight: bias and SD per radiosonde station and height bin ----------------------------
st <- load_stations()
B <- load_radiosondes(st)
sb <- B[is.finite(err_sl_rel) & !is.na(hbin) & as.integer(hbin) > 1, .(bias = mean(err_sl_rel),
  sd = sd(err_sl_rel), n = .N), by = .(id, hbin)][n >= 30]
sb[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(sb, file.path(dir_tables, "flight_station_height.csv"))
cat("Variation tables written.\n")
print(main)

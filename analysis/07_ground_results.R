# Ground results: errors of the three conversions at GHCNh stations, the comparison of ERA5
# single-levels with ERA5-Land, and the variation of bias and SD with elevation gap, climate,
# season and hour of day. Every station has equal total weight.
source("R/utils.R")
suppressPackageStartupMessages(library(mgcv))
setDTthreads(1)
formulas <- c("isa", "standard", "virtual")
st <- load_stations()

# ---- Three conversions -----------------------------------------------------------------------
G <- as.data.table(read_parquet(
  file.path(dir_derived, "errors_ghcnh.parquet"),
  col_select = c("id", "err_isa", "err_standard", "err_virtual")
))
G <- merge(G, st[network == "ghcnh", .(id, terrain, elev, lat, lon)], by = "id")
G[, w := 1 / .N, by = id]

# Bias (accuracy) and SD (precision) of each station.
gs <- rbindlist(lapply(formulas, function(f) {
  G[,
    .(
      formula = f,
      n = .N,
      bias = mean(get(paste0("err_", f))),
      sd = sd(get(paste0("err_", f))),
      terrain = terrain[1],
      elev = elev[1],
      lat = lat[1],
      lon = lon[1],
      cw = 1
    ),
    by = id
  ]
}))
fwrite(gs, file.path(dir_tables, "ground_station.csv"))
ground_summary <- function(s) {
  s[, .(
    n_stations = .N,
    abs_bias_median = wquant(abs(bias), cw, 0.5),
    abs_bias_p90 = wquant(abs(bias), cw, 0.9),
    sd_median = wquant(sd, cw, 0.5),
    sd_p90 = wquant(sd, cw, 0.9)
  )]
}
fwrite(
  rbind(
    gs[, ground_summary(.SD), by = formula][, terrain := "all"],
    gs[, ground_summary(.SD), by = .(formula, terrain)]
  ),
  file.path(dir_tables, "ground_summary.csv")
)

# Hourly absolute errors: median and 95th percentile, and their distribution in 5 m bins.
fwrite(
  rbindlist(lapply(formulas, function(f) {
    G[, .(
      formula = f,
      medae = wquant(abs(get(paste0("err_", f))), w, 0.5),
      p95_abs = wquant(abs(get(paste0("err_", f))), w, 0.95)
    )]
  })),
  file.path(dir_tables, "ground_tails.csv")
)
fwrite(
  rbindlist(lapply(formulas, function(f) {
    G[,
      .(weight = sum(w)),
      by = .(bin = pmin(floor(abs(get(paste0("err_", f))) / 5) * 5, 450))
    ][,
      `:=`(formula = f, percent = 100 * weight / sum(weight))
    ]
  })),
  file.path(dir_tables, "ground_observation_hist.csv")
)
rm(G)

# ---- ERA5 single-levels and ERA5-Land (standard lapse rate) ----------------------------------
A <- as.data.table(read_parquet(
  file.path(dir_derived, "errors_ghcnh.parquet"),
  col_select = c("id", "err_sl", "err_land", "lsh", "sdoy")
))
A <- A[is.finite(err_sl)]
stA <- A[,
  .(
    n = .N,
    bias_sl = mean(err_sl),
    sd_sl = sd(err_sl),
    bias_sl_paired = mean(err_sl[is.finite(err_land)]),
    sd_sl_paired = sd(err_sl[is.finite(err_land)]),
    bias_land = mean(err_land, na.rm = TRUE),
    sd_land = sd(err_land, na.rm = TRUE)
  ),
  by = id
]
stA <- merge(st[network == "ghcnh"], stA, by = "id")
fwrite(stA, file.path(dir_tables, "ground_station_products.csv"))
# Station bias and SD of both products over the hours covered by both.
fwrite(
  rbindlist(lapply(c("sl", "land"), function(ds) {
    b <- stA[[if (ds == "sl") "bias_sl_paired" else "bias_land"]]
    v <- stA[[if (ds == "sl") "sd_sl_paired" else "sd_land"]]
    ok <- is.finite(b) & is.finite(v)
    data.table(
      dataset = ds,
      n_stations = sum(ok),
      abs_bias_median = wquant(abs(b[ok]), rep(1, sum(ok)), 0.5),
      sd_median = wquant(v[ok], rep(1, sum(ok)), 0.5)
    )
  }))[,
    land_worse_bias := stA[
      is.finite(bias_land) & is.finite(bias_sl_paired),
      mean(abs(bias_land) > abs(bias_sl_paired))
    ]
  ],
  file.path(dir_tables, "ground_products.csv")
)

# Paired hourly absolute errors: joint histogram on the pseudo-log scale of the figure, and quantiles.
P <- A[is.finite(err_land), .(id, sl = abs(err_sl), land = abs(err_land))]
P[, w := 1 / .N, by = id]
plog <- function(x) asinh(x / 2) / log(10)
edges <- seq(0, plog(400), length.out = 61)
P[, `:=`(
  bx = findInterval(plog(sl), edges, all.inside = TRUE),
  by = findInterval(plog(land), edges, all.inside = TRUE)
)]
hist2 <- P[, .(w = sum(w)), by = .(bx, by)]
fwrite(
  hist2[, .(
    x0 = edges[bx],
    x1 = edges[bx + 1],
    y0 = edges[by],
    y1 = edges[by + 1],
    w = w / sum(w)
  )],
  file.path(dir_tables, "ground_land_hourly_hist.csv")
)
qs <- setNames(c(0.1, 0.25, 0.5, 0.75, 0.9), c("q10", "q25", "q50", "q75", "q90"))
fwrite(
  rbind(
    P[, c(product = "sl", lapply(qs, function(p) wquant(sl, w, p)))],
    P[, c(product = "land", lapply(qs, function(p) wquant(land, w, p)))]
  )[,
    land_larger := P[, sum(w * (land > sl)) / sum(w)]
  ],
  file.path(dir_tables, "ground_land_hourly_quantiles.csv")
)
rm(P, hist2)

# ---- Variation of bias and SD (ERA5 single-levels, standard lapse rate) ----------------------
wq <- function(x, w = rep(1, length(x))) {
  ok <- is.finite(x)
  setNames(
    as.list(vapply(qs, function(p) wquant(x[ok], w[ok], p), 1)),
    names(qs)
  )
}
# Elevation gap |station elevation - ERA5 orography|: expected |bias| and SD, and the residual per station.
d <- stA[is.finite(sd_sl)]
d[, adz := abs(dz_sl)]
m_b <- gam(log(abs(bias_sl) + 0.5) ~ s(log1p(adz), k = 6), data = d)
m_s <- gam(log(sd_sl) ~ s(log1p(adz), k = 6), data = d)
d[, `:=`(
  abs_bias_ratio = (abs(bias_sl) + 0.5) / exp(fitted(m_b)),
  sd_ratio = sd_sl / exp(fitted(m_s))
)]
fwrite(
  d[, .(id, lon, lat, adz, bias_sl, sd_sl, abs_bias_ratio, sd_ratio)],
  file.path(dir_tables, "ground_gap_residual.csv")
)
grid <- data.table(
  adz = c(0, exp(seq(log(1), log(max(d$adz)), length.out = 80)))
)
grid[, `:=`(
  abs_bias = exp(predict(m_b, grid)) - 0.5,
  sd = exp(predict(m_s, grid))
)]
fwrite(grid, file.path(dir_tables, "ground_gap_fit.csv"))
# Climate zone.
z <- stA[!is.na(climate)]
fwrite(
  rbind(
    cbind(metric = "bias", z[, c(.(n = .N), wq(bias_sl)), by = climate]),
    cbind(metric = "sd", z[, c(.(n = .N), wq(sd_sl)), by = climate])
  ),
  file.path(dir_tables, "ground_var_climate.csv")
)
# Seasonal month and 3 h local-time class (most stations report 3-hourly).
A[, month := pmin(12, floor((sdoy - 1) / 30.5) + 1)]
A[, hour := 3 * floor(lsh / 3) + 1.5]
by_class <- function(cl) {
  s <- A[, .(bias = mean(err_sl), sd = sd(err_sl), n = .N), by = c("id", cl)][
    n >= 30
  ]
  rbind(
    cbind(metric = "bias", s[, c(.(n = .N), wq(bias)), by = cl]),
    cbind(metric = "sd", s[, c(.(n = .N), wq(sd)), by = cl])
  )
}
fwrite(by_class("month"), file.path(dir_tables, "ground_var_month.csv"))
fwrite(by_class("hour"), file.path(dir_tables, "ground_var_hour.csv"))
cli::cli_alert_success("Ground results: {nrow(stA)} stations")

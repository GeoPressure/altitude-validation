# All figures of the report, drawn from the tables in output/tables (no model is refitted here).
#
# One theme and one set of colours for every figure (R/palette.R): accuracy (bias) in blue and
# precision (SD) in teal, side by side with zero, the perfect value, as a dark line; ERA5
# single-levels and GeoPressureR's formula in ink; fixed colours for the reference datasets, the
# ERA5 products, the formula changes and the climate zones. Distributions over stations are drawn
# as the median (point or line), the 25-75% range (thick or dark band) and the 10-90% range (thin
# or light band).

source("R/utils.R")
source("R/palette.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(sf)
})
sf_use_s2(FALSE)

# ---- Theme -------------------------------------------------------------------------------------
font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) "Helvetica Neue" else "sans"
theme_set(
  theme_minimal(base_size = 10, base_family = font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.3),
      axis.title = element_text(colour = "#374151"),
      axis.text = element_text(colour = "#4B5563"),
      plot.title = element_text(face = "bold", size = 10.5, colour = pal[["ink"]]),
      plot.title.position = "plot",
      plot.subtitle = element_text(colour = "#4B5563"),
      strip.text = element_text(face = "bold", hjust = 0, colour = pal[["ink"]]),
      legend.position = "bottom",
      legend.title = element_text(size = 9, colour = "#374151"),
      legend.title.position = "top",
      plot.tag = element_text(face = "bold", size = 11)
    )
)
update_geom_defaults("line", list(linewidth = 0.8))
save_fig <- function(p, name, w = 8, h = 4.5) {
  ggsave(file.path(dir_figures, paste0(name, ".png")), p, width = w, height = h, dpi = 200,
    bg = "white", device = ragg::agg_png)
}
tab <- function(f) fread(file.path(dir_tables, f))
height_axis <- function(top = 6000) {
  scale_x_continuous(breaks = seq(0, top, 1000), labels = function(x) x / 1000,
    limits = c(0, top), expand = expansion(mult = 0.01))
}
flip_height <- list(coord_flip(), labs(x = "Height above ground (km)"))

col_acc <- pal_metric[["accuracy"]]
col_pre <- pal_metric[["precision"]]
lab_acc <- "Accuracy: bias (m)"
lab_pre <- "Precision: SD (m)"
zero_line <- geom_hline(yintercept = 0, colour = pal[["ink"]], linewidth = 0.5)

# ---- Map helpers -----------------------------------------------------------------------------
crs_map <- "+proj=eqearth"
world <- st_transform(rnaturalearth::ne_countries(scale = 110, returnclass = "sf"), crs_map)
as_pts <- function(d) st_transform(st_as_sf(d, coords = c("lon", "lat"), crs = 4326), crs_map)
basemap <- function() {
  ggplot() +
    geom_sf(data = world, fill = "#EEF0F3", colour = "white", linewidth = 0.15) +
    coord_sf(crs = crs_map, expand = FALSE) +
    theme(axis.text = element_blank(), axis.title = element_blank(),
      panel.grid.major = element_line(colour = "#F3F4F6", linewidth = 0.2))
}
bar <- function(w = 12) guide_colourbar(barwidth = w, barheight = 0.5)

# ---- Data -------------------------------------------------------------------------------------
st <- tab("stations.csv")
stA <- tab("ground_station_stats.csv")
ref <- stA[reference == TRUE]
b_used <- tab("flight_stations_used.csv")
stB <- st[network == "igra" & id %in% b_used$id]
ind <- tab("indep_station_stats.csv")

# ==== Data: where the stations are ============================================================
pts <- rbind(
  ref[, .(lon, lat, elev, what = "HadISD")],
  ind[source == "MeteoSwiss" | height_ok, .(lon, lat, elev, what = source)],
  stB[, .(lon, lat, elev, what = "IGRA2")]
)
pts[, what := factor(what, names(pal_reference))]
p1 <- basemap() +
  geom_sf(data = as_pts(pts[order(what)]), aes(colour = what, shape = what), size = 1.1,
    alpha = 0.9) +
  scale_colour_manual(values = pal_reference, name = NULL) +
  scale_shape_manual(values = c(16, 15, 18, 17), name = NULL) +
  guides(colour = guide_legend(override.aes = list(size = 2.5)))
p2 <- ggplot(pts[, .(elev = pmax(elev, 1), what)], aes(elev, fill = what)) +
  geom_histogram(bins = 30, colour = "white", linewidth = 0.2) +
  scale_x_log10(breaks = c(1, 10, 100, 1000, 5000), labels = c("1", "10", "100", "1000", "5000")) +
  scale_fill_manual(values = pal_reference, guide = "none") +
  facet_wrap(~what, ncol = 1, scales = "free_y") +
  labs(x = "Ground elevation of the station\n(m, log scale)", y = "Number of stations")
save_fig(p1 + p2 + plot_layout(widths = c(4, 1)), "data_stations", 10, 5.5)
# Elevation panel alone, shown under the interactive map in the HTML report
save_fig(p2 + facet_wrap(~what, nrow = 1, scales = "free_y") +
  labs(x = "Ground elevation of the station (m, log scale)"), "data_elevation", 9, 2.6)

# ==== Surface stations ==============================================================================
qbars <- function(col) {
  list(
    geom_linerange(aes(ymin = q10, ymax = q90), colour = col, linewidth = 0.6),
    geom_linerange(aes(ymin = q25, ymax = q75), colour = col, linewidth = 2.4, alpha = 0.6),
    geom_point(aes(y = q50), colour = pal[["ink"]], size = 1.6)
  )
}
qribbon <- function(col) {
  list(
    geom_ribbon(aes(ymin = q10, ymax = q90), fill = col, alpha = 0.18),
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = col, alpha = 0.35),
    geom_line(aes(y = q50), colour = pal[["ink"]])
  )
}
# Accuracy or precision panel from a table with columns metric (bias / sd) and q10..q90
qpanel <- function(d, x, m, geom, xlab, tag, ...) {
  col <- if (m == "bias") col_acc else col_pre
  p <- ggplot(d[metric == m], aes(.data[[x]])) + zero_line + geom(col) +
    labs(x = xlab, y = if (m == "bias") lab_acc else lab_pre, tag = tag) + list(...)
  if (m == "sd") p <- p + expand_limits(y = 0)
  p
}

# Elevation gap: bias and SD per station, with the GAM fit (15_variation.R)
gr <- tab("ground_gap_residual.csv")
gf <- tab("ground_gap_fit.csv")
gap_x <- scale_x_continuous(trans = "log1p", breaks = c(0, 10, 30, 100, 300, 1000))
gap_lab <- "Elevation gap: |station - ERA5 orography| (m, log scale)"
p1 <- ggplot(gr, aes(adz, bias_sl)) +
  geom_point(size = 0.8, alpha = 0.35, colour = col_acc) +
  zero_line +
  geom_line(aes(adz, abs_bias), data = gf, colour = pal[["ink"]], linetype = 2) +
  geom_line(aes(adz, -abs_bias), data = gf, colour = pal[["ink"]], linetype = 2) +
  gap_x + coord_cartesian(ylim = c(-40, 40)) +
  labs(x = gap_lab, y = lab_acc, tag = "a")
p2 <- ggplot(gr, aes(adz, sd_sl)) +
  geom_point(size = 0.8, alpha = 0.35, colour = col_pre) +
  zero_line +
  geom_line(aes(adz, sd), data = gf, colour = pal[["ink"]]) +
  gap_x + coord_cartesian(ylim = c(0, 20)) +
  labs(x = gap_lab, y = lab_pre, tag = "b")
save_fig(p1 + p2, "ground_gap", 9, 4.2)

# Where the error is larger or smaller than the elevation gap predicts, as the median over 5 x 5
# degree cells (single stations are too noisy to read). Accuracy: signed bias, which the gap does
# not predict (only its size). Precision: SD / SD expected from the gap.
cell_map <- function(d, v, scale, title, tag) {
  g <- d[, .(v = median(get(v)), n = .N), by = .(lon0 = 5 * floor(lon / 5), lat0 = 5 * floor(lat / 5))]
  poly <- st_sfc(lapply(seq_len(nrow(g)), function(i) {
    x <- g$lon0[i] + c(0, 5, 5, 0, 0)
    y <- g$lat0[i] + c(0, 0, 5, 5, 0)
    st_polygon(list(cbind(x, y)))
  }), crs = 4326)
  g <- st_transform(st_sf(g, geometry = poly), crs_map)
  basemap() + geom_sf(data = g, aes(fill = v), colour = "white", linewidth = 0.1) + scale +
    labs(title = title, tag = tag)
}
gr[, ls := log2(sd_ratio)]
p1 <- cell_map(gr, "bias_sl", scale_fill_gradientn(colours = pal_diverging, limits = c(-8, 8),
  oob = scales::squish, name = "Median bias (m)", guide = bar()), "Accuracy: bias", "a")
p2 <- cell_map(gr, "ls", scale_fill_gradientn(colours = pal_diverging, limits = c(-1, 1),
  oob = scales::squish, breaks = c(-1, -0.5, 0, 0.5, 1), labels = c("1/2", "0.7", "1", "1.4", "2"),
  name = "Median SD / SD expected from the elevation gap", guide = bar()),
  "Precision: SD relative to the elevation gap", "b")
save_fig(p1 / p2, "ground_map_residual", 8, 8.2)

# Raw maps (appendix)
p1 <- basemap() +
  geom_sf(data = as_pts(ref[order(abs(bias_sl))]), aes(colour = pmax(pmin(bias_sl, 30), -30)),
    size = 1.1) +
  scale_colour_gradientn(colours = pal_diverging, limits = c(-30, 30), name = "Bias (m)",
    guide = bar(10)) +
  labs(title = "Accuracy: bias per station")
p2 <- basemap() +
  geom_sf(data = as_pts(ref[order(sd_sl)]), aes(colour = pmin(sd_sl, 15)), size = 1.1) +
  scale_colour_gradientn(colours = pal_sequential, limits = c(0, 15), name = "SD (m)",
    guide = bar(10)) +
  labs(title = "Precision: SD per station")
save_fig(p1 / p2, "ground_maps", 8, 8.2)

# Climate zone: where the zones are, and the distribution of bias and SD in each (ordered by
# the median latitude of their stations)
vc <- tab("ground_var_climate.csv")
lat_ord <- ref[!is.na(climate) & climate != "", median(abs(lat)), by = climate][order(V1), climate]
vc[, climate := factor(climate, rev(lat_ord))]
clim_bars <- function(m, tag) {
  ggplot(vc[metric == m], aes(climate, colour = climate)) +
    zero_line +
    geom_linerange(aes(ymin = q10, ymax = q90), linewidth = 0.6) +
    geom_linerange(aes(ymin = q25, ymax = q75), linewidth = 2.4, alpha = 0.7) +
    geom_point(aes(y = q50), colour = pal[["ink"]], size = 1.6) +
    scale_colour_manual(values = pal_climate, guide = "none") +
    coord_flip() +
    labs(x = NULL, y = if (m == "bias") lab_acc else lab_pre, tag = tag)
}
pm <- basemap() +
  geom_sf(data = as_pts(ref[!is.na(climate) & climate != ""]), aes(colour = climate), size = 0.7) +
  scale_colour_manual(values = pal_climate, name = NULL) +
  guides(colour = guide_legend(nrow = 1, override.aes = list(size = 2.5))) +
  labs(tag = "a")
save_fig(pm / (clim_bars("bias", "b") + (clim_bars("sd", "c") + expand_limits(y = 0))) +
  plot_layout(heights = c(1.6, 1)), "ground_climate", 8, 7)

# Season and hour of day: same x axis on top of each other
month_x <- scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1),
  expand = expansion(0.01))
hour_x <- scale_x_continuous(breaks = seq(0, 24, 3), limits = c(0, 24), expand = expansion(0))
vm <- tab("ground_var_month.csv")
vh <- tab("ground_var_hour.csv")
no_x <- theme(axis.title.x = element_blank(), axis.text.x = element_blank())
p <- (qpanel(vm, "month", "bias", qribbon, NULL, "a", month_x, no_x, ggtitle("Over the year")) |
  qpanel(vh, "hour", "bias", qribbon, NULL, "b", hour_x, no_x, ggtitle("Over the day"))) /
  (qpanel(vm, "month", "sd", qribbon, "Month (southern hemisphere shifted by six months)", "c",
    month_x) |
    qpanel(vh, "hour", "sd", qribbon, "Local solar hour", "d", hour_x))
save_fig(p, "ground_season_hour", 9, 6)

# Change over time, on a time axis
if (file.exists(file.path(dir_tables, "ground_var_year.csv"))) {
  vy <- tab("ground_var_year.csv")
  year_x <- scale_x_continuous(breaks = seq(1990, 2025, 5), limits = c(1988, 2026))
  line_q50 <- function(col) c(qbars(col), geom_line(aes(y = q50), colour = pal[["ink"]],
    linewidth = 0.4))
  save_fig(qpanel(vy, "year", "bias", line_q50, NULL, "a", year_x) +
    qpanel(vy, "year", "sd", line_q50, NULL, "b", year_x), "ground_era", 9, 3.6)
}

# ERA5 single-levels vs ERA5-Land at the three ground references
ind_ref <- ind[source == "MeteoSwiss" | height_ok == TRUE]
sl <- rbind(
  ref[, .(reference = "HadISD", bias_sl, sd_sl, bias_land, sd_land, w = cw)],
  ind_ref[, .(reference = source, bias_sl, sd_sl, bias_land, sd_land, w = 1)]
)
sl <- rbind(sl[, .(reference, dataset = "ERA5 single-levels", ab = abs(bias_sl), sd = sd_sl, w)],
  sl[, .(reference, dataset = "ERA5-Land", ab = abs(bias_land), sd = sd_land, w)])
sl <- sl[is.finite(ab) & is.finite(sd)]
qs <- function(x, w) as.list(setNames(vapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) {
  wquant(x, w, p)
}, 1), c("q10", "q25", "q50", "q75", "q90")))
ql <- rbind(cbind(metric = "abs_bias", sl[, qs(ab, w), by = .(reference, dataset)]),
  cbind(metric = "sd", sl[, qs(sd, w), by = .(reference, dataset)]))
ql[, reference := factor(reference, c("HadISD", "GNSS", "MeteoSwiss"))]
land_panel <- function(m, ylab, tag, ...) {
  ggplot(ql[metric == m], aes(reference, colour = dataset, group = dataset)) +
    zero_line +
    geom_linerange(aes(ymin = q10, ymax = q90), linewidth = 0.6,
      position = position_dodge(0.5)) +
    geom_linerange(aes(ymin = q25, ymax = q75), linewidth = 2.4, alpha = 0.6,
      position = position_dodge(0.5)) +
    geom_point(aes(y = q50), size = 1.8, position = position_dodge(0.5)) +
    scale_colour_manual(values = pal_product, name = NULL) +
    labs(x = NULL, y = ylab, tag = tag) + list(...)
}
p1 <- land_panel("abs_bias", "Accuracy: |bias| (m, log scale)", "a",
  scale_y_continuous(trans = scales::pseudo_log_trans(sigma = 1),
    breaks = c(0, 1, 3, 10, 30, 100), limits = c(0, NA)))
p2 <- land_panel("sd", lab_pre, "b", expand_limits(y = 0))
save_fig(p1 + p2 + plot_layout(guides = "collect"), "ground_sl_vs_land", 8, 4)

# Appendix: at Swiss stations, HadISD's bias follows the error of its listed elevation
ms <- tab("meteoswiss_vs_hadisd.csv")[is.finite(bias_hadisd)]
ms <- rbind(ms[, .(d_barometer, bias = bias_hadisd, with = "HadISD elevation")],
  ms[, .(d_barometer, bias = bias_meteoswiss, with = "MeteoSwiss barometer height")])
p <- ggplot(ms, aes(d_barometer, bias, colour = with)) +
  zero_line +
  geom_abline(slope = -1, intercept = 0, colour = pal[["slate"]], linetype = 2) +
  geom_point(size = 1.8, alpha = 0.85) +
  scale_colour_manual(values = c(`HadISD elevation` = pal_reference[["HadISD"]],
    `MeteoSwiss barometer height` = pal_reference[["MeteoSwiss"]]), name = "Bias with the") +
  labs(x = "HadISD elevation - MeteoSwiss barometer height (m)", y = lab_acc)
save_fig(p, "ground_swiss_elevation", 6, 4.6)

# ==== Radiosondes ====================================================================================
# Bird flight heights: share of flight time in 100 m bins, with the median and 90th percentile
bh <- tab("bird_height_hist.csv")
bq <- tab("bird_height_quantiles.csv")[flight == TRUE]
n_tags <- tab("bird_height_distribution.csv")$n_tags[1]
bird_base <- ggplot(bh[lo < 6000], aes(lo + 50, 100 * prop)) +
  geom_col(width = 100, fill = pal[["slate"]], colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = c(bq$p50, bq$p90), colour = pal[["ink"]], linetype = "dashed",
    linewidth = 0.4) +
  height_axis() + flip_height +
  labs(x = NULL, y = sprintf("Share of flight time\n(%%, %d tags)", n_tags), tag = "c")
bird_panel <- bird_base +
  annotate("text", x = c(bq$p50, bq$p90), y = Inf, vjust = -0.4, hjust = 1.05, size = 2.8,
    colour = pal[["ink"]], label = sprintf(c("median %d m", "90%% below %d m"),
      round(c(bq$p50, bq$p90), -1)))

# In flight: bias and SD per station and height bin, spread over the bin, with the cell-weighted
# mean bias and median SD
sb <- merge(tab("flight_station_height.csv"), load_stations()[network == "igra", .(id, cw)], by = "id")
sbm <- sb[, .(bias = wmean(bias, cw), sd = wquant(sd, cw, 0.5)), by = agl_mid]
set.seed(1)
k <- match(sb$agl_mid, hbin_mid)
sb[, agl_j := pmax(hbin_breaks[k], 0) + runif(.N) * (hbin_breaks[k + 1] - pmax(hbin_breaks[k], 0))]
flight_panel <- function(v, col, ylim, ylab, tag) {
  ggplot(sb, aes(agl_j, .data[[v]])) +
    geom_point(size = 0.5, alpha = 0.15, colour = col) +
    zero_line +
    geom_line(aes(agl_mid, .data[[v]]), data = sbm, colour = pal[["ink"]]) +
    geom_point(aes(agl_mid, .data[[v]]), data = sbm, colour = pal[["ink"]], size = 1.3) +
    height_axis() + flip_height + coord_flip(ylim = ylim) + labs(y = ylab, tag = tag)
}
pf1 <- flight_panel("bias", col_acc, c(-200, 100), lab_acc, "a")
pf2 <- flight_panel("sd", col_pre, c(0, 120), lab_pre, "b") + labs(x = NULL)
save_fig(pf1 + pf2 + bird_panel, "flight_height", 10, 5)

# Appendix: ERA5-Land and ERA5 single-levels in flight, by height
tb <- tab("flight_height.csv")[!is.na(hbin) & hbin != ""]
tb[, agl_mid := hbin_mid[match(hbin, levels(cut(0, hbin_breaks, right = TRUE)))]]
tb[, product := fifelse(method == "ERA5-Land", "ERA5-Land", "ERA5 single-levels")]
land_flight <- function(v, ylab, tag) {
  ggplot(tb[agl_mid <= 4000], aes(agl_mid, .data[[v]], colour = product)) +
    zero_line + geom_line() + geom_point(size = 1.3) +
    scale_colour_manual(values = pal_product, name = NULL) +
    height_axis(4000) + flip_height + labs(y = ylab, tag = tag)
}
save_fig(land_flight("bias", lab_acc, "a") + (land_flight("sd", lab_pre, "b") + labs(x = NULL) +
  expand_limits(y = 0)) + plot_layout(guides = "collect"), "flight_land", 8, 4.4)

# In-flight bias by climate zone and half-year
bc <- tab("flight_climate_season.csv")[n_st >= 3 & !is.na(climate) & climate != ""]
season_lt <- scale_linetype_manual(values = c(`summer half` = 1, `winter half` = 2), name = NULL,
  labels = c(`summer half` = "summer half-year", `winter half` = "winter half-year"))
p <- ggplot(bc[agl_mid <= 4000], aes(agl_mid, bias, colour = climate, linetype = season)) +
  zero_line +
  geom_line() +
  scale_colour_manual(values = pal_climate, name = NULL) +
  season_lt +
  height_axis(4000) + flip_height + labs(y = lab_acc) +
  guides(colour = guide_legend(nrow = 2))
save_fig(p, "flight_climate", 7, 4.5)

# Appendix: in-flight bias by day and night and half-year
dn <- tab("flight_daynight_season.csv")[method == "GeoPressureR (ERA5 single-levels)" &
  !is.na(hbin) & hbin != ""]
dn[, agl_mid := hbin_mid[match(hbin, levels(cut(0, hbin_breaks, right = TRUE)))]]
p <- ggplot(dn[agl_mid <= 4000], aes(agl_mid, bias, colour = daynight, linetype = season)) +
  zero_line + geom_line() +
  scale_colour_manual(values = c(day = "#E9A23B", night = "#1E2F57"), name = NULL) +
  season_lt +
  height_axis(4000) + flip_height + labs(y = lab_acc)
save_fig(p, "flight_daynight", 6, 4.5)

# Appendix: observed in-flight error against the error expected from the temperature assumption
bt <- tab("flight_temperature_bins.csv")
te <- tab("flight_temperature_explanation.csv")
p <- ggplot(bt[abs(pred) <= 200 & abs(obs) <= 200], aes(pred, obs, fill = N)) +
  geom_tile() +
  geom_abline(slope = 1, intercept = 0, colour = pal[["ink"]], linewidth = 0.5, linetype = 2) +
  scale_fill_gradientn(colours = pal_sequential, trans = "log10", name = "Sonde levels",
    labels = scales::label_comma(), guide = bar(10)) +
  coord_equal(xlim = c(-150, 100), ylim = c(-150, 100)) +
  labs(x = "Error expected from the temperature assumption (m)",
    y = "Observed error relative to the surface level (m)",
    subtitle = sprintf("r = %.2f, %d%% of variance explained", te$r, round(100 * te$r2)))
save_fig(p, "flight_temperature", 5.5, 5.8)

# ==== Formula variants (16_formula.R) ========================================================
if (file.exists(file.path(dir_tables, "formula_height.csv"))) {
  fh <- tab("formula_height.csv")
  codes <- names(pal_formula)
  labs_f <- setNames(c("GeoPressureR (T2m, -6.5 K/km)", "virtual temperature",
    "+ constant fitted lapse rate", "+ lapse rate by season and latitude"), codes)
  pal_f <- setNames(unname(pal_formula), labs_f)
  fh <- fh[code %in% codes & agl_mid <= 4000]
  fh[, method := factor(labs_f[code], labs_f)]
  formula_panel <- function(v, ylab, tag) {
    ggplot(fh, aes(agl_mid, .data[[v]], colour = method)) +
      zero_line +
      geom_line() + geom_point(size = 1.3) +
      scale_colour_manual(values = pal_f, name = NULL) +
      height_axis(4000) + flip_height + labs(y = ylab, tag = tag)
  }
  pb1 <- formula_panel("bias", lab_acc, "a")
  pb2 <- formula_panel("sd", lab_pre, "b") + expand_limits(y = 0) + labs(x = NULL)
  save_fig(pb1 + pb2 + plot_layout(guides = "collect") & guides(colour = guide_legend(nrow = 2)),
    "formula_height", 8, 4.6)

  fc <- tab("formula_climate_season.csv")[n_st >= 3 & agl_mid <= 4000 &
    code %in% c("current", "tv_lapse", "tv_lapse_var")]
  fc[, formula := factor(code, c("current", "tv_lapse", "tv_lapse_var"),
    c("GeoPressureR", "Tv + constant lapse rate", "Tv + lapse rate by season and latitude"))]
  p <- ggplot(fc, aes(agl_mid, bias, colour = climate, linetype = season)) +
    zero_line +
    geom_line() +
    facet_wrap(~formula) +
    scale_colour_manual(values = pal_climate, name = NULL) +
    season_lt +
    height_axis(4000) + flip_height + labs(y = lab_acc) +
    guides(colour = guide_legend(nrow = 2))
  save_fig(p, "formula_climate", 10, 4.5)

  if (file.exists(file.path(dir_tables, "formula_lapse_var_grid.csv"))) {
    lg <- tab("formula_lapse_var_grid.csv")
    p <- ggplot(lg, aes(sdoy, L, colour = factor(abs_lat))) +
      geom_hline(yintercept = -6.5, linetype = 3, colour = pal[["slate"]]) +
      geom_hline(yintercept = tab("formula_fit.csv")[temperature == "Tv", L_fit], linetype = 2,
        colour = pal_formula[["tv_lapse"]]) +
      geom_line() +
      scale_colour_manual(values = c(pal_sequential[2:5], "#0B1530"),
        name = "Latitude (degrees, north or south)") +
      scale_x_continuous(breaks = c(1, 91, 182, 274), labels = c("Jan", "Apr", "Jul", "Oct")) +
      guides(colour = guide_legend(nrow = 1)) +
      labs(x = "Day of year (southern hemisphere shifted by six months)",
        y = "Lapse rate (K/km)")
    save_fig(p, "formula_lapse_var", 9, 4)
  }
}
cat("Figures written to", dir_figures, "\n")

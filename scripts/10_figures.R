# All figures of the report, drawn from the tables in output/tables (no model is refitted here).
#
# One theme and one palette for every figure:
#   blue   GeoPressureR as implemented (ERA5 single-levels), and the reference set
#   coral  ERA5-Land, and stations excluded for an implausible offset
#   amber  radiosondes (Tier B stations), and stations excluded for a step change
#   teal / purple  formula variants
#   Koppen-Geiger climate zones have their own fixed colours.

source("R/utils.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(sf)
})
sf_use_s2(FALSE)

# ---- Theme and palette ---------------------------------------------------------------------
font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) "Helvetica Neue" else "sans"
pal <- c(blue = "#3B6FB6", coral = "#E4572E", amber = "#F2A541", teal = "#2A9D8F",
  purple = "#7E57C2", slate = "#94A3B8", ink = "#1F2937", grid = "#E5E7EB")
pal_climate <- c(`A tropical` = "#2A9D8F", `B arid` = "#E0A526", `C temperate` = "#E4572E",
  `D continental` = "#3B6FB6", `E polar` = "#8D99AE")
pal_dataset <- c(`ERA5 single-levels` = pal[["blue"]], `ERA5-Land` = pal[["coral"]])
seq_blue <- c("#F1F5FB", "#B9CDEB", "#6E97D0", "#3B6FB6", "#1E2F57")

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
height_axis <- scale_x_continuous(breaks = seq(0, 6000, 1000), labels = function(x) x / 1000,
  limits = c(0, 6000), expand = expansion(mult = 0.01))
flip_height <- list(coord_flip(), labs(x = "Height above ground (km)"))

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

# ---- Data -------------------------------------------------------------------------------------
st <- tab("stations.csv")
stA <- tab("A_station_stats.csv")
stA[, screen_class := factor(fifelse(!consistent, "excluded: implausible offset",
  fifelse(step_flag, "excluded: step change", "reference set")),
  c("reference set", "excluded: implausible offset", "excluded: step change"))]
pal_screen <- setNames(pal[c("blue", "coral", "purple")], levels(stA$screen_class))
ref <- stA[reference == TRUE]
b_used <- tab("B_stations_used.csv")
stB <- st[tier == "B" & id %in% b_used$id]

# ==== Data: where the stations are ============================================================
pts <- rbind(
  stA[, .(lon, lat, elev, what = as.character(screen_class))],
  stB[, .(lon, lat, elev, what = "radiosonde (Tier B)")]
)
pts[, what := factor(what, c("reference set", "excluded: implausible offset",
  "excluded: step change", "radiosonde (Tier B)"),
  c("surface barometer (Tier A)", "Tier A, excluded: implausible offset",
    "Tier A, excluded: step change", "radiosonde (Tier B)"))]
pal_pts <- setNames(c(pal[["blue"]], pal[["coral"]], pal[["purple"]], pal[["amber"]]), levels(pts$what))
p1 <- basemap() +
  geom_sf(data = as_pts(pts[order(what)]), aes(colour = what, shape = what, size = what),
    alpha = 0.9) +
  scale_colour_manual(values = pal_pts, name = NULL) +
  scale_shape_manual(values = c(16, 4, 4, 17), name = NULL) +
  scale_size_manual(values = c(0.9, 1.2, 1.2, 1.4), name = NULL) +
  guides(colour = guide_legend(nrow = 2, override.aes = list(size = 2)))
p2 <- ggplot(pts[, .(elev = pmax(elev, 1), tier = fifelse(grepl("Tier B", what),
  "radiosonde (Tier B)", "surface barometer (Tier A)"))], aes(elev, fill = tier)) +
  geom_histogram(bins = 30, colour = "white", linewidth = 0.2, position = "identity",
    alpha = 0.85) +
  scale_x_log10(breaks = c(1, 10, 100, 1000, 5000), labels = c("1", "10", "100", "1000", "5000")) +
  scale_fill_manual(values = c(`radiosonde (Tier B)` = pal[["amber"]],
    `surface barometer (Tier A)` = pal[["blue"]]), guide = "none") +
  facet_wrap(~tier, ncol = 1) +
  labs(x = "Station elevation (m, log scale)", y = "Stations")
save_fig(p1 + p2 + plot_layout(widths = c(4, 1)), "data_stations", 10, 4.2)

# ==== Tier A ==================================================================================
p1 <- basemap() +
  geom_sf(data = as_pts(ref[order(abs(bias_sl))]), aes(colour = pmax(pmin(bias_sl, 30), -30)),
    size = 1.1) +
  scale_colour_gradientn(colours = c("#1E2F57", pal[["blue"]], "#E8ECF2", pal[["coral"]],
    "#8C2A12"), limits = c(-30, 30), name = "Bias (m)",
    guide = guide_colourbar(barwidth = 10, barheight = 0.5)) +
  labs(title = "Accuracy: mean error per station")
p2 <- basemap() +
  geom_sf(data = as_pts(ref[order(sd_sl)]), aes(colour = pmin(sd_sl, 15)), size = 1.1) +
  scale_colour_gradientn(colours = seq_blue, limits = c(0, 15), name = "SD (m)",
    guide = guide_colourbar(barwidth = 10, barheight = 0.5)) +
  labs(title = "Precision: temporal SD of the error per station")
save_fig(p1 / p2, "A_maps", 8, 8.2)

# By station class
cls <- tab("A_summary.csv")[dataset == "sl" & group != "all"]
cls <- melt(cls[, .(group, subset, `median |bias|` = abs_bias_median, MAE = mae,
  `median SD` = sd_median)], id.vars = c("group", "subset"))
lev <- unique(tab("A_summary.csv")[dataset == "sl" & group != "all", subset])
cls[, subset := factor(subset, rev(lev))]
cls[, group := factor(group, c("terrain", "elevation", "latitude", "climate"),
  c("Terrain (sub-grid SD)", "Station elevation", "Latitude", "Climate"))]
p <- ggplot(cls, aes(value, subset, colour = variable)) +
  geom_line(aes(group = subset), colour = pal[["grid"]], linewidth = 1.6) +
  geom_point(size = 2.2) +
  facet_wrap(~group, scales = "free_y", ncol = 2) +
  scale_colour_manual(values = c(`median |bias|` = pal[["blue"]], MAE = pal[["ink"]],
    `median SD` = pal[["teal"]]), name = NULL) +
  labs(x = "Altitude error (m)", y = NULL)
save_fig(p, "A_by_class", 9, 5.5)

# Single-levels vs Land
dl <- melt(stA[reference == TRUE, .(id, `ERA5 single-levels` = abs(bias_sl),
  `ERA5-Land` = abs(bias_land))], id.vars = "id", variable.name = "dataset",
  value.name = "abs_bias")
p <- ggplot(dl[is.finite(abs_bias)], aes(abs_bias, colour = dataset)) +
  stat_ecdf(linewidth = 0.9) +
  scale_x_log10(breaks = c(0.1, 0.3, 1, 3, 10, 30, 100, 300)) +
  scale_y_continuous(labels = function(x) paste0(100 * x, "%")) +
  scale_colour_manual(values = pal_dataset, name = NULL) +
  labs(x = "|bias| per station (m, log scale)", y = "Share of stations")
save_fig(p, "A_sl_vs_land", 6, 4)

# Drivers: the screen and the terrain
bound <- data.table(dz = seq(-2500, 2500, 10))[, .(dz, hi = 30 + 0.1 * abs(dz))]
p1 <- ggplot(stA[order(screen_class)], aes(dz_sl, bias_sl, colour = screen_class)) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.3) +
  geom_line(aes(dz, hi), data = bound, inherit.aes = FALSE, colour = pal[["slate"]],
    linetype = 2, linewidth = 0.4) +
  geom_line(aes(dz, -hi), data = bound, inherit.aes = FALSE, colour = pal[["slate"]],
    linetype = 2, linewidth = 0.4) +
  geom_point(size = 0.9, alpha = 0.75) +
  scale_colour_manual(values = pal_screen, name = NULL) +
  coord_cartesian(ylim = c(-80, 80), xlim = c(-2000, 2000)) +
  guides(colour = guide_legend(nrow = 1, override.aes = list(size = 2))) +
  labs(x = "Station elevation - ERA5 orography (m)", y = "Bias (m)", tag = "a")
p2 <- ggplot(ref, aes(sdor, sd_sl)) +
  geom_point(size = 0.9, alpha = 0.5, colour = pal[["blue"]]) +
  geom_smooth(method = "gam", formula = y ~ s(x, k = 6), colour = pal[["ink"]],
    fill = pal[["slate"]], linewidth = 0.9) +
  scale_x_continuous(trans = "log1p", breaks = c(0, 10, 30, 100, 300, 1000)) +
  coord_cartesian(ylim = c(0, 20)) +
  labs(x = "Sub-grid orography SD in the ERA5 cell (m)", y = "Temporal SD of error (m)",
    tag = "b")
save_fig(p1 + p2, "A_drivers", 9, 4.6)

# Diurnal and seasonal cycles
# Most stations report 3-hourly, so hourly bins alternate between station subsets: use 3 h bins.
cyc_h <- tab("A_cycle_hour.csv")[!is.na(climate) & climate != ""]
cyc_h <- cyc_h[, .(sd = sqrt(sum(n * sd^2) / sum(n))), by = .(climate, hour_bin = 3 * (hour_bin %/% 3) + 1)]
cyc_m <- tab("A_cycle_month.csv")[!is.na(climate) & climate != ""]
p1 <- ggplot(cyc_h, aes(hour_bin + 0.5, sd, colour = climate)) +
  geom_line() +
  scale_x_continuous(breaks = seq(0, 24, 6)) +
  scale_colour_manual(values = pal_climate, name = NULL) +
  expand_limits(y = 0) +
  labs(x = "Local solar hour", y = "RMS of de-biased error (m)", tag = "a")
p2 <- ggplot(cyc_m, aes(month_seas, sd, colour = climate)) +
  geom_line() +
  scale_x_continuous(breaks = c(1, 4, 7, 10), labels = c("Jan", "Apr", "Jul", "Oct")) +
  scale_colour_manual(values = pal_climate, name = NULL) +
  expand_limits(y = 0) +
  labs(x = "Month (southern hemisphere shifted by 6 months)", y = NULL, tag = "b")
save_fig(p1 + p2 + plot_layout(guides = "collect"), "A_cycles", 9, 4)

# Change over time
if (file.exists(file.path(dir_tables, "A_era.csv"))) {
  era <- tab("A_era.csv")
  e <- melt(era[, .(year, `median |bias|` = abs_bias_median, `median SD` = sd_median,
    `90th percentile SD` = sd_p90)], id.vars = "year")
  p <- ggplot(e, aes(year, value, colour = variable)) +
    geom_line() + geom_point(size = 2) +
    scale_colour_manual(values = c(`median |bias|` = pal[["blue"]], `median SD` = pal[["teal"]],
      `90th percentile SD` = pal[["slate"]]), name = NULL) +
    scale_x_continuous(breaks = era$year) +
    expand_limits(y = 0) +
    labs(x = NULL, y = "Altitude error (m)")
  save_fig(p, "A_era", 6, 3.8)
}

# ==== Tier B ==================================================================================
bb <- bird_height_weights()[, .(lo = pmax(lo, 0), hi, prop)]
bird_panel <- ggplot(bb) +
  geom_rect(aes(xmin = lo, xmax = hi, ymin = 0, ymax = 100 * prop / (hi - lo) * 1000),
    fill = pal[["slate"]], colour = "white", linewidth = 0.3) +
  height_axis + flip_height +
  labs(x = NULL, y = "Bird flight\npoints (% per km)")

tabB <- tab("B_height.csv")[!is.na(hbin) & hbin != ""]
tabB[, agl_mid := hbin_mid[match(hbin, levels(cut(0, hbin_breaks, right = TRUE)))]]
tabB[, method := fifelse(method == "ERA5-Land", "ERA5-Land", "ERA5 single-levels")]
p1 <- ggplot(tabB, aes(agl_mid, bias, colour = method)) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.3) +
  geom_line() + geom_point(size = 1.3) +
  scale_colour_manual(values = pal_dataset, name = NULL) +
  height_axis + flip_height + labs(y = "Bias (m)", tag = "a")
p2 <- ggplot(tabB, aes(agl_mid, sd, colour = method)) +
  geom_line() + geom_point(size = 1.3) +
  scale_colour_manual(values = pal_dataset, name = NULL) +
  height_axis + flip_height + labs(x = NULL, y = "SD (m)", tag = "b")
save_fig(p1 + p2 + bird_panel + plot_layout(widths = c(2, 2, 1), guides = "collect"),
  "B_height", 9, 5)

bt <- tab("B_temperature_bins.csv")
te <- tab("B_temperature_explanation.csv")
p <- ggplot(bt[abs(pred) <= 200 & abs(obs) <= 200], aes(pred, obs, fill = N)) +
  geom_tile() +
  geom_abline(slope = 1, intercept = 0, colour = pal[["coral"]], linewidth = 0.6) +
  scale_fill_gradientn(colours = seq_blue, trans = "log10", name = "Sonde levels",
    labels = scales::label_comma(),
    guide = guide_colourbar(barwidth = 10, barheight = 0.5)) +
  coord_equal(xlim = c(-150, 100), ylim = c(-150, 100)) +
  labs(x = "Predicted: height x (T assumed - T observed) / T observed (m)",
    y = "Observed error vs surface level (m)",
    subtitle = sprintf("r = %.2f, %d%% of variance explained", te$r, round(100 * te$r2)))
save_fig(p, "B_temperature", 6, 6)

bc <- tab("B_height_climate_season.csv")[n_st >= 3 & !is.na(climate) & climate != ""]
p <- ggplot(bc, aes(agl_mid, bias, colour = climate, linetype = season)) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.3) +
  geom_line() +
  scale_colour_manual(values = pal_climate, name = NULL) +
  scale_linetype_manual(values = c(`summer half` = 1, `winter half` = 2), name = NULL) +
  height_axis + flip_height + labs(y = "Bias vs surface level (m)") +
  guides(colour = guide_legend(nrow = 2))
save_fig(p, "B_height_climate", 7, 5)

# ==== Formula variants (07b_formula.R) ========================================================
if (file.exists(file.path(dir_tables, "formula_height.csv"))) {
  fh <- tab("formula_height.csv")
  fbw <- tab("formula_bird_weighted.csv")
  codes <- c("current", "tv", "lapse", "tv_lapse")
  labs_f <- setNames(fbw$method[match(codes, fbw$code)], codes)
  pal_f <- setNames(pal[c("blue", "teal", "amber", "purple")], labs_f)
  fh[, method := factor(labs_f[code], labs_f)]
  p1 <- ggplot(fh, aes(agl_mid, bias, colour = method)) +
    geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.3) +
    geom_line() + geom_point(size = 1.3) +
    scale_colour_manual(values = pal_f, name = NULL) +
    height_axis + flip_height + labs(y = "Bias (m)", tag = "a")
  p2 <- ggplot(fh, aes(agl_mid, sd, colour = method)) +
    geom_line() + geom_point(size = 1.3) +
    scale_colour_manual(values = pal_f, name = NULL) +
    height_axis + flip_height + labs(x = NULL, y = "SD (m)", tag = "b")
  save_fig(p1 + p2 + bird_panel + plot_layout(widths = c(2, 2, 1), guides = "collect") &
    guides(colour = guide_legend(nrow = 2)), "B_formula", 9, 5.2)

  fc <- tab("formula_climate_season.csv")[n_st >= 3 & code %in% c("current", "tv_lapse")]
  fc[, formula := factor(labs_f[code], labs_f[c("current", "tv_lapse")])]
  p <- ggplot(fc, aes(agl_mid, bias, colour = climate, linetype = season)) +
    geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.3) +
    geom_line() +
    facet_wrap(~formula) +
    scale_colour_manual(values = pal_climate, name = NULL) +
    scale_linetype_manual(values = c(`summer half` = 1, `winter half` = 2), name = NULL) +
    height_axis + flip_height + labs(y = "Bias vs surface level (m)") +
    guides(colour = guide_legend(nrow = 2))
  save_fig(p, "B_formula_climate", 9, 5)
}
cat("Figures written to", dir_figures, "\n")

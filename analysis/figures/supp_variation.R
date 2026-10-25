# Additional file 1, S2: variation of ground errors with the station-ERA5 elevation difference,
# season, time of day and climate, and the column-temperature check of flight-height errors.
# Distributions over stations are drawn as the median (line or point), the 25-75% range (dark band
# or thick bar) and the 10-90% range (light band or thin bar).

source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages(library(patchwork))
theme_set(theme_paper(10))
update_geom_defaults("line", list(linewidth = 0.8))
tab <- function(f) fread(file.path(dir_tables, f))

col_acc <- pal_metric[["accuracy"]]
col_pre <- pal_metric[["precision"]]
lab_acc <- "Station bias (m)"
lab_pre <- "Within-station SD (m)"
zero_line <- geom_hline(yintercept = 0, colour = pal[["ink"]], linewidth = 0.5)
qribbon <- function(col) {
  list(
    geom_ribbon(aes(ymin = q10, ymax = q90), fill = col, alpha = 0.18),
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = col, alpha = 0.35),
    geom_line(aes(y = q50), colour = pal[["ink"]])
  )
}
# Bias or SD panel from a table with columns metric (bias / sd) and q10..q90
qpanel <- function(d, x, m, xlab, tag, ...) {
  col <- if (m == "bias") col_acc else col_pre
  p <- ggplot(d[metric == m], aes(.data[[x]])) + zero_line + qribbon(col) +
    labs(x = xlab, y = if (m == "bias") lab_acc else lab_pre, tag = tag) + list(...)
  if (m == "sd") p <- p + expand_limits(y = 0)
  p
}

# Elevation difference: bias and SD per station, with the GAM fit (environmental_variation.R)
gr <- tab("ground_gap_residual.csv")
gf <- tab("ground_gap_fit.csv")
gap_x <- scale_x_continuous(trans = "log1p", breaks = c(0, 10, 30, 100, 300, 1000))
gap_lab <- "|Station elevation − ERA5 orography| (m, log scale)"
p1 <- ggplot(gr, aes(adz, bias_sl)) +
  geom_point(size = 0.7, alpha = 0.35, colour = col_acc) +
  zero_line +
  geom_line(aes(adz, abs_bias), data = gf, colour = pal[["ink"]], linetype = 2) +
  geom_line(aes(adz, -abs_bias), data = gf, colour = pal[["ink"]], linetype = 2) +
  gap_x + coord_cartesian(ylim = c(-40, 40)) +
  labs(x = gap_lab, y = lab_acc, tag = "a")
p2 <- ggplot(gr, aes(adz, sd_sl)) +
  geom_point(size = 0.7, alpha = 0.35, colour = col_pre) +
  zero_line +
  geom_line(aes(adz, sd), data = gf, colour = pal[["ink"]]) +
  gap_x + coord_cartesian(ylim = c(0, 20)) +
  labs(x = gap_lab, y = lab_pre, tag = "b")
save_figure(p1 + p2, "supp_ground_gap", 7.2, 3.4)

# Season and local time
month_x <- scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1),
  expand = expansion(0.01))
hour_x <- scale_x_continuous(breaks = seq(0, 24, 3), limits = c(0, 24), expand = expansion(0))
vm <- tab("ground_var_month.csv")
vh <- tab("ground_var_hour.csv")
no_x <- theme(axis.title.x = element_blank(), axis.text.x = element_blank())
p <- (qpanel(vm, "month", "bias", NULL, "a", month_x, no_x, ggtitle("Over the year")) |
  qpanel(vh, "hour", "bias", NULL, "b", hour_x, no_x, ggtitle("Over the day"))) /
  (qpanel(vm, "month", "sd", "Month (southern hemisphere shifted by six months)", "c", month_x) |
    qpanel(vh, "hour", "sd", "Local solar hour", "d", hour_x))
save_figure(p, "supp_ground_season_hour", 7.2, 4.8)

# Climate zones, ordered by the median latitude of their stations
ref <- tab("ground_station_products.csv")
vc <- tab("ground_var_climate.csv")
lat_ord <- ref[!is.na(climate) & climate != "", median(abs(lat)), by = climate][order(V1), climate]
vc[, climate := factor(climate, rev(lat_ord))]
clim_names <- setNames(tools::toTitleCase(sub("^[A-E] ", "", names(pal_climate))), names(pal_climate))
clim_bars <- function(m, tag) {
  ggplot(vc[metric == m], aes(climate, colour = climate)) +
    zero_line +
    geom_linerange(aes(ymin = q10, ymax = q90), linewidth = 0.6) +
    geom_linerange(aes(ymin = q25, ymax = q75), linewidth = 2.4, alpha = 0.7) +
    geom_point(aes(y = q50), colour = pal[["ink"]], size = 1.6) +
    scale_colour_manual(values = pal_climate, guide = "none") +
    scale_x_discrete(labels = clim_names) +
    coord_flip() +
    labs(x = NULL, y = if (m == "bias") lab_acc else lab_pre, tag = tag)
}
save_figure(clim_bars("bias", "a") + (clim_bars("sd", "b") + expand_limits(y = 0)),
  "supp_ground_climate", 7.2, 2.9)

# Observed flight-height error against the error predicted from the mean column temperature
bt <- tab("flight_temperature_bins.csv")
p <- ggplot(bt[abs(pred) <= 200 & abs(obs) <= 200], aes(pred, obs, fill = N)) +
  geom_tile() +
  geom_abline(slope = 1, intercept = 0, colour = pal[["ink"]], linewidth = 0.5, linetype = 2) +
  scale_fill_gradientn(colours = pal_sequential, trans = "log10", name = "Estimates",
    labels = scales::label_comma(), guide = guide_colourbar(barwidth = 10, barheight = 0.5)) +
  coord_equal(xlim = c(-150, 100), ylim = c(-150, 100)) +
  labs(x = "Error predicted from mean column temperature (m)",
    y = "Observed flight-height error (m)") +
  theme(legend.title.position = "top")
save_figure(p, "supp_flight_temperature", 4.6, 5)

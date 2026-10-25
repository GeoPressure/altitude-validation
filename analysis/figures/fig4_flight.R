# Figure 4: station bias and within-station SD of flight-height errors against height, with the
# flight-time height distribution of tracked birds.
source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages(library(patchwork))
theme_set(theme_paper(10.5))
update_geom_defaults("line", list(linewidth = 0.7))
tab <- function(f) fread(file.path(dir_tables, f))

formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate",
  virtual = "ERA5, virtual temperature + GPT3")
pal_f <- setNames(pal_conversion[names(formulas)], formulas)
fform <- function(x) factor(formulas[x], formulas)

qs <- function(x, w) as.list(setNames(vapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) {
  wquant(x, w, p)
}, 1), c("q10", "q25", "q50", "q75", "q90")))

# Equally weighted station medians and IQRs at each interpolated height, from zero error at the
# surface to 5 km.
fs <- tab("flight_profile_station.csv")[agl_mid <= 5000]
fsq <- rbind(cbind(metric = "bias", fs[, qs(bias, cw), by = .(formula, agl_mid)]),
  cbind(metric = "sd", fs[is.finite(sd), qs(sd, cw), by = .(formula, agl_mid)]))
fsq <- rbind(fsq, unique(fsq[, .(metric, formula)])[, `:=`(agl_mid = 0, q10 = 0, q25 = 0, q50 = 0,
  q75 = 0, q90 = 0)])
fsq[, formula := fform(formula)]
setorder(fsq, metric, formula, agl_mid)
bq <- tab("bird_height_quantiles.csv")[flight == TRUE]
bird_lines <- geom_hline(yintercept = c(bq$p50, bq$p90) / 1000, colour = "#A5B4CB",
  linewidth = 0.6, alpha = 0.6)
flight_panel <- function(m, xlab, tag, xlim, xbreaks) {
  d <- fsq[metric == m]
  ggplot(d, aes(q50, agl_mid / 1000, colour = formula, fill = formula)) +
    bird_lines +
    geom_vline(xintercept = 0, colour = pal[["ink"]], linewidth = 0.4) +
    geom_ribbon(aes(xmin = q25, xmax = q75), alpha = 0.12, colour = NA, orientation = "y") +
    geom_path(linewidth = 0.75) +
    scale_colour_manual(values = pal_f, name = NULL) +
    scale_fill_manual(values = pal_f, guide = "none") +
    scale_y_continuous(breaks = 0:5, limits = c(0, 5), expand = expansion(mult = 0.01)) +
    scale_x_continuous(breaks = xbreaks) +
    coord_cartesian(xlim = xlim) +
    labs(y = "Height above sounding surface (km)", x = xlab, tag = tag)
}
bh <- tab("bird_height_figure_distributions.csv")[quantity == "Height above terrain"]
bq_labels <- tab("bird_height_figure_quantiles.csv")[quantity == "Height above terrain"]
bq_labels[, label := paste(percentile, formatC(value, format = "f", digits = 0, big.mark = ","), "m")]
n_tags <- tab("bird_height_sample.csv")$n_tags
bird_panel <- ggplot(bh[lo < 5000], aes(percent, (lo + 50) / 1000)) +
  geom_col(width = 0.095, fill = pal_metric[["precision"]], orientation = "y") +
  bird_lines +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = .35) +
  geom_label(data = bq_labels, aes(x = Inf, y = value / 1000, label = label), inherit.aes = FALSE,
    hjust = 1.02, vjust = -.15, size = 2.5, colour = "#4B5563", family = font,
    linewidth = 0, label.padding = grid::unit(.08, "lines"), fill = "white") +
  scale_y_continuous(breaks = 0:5, limits = c(0, 5), expand = expansion(mult = 0.01)) +
  labs(y = NULL, x = sprintf("Flight time\n(%%, %d birds)", n_tags), tag = "c")

p4 <- flight_panel("bias", "Station bias (m)", "a", c(-250, 100),
    seq(-200, 100, 100)) +
  (flight_panel("sd", "Within-station SD (m)", "b", c(0, max(fsq[metric == "sd"]$q75)),
    seq(0, 300, 50)) +
    labs(y = NULL)) +
  bird_panel + plot_layout(guides = "collect", widths = c(1.15, 1, 0.7)) &
  theme(legend.position = "bottom", legend.text = element_text(size = 9.5))
save_figure(p4, "fig4_flight", 7.2, 4.3)

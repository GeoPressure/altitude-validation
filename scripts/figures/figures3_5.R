# Figures of the paper (paper/), from the tables of conversion_comparison.R and, for the example soundings
# of Figure 1, the radiosonde and ERA5 files. Same theme and colours as the report (supplement.R).

invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))
source("R/utils.R")
source("R/palette.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) "Helvetica Neue" else "sans"
theme_set(
  theme_minimal(base_size = 10.5, base_family = font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.3),
      axis.title = element_text(colour = "#374151"),
      axis.text = element_text(colour = "#4B5563"),
      plot.title = element_text(face = "bold", size = 10.5, colour = pal[["ink"]]),
      plot.title.position = "plot",
      strip.text = element_text(face = "bold", hjust = 0, colour = pal[["ink"]]),
      legend.position = "bottom",
      legend.title = element_text(size = 9.5, colour = "#374151"),
      plot.tag = element_text(face = "bold", size = 12)
    )
)
update_geom_defaults("line", list(linewidth = 0.7))
dir_paper_fig <- "paper/figures"
dir.create(dir_paper_fig, showWarnings = FALSE)
save_fig <- function(p, name, w, h) {
  ggsave(file.path(dir_paper_fig, paste0(name, ".pdf")), p, width = w, height = h,
    device = grDevices::cairo_pdf)
  ggsave(file.path(dir_paper_fig, paste0(name, ".png")), p, width = w, height = h, dpi = 300,
    bg = "white", device = ragg::agg_png)
}
tab <- function(f) fread(file.path(dir_tables, f))

formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate",
  virtual = "ERA5, virtual temperature + GPT3")
# Conversion identities: solid lines in burnt orange, blue and teal; reference profiles are thicker.
pal_f <- setNames(pal_conversion[names(formulas)], formulas)
fform <- function(x) factor(formulas[x], formulas)

# ---- Figure 3: observation-level errors and station-level distributions -------------------------
gs <- tab("paper_ground_station.csv")[reference == "GHCNh"]
qs <- function(x, w) as.list(setNames(vapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) {
  wquant(x, w, p)
}, 1), c("q10", "q25", "q50", "q75", "q90")))
obs <- tab("paper_ground_observation_quantiles.csv")
station_q <- rbind(cbind(metric = "abs_bias", gs[, qs(abs(bias), cw), by = formula]),
  cbind(metric = "sd", gs[, qs(sd, cw), by = formula]))
ql <- rbindlist(list(obs, station_q), use.names = TRUE, fill = TRUE)
form_order <- c("Standard atmosphere", "ERA5, standard lapse rate", "ERA5, virtual temperature + GPT3")
form_legend <- c("Standard atmosphere" = "ISA", "ERA5, standard lapse rate" = "ERA5 lapse rate",
  "ERA5, virtual temperature + GPT3" = "ERA5 virtual T + GPT3")
ql[, formula := factor(formulas[formula], form_order)]
ql[, metric := factor(metric, c("observation", "abs_bias", "sd"),
  c("Hourly |error|", "Station |bias|", "Station SD"))]
ql[, row := 2 + (as.numeric(formula) - 2) * 0.36]
ql[, `:=`(label_y = row - 0.24, label = sprintf("%.1f", q50))]
# Shared interval geometry and a quiet observation-panel background.
p3 <- ggplot(ql, aes(q50, row, colour = formula)) +
  geom_rect(data = ql[metric == "Hourly |error|"][1],
    aes(xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf), inherit.aes = FALSE,
    fill = "#F1F5F9", colour = NA) +
  geom_segment(aes(x = q10, xend = q90, yend = row), linewidth = 0.55) +
  geom_segment(aes(x = q25, xend = q75, yend = row), linewidth = 3.2, lineend = "butt") +
  geom_point(shape = 21, fill = "white", size = 2.2, stroke = 0.7) +
  geom_text(aes(x = 175, label = label), hjust = 1, colour = "#374151",
    fontface = "bold", size = 2.9) +
  facet_grid(metric ~ ., switch = "y") +
  scale_colour_manual(values = pal_f, labels = form_legend, name = NULL,
    guide = guide_legend(override.aes = list(linewidth = 1.2, size = 2))) +
  scale_y_continuous(breaks = NULL, limits = c(1.35, 2.65), trans = scales::reverse_trans()) +
  scale_x_continuous(trans = scales::pseudo_log_trans(sigma = 1),
    breaks = c(0, 1, 3, 10, 30, 100), limits = c(0, 180), expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = "Error magnitude (m)", y = NULL) +
  theme(legend.position = "top", legend.text = element_text(size = 8.5),
    strip.placement = "outside", strip.background = element_blank(),
    strip.text.y.left = element_text(angle = 0, hjust = 1, face = "bold", size = 9),
    panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(linewidth = 0.2),
    panel.spacing.y = unit(0.7, "lines"), plot.margin = margin(2, 4, 2, 4))
save_fig(p3, "fig3_ground", 7.2, 3.7)

# ---- Figure 4: error of the height above the ground in flight --------------------------------
# Equally weighted station medians and IQRs in 250 m bands of observed levels.
fs <- tab("paper_flight_profile_station.csv")[agl_mid <= 4000]
fsq <- rbind(cbind(metric = "bias", fs[, qs(bias, cw), by = .(formula, agl_mid)]),
  cbind(metric = "sd", fs[is.finite(sd), qs(sd, cw), by = .(formula, agl_mid)]))
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
    scale_y_continuous(breaks = 0:4, limits = c(0, 4), expand = expansion(mult = 0.01)) +
    scale_x_continuous(breaks = xbreaks) +
    coord_cartesian(xlim = xlim) +
    labs(y = "Height above sounding surface (km)", x = xlab, tag = tag)
}
bh <- tab("bird_height_hist.csv")
n_tags <- tab("bird_height_distribution.csv")[flight == TRUE, n_tags][1]
bird_panel <- ggplot(bh[lo < 4000], aes(100 * prop, (lo + 50) / 1000)) +
  geom_col(width = 0.1, fill = pal[["slate"]], colour = "white", linewidth = 0.2,
    orientation = "y") +
  bird_lines +
  annotate("text", x = Inf, y = c(bq$p50, bq$p90) / 1000, label = c("median", "90%"),
    hjust = 1.05, vjust = -0.4, size = 2.9, colour = "#4B5563", family = font) +
  scale_y_continuous(breaks = 0:4, limits = c(0, 4), expand = expansion(mult = 0.01)) +
  labs(y = NULL, x = sprintf("Flight time\n(%%, %d birds)", n_tags), tag = "c")
p4 <- flight_panel("bias", "Station bias (m)", "a", c(-200, 150),
    seq(-200, 150, 50)) +
  (flight_panel("sd", "Within-station SD (m)", "b", c(0, 125), seq(0, 125, 25)) +
    labs(y = NULL)) +
  bird_panel + plot_layout(guides = "collect", widths = c(1.15, 1, 0.55)) &
  theme(legend.position = "bottom", legend.text = element_text(size = 9.5))
save_fig(p4, "fig4_flight", 7.2, 3.9)

# ---- Figure 5: in-flight bias by climate zone and season ---------------------------------------
fc <- tab("paper_flight_climate.csv")[agl_mid <= 4000]
fc[, formula := fform(formula)]
setorder(fc, climate, season, formula, agl_mid)
fc[, season := factor(season, c("summer half", "winter half"), c("Summer half", "Winter half"))]
p5 <- ggplot(fc, aes(bias, agl_mid / 1000, colour = formula)) +
  geom_vline(xintercept = 0, colour = pal[["ink"]], linewidth = 0.4) +
  geom_path() +
  facet_grid(season ~ climate) +
  scale_colour_manual(values = pal_f, name = NULL) +
  scale_x_continuous(breaks = c(-100, 0, 100), limits = c(-185, 195)) +
  scale_y_continuous(breaks = 0:4, limits = c(0, 4), expand = expansion(mult = 0.01)) +
  labs(y = "Height above sounding surface (km)", x = "Mean profile-level error (m)") +
  theme(panel.spacing = unit(0.8, "lines"),
    legend.text = element_text(size = 9.5), panel.border = element_rect(fill = NA,
    colour = pal[["grid"]], linewidth = 0.4))
save_fig(p5, "fig5_climate", 7.2, 4.4)

jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), source_md5 = as.list(tools::md5sum(c("R/palette.R", "scripts/figures/figures3_5.R", "scripts/figures/figure1.R", "scripts/figures/figure2.R")))), file.path(dir_tables, "paper_figures_provenance.json"), pretty = TRUE, auto_unbox = TRUE)

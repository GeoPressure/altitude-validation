# Figure 1: atmospheric conditions and their effects on pressure-derived altitude.
# Run from the repository root; called by Rscript run_all.R figures.
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))
source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages({ library(ggplot2); library(grid); library(gtable) })
# Measure text with the same font engine used for the raster export.
ragg::agg_png(tempfile(fileext = ".png"), width = 2160, height = 1602, res = 300)
previous_theme <- theme_get()
theme_set(theme_minimal(base_size = 9, base_family = font) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = pal[["grid"]], linewidth = .25),
    axis.title = element_text(size = 9.5, colour = "#374151"),
    axis.text = element_text(colour = "#4B5563"), strip.text = element_text(face = "bold", hjust = 0, size = 9),
    legend.position = "none", legend.title = element_blank(), plot.tag = element_text(face = "bold", size = 11),
    plot.margin = margin(5, 5, 5, 5)))
formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate",
  virtual = "ERA5, virtual temperature + GPT3", observed = "Observed")
colours <- c(pal_conversion, observed = "#3B6FB6")
conversion_scale <- scale_colour_manual(values = colours, breaks = names(formulas), labels = formulas)
examples <- readRDS(file.path(analysis_dir, "figure1.rds"))
W <- examples$W
Ew <- examples$Ew
P <- examples$P
E <- examples$E
date_axis <- scale_x_datetime(breaks = seq(as.POSIXct("2024-10-08", tz = "UTC"),
  as.POSIXct("2024-10-23", tz = "UTC"), by = "5 days"), date_labels = "%d %b",
  limits = as.POSIXct(c("2024-10-08", "2024-10-23"), tz = "UTC"), expand = expansion(mult = .02))
a <- ggplot(W, aes(date, pressure)) +
  geom_line(colour = colours[["observed"]], linewidth = .85) +
  date_axis + labs(x = NULL, y = "Pressure (hPa)")
b <- ggplot(Ew, aes(date, error, colour = formula)) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linetype = 2, linewidth = .35) +
  geom_line(linewidth = .7) + conversion_scale + date_axis +
  labs(x = NULL, y = "Altitude error (m)")
c <- ggplot(P, aes(temperature, height / 1000, colour = formula)) +
  geom_path(data = P[formula != "observed"], linewidth = .7) +
  geom_path(data = P[formula == "observed"], linewidth = .85) +
  geom_point(data = P[formula == "observed"], size = .7) +
  facet_wrap(~example) + conversion_scale +
  scale_y_continuous(breaks = 0:5) + scale_x_continuous(breaks = c(-40, -20, 0, 20)) +
  coord_cartesian(ylim = c(0, 5)) +
  labs(x = "Temperature (°C)", y = "Height above surface (km)") + theme(strip.text = element_blank())
d <- ggplot(E, aes(error, height / 1000, colour = formula)) +
  geom_vline(xintercept = 0, colour = pal[["slate"]], linetype = 2, linewidth = .35) +
  geom_path(linewidth = .7) + facet_wrap(~example) + conversion_scale +
  geom_point(data = E[, .SD[which.max(height)], by = .(example, formula)], size = .9) +
  scale_y_continuous(breaks = 0:5) +
  scale_x_continuous(breaks = seq(-300, 200, 100)) + coord_cartesian(xlim = c(-320, 200), ylim = c(0, 5)) +
  labs(x = "Flight-height error (m)", y = "Height above surface (km)") + theme(strip.text = element_blank())

# Align plotting areas within each column ----------------------------------
left <- lapply(list(a, b), ggplotGrob)
left[[1]]$widths <- left[[2]]$widths <- unit.pmax(left[[1]]$widths, left[[2]]$widths)
right <- lapply(list(c, d), ggplotGrob)
right[[1]]$widths <- right[[2]]$widths <- unit.pmax(right[[1]]$widths, right[[2]]$widths)

# Match the actual data-panel heights, including space taken by axis labels.
plots <- c(left, right)
above <- below <- numeric(4)
for (i in seq_along(plots)) {
  row <- min(plots[[i]]$layout[grepl("^panel", plots[[i]]$layout$name), "t"])
  above[i] <- convertHeight(sum(plots[[i]]$heights[seq_len(row - 1)]), "in", valueOnly = TRUE)
  below[i] <- convertHeight(sum(plots[[i]]$heights[(row + 1):length(plots[[i]]$heights)]), "in", valueOnly = TRUE)
}
for (i in seq_along(plots)) {
  plots[[i]] <- gtable_add_rows(plots[[i]], unit(max(above) - above[i], "in"), pos = 0)
  plots[[i]] <- gtable_add_rows(plots[[i]], unit(max(below) - below[i], "in"))
}
left <- plots[1:2]
right <- plots[3:4]

# Downloaded Lucide icons and shared headers --------------------------------
# Source SVGs and their licence are retained in manuscript/figures/icons/.
header <- function(icon, label, vertical = FALSE) {
  gp <- gpar(fontfamily = font, fontsize = 9.5, fontface = "bold", col = pal[["ink"]])
  text <- textGrob(label, gp = gp)
  width <- convertWidth(grobWidth(text), "in", valueOnly = TRUE)
  start <- unit(.5, "npc") - unit((width + .29) / 2, "in")
  grobTree(rasterGrob(png::readPNG(file.path("manuscript/figures/icons", paste0(icon, ".png")), native = TRUE),
      vp = viewport(x = start + unit(.11, "in"), width = unit(.22, "in"), height = unit(.22, "in"),
        angle = if (vertical) -90 else 0)),
    editGrob(text, x = start + unit(.29, "in"), hjust = 0),
    vp = viewport(angle = if (vertical) 90 else 0))
}
header_station <- header("radio-tower", "Weather station")
header_balloon <- header("balloon", "Balloon soundings")
header_atmosphere <- header("cloud-sun", "Atmospheric conditions", TRUE)
header_altitude <- header("move-vertical", "Effect on altitude", TRUE)
connector <- segmentsGrob(.5, .85, .5, .15,
  arrow = arrow(length = unit(1.5, "mm"), type = "closed"),
  gp = gpar(col = "#7B8795", fill = "#7B8795", lwd = .8))
legend_plot <- ggplot(CJ(formula = factor(names(formulas), names(formulas)), x = 1:2)[, y := 1],
  aes(x, y, colour = formula)) + geom_line(linewidth = .7) + conversion_scale +
  theme(legend.position = "bottom", legend.text = element_text(size = 8.5)) +
  guides(colour = guide_legend(nrow = 1, byrow = TRUE,
    override.aes = list(linewidth = c(.7, .7, .7, .85))))
legend <- ggplotGrob(legend_plot)
legend <- legend$grobs[[which(legend$layout$name == "guide-box-bottom")]]
figure <- gtable(widths = unit(c(.36, .10, 2.50, .12, 4.12), "in"),
  heights = unit(c(.34, .22, 1.95, .23, 1.95, .30), "in"))
figure <- gtable_add_grob(figure, header_station, t = 1, l = 3)
figure <- gtable_add_grob(figure, header_balloon, t = 1, l = 5)
# Shared sounding labels replace duplicate facet headings inside both rows.
figure <- gtable_add_grob(figure, grobTree(
  textGrob("Summer night", x = .33, gp = gpar(fontfamily = font, fontsize = 8.5, col = "#566476")),
  textGrob("Winter night", x = .79, gp = gpar(fontfamily = font, fontsize = 8.5, col = "#566476"))), t = 2, l = 5)
figure <- gtable_add_grob(figure, segmentsGrob(0, .01, 1, .01, gp = gpar(col = pal[["grid"]], lwd = .8)),
  t = 2, l = 1, r = 5)
figure <- gtable_add_grob(figure, segmentsGrob(.5, 0, .5, 1, gp = gpar(col = "#D1D5DB", lwd = .65)),
  t = 1, b = 5, l = 2)
figure <- gtable_add_grob(figure, segmentsGrob(.5, 0, .5, 1, gp = gpar(col = pal[["grid"]], lwd = .6)),
  t = 1, b = 5, l = 4)
figure <- gtable_add_grob(figure, header_atmosphere, t = 3, l = 1)
figure <- gtable_add_grob(figure, header_altitude, t = 5, l = 1)
figure <- gtable_add_grob(figure, left[[1]], t = 3, l = 3)
figure <- gtable_add_grob(figure, right[[1]], t = 3, l = 5)
figure <- gtable_add_grob(figure, connector, t = 4, l = 3)
figure <- gtable_add_grob(figure, connector, t = 4, l = 5)
figure <- gtable_add_grob(figure, left[[2]], t = 5, l = 3)
figure <- gtable_add_grob(figure, right[[2]], t = 5, l = 5)
figure <- gtable_add_grob(figure, legend, t = 6, l = 3, r = 5)
save_figure(figure, "fig1_column", 7.2, 4.99)
invisible(dev.off())
theme_set(previous_theme)
cli::cli_alert_success("Figure 1 saved")

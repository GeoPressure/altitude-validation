# Figure 1: atmospheric conditions and their effects on pressure-derived altitude.
# Run from the repository root; also called by scripts/19_paper_figures.R.
source("R/utils.R")
source("R/palette.R")
suppressPackageStartupMessages({ library(ggplot2); library(grid); library(gtable) })
out <- "paper/figures"
st <- load_stations()
gpt3 <- gpt3_read(1)
font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) "Helvetica Neue" else "sans"
# Measure text with the same font engine used for the raster export.
ragg::agg_png(tempfile(fileext = ".png"), width = 2160, height = 1602, res = 300)
previous_theme <- theme_get()
theme_set(theme_minimal(base_size = 9, base_family = font) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = pal[["grid"]], linewidth = .25),
    axis.title = element_text(size = 9.5, colour = "#374151"),
    axis.text = element_text(colour = "#4B5563"), strip.text = element_text(face = "bold", hjust = 0, size = 9),
    legend.position = "none", legend.title = element_blank(), plot.tag = element_text(face = "bold", size = 11),
    plot.margin = margin(5, 5, 5, 5)))
formulas <- c(isa = "Standard atmosphere", standard = "ERA5 · standard lapse",
  virtual = "ERA5 · virtual + GPT3", observed = "Observed")
colours <- c(pal_conversion, observed = "#3B6FB6")
conversion_scale <- scale_colour_manual(values = colours, breaks = names(formulas), labels = formulas)
gs <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh"]
candidates <- dcast(gs[formula %in% c("isa", "standard")], id ~ formula, value.var = "sd")
candidates <- merge(candidates, st[network == "ghcnh" & koppen_main == "C" & sdor < 20,
  .(id, name, elev)], by = "id")
candidates[, distance := ((isa - median(isa)) / IQR(isa))^2 +
  ((standard - median(standard)) / IQR(standard))^2]
site <- candidates[order(distance, id)][1]
W <- as.data.table(read_parquet(file.path(analysis_dir, "errors", paste0("ghcnh_", site$id, ".parquet"))))
setorder(W, date)
W[, block := as.integer(difftime(date, min(date), units = "days")) %/% 14]
blocks <- W[, .(n = .N, span = as.numeric(difftime(max(date), min(date), units = "days")),
  pressure_range = diff(range(pressure))), by = block][span > 13 & n >= .9 * max(n)]
chosen <- blocks[order(abs(pressure_range - median(pressure_range)), block)][1]
W <- W[block == chosen$block]
fwrite(data.table(id = site$id, name = site$name, elevation = site$elev,
  start = min(W$date), end = max(W$date), n = nrow(W)),
  file.path(dir_tables, "paper_fig1_weather.csv"))
Ew <- melt(W, id.vars = "date", measure.vars = paste0("err_", names(pal_conversion)),
  variable.name = "formula", value.name = "error")
Ew[, formula := sub("err_", "", formula)]
picks <- fread(file.path(dir_tables, "paper_fig1_soundings.csv"))
profiles <- list()
profile_errors <- list()
for (i in seq_len(nrow(picks))) {
  k <- picks[i]
  d <- as.data.table(read_parquet(file.path(analysis_dir, "errors", paste0("igra_", k$id, ".parquet"))))
  d <- d[sounding == k$sounding][order(agl)]
  k0 <- d[which.min(abs(agl - k$agl))]
  s <- st[network == "igra" & id == k$id]
  L <- gpt3_lapse(gpt3, s$lon, s$lat, as.POSIXlt(k0$level_time, tz = "UTC")$yday + 1)
  heights <- seq(0, 3000, 25)
  z <- heights + k0$gph_s
  profiles[[i]] <- rbind(
    d[temp > -8000 & agl <= 3000, .(height = agl, temperature = temp / 10, formula = "Observed temperature")],
    data.table(height = heights, temperature = 15 - .0065 * z, formula = "isa"),
    data.table(height = heights, temperature = k0$t2m_sl - 273.15 - .0065 * (z - k0$z_sl), formula = "standard"),
    data.table(height = heights, temperature = virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl) -
      273.15 + L * (z - k0$z_sl), formula = "virtual"))[, example := k$class]
  d[, `:=`(illustration_isa = altitude_lapse(press, 101325, 288.15, 0) -
      altitude_lapse(press_s, 101325, 288.15, 0) - agl,
    illustration_standard = altitude_lapse(press, k0$sp_sl, k0$t2m_sl, k0$z_sl) -
      altitude_lapse(press_s, k0$sp_sl, k0$t2m_sl, k0$z_sl) - agl,
    illustration_virtual = altitude_lapse(press, k0$sp_sl,
      virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl), k0$z_sl, L) -
      altitude_lapse(press_s, k0$sp_sl,
        virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl), k0$z_sl, L) - agl)]
  profile_errors[[i]] <- melt(d[agl <= 3000, .(height = agl, isa = illustration_isa,
    standard = illustration_standard, virtual = illustration_virtual)], id.vars = "height",
    variable.name = "formula", value.name = "error")[, example := k$class]
}
P <- rbindlist(profiles)
E <- rbindlist(profile_errors)
P[formula == "Observed temperature", formula := "observed"]
for (d in list(P, E)) d[, example := factor(example,
  c("Temperate summer day", "Continental winter night"), c("Summer day", "Winter night"))]
date_axis <- scale_x_datetime(date_breaks = "5 days", date_labels = "%d %b")
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
  facet_wrap(~example) + conversion_scale +
  scale_y_continuous(breaks = 0:3) + scale_x_continuous(breaks = c(-20, 0, 20)) +
  labs(x = "Temperature (°C)", y = "Height above surface (km)") + theme(strip.text = element_blank())
d <- ggplot(E, aes(error, height / 1000, colour = formula)) +
  geom_vline(xintercept = 0, colour = pal[["slate"]], linetype = 2, linewidth = .35) +
  geom_path(linewidth = .7) + facet_wrap(~example) + conversion_scale +
  scale_y_continuous(breaks = 0:3) + scale_x_continuous(breaks = c(-100, 0, 100)) +
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
# Source SVGs and their licence are retained in paper/figures/icons/.
header <- function(icon, label, vertical = FALSE) {
  gp <- gpar(fontfamily = font, fontsize = 9.5, fontface = "bold", col = pal[["ink"]])
  text <- textGrob(label, gp = gp)
  width <- convertWidth(grobWidth(text), "in", valueOnly = TRUE)
  start <- unit(.5, "npc") - unit((width + .29) / 2, "in")
  grobTree(rasterGrob(png::readPNG(file.path("paper/figures/icons", paste0(icon, ".png")), native = TRUE),
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
  textGrob("Summer day", x = .33, gp = gpar(fontfamily = font, fontsize = 8.5, col = "#566476")),
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
ggsave(file.path(out, "fig1_column.png"), figure, width = 7.2, height = 4.99, dpi = 300, bg = "white")
ggsave(file.path(out, "fig1_column.pdf"), figure, width = 7.2, height = 4.99, device = cairo_pdf)
invisible(dev.off())
theme_set(previous_theme)
cli::cli_alert_success("Figure 1 saved")

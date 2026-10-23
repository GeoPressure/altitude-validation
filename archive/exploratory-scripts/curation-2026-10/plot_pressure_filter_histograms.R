# Compare station-level error distributions before and after pattern screening.
source("R/utils.R")
library(ggplot2)
library(patchwork)
out <- "output/drafts/pattern-application"
d <- rbindlist(list(Before = fread(file.path(out, "previous_station_errors.csv")),
  After = fread(file.path(dir_tables, "paper_ground_station.csv"))), idcol = "selection")[reference == "GHCNh"]
methods <- c(isa = "Standard atmosphere", standard = "ERA5 · standard lapse", virtual = "ERA5 · virtual + GPT3")
theme_set(theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "bottom"))
panels <- list()
for (metric in c("bias", "sd")) for (f in names(methods)) {
  width <- if (metric == "bias") 5 else 2
  h <- d[formula == f, .(weight = sum(cw)),
    by = .(selection, bin = pmin(floor(if (metric == "bias") abs(bias) / width else sd / width) * width, 150))]
  h[, percent := 100 * weight / sum(weight), by = selection]
  h <- merge(CJ(selection = c("Before", "After"), bin = seq(0, 150, width)), h, by = c("selection", "bin"), all.x = TRUE)
  h[is.na(percent), percent := 0]
  h <- rbind(h, h[bin == 150][, `:=`(bin = 150 + width, percent = 0)])
  h[, selection := factor(selection, c("Before", "After"))]
  panels[[length(panels) + 1L]] <- ggplot(h, aes(bin, percent, colour = selection, linetype = selection)) +
    geom_step(linewidth = .7, direction = "hv") +
    scale_colour_manual(values = c(Before = "#737373", After = "#2166AC"), name = NULL) +
    scale_linetype_manual(values = c(Before = "dashed", After = "solid"), name = NULL) +
    scale_x_continuous(breaks = c(0, 25, 50, 100, 150), labels = c("0", "25", "50", "100", "≥150"), limits = c(0, 155)) +
    scale_y_continuous(trans = scales::pseudo_log_trans(sigma = .05, base = 10), breaks = c(0, .1, 1, 10, 50)) +
    labs(title = methods[[f]], x = if (metric == "bias") "Absolute station bias (m)" else "Within-station error SD (m)",
      y = if (f == "isa") "Stations (%)" else NULL)
}
p <- wrap_plots(panels, ncol = 3, guides = "collect") +
  plot_annotation(title = "Station error distributions before and after pressure-pattern screening",
    subtitle = "2,179 stations; 19 selected years change. ERA5 is used only for evaluation.",
    caption = "Each station has equal weight. Bins: 5 m for bias, 2 m for SD; the final bin includes all values ≥150 m.\nThe frequency axis is compressed to make rare large errors visible. Overlapping curves indicate little change.")
ggsave(file.path(out, "filter_histograms.png"), p, width = 13, height = 8, dpi = 180, bg = "white")
ggsave(file.path(out, "filter_histograms.pdf"), p, width = 13, height = 8, device = cairo_pdf)

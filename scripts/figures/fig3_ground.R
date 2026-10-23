# Figure 3: hourly errors, persistent offsets and temporal scatter.
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))
source("R/utils.R")
source("R/figures.R")
library(ggplot2)
library(patchwork)
gs <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh"]
hist <- fread(file.path(dir_tables, "paper_ground_observation_hist.csv"))
med <- fread(file.path(dir_tables, "paper_ground_tails.csv"))[, .(formula, q50 = medae, p95_abs)]

# Shared linear scales show the size of the correction directly.
methods <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate", virtual = "ERA5, virtual temperature + GPT3")
previous_theme <- theme_set(theme_minimal(base_size = 9, base_family = font) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = pal[["grid"]], linewidth = .22),
    axis.text = element_text(colour = "#4B5563", size = 8),
    axis.title = element_text(colour = "#374151", size = 9),
    plot.title = element_text(face = "bold", size = 9, colour = pal[["ink"]]),
    plot.margin = margin(2, 4, 1, 2),
    legend.position = "none", legend.text = element_text(size = 8.5),
    legend.key.height = unit(8, "pt"), legend.key.width = unit(14, "pt"),
    legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(0, "pt")))
panels <- list()
for (i in seq_along(methods)) {
  f <- names(methods)[i]
  d <- gs[formula == f]
  counts <- rbind(
    d[, .(percent = 100 * sum(cw) / sum(d$cw)), by = .(bin = pmin(floor(abs(bias) / 5) * 5, 80))][, metric := "bias"],
    d[, .(percent = 100 * sum(cw) / sum(d$cw)), by = .(bin = pmin(floor(sd / 2) * 2, 100))][, metric := "sd"])
  for (m in c("error", "bias", "sd")) {
    v <- copy(if (m == "error") hist[formula == f] else counts[metric == m])
    if (m == "error") v <- v[, .(percent = sum(percent)), by = .(bin = pmin(bin, 200))]
    width <- if (m == "sd") 2 else 5
    v[, `:=`(upper = bin + width, formula = factor(f, names(methods)))]
    value <- switch(m, error = med[formula == f]$q50, bias = wquant(abs(d$bias), d$cw, .5), sd = wquant(d$sd, d$cw, .5))
    labels <- data.table(value, x = if (m == "error") 40 else 75, label = sprintf("Median %.1f m", value))
    if (m == "error") labels <- rbind(labels,
      data.table(value = med[formula == f]$p95_abs, x = 75, label = sprintf("P95 %.1f m", med[formula == f]$p95_abs)))
    p <- ggplot(v, aes(fill = formula)) +
      geom_rect(aes(xmin = 0, xmax = percent, ymin = bin, ymax = upper),
        colour = "white", linewidth = .08, show.legend = TRUE) +
      geom_hline(data = labels, aes(yintercept = value), linewidth = .3, colour = "#697586") +
      geom_label(data = labels, aes(x = x, y = value, label = label), inherit.aes = FALSE,
        hjust = 1.02, vjust = -.12, family = font, size = 2.8, colour = "#374151",
        linewidth = 0, label.padding = unit(.05, "lines"), fill = "white") +
      scale_fill_manual(values = pal_conversion, limits = names(methods), breaks = names(methods), labels = methods, drop = FALSE, name = NULL) +
      scale_y_continuous(limits = c(0, switch(m, error = 205, bias = 85, sd = 102)),
        breaks = switch(m, error = c(0, 50, 100, 150, 202.5), bias = c(0, 20, 40, 60, 82.5), sd = c(0, 25, 50, 75, 101)),
        labels = switch(m, error = c("0", "50", "100", "150", "≥200"), bias = c("0", "20", "40", "60", "≥80"), sd = c("0", "25", "50", "75", "≥100")),
        expand = expansion(mult = c(0, .04))) +
      scale_x_continuous(limits = c(0, 75), breaks = if (i == 3) c(0, 25, 50, 75) else c(0, 25, 50),
        expand = expansion(mult = c(0, .01))) +
      labs(title = if (m == "error") c("Standard\natmosphere", "ERA5\nstandard lapse rate", "ERA5\nvirtual + GPT3")[i] else NULL,
        y = if (i == 1) switch(m, error = "Hourly absolute\nerror (m)", bias = "Absolute station\nbias (m)", sd = "Within-station\nSD (m)") else NULL,
        x = if (i == 2 && m != "bias") if (m == "error") "Observations (%)" else "Stations (%)" else NULL)
    p <- p + theme(plot.title = element_text(hjust = .5, colour = pal_conversion[[f]], margin = margin(b = 7)))
    if (i > 1) p <- p + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
    stopifnot(abs(sum(v$percent) - 100) < 1e-7)
    built <- ggplot_build(p)$data[[1]]
    stopifnot(!anyNA(built$xmax), !anyNA(built$ymin), !anyNA(built$ymax), abs(sum(built$xmax) - 100) < 1e-7,
      max(abs(built$ymax - v$upper)) < 1e-10)
    panels[[length(panels) + 1L]] <- p
  }
}
p <- wrap_plots(panels, ncol = 3, byrow = FALSE)
save_figure(p, "fig3_ground", 7, 4.7)
theme_set(previous_theme)

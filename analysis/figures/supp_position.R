# Additional file 1, S5: errors against the displacement of the atmospheric query location.
library(readr)
library(dplyr)
library(ggplot2)
library(patchwork)
source("R/figures.R")

summary <- read_csv("results/position-sensitivity/results.csv", show_col_types = FALSE)
station <- read_csv("results/position-sensitivity/station-results.csv", show_col_types = FALSE) |> mutate(sd = sqrt(variance))
short <- c(isa = "Standard atm.", standard = "ERA5 standard", virtual = "ERA5 virtual")
theme_set(theme_minimal(base_size = 10, base_family = font) + theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.25), axis.text = element_text(colour = "#586575"), axis.title = element_text(colour = pal[["ink"]]), plot.tag = element_text(face = "bold", size = 11), plot.margin = margin(7, 8, 5, 5), plot.title = element_text(face = "bold", size = 10, colour = pal[["ink"]])))

# Repeat the same comparison for signed error and scatter -----------------
distance_panel <- function(target, statistic, ylab, tag) {
  d <- summary |> filter(metric == target)
  s <- station |> filter(metric == target)
  labels <- d |> filter(distance == 200) |> arrange(.data[[statistic]])
  transform <- scales::pseudo_log_trans(sigma = 5)
  labels$label_y <- transform$transform(labels[[statistic]])
  for (i in 2:3) labels$label_y[i] <- max(labels$label_y[i], labels$label_y[i - 1] + 0.75)
  labels$label_y <- transform$inverse(labels$label_y)
  labels <- labels |> mutate(label = paste0(short[formula], "\n", sprintf("%.1f m", .data[[statistic]])))
  ggplot(d, aes(distance, .data[[statistic]], colour = formula, linetype = formula)) +
    geom_hline(yintercept = 0, colour = "#586575", linewidth = 0.3) +
    geom_vline(xintercept = 50, colour = "#8793A1", linetype = "dotted", linewidth = 0.3) +
    geom_line(aes(group = interaction(id, formula)), data = s, linewidth = 0.3, alpha = 0.14) +
    geom_line(linewidth = 0.7) +
    geom_point(aes(shape = formula), size = 1.4, stroke = 0.6) +
    geom_segment(aes(x = 200, xend = 207, yend = label_y), data = labels, linewidth = 0.3, linetype = "solid") +
    geom_text(aes(x = 210, y = label_y, label = label), data = labels, hjust = 0, size = 2.7, lineheight = 1, family = font) +
    scale_colour_manual(values = pal_conversion, guide = "none") +
    scale_linetype_manual(values = lt_conversion, guide = "none") +
    scale_shape_manual(values = pch_conversion, guide = "none") +
    scale_x_continuous(breaks = c(0, 50, 100, 150, 200), limits = c(0, 305), expand = expansion(mult = c(0.02, 0))) +
    scale_y_continuous(trans = scales::pseudo_log_trans(sigma = 5), breaks = c(0, 10, 30, 100, 300, 600), expand = expansion(mult = c(0.06, 0.13))) +
    labs(x = "Displacement from launch station (km)", y = ylab, tag = tag)
}

absolute_mae <- distance_panel("Absolute altitude: level", "medae", "Median absolute error (m)", "a") +
  ggtitle("Absolute altitude near 2 km")
relative_mae <- distance_panel("Surface-referenced height", "medae", "Median absolute error (m)", "b") +
  ggtitle("Flight height near 2 km")
absolute_sd <- distance_panel("Absolute altitude: level", "sd", "SD (m)", "c")
relative_sd <- distance_panel("Surface-referenced height", "sd", "SD (m)", "d")
figure <- (absolute_mae + relative_mae) / (absolute_sd + relative_sd)
save_figure(figure, "supp_position", 7.2, 5.3)

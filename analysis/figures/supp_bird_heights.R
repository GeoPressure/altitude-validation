# Additional file 1, S4: bird flight altitude and its conversion to height above terrain.
source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})
theme_set(
  theme_minimal(base_size = 10, base_family = font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.3),
      axis.text = element_text(colour = "#4B5563"),
      axis.title = element_text(colour = "#374151"),
      plot.tag = element_text(face = "bold", size = 11),
      legend.position = "bottom",
      legend.title = element_blank()
    )
)
colours <- c(
  `Sea-level altitude` = pal_metric[["accuracy"]],
  `Terrain median` = pal[["ink"]],
  `Height above terrain` = pal_metric[["precision"]]
)

# Both distributions use all flight time and uncapped 100 m bins ------------
hist <- fread(file.path(dir_tables, "bird_height_figure_distributions.csv"))
quantiles <- fread(file.path(dir_tables, "bird_height_figure_quantiles.csv"))
quantiles[,
  label := paste(
    percentile,
    formatC(value, format = "f", digits = 0, big.mark = ","),
    "m"
  )
]
q_asl <- quantiles[quantity == "Sea-level altitude"]
q_agl <- quantiles[quantity == "Height above terrain"]
p_asl <- ggplot(
  hist[quantity == "Sea-level altitude"],
  aes(percent, (lo + 50) / 1000)
) +
  geom_col(
    width = 0.095,
    orientation = "y",
    fill = colours[["Sea-level altitude"]]
  ) +
  geom_hline(
    data = q_asl,
    aes(yintercept = value / 1000),
    colour = "#64748B",
    linewidth = 0.4
  ) +
  geom_label(
    data = q_asl,
    aes(x = Inf, y = value / 1000, label = label),
    inherit.aes = FALSE,
    hjust = 1.02,
    vjust = -0.15,
    size = 2.7,
    family = font,
    linewidth = 0,
    label.padding = grid::unit(0.1, "lines"),
    fill = "white",
    colour = pal[["ink"]]
  ) +
  scale_y_continuous(breaks = scales::breaks_pretty(5)) +
  coord_cartesian(
    ylim = c(
      min(hist[quantity == "Sea-level altitude", lo]) / 1000,
      max(hist[quantity == "Sea-level altitude", lo] + 100) / 1000
    )
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.07))) +
  labs(x = "Flight time (%)", y = "Altitude above\nsea level (km)", tag = "b")
p_agl <- ggplot(
  hist[quantity == "Height above terrain"],
  aes(percent, (lo + 50) / 1000)
) +
  geom_col(
    width = 0.095,
    orientation = "y",
    fill = colours[["Height above terrain"]]
  ) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.35) +
  geom_hline(
    data = q_agl,
    aes(yintercept = value / 1000),
    colour = "#64748B",
    linewidth = 0.4
  ) +
  geom_label(
    data = q_agl,
    aes(x = Inf, y = value / 1000, label = label),
    inherit.aes = FALSE,
    hjust = 1.02,
    vjust = -0.15,
    size = 2.7,
    family = font,
    linewidth = 0,
    label.padding = grid::unit(0.1, "lines"),
    fill = "white",
    colour = pal[["ink"]]
  ) +
  scale_y_continuous(breaks = scales::breaks_pretty(5)) +
  coord_cartesian(
    ylim = c(0, max(hist[quantity == "Height above terrain", lo] + 100) / 1000)
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.07))) +
  labs(x = "Flight time (%)", y = "Height above\nterrain (km)", tag = "d")

# One illustrative flight with substantial variation in terrain elevation ---
e <- fread(file.path(dir_tables, "bird_height_figure_example.csv"))
setnames(e, "height", "agl")
example_source <- fread(file.path(
  dir_tables,
  "bird_height_figure_example_source.csv"
))
long <- melt(
  e,
  id.vars = "hour",
  measure.vars = c("altitude", "ground", "agl"),
  variable.name = "quantity",
  value.name = "height"
)
long[,
  quantity := factor(quantity, c("altitude", "ground", "agl"), names(colours))
]
example_top <- ceiling(max(e$altitude, e$ground_high) / 1000)
annotation <- e[which.min(abs(hour - 0.5 * example_source$duration_hours))]
p_example <- ggplot() +
  geom_area(data = e, aes(hour, ground / 1000), fill = pal[["light"]]) +
  geom_ribbon(
    data = e,
    aes(hour, ymin = ground_low / 1000, ymax = ground_high / 1000),
    fill = pal[["slate"]],
    alpha = 0.25
  ) +
  geom_line(
    data = long[quantity != "Height above terrain"],
    aes(hour, height / 1000, colour = quantity),
    linewidth = 0.65,
    show.legend = TRUE
  ) +
  annotate(
    "segment",
    x = annotation$hour,
    xend = annotation$hour,
    y = annotation$ground / 1000,
    yend = annotation$altitude / 1000,
    colour = colours[["Height above terrain"]],
    linewidth = 0.5,
    arrow = grid::arrow(ends = "both", length = grid::unit(1.6, "mm"))
  ) +
  annotate(
    "text",
    x = annotation$hour + 0.025 * example_source$duration_hours,
    y = (annotation$ground + annotation$altitude) / 2000,
    label = "Height\nabove terrain",
    hjust = 0,
    size = 2.8,
    family = font,
    colour = colours[["Height above terrain"]]
  ) +
  scale_colour_manual(values = colours, drop = FALSE) +
  scale_x_continuous(
    limits = c(0, example_source$duration_hours),
    breaks = seq(0, example_source$duration_hours, 2),
    expand = expansion(mult = 0.01)
  ) +
  scale_y_continuous(breaks = seq(0, example_top)) +
  coord_cartesian(ylim = c(0, example_top)) +
  labs(
    x = "Time since departure (h)",
    y = "Altitude above\nsea level (km)",
    tag = "a"
  )
p_height <- ggplot(
  long[quantity == "Height above terrain"],
  aes(hour, height / 1000, colour = quantity)
) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linewidth = 0.35) +
  geom_line(linewidth = 0.65, show.legend = FALSE) +
  scale_colour_manual(values = colours, drop = FALSE) +
  scale_x_continuous(
    limits = c(0, example_source$duration_hours),
    breaks = seq(0, example_source$duration_hours, 2),
    expand = expansion(mult = 0.01)
  ) +
  scale_y_continuous(breaks = seq(0, ceiling(max(e$agl) / 500) * 0.5, 0.5)) +
  coord_cartesian(ylim = c(0, ceiling(max(e$agl) / 500) * 0.5)) +
  labs(
    x = "Time since departure (h)",
    y = "Height above\nterrain (km)",
    tag = "c"
  ) +
  guides(colour = "none")
p <- ((p_example | p_asl) / (p_height | p_agl)) +
  plot_layout(guides = "collect", widths = c(1.25, 1), heights = c(1, 1)) &
  theme(legend.position = "bottom", legend.direction = "horizontal")
save_figure(p, "supp_bird_heights", 7.2, 4.6)

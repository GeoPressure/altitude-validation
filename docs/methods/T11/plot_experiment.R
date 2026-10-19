library(readr)
library(dplyr)
library(ggplot2)
source("R/palette.R")

results <- read_csv("docs/methods/T11/results.csv", show_col_types = FALSE) |>
  filter(metric %in% c("Absolute altitude: level", "Surface-referenced height")) |>
  mutate(metric = recode(metric, `Absolute altitude: level` = "Absolute altitude", `Surface-referenced height` = "Surface-referenced height"), formula = factor(formula, levels = c("standard", "virtual", "isa"), labels = c("ERA5 standard", "Virtual + GPT3", "Standard atmosphere")))

figure <- ggplot(results, aes(distance, mae_percent_change, colour = formula, fill = formula, linetype = formula, shape = formula)) +
  geom_hline(yintercept = 0, colour = "#586575", linewidth = 0.35) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.75) +
  geom_point(size = 1.8, stroke = 0.6) +
  facet_wrap(~metric) +
  scale_colour_manual(values = pal_conversion) +
  scale_fill_manual(values = pal_conversion) +
  scale_linetype_manual(values = lt_conversion) +
  scale_shape_manual(values = pch_conversion) +
  scale_x_continuous(breaks = c(0, 50, 100, 150, 200), limits = c(0, 200), expand = expansion(mult = c(0.02, 0.02))) +
  labs(x = "Displacement from exact-location query (km)", y = "Change in pooled MAE from exact location (%)", colour = NULL, fill = NULL, linetype = NULL, shape = NULL) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom", strip.text = element_text(face = "bold"), panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.25))

ggsave("docs/methods/T11/figure.pdf", figure, width = 7.2, height = 4.3, device = cairo_pdf)
ggsave("docs/methods/T11/figure.png", figure, width = 7.2, height = 4.3, dpi = 300, bg = "white", device = ragg::agg_png)

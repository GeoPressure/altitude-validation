# Load design specification -----------------------------------------------
library(readr)
library(dplyr)
library(ggplot2)
library(patchwork)
library(systemfonts)

palette <- read_csv("docs/manuscript/T08/palette.csv", show_col_types = FALSE)
font <- if ("Helvetica Neue" %in% system_fonts()$family) "Helvetica Neue" else "sans"
theme_set(theme_void(base_family = font, base_size = 11) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.margin = margin(10, 12, 10, 12)))

# Conversion strokes and direct labels -----------------------------------
conversion <- palette |> filter(group == "conversion") |> mutate(y = 4 - row_number())
p1 <- ggplot(conversion, aes(colour = key)) +
  geom_segment(aes(x = 0, xend = 1.5, y = y, yend = y, linetype = key), linewidth = 0.8) +
  geom_point(aes(x = 0.75, y = y, shape = key), size = 2.3, stroke = 0.8) +
  geom_text(aes(x = 1.8, y = y + 0.09, label = label), hjust = 0, size = 3.5, family = font) +
  geom_text(aes(x = 1.8, y = y - 0.20, label = paste(colour, linetype, sep = "  ·  ")), hjust = 0, size = 2.8, colour = "#586575", family = font) +
  scale_colour_manual(values = setNames(conversion$colour, conversion$key)) +
  scale_linetype_manual(values = setNames(conversion$linetype, conversion$key)) +
  scale_shape_manual(values = setNames(conversion$shape, conversion$key)) +
  coord_cartesian(xlim = c(0, 7.5), ylim = c(0.55, 3.4)) +
  theme(legend.position = "none")

# Reference markers -------------------------------------------------------
reference <- palette |> filter(group == "reference") |> mutate(y = 6 - row_number())
p2 <- ggplot(reference, aes(colour = key)) +
  geom_point(aes(x = 0.3, y = y, shape = key), size = 2.8, stroke = 0.8) +
  geom_text(aes(x = 0.9, y = y, label = label), hjust = 0, size = 3.4, family = font) +
  geom_text(aes(x = 5.2, y = y, label = colour), hjust = 0, size = 3, family = font, colour = "#586575") +
  scale_colour_manual(values = setNames(reference$colour, reference$key)) +
  scale_shape_manual(values = setNames(reference$shape, reference$key)) +
  coord_cartesian(xlim = c(0, 7.5), ylim = c(0.5, 5.5)) +
  theme(legend.position = "none")

preview <- p1 / p2 + plot_layout(heights = c(3, 4))
ggsave("docs/manuscript/T08/palette-preview.png", preview, width = 7.2, height = 5.6, dpi = 200, bg = "white", device = ragg::agg_png)
ggsave("docs/manuscript/T08/palette-preview.pdf", preview, width = 7.2, height = 5.6, device = cairo_pdf)

# Shared figure settings: font, theme and output of the manuscript and supplementary figures.
source("R/palette.R")
suppressPackageStartupMessages(library(ggplot2))

font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) "Helvetica Neue" else "sans"

#' Minimal theme shared by the data figures; `base_size` follows each figure's width.
theme_paper <- function(base_size = 10.5) {
  theme_minimal(base_size = base_size, base_family = font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.3),
      axis.title = element_text(colour = "#374151"),
      axis.text = element_text(colour = "#4B5563"),
      plot.title = element_text(face = "bold", size = base_size, colour = pal[["ink"]]),
      plot.title.position = "plot",
      strip.text = element_text(face = "bold", hjust = 0, colour = pal[["ink"]]),
      legend.position = "bottom",
      legend.title = element_text(size = base_size - 1, colour = "#374151"),
      plot.tag = element_text(face = "bold", size = base_size + 1.5)
    )
}

#' Save a figure in paper/figures as vector PDF (typesetting) and 300 dpi PNG (HTML).
save_figure <- function(p, name, width, height) {
  dir.create("paper/figures", showWarnings = FALSE)
  ggsave(file.path("paper/figures", paste0(name, ".pdf")), p, width = width, height = height,
    device = grDevices::cairo_pdf)
  ggsave(file.path("paper/figures", paste0(name, ".png")), p, width = width, height = height,
    dpi = 300, bg = "white", device = ragg::agg_png)
}

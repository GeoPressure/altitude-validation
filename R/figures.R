# Shared figure settings: colours, font, theme and output of the manuscript and supplementary figures.
# Each colour has one meaning throughout:
#   metric      accuracy (bias) and precision (SD), when a figure shows one series per panel
#   reference   the two reference datasets
#   product     the two ERA5 products; ERA5 single-levels is drawn in ink
#   climate     main Koppen-Geiger zones
#   conversion  the three pressure-to-altitude conversions
pal <- c(
  ink = "#1F2937",
  grid = "#E5E7EB",
  slate = "#94A3B8",
  light = "#E8ECF2"
)
pal_metric <- c(accuracy = "#3B6FB6", precision = "#2A9D8F")
pal_reference <- c(GHCNh = "#3B6FB6", IGRA2 = "#E9A23B")
pal_product <- c(`ERA5 single-levels` = "#1F2937", `ERA5-Land` = "#E4572E")
pal_climate <- c(
  `A tropical` = "#4DAF4A",
  `B arid` = "#E6AB02",
  `C temperate` = "#D95F02",
  `D continental` = "#7570B3",
  `E polar` = "#8D99AE"
)
# Sequential scale for maps
pal_sequential <- c("#F1F5FB", "#B9CDEB", "#6E97D0", "#3B6FB6", "#1E2F57")

pal_conversion <- c(isa = "#C46532", standard = "#315B91", virtual = "#007F86")
lt_conversion <- c(isa = "solid", standard = "solid", virtual = "solid")
pch_conversion <- c(isa = 1, standard = 15, virtual = 16)

suppressPackageStartupMessages(library(ggplot2))

font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) {
  "Helvetica Neue"
} else {
  "sans"
}

#' Minimal theme shared by the data figures; `base_size` follows each figure's width.
theme_paper <- function(base_size = 10.5) {
  theme_minimal(base_size = base_size, base_family = font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.3),
      axis.title = element_text(colour = "#374151"),
      axis.text = element_text(colour = "#4B5563"),
      plot.title = element_text(
        face = "bold",
        size = base_size,
        colour = pal[["ink"]]
      ),
      plot.title.position = "plot",
      strip.text = element_text(
        face = "bold",
        hjust = 0,
        colour = pal[["ink"]]
      ),
      legend.position = "bottom",
      legend.title = element_text(size = base_size - 1, colour = "#374151"),
      plot.tag = element_text(face = "bold", size = base_size + 1.5)
    )
}

#' Save a figure in manuscript/figures as vector PDF.
save_figure <- function(p, name, width, height) {
  dir.create("manuscript/figures", showWarnings = FALSE)
  ggsave(
    file.path("manuscript/figures", paste0(name, ".pdf")),
    p,
    width = width,
    height = height,
    device = grDevices::cairo_pdf
  )
}

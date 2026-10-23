# Visual check of the trial backwards search; no manuscript figures are changed.
source("R/utils.R")
source("R/palette.R")
library(ggplot2)
library(patchwork)
library(lubridate)
out <- "output/drafts/atmospheric-figures"
d <- as.data.table(read_parquet(file.path(out, "pressure_window_trial_examples.parquet")))
q <- fread(file.path(out, "pressure_window_trial.csv"))
ids <- c("BRM00086850", "BRM00086781", "CIN00320041", "MXM00076737")
places <- c("Barbacena, Brazil", "Diamantina, Brazil", "Viña del Mar, Chile", "Orizaba, Mexico")
colours <- c(`220` = pal_conversion[["standard"]], `223` = pal_conversion[["virtual"]], `412` = pal_conversion[["isa"]])
theme_set(theme_minimal(base_size = 10, base_family = "Helvetica Neue") +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = pal[["grid"]], linewidth = .25),
    plot.title = element_text(size = 10, face = "bold"), plot.subtitle = element_text(size = 9),
    legend.position = "bottom", plot.margin = margin(5, 10, 5, 5)))
panels <- list()
for (i in seq_along(ids)) {
  limits <- range(d[id == ids[i]]$pressure)
  limits <- limits + c(-1, 1) * diff(limits) * .04
  for (which_period in c("before", "after")) {
    z <- d[id == ids[i] & period == which_period][order(date)]
    z[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 6), by = source_code]
    row <- q[id == ids[i]]
    endpoint <- as.Date(if (which_period == "before") row$end_before else row$end_after)
    panels[[length(panels) + 1L]] <- ggplot(z, aes(date, pressure)) +
      geom_line(colour = "#9CA3AF", linewidth = .2, alpha = .5) +
      geom_line(aes(colour = source_code, group = interaction(source_code, segment)), linewidth = .45, show.legend = TRUE) +
      scale_colour_manual(values = colours, limits = names(colours), drop = FALSE, name = "Archive source code") +
      scale_y_continuous(limits = limits) +
      scale_x_datetime(date_breaks = "3 months", date_labels = "%b %Y", expand = expansion(mult = .01)) +
      labs(title = if (which_period == "before") places[i] else "After pressure-only backwards search",
        subtitle = sprintf("%s to %s", endpoint %m-% years(1), endpoint - 1), x = NULL,
        y = if (which_period == "before") "Pressure (hPa)" else NULL)
  }
}
p <- wrap_plots(panels, ncol = 2, guides = "collect") & theme(legend.position = "bottom")
ggsave(file.path(out, "pressure_window_before_after.png"), p, width = 11.8, height = 8.2, dpi = 220, bg = "white", device = ragg::agg_png)
ggsave(file.path(out, "pressure_window_before_after.pdf"), p, width = 11.8, height = 8.2, device = cairo_pdf)

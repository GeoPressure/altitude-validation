# Pressure-only diagnostic plots for extreme stations; no filtering is applied.
source("R/utils.R")
source("R/palette.R")
library(ggplot2)
library(patchwork)

# Read the evaluated records and their archive source codes -----------------
out <- "output/drafts/atmospheric-figures"
review <- fread(file.path(out, "pressure_timeseries_filter_review.csv"))
records <- as.data.table(read_parquet(file.path(out, "pressure_timeseries_filter_examples.parquet")))
ids <- c("BRM00086850", "BRM00086781", "CIN00320041", "MXM00076737")
names <- c("Barbacena, Brazil", "Diamantina, Brazil", "Viña del Mar, Chile", "Orizaba, Mexico")
series <- list()
for (id_value in ids) {
  raw <- as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/pressure", paste0(id_value, ".parquet"))))
  series[[length(series) + 1L]] <- merge(records[id == id_value], raw[, .(date, source_code)], by = "date")
}
d <- rbindlist(series)
setorder(d, id, date)
d[, jump := abs(pressure - shift(pressure)) > 20 & as.numeric(difftime(date, shift(date), units = "hours")) <= 3, by = id]
d[is.na(jump), jump := FALSE]
d[, block := floor(as.numeric(difftime(date, min(date), units = "days")) / 14), by = id]
windows <- d[, .(jumps = sum(jump), observations = .N), by = .(id, block)][order(id, -jumps, -observations, block)][, .SD[1], by = id]
windows <- merge(windows, d[, .(origin = min(date)), by = id], by = "id")
windows[, `:=`(start = origin + block * 14 * 86400, end = origin + (block + 1) * 14 * 86400)]
fwrite(windows, file.path(out, "pressure_timeseries_example_windows.csv"))
fwrite(d[, .(n = .N, median_pressure = median(pressure), min_pressure = min(pressure), max_pressure = max(pressure)),
  by = .(id, source_code)], file.path(out, "pressure_timeseries_example_sources.csv"))

# Full records and matching two-week close-ups -----------------------------
colours <- c(`220` = pal_conversion[["standard"]], `223` = pal_conversion[["virtual"]], `412` = pal_conversion[["isa"]])
theme_set(theme_minimal(base_size = 10, base_family = "Helvetica Neue") +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = pal[["grid"]], linewidth = .25),
    plot.title = element_text(size = 10, face = "bold", colour = pal[["ink"]]),
    axis.text = element_text(colour = "#4B5563"), legend.position = "bottom",
    plot.margin = margin(5, 10, 5, 5)))
panels <- list()
for (i in seq_along(ids)) {
  z <- d[id == ids[i]]
  w <- windows[id == ids[i]]
  limits <- range(z$pressure) + c(-1, 1) * diff(range(z$pressure)) * .04
  for (j in 1:2) {
    v <- if (j == 1) copy(z) else z[date >= w$start & date < w$end]
    v[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 6), by = source_code]
    p <- ggplot(v, aes(date, pressure))
    if (j == 1) p <- p + annotate("rect", xmin = w$start, xmax = w$end,
      ymin = -Inf, ymax = Inf, fill = pal[["slate"]], alpha = .2)
    p <- p + geom_line(colour = "#9CA3AF", linewidth = .2, alpha = .5) +
      geom_line(aes(colour = source_code, group = interaction(source_code, segment)), linewidth = .45, show.legend = TRUE) +
      scale_colour_manual(values = colours, limits = names(colours), drop = FALSE, name = "Archive source code") +
      scale_y_continuous(limits = limits) +
      scale_x_datetime(date_breaks = if (j == 1) "3 months" else "3 days", date_labels = if (j == 1) "%b %Y" else "%d %b",
        expand = expansion(mult = c(.01, .01))) +
      labs(title = if (j == 1) sprintf("%s · %s", names[i], ids[i]) else
          sprintf("Close-up · %s–%s", format(w$start, "%d %b"), format(w$end - 1, "%d %b %Y")),
        x = NULL, y = if (j == 1) "Pressure (hPa)" else NULL)
    panels[[length(panels) + 1L]] <- p
  }
}
p <- wrap_plots(panels, ncol = 2, widths = c(1.4, 1), guides = "collect") & theme(legend.position = "bottom")
ggsave(file.path(out, "problematic_pressure_timeseries.png"), p, width = 11.8, height = 8.2, dpi = 220, bg = "white", device = ragg::agg_png)
ggsave(file.path(out, "problematic_pressure_timeseries.pdf"), p, width = 11.8, height = 8.2, device = cairo_pdf)
writeLines("Pressure records at four illustrative stations with extreme conversion-error scatter in the selection without ERA5-residual screening. Left: the full evaluated record; grey shading marks the interval shown on the right, with the same pressure range in both panels. Close-ups show the 14-day block with the most pressure jumps exceeding 20 hPa between records no more than three hours apart (ties favour more observations, then the earlier block). Colours identify archive source codes; thin grey lines connect successive observations in the combined record. Coloured lines join records from the same source only where separated by at most six hours. Source codes are identifiers, not quality rankings. No observations are removed. These deliberately selected examples illustrate record problems and are not representative of all stations.", file.path(out, "problematic_pressure_timeseries_caption.txt"))

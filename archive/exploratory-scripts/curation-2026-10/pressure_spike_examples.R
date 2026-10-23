# Illustrate pressure-only rejection in the reviewed station records.
source("R/utils.R")
source("R/ghcnh_sampling.R")
library(ggplot2)
library(patchwork)
out <- "output/drafts/atmospheric-figures"
d <- as.data.table(read_parquet(file.path(out, "era5_batch4_review_station_records.parquet")))
examples <- data.table(id = c("KGM00038345", "MZM00067225", "CTI0000FEFT"),
  name = c("Talas", "Furancungo", "Berberati"),
  date = as.POSIXct(c("2026-05-18", "2025-07-17", "2025-11-08"), tz = "UTC"))
panels <- list()
for (j in seq_len(nrow(examples))) {
  v <- d[id == examples$id[j]]
  retained <- ghcnh_pressure_spikes(v)
  v[, removed := !date %in% retained$date]
  v <- v[date >= examples$date[j] - 2 * 86400 & date <= examples$date[j] + 2 * 86400]
  panels[[j]] <- ggplot(v, aes(date, pressure)) +
    geom_line(colour = "#2572A0", linewidth = .4) +
    geom_segment(data = v[removed == TRUE], aes(x = date - 3600, xend = date + 3600,
      y = pressure, yend = pressure), colour = "#D16637", linewidth = 1) +
    labs(title = examples$name[j], x = NULL, y = "Pressure (hPa)") +
    theme_minimal(base_family = "Helvetica Neue")
}
p <- wrap_plots(panels, ncol = 1)
ggsave(file.path(out, "era5_batch4_spike_examples.png"), p, width = 9, height = 7, dpi = 160, bg = "white")

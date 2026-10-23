# Review pressure records with large residual bias or scatter.
source("R/utils.R")
source("R/palette.R")
source("R/ghcnh_sampling.R")
library(ggplot2)
library(patchwork)
setDTthreads(1)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
out <- "output/drafts/atmospheric-figures"
tail_review <- "tails" %in% commandArgs(trailingOnly = TRUE)
more_review <- "more" %in% commandArgs(trailingOnly = TRUE)
batch <- as.integer(sub("batch", "", grep("^batch[0-9]+$", commandArgs(trailingOnly = TRUE), value = TRUE)))
batch_review <- length(batch) > 0
extended_review <- "review" %in% commandArgs(trailingOnly = TRUE)
terrain_screen <- tail_review | more_review | extended_review | batch_review | "terrain" %in% commandArgs(trailingOnly = TRUE)
input <- if (terrain_screen) "ground_terrain_window" else "ground_pressure_window"
output <- if (batch_review) paste0("era5_batch", batch, "_review") else if (extended_review) "era5_extended_review" else if (more_review) "era5_followup_review" else if (tail_review) "era5_tail_review" else if (terrain_screen) "high_bias_terrain_filtered" else "high_bias"
n_stations <- if (terrain_screen) 10L else 12L
rows_per_page <- n_stations / 2
if (!"cached" %in% commandArgs(trailingOnly = TRUE)) {
if (!batch_review) load_geopressurer()
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
stations <- fread(file.path(out, paste0(input, "_stations.csv")))[formula == "standard"][order(-abs(bias))]
if (batch_review) {
  reviewed <- rbindlist(lapply(c("era5_tail_review", "era5_followup_review", "era5_extended_review", if (batch > 4) paste0("era5_batch", 4:(batch - 1), "_review")), function(x) fread(file.path(out, paste0(x, "_stations_review.csv")))), fill = TRUE)
  stations <- unique(rbind(stations[order(-sd)][1:40], stations[1:20]), by = "id")[!id %in% reviewed$id]
}
if (more_review) stations <- stations[order(-sd)]
stations <- if (batch_review) stations else if (extended_review) unique(rbind(stations[order(-sd)][1:20], stations[1:10]), by = "id") else if (tail_review) stations[sd > 30 | bias < -100] else stations[seq_len(n_stations)]
if (extended_review || batch_review) {
  n_stations <- nrow(stations)
  rows_per_page <- 5L
}
if (tail_review) {
  n_stations <- nrow(stations)
  rows_per_page <- 6L
}
stations <- merge(stations, candidates, by = c("id", "cell"))[order(-abs(bias))]
windows <- fread(file.path(out, paste0(input, "_selection.csv")))
records <- list()
metadata <- list()
for (id_value in stations$id) {
  s <- stations[id == id_value]
  w <- windows[id == id_value]
  if (batch_review) {
    d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(id_value, ".parquet"))))
    d[, altitude := err_sl + s$elev]
  } else {
    d <- merge(as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(id_value, ".parquet")))),
      as.data.table(read_parquet(file.path(run_dir, "core", paste0(id_value, ".parquet")))), by = "date")
    if (terrain_screen && "n_spikes" %in% names(windows)) d <- ghcnh_pressure_spikes(d)
    d <- d[date >= as.POSIXct(w$start, tz = "UTC") & date < as.POSIXct(w$end, tz = "UTC")]
    d[, altitude := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl)]
  }
  d[, id := id_value]
  records[[length(records) + 1L]] <- d
  files <- c(list.files(file.path(run_dir, "annual"), pattern = paste0("^", id_value, "_"), full.names = TRUE),
    list.files("data/interim/ghcnh/annual", pattern = paste0("^", id_value, "_"), full.names = TRUE))
  files <- files[!duplicated(basename(files))]
  for (f in files) {
    a <- as.data.table(read_parquet(f, col_select = c("DATE", "Station_name", "LATITUDE", "LONGITUDE", "ELEVATION", "station_level_pressure", "sea_level_pressure", "station_level_pressure_Source_Code", "station_level_pressure_Source_Station_ID")))
    a <- a[is.finite(station_level_pressure)]
    metadata[[length(metadata) + 1L]] <- a[, .(id = id_value, file = basename(f), n = .N,
      first = min(DATE), last = max(DATE), pressure_median = median(station_level_pressure),
      sea_level_median = median(sea_level_pressure, na.rm = TRUE)),
      by = .(Station_name, LATITUDE, LONGITUDE, ELEVATION, station_level_pressure_Source_Code, station_level_pressure_Source_Station_ID)]
  }
}
d <- rbindlist(records)
summary <- d[, .(inferred_height = median(altitude), era5_surface_height = median(z_sl),
  median_pressure = median(pressure), sources = paste(sort(unique(source_code)), collapse = ",")), by = id]
summary <- merge(stations, summary, by = "id")[order(-abs(bias))]
fwrite(summary, file.path(out, paste0(output, "_stations_review.csv")))
fwrite(rbindlist(metadata), file.path(out, paste0(output, "_report_metadata.csv")))
write_parquet(d, file.path(out, paste0(output, "_station_records.parquet")))
} else {
  summary <- fread(file.path(out, paste0(output, "_stations_review.csv")))
  d <- as.data.table(read_parquet(file.path(out, paste0(output, "_station_records.parquet"))))
  n_stations <- nrow(summary)
  rows_per_page <- if (tail_review) 6L else 5L
}

# Pressure records and their corresponding inferred heights ----------------
theme_set(theme_minimal(base_family = "Helvetica Neue", base_size = 10) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 10, face = "bold"),
    legend.position = "bottom", plot.margin = margin(5, 12, 5, 5)))
panels <- list()
for (i in seq_len(nrow(summary))) {
  s <- summary[i]
  v <- d[id == s$id][order(date)]
  v[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 12)]
  v[, single := .N == 1L, by = segment]
  p1 <- ggplot(v, aes(date, pressure, group = segment)) +
    geom_line(colour = pal_conversion[["standard"]], linewidth = .3) +
    geom_segment(data = v[single == TRUE], aes(x = date - 43200, xend = date + 43200, y = pressure, yend = pressure),
      inherit.aes = FALSE, colour = pal_conversion[["standard"]], linewidth = .3) +
    scale_x_datetime(date_breaks = "3 months", date_labels = "%b %Y") +
    labs(title = sprintf("%s · %s", s$name, s$id), x = NULL, y = "Pressure (hPa)")
  p2 <- ggplot(v, aes(date, altitude, group = segment)) +
    geom_hline(aes(yintercept = elev, colour = "Listed station elevation"), data = s, linewidth = .45) +
    geom_line(aes(colour = "Pressure-derived height"), linewidth = .3) +
    geom_segment(data = v[single == TRUE], aes(x = date - 43200, xend = date + 43200, y = altitude, yend = altitude,
      colour = "Pressure-derived height"), inherit.aes = FALSE, linewidth = .3, show.legend = FALSE) +
    scale_colour_manual(values = c("Listed station elevation" = "#67727E", "Pressure-derived height" = pal_conversion[["standard"]]), name = NULL) +
    scale_x_datetime(date_breaks = "3 months", date_labels = "%b %Y") +
    scale_y_continuous(expand = expansion(mult = .12)) +
    labs(title = sprintf("Bias %+.0f m · SD %.1f m · listed height %.0f m", s$bias, s$sd, s$elev), x = NULL, y = "Altitude (m ASL)")
  panels <- c(panels, list(p1, p2))
}
for (page in seq_len(ceiling(n_stations / rows_per_page))) {
  p <- wrap_plots(panels[((page - 1) * rows_per_page * 2 + 1):min(page * rows_per_page * 2, length(panels))], ncol = 2, guides = "collect") & theme(legend.position = "bottom")
  suffix <- if (page == 1) "" else if (page == 2) "_additional" else paste0("_page", page)
  ggsave(file.path(out, paste0(output, "_station_timeseries", suffix, ".png")), p, width = 12, height = rows_per_page * 2 + .5, dpi = 190, bg = "white", device = ragg::agg_png)
  ggsave(file.path(out, paste0(output, "_station_timeseries", suffix, ".pdf")), p, width = 12, height = rows_per_page * 2 + .5, device = cairo_pdf)
}
writeLines(sprintf("The %s stations with the largest absolute mean bias under the ERA5 standard-lapse conversion in the %s selection. Each row shows retained hourly pressure (left) and converted altitude above sea level (right); the grey horizontal line is the archive station elevation. Blue heights use ERA5 surface pressure, temperature and orography. Titles report mean signed error and its hourly standard deviation. Each station uses its own selected 12-month period. Gaps longer than 12 hours are left unconnected. The first file contains ranks 1–%s and the additional file ranks %s–%s. Stable offsets do not identify their cause by themselves.", n_stations, if (terrain_screen) "terrain-filtered pressure-only backwards-window" else "pressure-only backwards-window", rows_per_page, rows_per_page + 1, n_stations), file.path(out, paste0(output, "_station_timeseries_caption.txt")))
if (tail_review) writeLines("Stations with ERA5 standard-lapse error SD >30 m or mean bias below −100 m after terrain screening and documented metadata exclusions. Rows show retained pressure (left) and converted altitude (right), with archive elevation in grey. Each station uses its selected 12-month window. Gaps longer than 12 hours are left unconnected. Stations are ordered by absolute mean bias across the two files.", file.path(out, paste0(output, "_station_timeseries_caption.txt")))
if (more_review) writeLines("The ten stations with the highest remaining ERA5 standard-lapse error SD after curation and isolated pressure-spike removal. Pressure is shown on the left and converted ASL height on the right. Rows are ordered by absolute bias across the two pages. No further exclusions are applied by this diagnostic script.", file.path(out, paste0(output, "_station_timeseries_caption.txt")))
if (extended_review) writeLines("The union of the twenty stations with highest remaining ERA5 standard-lapse error SD and the ten with largest absolute bias. Retained pressure is shown on the left and converted ASL height on the right. Rows are ordered by absolute bias across pages. The script does not change station selection.", file.path(out, paste0(output, "_station_timeseries_caption.txt")))
cat("\nIsolated reports separated from both neighbours by gaps longer than 12 hours are drawn as short horizontal strokes spanning one day for visibility.\n", file = file.path(out, paste0(output, "_station_timeseries_caption.txt")), append = TRUE)
print(summary[, .(id, name, elev, bias, sd, inferred_height, era5_surface_height, sources)])

if (batch_review) writeLines("Previously unreviewed stations among the forty highest remaining ERA5 standard-lapse error SDs and twenty largest absolute biases. Pressure is shown on the left, converted height on the right. Each row has its own vertical scale; isolated reports are drawn as short horizontal strokes. Stable offsets and scatter alone do not establish a reporting fault. The script does not change station selection.", file.path(out, paste0(output, "_station_timeseries_caption.txt")))

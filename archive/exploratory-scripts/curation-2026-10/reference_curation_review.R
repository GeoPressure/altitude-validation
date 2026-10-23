# Inspect unresolved offsets and pressure patterns without changing selection.
source("R/utils.R")
source("R/ghcnh_sampling.R")
library(ggplot2)
library(patchwork)
load_geopressurer()
setDTthreads(1)
out <- "output/drafts/reference-curation"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
stations <- fread("output/drafts/isa-bias-review/station_review.csv")
stations <- stations[abs(bias_standard) > 150 & !grepl("MOVING ICE", name) & !id %in% c("CIM00085410", "CHM00059948", "CHI0000ZLYA", "RPI0000RPUB")]
d <- as.data.table(read_parquet("output/drafts/isa-bias-review/accepted_records.parquet"))[id %in% stations$id, .(id, date, pressure, err_standard, source_code)]
extra <- fread("output/tables/stations.csv")[id %in% c("AYM00089003", "ARI0000SASQ", "COI0000SKIP")]
for (i in seq_len(nrow(extra))) {
  v <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(extra$id[i], ".parquet"))))
  d <- rbind(d, v[, .(id = extra$id[i], date, pressure, err_standard, source_code)])
  stations <- rbind(stations, data.table(id = extra$id[i], name = extra$name[i], elev = extra$elev[i], bias_standard = mean(v$err_standard)), fill = TRUE)
}
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
settings <- readRDS(file.path(run_dir, "settings.rds"))
for (id_value in c("IRM00040770", "IRI0000OIFK")) {
  s <- candidates[id == id_value]
  v <- ghcnh_pressure_spikes(as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(s$id, ".parquet")))))
  window <- ghcnh_pressure_window(v, settings)
  v <- merge(window$hours, as.data.table(read_parquet(file.path(run_dir, "core", paste0(s$id, ".parquet")))), by = "date")
  v[, err_standard := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
  write_parquet(v, file.path(out, if (id_value == "IRM00040770") "qom_candidate.parquet" else "kashan_candidate.parquet"))
  d <- rbind(d, v[, .(id = id_value, date, pressure, err_standard, source_code)])
  stations <- rbind(stations, data.table(id = s$id, name = s$name, elev = s$elev, bias_standard = mean(v$err_standard)), fill = TRUE)
}
fwrite(d[, .(n = .N, pressure_median = median(pressure), error_median = median(err_standard), first = min(date), last = max(date)), by = .(id, source_code)], file.path(out, "source_comparison.csv"))

# Full history, selected year and a fortnight around the largest daily error range.
theme_set(theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "bottom"))
panels <- list()
for (i in seq_len(nrow(stations))) {
  s <- stations[i]
  v <- d[id == s$id][order(date)]
  v[, source := factor(source_code)]
  v[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 12)]
  history <- as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/pressure", paste0(s$id, ".parquet"))))
  setorder(history, date)
  history[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 12)]
  daily <- v[, .(error = median(err_standard), range = diff(range(err_standard))), by = .(day = as.Date(date, tz = "UTC"))]
  daily[, segment := cumsum(is.na(shift(day)) | as.numeric(day - shift(day)) > 1)]
  centre <- as.POSIXct(daily[which.max(range)]$day, tz = "UTC")
  zoom <- v[date >= centre - 7 * 86400 & date < centre + 7 * 86400]
  p1 <- ggplot(history, aes(date, pressure, group = segment)) +
    annotate("rect", xmin = min(v$date), xmax = max(v$date), ymin = -Inf, ymax = Inf, fill = "#E5A13B", alpha = .15) +
    geom_line(linewidth = .25) + geom_point(size = .15) + labs(title = "Available pressure history; selected year shaded", x = NULL, y = "Pressure (hPa)")
  p2 <- ggplot(v, aes(date, pressure)) + geom_line(aes(group = segment), colour = "grey65", linewidth = .25) +
    geom_point(aes(colour = source), size = .5, show.legend = TRUE) + labs(title = "Reviewed year", x = NULL, y = "Pressure (hPa)", colour = "Archive source")
  p3 <- ggplot(v, aes(date, err_standard)) + geom_line(aes(group = segment), colour = "grey65", linewidth = .25) +
    geom_point(aes(colour = source), size = .5, show.legend = TRUE) +
    geom_line(data = daily, aes(as.POSIXct(day, tz = "UTC"), error, group = segment), inherit.aes = FALSE, linewidth = .5) +
    labs(title = sprintf("ERA5 error: mean bias %+.1f m", mean(v$err_standard)), subtitle = "Black line: daily median", x = NULL, y = "Height error (m)", colour = "Archive source")
  p4 <- ggplot(zoom, aes(date, pressure)) + geom_line(aes(group = segment), colour = "grey65", linewidth = .35) +
    geom_point(aes(colour = source), size = 1, show.legend = TRUE) + scale_x_datetime(date_breaks = "3 days", date_labels = "%d %b") +
    labs(title = "Fortnight around the largest within-day error range", x = NULL, y = "Pressure (hPa)", colour = "Archive source")
  source_colours <- scale_colour_manual(values = c("220" = "#D55E00", "223" = "#0072B2", "412" = "#009E73"), limits = c("220", "223", "412"), drop = FALSE)
  p2 <- p2 + source_colours
  p3 <- p3 + source_colours
  p4 <- p4 + source_colours
  p <- wrap_plots(p1, p2, p3, p4, ncol = 1, guides = "collect") +
    plot_annotation(title = paste(s$name, s$id), subtitle = sprintf("Archive height %.1f m; %s retained reports; times in UTC", s$elev, nrow(v)))
  ggsave(file.path(out, paste0(s$id, ".png")), p, width = 12, height = 12, dpi = 140)
  panels <- c(panels, list(p2 + labs(title = paste(s$name, s$id)), p3))
}
for (page in seq_len(ceiling(nrow(stations) / 4))) {
  p <- wrap_plots(panels[((page - 1) * 8 + 1):min(page * 8, length(panels))], ncol = 2, guides = "collect")
  ggsave(file.path(out, paste0("review_page", page, ".png")), p, width = 15, height = min(4, nrow(stations) - (page - 1) * 4) * 2.75, dpi = 140)
}
fwrite(stations, file.path(out, "reviewed_stations.csv"))

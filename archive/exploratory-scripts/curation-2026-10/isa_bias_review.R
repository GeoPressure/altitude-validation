# Inspect the large-bias tail without changing station selection.
source("R/utils.R")
source("R/ghcnh_sampling.R")
library(ggplot2)
library(patchwork)
setDTthreads(1)
out <- "output/drafts/isa-bias-review"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
s <- fread("output/tables/paper_ground_station.csv")[reference == "GHCNh"]
wide <- dcast(s, id + n + elev + lat + lon ~ formula, value.var = c("bias", "sd"))
wide <- merge(wide, fread("output/tables/stations.csv")[network == "ghcnh", .(id, name, window_start, window_end)], by = "id")
stations <- wide[abs(bias_isa) > 150 | abs(bias_standard) > 150][order(-abs(bias_isa))]
records <- list()
summary <- list()
monthly <- list()
metadata <- list()
for (i in seq_len(nrow(stations))) {
  s <- stations[i]
  d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(s$id, ".parquet"))))
  setorder(d, date)
  records[[s$id]] <- d[, .(id = s$id, date, pressure, err_isa, err_standard, source_code)]
  days <- d[, .N, by = .(day = as.Date(date, tz = "UTC"))]
  bounds <- s$window_end %m-% months(0:12)
  coverage <- vapply(1:12, function(m) sum(days$day >= bounds[m + 1L] & days$day < bounds[m] & days$N >= 4), integer(1))
  history <- as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(s$id, ".parquet")), col_select = c("date", "pressure")))
  summary[[s$id]] <- d[, .(id = s$id, first = min(date), last = max(date), span_days = as.numeric(difftime(max(date), min(date), units = "days")),
    observed_days = nrow(days), qualifying_days = sum(days$N >= 4), min_month_qualifying_days = min(coverage),
    largest_gap_days = max(as.numeric(diff(date), units = "days")),
    history_first = min(history$date), history_last = max(history$date),
    pressure_median = median(pressure), isa_median = median(err_isa), era5_median = median(err_standard),
    era5_p05 = quantile(err_standard, .05), era5_p95 = quantile(err_standard, .95),
    sources = paste(sort(unique(source_code)), collapse = ","))]
  monthly[[s$id]] <- d[, .(id = s$id, n = .N, pressure_median = median(pressure),
    isa_median = median(err_isa), era5_median = median(err_standard)), by = .(month = format(date, "%Y-%m"))]
  files <- c(list.files(file.path(run_dir, "annual"), pattern = paste0("^", s$id, "_"), full.names = TRUE),
    list.files("data/interim/ghcnh/annual", pattern = paste0("^", s$id, "_"), full.names = TRUE))
  files <- files[!duplicated(basename(files)) & as.integer(sub(".*_([0-9]{4})[.]parquet$", "\\1", files)) %in% year(d$date)]
  for (file in files) {
    schema <- names(open_dataset(file)$schema)
    columns <- schema[tolower(schema) %in% c("date", "station_name", "latitude", "longitude", "elevation", "station_level_pressure", "sea_level_pressure", "station_level_pressure_source_code", "station_level_pressure_source_station_id")]
    a <- as.data.table(read_parquet(file, col_select = tidyselect::all_of(columns)))
    setnames(a, tolower(names(a)))
    a[, date := as.POSIXct(date, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")]
    a <- a[date >= as.POSIXct(s$window_start, tz = "UTC") & date < as.POSIXct(s$window_end, tz = "UTC") & station_level_pressure > 300 & station_level_pressure < 1100]
    metadata[[length(metadata) + 1L]] <- a[, .(id = s$id, n = .N, first = min(date), last = max(date),
      pressure_median = median(station_level_pressure),
      sea_level_median = median(sea_level_pressure[sea_level_pressure > 800 & sea_level_pressure < 1100], na.rm = TRUE)),
      by = .(station_name, latitude, longitude, elevation, station_level_pressure_source_code, station_level_pressure_source_station_id)]
  }
}
summary <- merge(stations, rbindlist(summary), by = "id")[order(-abs(bias_isa))]
fwrite(summary, file.path(out, "station_review.csv"))
fwrite(rbindlist(monthly), file.path(out, "monthly.csv"))
fwrite(rbindlist(metadata), file.path(out, "report_metadata.csv"))
d <- rbindlist(records)
write_parquet(d, file.path(out, "accepted_records.parquet"))

# Compare pressure and the two conversions over the full selected year.
theme_set(theme_bw(base_size = 9))
for (page in seq_len(ceiling(nrow(summary) / 6))) {
  panels <- list()
  for (i in ((page - 1) * 6 + 1):min(page * 6, nrow(summary))) {
    s <- summary[i]
    v <- d[id == s$id]
    v[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 12)]
    panels <- c(panels, list(
      ggplot(v, aes(date, pressure, group = segment)) + geom_line(linewidth = .25) + geom_point(size = .2) +
        labs(title = paste(s$name, s$id), subtitle = sprintf("%s reports over %.0f days; minimum %s qualifying days/month", s$n, s$span_days, s$min_month_qualifying_days), x = NULL, y = "Pressure (hPa)"),
      ggplot(v, aes(date, err_isa, group = segment)) + geom_hline(yintercept = 0, colour = "grey60") + geom_line(colour = "#C7662D", linewidth = .25) +
        labs(title = sprintf("ISA bias %+.1f m; median %+.1f m", s$bias_isa, s$isa_median), x = NULL, y = "ISA error (m)"),
      ggplot(v, aes(date, err_standard, group = segment)) + geom_hline(yintercept = 0, colour = "grey60") + geom_line(colour = "#315F98", linewidth = .25) +
        labs(title = sprintf("ERA5 bias %+.1f m; median %+.1f m", s$bias_standard, s$era5_median), x = NULL, y = "ERA5 error (m)")))
  }
  ggsave(file.path(out, sprintf("timeseries_%02d.png", page)), wrap_plots(panels, ncol = 3), width = 15, height = 12, dpi = 140)
}
print(summary[, .(id, name, bias_isa, bias_standard, n, span_days, min_month_qualifying_days, isa_median, era5_median)])

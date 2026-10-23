# Evaluate experimental checks on the current accepted sample and full histories.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/ghcnh_pressure_patterns.R")
library(ggplot2)
library(patchwork)
setDTthreads(1)
set.seed(23)
out <- "output/drafts/pressure-pattern-tests"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
stations <- fread(file.path(selection_dir("ghcnh"), "full-accepted.csv"))
blocks <- list()
steps <- list()
summary <- list()
for (i in seq_len(nrow(stations))) {
  s <- stations[i]
  d <- ghcnh_pressure_spikes(as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/pressure", paste0(s$id, ".parquet")))))
  start <- as.POSIXct(s$window_start, tz = "UTC")
  end <- as.POSIXct(s$window_end, tz = "UTC")
  result <- ghcnh_pressure_patterns(d, start, end)
  b <- result$blocks
  e <- result$steps
  b[, `:=`(id = s$id, selected = as.POSIXct(block, tz = "UTC") < end & as.POSIXct(block + 14, tz = "UTC") > start)]
  e[, `:=`(id = s$id, selected = date > start & date < end)]
  blocks[[i]] <- b
  steps[[i]] <- e
  summary[[i]] <- data.table(id = s$id, noise_blocks = sum(b$noise & b$selected), steps = sum(e$step & e$selected),
    max_noise = if (any(b$selected)) max(b[selected == TRUE]$p90) else NA_real_)
  if (i %% 250 == 0) cli::cli_alert_info("Reviewed {i}/{nrow(stations)} pressure histories")
}
b <- rbindlist(blocks)
e <- rbindlist(steps)
summary <- merge(stations, rbindlist(summary), by = "id")
fwrite(b, file.path(out, "noise_blocks.csv"))
fwrite(e, file.path(out, "step_candidates.csv"))
fwrite(summary, file.path(out, "station_results.csv"))

# Threshold sensitivity describes workload, not measured false-positive rates.
sensitivity <- list()
for (threshold in c(1, 1.5, 2)) for (ratio_cut in c(3, 4, 6)) {
  flagged <- b[selected == TRUE & p90 >= threshold & ratio >= ratio_cut & large >= 10]
  sensitivity[[length(sensitivity) + 1L]] <- data.table(test = "noise", threshold = threshold, ratio = ratio_cut, stations = uniqueN(flagged$id))
}
for (threshold in c(4, 5, 6)) for (ratio_cut in c(6, 8, 10)) {
  flagged <- e[selected == TRUE & step == TRUE & abs(jump) >= threshold & ratio >= ratio_cut]
  sensitivity[[length(sensitivity) + 1L]] <- data.table(test = "step", threshold = threshold, ratio = ratio_cut, stations = uniqueN(flagged$id))
}
fwrite(rbindlist(sensitivity), file.path(out, "threshold_sensitivity.csv"))
print(summary[noise_blocks > 0 | steps > 0, .(id, name, noise_blocks, steps, max_noise)])

# Show targets and a reproducible sample of other detections.
targets <- c("ARI0000SASQ", "COI0000SKIP", "AYM00089003", "CHI0000ZLXN")
flagged <- summary[(noise_blocks > 0 | steps > 0) & !id %in% targets]$id
ids <- unique(c(targets, sample(setdiff(flagged, targets), min(12, length(setdiff(flagged, targets))))))
theme_set(theme_bw(base_size = 10))
panels <- list()
for (id_value in ids) {
  s <- summary[id == id_value]
  d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(id_value, ".parquet"))))
  d[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 12)]
  bb <- b[id == id_value & selected == TRUE]
  ee <- e[id == id_value & selected == TRUE & step == TRUE]
  p1 <- ggplot(d, aes(date, pressure)) + geom_rect(data = bb[noise == TRUE], aes(xmin = as.POSIXct(block, tz = "UTC"), xmax = as.POSIXct(block + 14, tz = "UTC"), ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "#D55E00", alpha = .2) +
    geom_line(aes(group = segment), linewidth = .25) + geom_vline(data = ee, aes(xintercept = date), colour = "#0072B2") +
    labs(title = paste(s$name, id_value), subtitle = sprintf("%s noise blocks; %s step candidates", s$noise_blocks, s$steps), x = NULL, y = "Pressure (hPa)")
  p2 <- ggplot(bb, aes(block, p90, colour = factor(cadence))) + geom_line() + geom_point(size = 1) + geom_hline(yintercept = 1.5, linetype = 2) +
    labs(title = "90th percentile of short-term irregularity", x = NULL, y = "Irregularity (hPa/h)", colour = "Report spacing (h)")
  p3 <- ggplot(d, aes(date, err_standard, group = segment)) + geom_line(linewidth = .25, colour = "#315F98") +
    labs(title = "ERA5 error: evaluation only", x = NULL, y = "Height error (m)")
  panels <- c(panels, list(p1, p2, p3))
}
for (page in seq_len(ceiling(length(ids) / 4))) {
  ggsave(file.path(out, paste0("review_page", page, ".png")), wrap_plots(panels[((page - 1) * 12 + 1):min(page * 12, length(panels))], ncol = 3), width = 16, height = 11, dpi = 140)
}
fwrite(data.table(id = ids), file.path(out, "plotted_stations.csv"))

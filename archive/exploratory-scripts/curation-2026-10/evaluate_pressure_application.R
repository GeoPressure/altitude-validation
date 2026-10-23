# Evaluate the rebuilt sample after pressure-only pattern screening.
source("R/utils.R")
library(ggplot2)
library(patchwork)
setDTthreads(1)
out <- "output/drafts/pattern-application"
before <- fread(file.path(out, "previous_station_errors.csv"))[reference == "GHCNh" & formula == "standard"]
after <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh" & formula == "standard"]
old_selection <- fread(file.path(out, "previous_selection.csv"))
selection <- fread(file.path(dir_tables, "ground_selection.csv"))
paired <- merge(old_selection, selection, by = "cell", suffixes = c("_before", "_after"))
changes <- paired[id_before != id_after | (!is.na(start_before) & !is.na(start_after) & (start_before != start_after | end_before != end_after))]
fwrite(changes, file.path(out, "selection_changes.csv"))
summary <- rbindlist(list(before = before[, .(stations = .N, reports = sum(n), abs_bias_above150 = sum(abs(bias) > 150), sd_above20 = sum(sd > 20),
    sd_above50 = sum(sd > 50), median_abs_bias = median(abs(bias)), median_sd = median(sd))],
  after = after[, .(stations = .N, reports = sum(n), abs_bias_above150 = sum(abs(bias) > 150), sd_above20 = sum(sd > 20),
    sd_above50 = sum(sd > 50), median_abs_bias = median(abs(bias)), median_sd = median(sd))]), idcol = "selection")
tails <- rbindlist(list(before = fread(file.path(out, "previous_tails.csv")), after = fread(file.path(dir_tables, "paper_ground_tails.csv"))), idcol = "selection")
summary <- merge(summary, tails[reference == "GHCNh" & formula == "standard", .(selection, median_absolute_error = medae, p95_absolute_error = p95_abs)], by = "selection")
fwrite(summary, file.path(out, "comparison.csv"))
print(summary)
stations <- fread(file.path(dir_tables, "stations.csv"))[network == "ghcnh"]
review <- merge(after[abs(bias) > 150 | sd > 20], stations[, .(id, name, window_start, window_end)], by = "id")[order(-sd)]
fwrite(review, file.path(out, "remaining_tail.csv"))
print(review[, .(id, name, bias, sd, n)])

# Compare the motivating examples and inspect all remaining large-error records.
targets <- c("ARI0000SASQ", "COI0000SKIP", "AYM00089003", "CHI0000ZLXN")
target_results <- merge(before[id %in% targets, .(id, bias_before = bias, sd_before = sd)], after[id %in% targets, .(id, bias_after = bias, sd_after = sd)], by = "id", all = TRUE)
fwrite(target_results, file.path(out, "target_results.csv"))
ids <- unique(c(targets[targets %in% after$id], review$id))
theme_set(theme_bw(base_size = 10) + theme(panel.grid.minor = element_blank()))
panels <- list()
for (id_value in ids) {
  s <- stations[id == id_value]
  a <- after[id == id_value]
  d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(id_value, ".parquet"))))
  d[, segment := cumsum(is.na(shift(date)) | as.numeric(difftime(date, shift(date), units = "hours")) > 12)]
  panels <- c(panels, list(
    ggplot(d, aes(date, pressure, group = segment)) + geom_line(linewidth = .25) + geom_point(size = .15) +
      labs(title = paste(s$name, id_value), subtitle = paste(s$window_start, "to", s$window_end), x = NULL, y = "Pressure (hPa)"),
    ggplot(d, aes(date, err_standard, group = segment)) + geom_line(colour = "#315F98", linewidth = .25) +
      labs(title = sprintf("ERA5 bias %+.1f m; SD %.1f m", a$bias, a$sd), x = NULL, y = "Height error (m)")))
}
for (page in seq_len(ceiling(length(ids) / 5))) {
  ggsave(file.path(out, paste0("remaining_page", page, ".png")), wrap_plots(panels[((page - 1) * 10 + 1):min(page * 10, length(panels))], ncol = 2), width = 14, height = 12, dpi = 140)
}
fwrite(data.table(id = ids), file.path(out, "plotted_stations.csv"))

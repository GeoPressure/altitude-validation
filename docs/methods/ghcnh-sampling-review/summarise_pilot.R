# Summarise the measured pilot and project selection-only resources ----------
library(data.table)
out <- "docs/methods/ghcnh-sampling-review"
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
a <- fread(file.path(out, "pilot-64-initial-attempts.csv"))
metrics <- fread(file.path(out, "pilot-64-initial-metrics.csv"))

# Attribute all added candidate files, including historical source downloads.
files <- unlist(lapply(c("annual", "pressure", "core", "accepted"), function(part) list.files(file.path(run_dir, part), full.names = TRUE, pattern = "parquet$")))
old_annual <- list.files("data/interim/ghcnh/annual", full.names = TRUE, pattern = "parquet$")
files <- c(files, old_annual[file.info(old_annual)$mtime >= file.info(file.path(run_dir, "settings.rds"))$mtime])
bytes <- data.table(id = substr(basename(files), 1, 11), bytes = file.size(files))[, .(bytes = sum(bytes)), by = id]
cell_stats <- merge(a, bytes, by = "id", all.x = TRUE)[, .(attempts = .N, seconds = sum(seconds),
  bytes = sum(bytes, na.rm = TRUE), accepted = sum(reason == "accepted")), by = cell]
set.seed(11)
draws <- matrix(NA_real_, nrow = 2000, ncol = 4, dimnames = list(NULL, c("attempts", "selection_hours", "added_GiB", "stations")))
for (i in seq_len(nrow(draws))) {
  b <- cell_stats[sample.int(nrow(cell_stats), replace = TRUE)]
  draws[i, ] <- c(mean(b$attempts), mean(b$seconds) / 4 / 3600, mean(b$bytes) / 1024^3, mean(b$accepted)) * metrics$cells_total
}
projection <- data.table(quantity = colnames(draws), estimate = c(mean(cell_stats$attempts), mean(cell_stats$seconds) / 4 / 3600,
  mean(cell_stats$bytes) / 1024^3, mean(cell_stats$accepted)) * metrics$cells_total,
  bootstrap_p025 = apply(draws, 2, quantile, .025), bootstrap_p975 = apply(draws, 2, quantile, .975))
fwrite(cell_stats, file.path(out, "pilot-64-resources-by-cell.csv"))
fwrite(projection, file.path(out, "pilot-resource-projection.csv"))
fwrite(a[, .(candidates = .N, seconds = sum(seconds)), by = reason], file.path(out, "pilot-rejections.csv"))
print(projection)

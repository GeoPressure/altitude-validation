# Check source-specific QC meanings against the station-curation evidence.
source("R/utils.R")
out <- "output/drafts/atmospheric-figures"
prefixes <- c("era5_tail_review", "era5_followup_review", "era5_extended_review", paste0("era5_batch", 4:7, "_review"))
quality <- list()
extremes <- list()
for (prefix in prefixes) {
  s <- fread(file.path(out, paste0(prefix, "_stations_review.csv")))
  d <- as.data.table(read_parquet(file.path(out, paste0(prefix, "_station_records.parquet"))))
  d <- merge(d, s[, .(id, elev)], by = "id")
  d[, dev := abs(altitude - elev - median(altitude - elev)), by = id]
  quality[[prefix]] <- d[, .(n = .N, median_dev = median(dev), max_dev = max(dev)), by = .(id, source_code, quality_code)]
  extremes[[prefix]] <- d[order(-dev), head(.SD, 3), by = id][, .(id, date, pressure, altitude, dev, source_code, quality_code)]
}
fwrite(unique(rbindlist(quality)), file.path(out, "curation_quality_codes.csv"))
extremes <- unique(rbindlist(extremes), by = c("id", "date", "pressure", "source_code"))
fwrite(extremes, file.path(out, "curation_quality_extremes.csv"))
print(extremes[dev > 100, .N, by = .(source_code, quality_code)])

# Count accepted source/QC combinations without conflating source-specific code 4.
stations <- fread(file.path(selection_dir("ghcnh"), "full-accepted.csv"))
quality <- list()
for (id_value in stations$id) {
  d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(id_value, ".parquet")),
    col_select = c("quality_code", "source_code")))
  quality[[id_value]] <- d[, .N, by = .(source_code, quality_code)]
}
quality <- rbindlist(quality)[, .(n = sum(N)), by = .(source_code, quality_code)]
fwrite(quality, file.path(out, "current_accepted_quality_codes.csv"))
print(quality[quality_code == "4" | quality_code %in% c("A", "U", "P", "I", "M", "R") | source_code == "401"])

stopifnot(nrow(quality[quality_code %in% c("2", "3", "6", "7") |
  (quality_code == "5" & source_code %in% c("220", "221", "222", "223", "347", "348")) |
  grepl("[a-z]", quality_code)]) == 0)

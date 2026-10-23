# Diagnose selected residual tails without changing station selection.
source("R/utils.R")
out <- "output/drafts/atmospheric-figures"
batch <- grep("^batch[0-9]+$", commandArgs(trailingOnly = TRUE), value = TRUE)
prefix <- if (length(batch)) paste0("era5_", batch, "_review") else if ("review" %in% commandArgs(trailingOnly = TRUE)) "era5_extended_review" else if ("more" %in% commandArgs(trailingOnly = TRUE)) "era5_followup_review" else "era5_tail_review"
s <- fread(file.path(out, paste0(prefix, "_stations_review.csv")))
d <- as.data.table(read_parquet(file.path(out, paste0(prefix, "_station_records.parquet"))))
d <- merge(d, s[, .(id, elev, name)], by = "id")
setorder(d, id, date)
d[, error := altitude - elev]
d[, `:=`(gap_hours = as.numeric(difftime(date, shift(date), units = "hours")),
  pressure_change = pressure - shift(pressure)), by = id]

# Separate sparse excursions, shifts and persistent scatter.
monthly <- d[, .(n = .N, bias = mean(error), sd = sd(error), median_error = median(error),
  pressure_median = median(pressure)), by = .(id, name, month = format(date, "%Y-%m"))]
fwrite(monthly, file.path(out, paste0(prefix, "_monthly.csv")))
summary <- d[, .(n = .N, bias = mean(error), sd = sd(error), median_error = median(error),
  robust_sd = mad(error), p01 = quantile(error, .01), p99 = quantile(error, .99),
  n_above100 = sum(abs(error - median(error)) > 100),
  jumps_above10_within3h = sum(abs(pressure_change) > 10 & gap_hours <= 3, na.rm = TRUE)), by = .(id, name)]
summary <- merge(summary, d[gap_hours <= 3, .(max_jump_within3h = max(abs(pressure_change))), by = id], by = "id", all.x = TRUE)
fwrite(summary, file.path(out, paste0(prefix, "_diagnostics.csv")))

# A timestamp mismatch would reduce pressure residual SD at a nonzero lag.
d[, expected_pressure := sp_sl / 100 * (1 - .0065 * (elev - z_sl) / t2m_sl)^(9.80665 * .0289644 / (8.31432 * .0065))]
lags <- list()
for (id_value in s$id) {
  v <- d[id == id_value]
  for (lag_hours in -26:26) {
    e <- v[, .(date = date + lag_hours * 3600, expected_pressure)]
    p <- merge(v[, .(date, pressure)], e, by = "date")
    lags[[length(lags) + 1L]] <- p[, .(id = id_value, lag_hours = lag_hours, n = .N,
      pressure_residual_sd = sd(pressure - expected_pressure))]
  }
}
lags <- rbindlist(lags)
fwrite(lags, file.path(out, paste0(prefix, "_lags.csv")))
print(summary)
print(lags[order(pressure_residual_sd), .SD[1], by = id])

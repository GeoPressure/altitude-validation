# Test persistent pressure-level transitions across reporting gaps.
source("R/utils.R")
source("R/ghcnh_sampling.R")
setDTthreads(1)
stations <- fread("output/drafts/pattern-application/previous_accepted.csv")
results <- list()
for (i in seq_len(nrow(stations))) {
  s <- stations[i]
  d <- ghcnh_pressure_spikes(as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/pressure", paste0(s$id, ".parquet")))))
  d[, `:=`(previous = shift(date), jump = pressure - shift(pressure))]
  candidates <- d[date >= as.POSIXct(s$window_start, tz = "UTC") & date < as.POSIXct(s$window_end, tz = "UTC") &
    previous >= as.POSIXct(s$window_start, tz = "UTC") & as.numeric(difftime(date, previous, units = "hours")) >= 24 & as.numeric(difftime(date, previous, units = "hours")) <= 168 & abs(jump) >= 10]
  for (j in seq_len(nrow(candidates))) {
    e <- candidates[j]
    pre <- d[date > e$previous - 28 * 86400 & date <= e$previous,
      .(n = .N, pressure = median(pressure)), by = .(day = floor(as.numeric(difftime(date, e$previous + 3600, units = "days"))))][n >= 4]
    post <- d[date >= e$date & date < e$date + 28 * 86400,
      .(n = .N, pressure = median(pressure)), by = .(day = floor(as.numeric(difftime(date, e$date, units = "days"))))][n >= 4]
    pre <- pre[, .(days = .N, pressure = median(pressure)), by = .(week = floor(day / 7))]
    post <- post[, .(days = .N, pressure = median(pressure)), by = .(week = floor(day / 7))]
    if (nrow(pre) != 4 || nrow(post) != 4 || any(c(pre$days, post$days) < 1) || sum(pre$days) < 12 || sum(post$days) < 12) next
    spread <- max(diff(range(pre$pressure)), diff(range(post$pressure)))
    persistent <- min(sign(e$jump) * (post$pressure - median(pre$pressure)))
    results[[length(results) + 1L]] <- data.table(id = s$id, previous = e$previous, date = e$date, jump = e$jump,
      spread = spread, persistent = persistent, flag = spread <= abs(e$jump) / 4 & persistent >= abs(e$jump) / 2)
  }
}
r <- rbindlist(results)
fwrite(r, "output/drafts/pattern-application/gap_step_candidates.csv")
print(r[flag == TRUE])

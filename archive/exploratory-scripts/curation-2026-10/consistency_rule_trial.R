# Offline trial of candidate consistency rules on cached station data; ERA5 joined only to evaluate.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/ghcnh_consistency.R")
setDTthreads(1)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
acc <- fread("data/interim/ghcnh/selection-curated-2026-10-22/full-accepted.csv")
st <- fread("output/tables/ground_station_stats.csv")[network == "ghcnh", .(id, bias = bias_sl, sd = sd_sl)]
r <- consistency_rules
trial <- function(i) {
  s <- acc[i]
  o <- ghcnh_pressure_spikes(as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(s$id, ".parquet")))))
  x <- ghcnh_consistency_inputs(o, as.data.table(read_parquet(file.path(run_dir, "reference", paste0(s$id, ".parquet")))), s)
  tol_slp <- r$height_m + r$slp_height_fraction * max(s$elev, 0)
  x[, h := fifelse(is.finite(h_alt), h_alt, h_slp) - s$elev]
  x[, tol := fifelse(is.finite(h_alt), r$height_m, tol_slp)]
  inside <- x$date >= as.POSIXct(s$window_start, tz = "UTC") & x$date < as.POSIXct(s$window_end, tz = "UTC")
  daily <- x[inside & is.finite(h), .(h = median(h), tol = tol[1], .N), by = .(day = as.Date(date))][N >= 4]
  monthly <- x[is.finite(h), .(h = median(h), tol = median(tol), .N), by = .(m = format(date, "%Y-%m"))][N >= r$month_reports][order(m)]
  monthly[, out := abs(h) > tol]
  data.table(id = s$id, day_excess = if (nrow(daily)) max(abs(daily$h) / daily$tol) else NA_real_,
    full_run = if (nrow(monthly)) max(rle(monthly$out)$lengths[rle(monthly$out)$values], 0L) else 0L)
}
d <- merge(rbindlist(parallel::mclapply(seq_len(nrow(acc)), trial, mc.cores = 10)), st, by = "id")
fwrite(d, "output/drafts/station-consistency/rule_trial.csv")
summ <- function(x) x[, .(n = .N, b20 = sum(abs(bias) > 20), b30 = sum(abs(bias) > 30), sd20 = sum(sd > 20), clean = sum(abs(bias) < 10 & sd < 10))]
for (k in c(2, 3, 5)) cat("daily >", k, "x tol:", unlist(summ(d[day_excess > k])), "\n")
for (k in 1:3) cat("full-record run >=", k, "months:", unlist(summ(d[full_run >= k])), "\n")
cat("all:", unlist(summ(d)), "\n")
cat("both (daily>3, run>=2) removed:", unlist(summ(d[day_excess > 3 | full_run >= 2])), " kept:", unlist(summ(d[!(day_excess > 3 | full_run >= 2)])), "\n")
print(d[full_run >= 2 & abs(bias) < 10 & sd < 10][1:15])

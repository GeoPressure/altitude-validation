source('R/utils.R')
source('R/ghcnh_sampling.R')
load_geopressurer()
setDTthreads(1)
run_dir <- 'data/interim/ghcnh/selection-2026-10-13'
settings <- readRDS(file.path(run_dir, 'settings.rds'))
x <- fread('output/drafts/atmospheric-figures/ground_no_era5_screen_stations.csv')[formula == 'standard']
ids <- unique(c(x[order(-sd)][1:15]$id, x[order(-abs(bias))][1:10]$id, x[order(abs(sd - median(sd)))][1:5]$id))
candidates <- readRDS(file.path(run_dir, 'candidates.rds'))
results <- list()
examples <- list()
for (id_value in ids) {
  s <- candidates[id == id_value]
  o <- as.data.table(read_parquet(file.path(run_dir, 'pressure', paste0(id_value, '.parquet'))))
  e <- as.data.table(read_parquet(file.path(run_dir, 'core', paste0(id_value, '.parquet'))))
  d <- merge(o, e, by='date')[is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m) & is.finite(z_sl)]
  endpoint <- ghcnh_window(d, settings, clean=FALSE)
  d <- d[as.Date(date, tz='UTC') >= endpoint %m-% years(1) & as.Date(date, tz='UTC') < endpoint][order(date)]
  d[, error := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
  d[, `:=`(p_before=shift(pressure), p_after=shift(pressure, type='lead'),
    dt_before=as.numeric(difftime(date, shift(date), units='hours')),
    dt_after=as.numeric(difftime(shift(date,type='lead'), date, units='hours')))]
  d[, spike := dt_before <= 3 & dt_after <= 3 & abs(p_before-p_after) <= 5 &
    abs(pressure-(p_before+p_after)/2) > 10]
  d[is.na(spike), spike := FALSE]
  results[[length(results)+1L]] <- d[, .(id=id_value, name=s$name, n=.N,
    pressure_min=min(pressure), pressure_max=max(pressure),
    error_sd=sd(error), error_mad=mad(error), error_iqr=IQR(error)/1.349,
    median_error=median(error), mean_error=mean(error), spikes=sum(spike),
    filtered_sd=sd(error[!spike]), filtered_mad=mad(error[!spike]),
    jumps20=sum(abs(pressure-p_before)>20 & dt_before<=3, na.rm=TRUE),
    jump_max=max(abs(pressure-p_before)[dt_before<=3],na.rm=TRUE))]
  examples[[length(examples)+1L]] <- d[, .(id=id_value,date,pressure,error,spike)]
}
r <- rbindlist(results)
fwrite(r, 'output/drafts/atmospheric-figures/pressure_timeseries_filter_review.csv')
write_parquet(rbindlist(examples), 'output/drafts/atmospheric-figures/pressure_timeseries_filter_examples.parquet')
print(r)

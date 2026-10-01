# In-flight error averaged over the heights at which tracked birds fly.
#
# The per-height errors (flight_height.csv, 12_analysis.R) are weighted by the share of bird flight time
# in each height bin (00_bird_heights.R). Kept separate from 12_analysis.R so that a change of the
# bird height distribution does not require refitting the models of 12_analysis.R.

source("R/utils.R")

tabB <- fread(file.path(dir_tables, "flight_height.csv"))
bird_bins <- bird_height_weights()
bw <- merge(tabB, bird_bins[, .(hbin, prop)], by = "hbin")
bird_w <- bw[, .(
  mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop)), bias = sum(bias * prop)
), by = method]
fwrite(bird_w, file.path(dir_tables, "flight_bird_weighted.csv"))
print(bird_w)

# Equal-tag robustness check using the primary airborne errors -------------
source("R/utils.R")
B <- load_radiosondes(load_stations(), c("id", "band", "lsh", "sdoy", "err_isa", "err_standard", "err_virtual", "sounding"))
weights <- fread(file.path(dir_tables, "bird_target_height_weights.csv"))[variant %in% c("all_flight", "equal_bird")]
B[, w_band := w / sum(w), by = hbin]
result <- rbindlist(lapply(unique(weights$variant), function(target) {
  p <- weights[variant == target]
  w_target <- B$w_band * p$prop[match(as.character(B$hbin), p$hbin)]
  rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
    data.table(variant = target, formula = f, medae = wquant(abs(B[[paste0("err_", f)]]), w_target, .5))
  }))
}))
primary <- fread(file.path(dir_tables, "paper_flight_bird.csv"))
check <- merge(result[variant == "all_flight"], primary, by = "formula")
stopifnot(max(abs(check$medae.x - check$medae.y)) < 1e-7)
fwrite(result, file.path(dir_tables, "paper_bird_target_sensitivity.csv"))
fwrite(B[, .(stations = uniqueN(id), soundings = uniqueN(paste(id, sounding)), levels = .N), by = hbin],
  file.path(dir_tables, "paper_flight_support.csv"))
print(result)

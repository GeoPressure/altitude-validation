# Run after compare_designs.R, from the project root.
library(data.table)
library(ggplot2)
out <- "docs/methods/T06"
dir.create(file.path(out, "figures"), showWarnings = FALSE)

# Separate a height-only change from the change of pressure archive ----------
swiss <- fread("output/tables/meteoswiss_vs_hadisd.csv")[is.finite(bias_hadisd) & is.finite(bias_meteoswiss)]
swiss[, bias_height_only := bias_hadisd + d_barometer]
fwrite(swiss, file.path(out, "swiss_height_only.csv"))
fwrite(swiss[, .(stations = .N, median_abs_hadisd = median(abs(bias_hadisd)), median_abs_height_only = median(abs(bias_height_only)), median_abs_meteoswiss = median(abs(bias_meteoswiss)), mean_abs_hadisd = mean(abs(bias_hadisd)), mean_abs_height_only = mean(abs(bias_height_only)), mean_abs_meteoswiss = mean(abs(bias_meteoswiss)), median_abs_archive_difference_after_height_change = median(abs(bias_height_only - bias_meteoswiss)))], file.path(out, "swiss_height_summary.csv"))
sw <- melt(swiss, id.vars = "id", measure.vars = c("bias_hadisd", "bias_height_only", "bias_meteoswiss"), variable.name = "reference", value.name = "bias")
sw[, reference := factor(reference, c("bias_hadisd", "bias_height_only", "bias_meteoswiss"), c("HadISD\nlisted height", "Same HadISD pressure\npublished barometer height", "MeteoSwiss pressure\npublished barometer height"))]
p <- ggplot(sw, aes(reference, abs(bias))) + geom_line(aes(group = id), colour = "grey75", linewidth = 0.3) + geom_point(colour = "#356CA5", size = 1.5, alpha = 0.65) + stat_summary(fun = median, geom = "point", shape = 18, size = 4, colour = "#B64535") + labs(x = NULL, y = "Absolute station mean error (m)", caption = "32 matched stations. Red diamonds: medians. The middle column changes only the reference height.") + theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank())
ggsave(file.path(out, "figures/swiss-height-check.png"), p, width = 8, height = 4.5, dpi = 180)

# Screening and weighting contrasts ---------------------------------------
g <- fread(file.path(out, "ground_filter_weighting.csv"))
g <- g[weighting == "existing_cell" & rule %in% c("no_station_screen", "step_and_noise_only", "current_screen", "strict_screen")]
g[, rule := factor(rule, c("no_station_screen", "step_and_noise_only", "current_screen", "strict_screen"), c("No station\nscreen", "Step/noise\nonly", "Current\nscreen", "Stricter\nscreen"))]
g[, formula := factor(formula, c("isa", "standard", "virtual"), c("Standard atmosphere", "ERA5 standard", "ERA5 virtual + GPT3"))]
p <- ggplot(g, aes(rule, mae, group = formula)) + geom_line(colour = "#356CA5") + geom_point(colour = "#356CA5", size = 2) + facet_wrap(~formula, scales = "free_y") + labs(x = NULL, y = "Station/cell-weighted mean absolute error (m)", caption = "Same saved pressure inputs for all three conversions; isolated gross-error observations removed in all panels.\nEach panel has its own vertical scale. Screening is based on ERA5-standard residuals.") + theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank())
ggsave(file.path(out, "figures/ground-screening.png"), p, width = 9, height = 4, dpi = 180)

# Compact tables for the recommendation ------------------------------------
draws <- fread(file.path(out, "one_station_per_cell_draws.csv"))
fwrite(draws[, .(draws = .N, stations = stations[1], high_stations_min = min(high_stations), high_stations_max = max(high_stations), mae_min = min(mae), mae_p025 = unname(quantile(mae, 0.025)), mae_median = median(mae), mae_p975 = unname(quantile(mae, 0.975)), mae_max = max(mae)), by = formula], file.path(out, "one_station_draw_summary.csv"))
f <- fread(file.path(out, "flight_weighting.csv"))
f0 <- f[variant == "current", .(formula, hbin, baseline_mae = mae, baseline_p95 = p95_abs)]
f <- merge(f, f0, by = c("formula", "hbin"))
f[, `:=`(mae_change = mae - baseline_mae, p95_change = p95_abs - baseline_p95)]
fwrite(f, file.path(out, "flight_weighting_changes.csv"))
cat("\nGround screens\n"); print(fread(file.path(out, "ground_filter_weighting.csv"))[weighting == "existing_cell" & rule %in% c("no_station_screen", "step_and_noise_only", "current_screen", "strict_screen", "loose_screen"), .(rule, formula, stations, mae, median_abs_bias, median_station_sd)])
cat("\nGround spatial weights\n"); print(fread(file.path(out, "ground_filter_weighting.csv"))[rule == "current_screen", .(weighting, formula, mae)])
cat("\nOne-station draws\n"); print(fread(file.path(out, "one_station_draw_summary.csv")))
cat("\nGNSS duplicates\n"); print(fread(file.path(out, "gnss_duplicate_sensitivity.csv")))
cat("\nFlight weighting\n"); print(fread(file.path(out, "flight_weighting_bird.csv")))

# Height-band support: levels and distinct soundings are different denominators.
support <- fread(file.path(out, "flight_sampling_bin.csv"))
meta <- fread("output/tables/stations.csv")[network == "igra", .(id, elev)]
support <- merge(support, meta, by = "id")
fwrite(support[, .(stations = uniqueN(id), high_stations = uniqueN(id[elev > 1000]), levels = sum(levels), station_soundings = sum(soundings), min_levels_station = min(levels), median_levels_station = as.numeric(median(levels)), max_levels_station = max(levels), stations_under30_soundings = sum(soundings < 30), stations_under100_soundings = sum(soundings < 100)), by = hbin], file.path(out, "flight_bin_support.csv"))

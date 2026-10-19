# Reweight unchanged reference-error curves after rebuilding the published bird-height distribution.
# Run from the project root after step 00. Full steps 13, 18 and 20 produce the same summaries.
source("R/utils.R")
bb <- bird_height_weights()[, .(hbin, prop)]
inputs <- file.path(dir_tables, c("bird_height_distribution.csv", "bird_height_provenance.json", "paper_flight_height.csv", "paper_flight_weighting_height.csv", "flight_height.csv", "bird_target_height_weights.csv", "bird_target_support.csv"))

# Main and supplementary reference comparisons ------------------------------
x <- merge(fread(file.path(dir_tables, "paper_flight_height.csv")), bb, by = "hbin")
fwrite(x[, .(bias = sum(bias * prop), mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop))), by = formula], file.path(dir_tables, "paper_flight_bird.csv"))
x <- merge(fread(file.path(dir_tables, "paper_flight_weighting_height.csv")), bb, by = "hbin")
fwrite(x[, .(bias = sum(bias * prop), mae = sum(mae * prop)), by = .(variant, formula)], file.path(dir_tables, "paper_flight_weighting_sensitivity.csv"))
x <- merge(fread(file.path(dir_tables, "flight_height.csv")), bb, by = "hbin")
fwrite(x[, .(mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop)), bias = sum(bias * prop)), by = method], file.path(dir_tables, "flight_bird_weighted.csv"))

# Biological target comparisons use the separately cached empirical height weights.
x <- merge(fread(file.path(dir_tables, "bird_target_height_weights.csv")), fread(file.path(dir_tables, "paper_flight_height.csv")), by = "hbin", allow.cartesian = TRUE)
x <- x[, .(bias = sum(bias * prop), mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop))), by = .(variant, formula)]
fwrite(merge(fread(file.path(dir_tables, "bird_target_support.csv")), x, by = "variant"), file.path(dir_tables, "paper_bird_target_sensitivity.csv"))

# Verify common primary curve and sensitivity aggregation -------------------
x <- merge(fread(file.path(dir_tables, "paper_flight_weighting_sensitivity.csv"))[variant == "current"], fread(file.path(dir_tables, "paper_flight_bird.csv")), by = "formula")
stopifnot(max(abs(x$bias.x - x$bias.y)) < 1e-7, max(abs(x$mae.x - x$mae.y)) < 1e-7)
jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), note = "Updated biological weights only. Reference error curves and their original generation provenance remain unchanged; full steps 13, 18 and 20 reproduce these summaries.", doi = "10.5281/zenodo.18187093", source_md5 = as.list(tools::md5sum(c("R/utils.R", "docs/methods/T07/update_cached_weights.R"))), input_md5 = as.list(tools::md5sum(inputs))), file.path(dir_tables, "paper_bird_reweight_provenance.json"), pretty = TRUE, auto_unbox = TRUE)

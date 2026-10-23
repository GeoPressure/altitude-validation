# Evaluate the fixed pressure-only selection against ERA5 afterward.
source("R/utils.R")
out <- "output/drafts/pressure-filter"
previous <- fread(file.path(out, "previous_selection.csv"))
current <- fread(file.path(dir_tables, "ground_selection.csv"))
paired <- merge(previous, current, by = "cell", all = TRUE, suffixes = c("_before", "_after"))
curation <- fread("docs/methods/ghcnh_curation_exclusions.csv")
reference <- fread("docs/methods/ghcnh_reference_exclusions.csv")
summary <- data.table(candidate_cells = nrow(current), stations_before = previous[!is.na(start), .N],
  stations_after = current[!is.na(start), .N],
  newly_represented_cells = paired[is.na(start_before) & !is.na(start_after), .N],
  lost_cells = paired[!is.na(start_before) & is.na(start_after), .N],
  changed_station = paired[!is.na(start_before) & !is.na(start_after) & id_before != id_after, .N],
  changed_year_same_station = paired[!is.na(start_before) & !is.na(start_after) & id_before == id_after &
    (start_before != start_after | end_before != end_after), .N],
  historical_curation_stations_now_selected = sum(current$id %in% setdiff(curation$id, reference$id)),
  spikes_removed = sum(current$n_spikes))
fwrite(summary, file.path(out, "selection_comparison.csv"))
print(summary)
previous <- fread(file.path(out, "previous_station_errors.csv"))[reference == "GHCNh" & formula == "standard"]
current <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh" & formula == "standard"]
comparison <- rbindlist(list(before = previous[, .(stations = .N, median_absolute_bias = median(abs(bias)), median_sd = median(sd))],
  after = current[, .(stations = .N, median_absolute_bias = median(abs(bias)), median_sd = median(sd))]), idcol = "selection")
tails <- rbindlist(list(before = fread(file.path(out, "previous_error_summaries.csv")),
  after = fread(file.path(dir_tables, "paper_ground_tails.csv"))), idcol = "selection")
comparison <- merge(comparison, tails[reference == "GHCNh" & formula == "standard", .(selection, median_absolute_error = medae, p95_absolute_error = p95_abs)], by = "selection")
fwrite(comparison, file.path(out, "era5_comparison.csv"))
print(comparison)

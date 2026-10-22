# Audit whether the cached DWD archives supply a distinct barometer-height reference.
source("R/utils.R")
files <- list.files(file.path(dir_raw, "dwd"), "_hist[.]zip$", full.names = TRUE)
metadata <- rbindlist(lapply(files, function(f) {
  members <- unzip(f, list = TRUE)$Name
  member <- members[grepl("^Metadaten_Geraete_Luftdruck_Stationshoehe_.*[.]txt$", members)]
  text <- readLines(unz(f, member), warn = FALSE, encoding = "latin1")
  text <- iconv(text, "latin1", "UTF-8")
  text <- text[!grepl("^generiert:", text) & nzchar(text)]
  d <- fread(text = paste(text, collapse = "\n"), sep = ";", encoding = "UTF-8")
  setnames(d, names(d), iconv(names(d), "UTF-8", "ASCII//TRANSLIT"))
  d[, archive := basename(f)]
  d
}), fill = TRUE)
metadata[, `:=`(from = as.Date(as.character(Von_Datum), "%Y%m%d"),
  to = as.Date(as.character(Bis_Datum), "%Y%m%d"))]
metadata[is.na(to), to := as.Date("2100-01-01")]
metadata <- metadata[from <= as.Date("2026-12-31") & to >= as.Date("2022-01-01")]
metadata[, sensor_height_reported := is.finite(`Geberhoehe ueber Grund [m]`)]
fwrite(metadata, file.path(dir_interim, "dwd", "barometer_metadata_audit.csv"))
summary <- metadata[, .(stations = uniqueN(Stations_ID), metadata_periods = .N,
  stations_with_sensor_height = uniqueN(Stations_ID[sensor_height_reported]))]
fwrite(summary, file.path(dir_interim, "dwd", "barometer_metadata_summary.csv"))
print(summary)

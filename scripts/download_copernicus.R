# Retrieve the Copernicus global surface archive and the overlapping GRUAN reference soundings.
#
# This is a standalone data intake step because the global sub-daily requests can be large. It
# uses the CDS account configured for ecmwfr; accept both datasets' licence terms in the CDS web
# interface before running it. Output is kept separate from the analysis inputs.

source("R/utils.R")

out_dir <- file.path(dir_interim, "copernicus")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Use the current CDS retrieval endpoint. The installed ecmwfr release submits to the older
# `/execute` route, which returned an internal-server error for this newer dataset.
cds_retrieve <- function(dataset, inputs, target) {
  key <- ecmwfr:::wf_get_key(user = "ecmwfr")
  base <- "https://cds.climate.copernicus.eu/api/retrieve/v1"
  response <- httr2::request(sprintf("%s/processes/%s/execution", base, dataset)) |>
    httr2::req_headers(`PRIVATE-TOKEN` = key) |>
    httr2::req_body_json(list(inputs = inputs), auto_unbox = TRUE) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_is_error(response)) {
    stop(httr2::resp_body_string(response), call. = FALSE)
  }
  job <- httr2::resp_body_json(response)
  started <- Sys.time()
  repeat {
    Sys.sleep(20)
    status <- httr2::request(sprintf("%s/jobs/%s", base, job$jobID)) |>
      httr2::req_headers(`PRIVATE-TOKEN` = key) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    message(dataset, " ", status$status,
      if (!is.null(status$progress)) paste0(" (", status$progress, "%)") else "")
    if (status$status == "successful") break
    if (status$status %in% c("failed", "dismissed", "cancelled")) {
      stop(dataset, " request failed: ", status$message, call. = FALSE)
    }
    if (as.numeric(difftime(Sys.time(), started, units = "secs")) > 86400) {
      stop(dataset, " request did not finish within 24 hours; job ID: ", job$jobID,
        call. = FALSE)
    }
  }
  results <- httr2::request(sprintf("%s/jobs/%s/results", base, job$jobID)) |>
    httr2::req_headers(`PRIVATE-TOKEN` = key) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
  result_fields <- unlist(results, recursive = TRUE, use.names = TRUE)
  download_url <- result_fields[grepl("href$", names(result_fields))][1]
  if (is.na(download_url)) stop("CDS returned no download link for ", dataset, call. = FALSE)
  curl_download(download_url, target)
  invisible(target)
}

# ---- Global land observations ----------------------------------------------------------------
for (year in years_main) {
  for (month in sprintf("%02d", 1:12)) {
    out <- file.path(out_dir, sprintf("surface_land_%d_%s.zip", year, month))
    if (file.exists(out)) next
    cds_retrieve(
      dataset = "insitu-observations-surface-land",
      inputs = list(
        version = "3_0_0",
        time_aggregation = "sub_daily",
        variable = c("air_pressure", "air_pressure_at_sea_level", "air_temperature",
          "dew_point_temperature"),
        year = as.character(year),
        month = month,
        day = sprintf("%02d", 1:31),
        data_format = "csv"
      ),
      target = out
    )
  }
}

# ---- GRUAN reference soundings ----------------------------------------------------------------
# The current CDS GRUAN product covers 2006-2020 (RS92 and Meisei RS-11G). 2015 overlaps the
# project's historical ERA5 sensitivity years. Its pressure is a reference radiosonde product;
# retain the reported height and uncertainty fields for assessment of independence and provenance.
for (month in sprintf("%02d", 1:12)) {
  gruan_file <- file.path(out_dir, sprintf("gruan_2015_%s.zip", month))
  if (file.exists(gruan_file)) next
  cds_retrieve(
    dataset = "insitu-observations-gruan-reference-network",
    inputs = list(
      version = "1_0_0",
      variable = c("air_pressure", "air_temperature", "altitude", "geopotential_height"),
      year = "2015",
      month = month,
      day = sprintf("%02d", 1:31),
      data_format = "csv"
    ),
    target = gruan_file
  )
}

jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  surface_land = list(dataset = "insitu-observations-surface-land", version = "3_0_0",
    years = years_main, variables = c("air_pressure", "air_pressure_at_sea_level",
      "air_temperature", "dew_point_temperature")),
  gruan = list(dataset = "insitu-observations-gruan-reference-network", version = "1_0_0",
    years = 2015, note = "CDS GRUAN product covers 2006-2020")),
  file.path(out_dir, "provenance.json"), pretty = TRUE, auto_unbox = TRUE)

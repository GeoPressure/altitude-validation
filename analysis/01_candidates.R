# Candidate stations of both networks: station inventories, archive availability, 200 km equal-area
# cells and a random candidate order within each cell. Existing files are kept, so that later
# archive updates do not change the frozen candidate lists.
source("R/utils.R")
source("R/ghcnh.R")

settings <- list(
  ghcnh = list(
    start = as.POSIXct("2022-01-01", tz = "UTC"),
    end = as.POSIXct("2026-10-13", tz = "UTC"),
    years = 2022:2026,
    width_m = 200000,
    seed = 11L,
    pressure_min = 300,
    pressure_max = 1100,
    days_per_month = 15L,
    hours_per_day = 4L,
    base = "https://www.ncei.noaa.gov/oa/global-historical-climatology-network"
  ),
  igra = list(
    start = as.POSIXct("2022-01-01", tz = "UTC"),
    end = as.POSIXct("2026-10-13", tz = "UTC"),
    years = 2022:2026,
    width_m = 200000,
    seed = 11L,
    days_per_month = 15L,
    max_agl = 6000,
    ascent_m_s = 5,
    height_breaks = c(
      0,
      100,
      250,
      500,
      1000,
      1500,
      2000,
      3000,
      4000,
      5000,
      6000
    ),
    base = "https://www.ncei.noaa.gov/data/integrated-global-radiosonde-archive"
  )
)

# Stations with a valid position and elevation in the archive's station list.
read_inventory <- function(file, url) {
  if (!file.exists(file)) {
    curl_download(url, file)
  }
  x <- readLines(file, warn = FALSE, encoding = "UTF-8")
  d <- data.table(
    id = trimws(substr(x, 1, 11)),
    lat = as.numeric(substr(x, 13, 20)),
    lon = as.numeric(substr(x, 22, 30)),
    elev = as.numeric(substr(x, 32, 37)),
    name = trimws(substr(x, 42, 71)),
    first = suppressWarnings(as.integer(substr(x, 73, 76))),
    last = suppressWarnings(as.integer(substr(x, 78, 81)))
  )
  d[
    is.finite(lat) &
      is.finite(lon) &
      abs(lat) <= 90 &
      abs(lon) <= 180 &
      is.finite(elev) &
      elev > -900
  ]
}

# Equal Earth (EPSG:8857) grid cells of `width_m` and a seeded random order within each cell.
assign_cells <- function(candidates, s) {
  xy <- sf::st_coordinates(sf::st_transform(
    sf::st_as_sf(candidates, coords = c("lon", "lat"), crs = 4326),
    8857
  ))
  candidates[,
    cell := paste(
      floor(xy[, 1] / s$width_m),
      floor(xy[, 2] / s$width_m),
      sep = "_"
    )
  ]
  setorder(candidates, cell, id)
  set.seed(s$seed)
  candidates[, candidate_order := sample.int(.N), by = cell]
  candidates[]
}

for (network in names(settings)) {
  s <- settings[[network]]
  run_dir <- network_dir(network, "candidates")
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(s, file.path(run_dir, "settings.rds"))
  if (file.exists(file.path(run_dir, "candidates.rds"))) {
    next
  }
  if (network == "ghcnh") {
    inventory <- read_inventory(
      file.path(dir_raw, "ghcnh-station-list.txt"),
      paste0(s$base, "/hourly/doc/ghcnh-station-list.txt")
    )[, .(id, lat, lon, elev, name)]
    # Station files published for each year of the study period.
    catalogue <- rbindlist(lapply(
      s$years,
      ghcnh_catalogue,
      run_dir = run_dir,
      base = s$base
    ))
    candidates <- inventory[id %in% catalogue$id][order(id)]
  } else {
    inventory <- read_inventory(
      file.path(dir_raw, "igra2-station-list.txt"),
      paste0(s$base, "/doc/igra2-station-list.txt")
    )
    inventory <- inventory[first <= max(s$years) & last >= min(s$years)]
    # Stations with a period-of-record data file in the archive.
    catalogue_file <- file.path(run_dir, "catalogue.rds")
    if (!file.exists(catalogue_file)) {
      html <- httr2::request(paste0(s$base, "/access/data-por/")) |>
        httr2::req_retry(max_tries = 4) |>
        httr2::req_timeout(120) |>
        httr2::req_perform() |>
        httr2::resp_body_string()
      rows <- xml2::xml_find_all(
        xml2::read_html(html),
        "//tr[td/a[contains(@href, '-data.txt.zip')]]"
      )
      catalogue <- data.table(
        id = sub(
          "-data.txt.zip$",
          "",
          xml2::xml_attr(xml2::xml_find_first(rows, "td/a"), "href")
        ),
        modified = xml2::xml_text(xml2::xml_find_first(rows, "td[2]")),
        bytes = as.numeric(xml2::xml_text(xml2::xml_find_first(rows, "td[3]")))
      )
      ghcnh_save(catalogue, catalogue_file)
    }
    catalogue <- readRDS(catalogue_file)
    candidates <- merge(inventory, catalogue, by = "id")
  }
  candidates <- assign_cells(candidates, s)
  ghcnh_save(candidates, file.path(run_dir, "candidates.rds"))
  cli::cli_alert_success(
    "{network}: {nrow(candidates)} candidates in {uniqueN(candidates$cell)} cells"
  )
}

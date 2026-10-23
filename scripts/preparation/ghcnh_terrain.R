# Check cached candidate coordinates before selecting pressure windows.
source("R/utils.R")
source("R/ghcnh_terrain.R")
candidates <- as.data.table(readRDS("data/interim/ghcnh/selection-2026-10-13/candidates.rds"))
cached <- tools::file_path_sans_ext(list.files("data/interim/ghcnh/selection-2026-10-13/pressure", pattern = "parquet$"))
s <- ghcnh_terrain(candidates[id %in% cached])
cli::cli_alert_success("Terrain check: {sum(s$terrain_ok)}/{nrow(s)} cached candidates pass")

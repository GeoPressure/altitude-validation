# Numbers quoted in the manuscript and supplement, formatted as printed, in one table
# (results/manuscript_values.csv) read by manuscript/paper.qmd and manuscript/supplement.qmd.
source("R/utils.R")
tab <- function(f) fread(file.path(dir_tables, f))
r0 <- function(x) formatC(x, format = "f", digits = 0, big.mark = ",")
r1 <- function(x) formatC(x, format = "f", digits = 1)
pct <- function(x) paste0(round(100 * x), "%")
v <- list()

# ---- Samples ---------------------------------------------------------------------------------
st <- tab("stations.csv")
bird <- tab("bird_height_sample.csv")
v$n_ghcnh <- r0(st[network == "ghcnh", .N])
v$n_sonde <- r0(nrow(tab("flight_stations_used.csv")))
v$n_tags <- bird$n_tags
v$n_species <- bird$n_species
v$geopressurer <- readLines(file.path(dir_tables, "geopressurer_version.txt"))

# ---- Ground ----------------------------------------------------------------------------------
gt <- tab("ground_tails.csv")
gs <- tab("ground_summary.csv")
for (f in c("isa", "standard", "virtual")) {
  v[[paste0("ground_medae_", f)]] <- r1(gt[formula == f]$medae)
  v[[paste0("ground_medae_", f, "_r0")]] <- r0(gt[formula == f]$medae)
  v[[paste0("ground_p95_", f)]] <- r0(gt[formula == f]$p95_abs)
  v[[paste0("ground_absbias_", f)]] <- r1(
    gs[formula == f & terrain == "all"]$abs_bias_median
  )
  v[[paste0("ground_sd_", f)]] <- r1(
    gs[formula == f & terrain == "all"]$sd_median
  )
}
for (t in c(flat = "flat (<20 m)", mountain = "mountain (>300 m)")) {
  key <- sub(" .*", "", t)
  v[[paste0("ground_absbias_standard_", key)]] <- r1(
    gs[formula == "standard" & terrain == t]$abs_bias_median
  )
  v[[paste0("ground_sd_standard_", key)]] <- r1(
    gs[formula == "standard" & terrain == t]$sd_median
  )
}
# ERA5-Land against ERA5 single-levels over the same station hours.
gp <- tab("ground_products.csv")
gq <- tab("ground_land_hourly_quantiles.csv")
v$land_n <- r0(gp[dataset == "land"]$n_stations)
v$land_medae <- r1(gq[product == "land"]$q50)
v$land_medae_sl <- r1(gq[product == "sl"]$q50)
v$land_larger_hours <- pct(gq$land_larger[1])
v$land_absbias <- r1(gp[dataset == "land"]$abs_bias_median)
v$land_absbias_sl <- r1(gp[dataset == "sl"]$abs_bias_median)
v$land_worse_bias <- pct(gp$land_worse_bias[1])
v$land_sd <- r1(gp[dataset == "land"]$sd_median)
v$land_sd_sl <- r1(gp[dataset == "sl"]$sd_median)

# ---- Flight ----------------------------------------------------------------------------------
# Errors at the interpolated heights nearest the median and 90th percentile of tracked flight heights.
bq <- tab("bird_height_quantiles.csv")[flight]
h50 <- round(bq$p50, -2)
h90 <- round(bq$p90, -2)
v$bird_p50 <- r0(bq$p50)
v$bird_p90 <- r0(bq$p90)
v$h50 <- r0(h50)
v$h90 <- r0(h90)
ptl <- tab("flight_profile_tails.csv")
pst <- tab("flight_profile_station.csv")
pt <- function(f, z, col) ptl[formula == f & agl == z][[col]]
pmed <- function(f, z, m) {
  median(pst[formula == f & agl_mid == z][[m]], na.rm = TRUE)
}
for (f in c("isa", "standard", "virtual")) {
  v[[paste0("flight_medae_", f, "_h50")]] <- r1(pt(f, h50, "medae"))
  v[[paste0("flight_medae_", f, "_h90")]] <- r1(pt(f, h90, "medae"))
  v[[paste0("flight_p95_", f, "_h90")]] <- r0(pt(f, h90, "p95_abs"))
  v[[paste0("flight_bias_", f, "_h90")]] <- r1(pmed(f, h90, "bias"))
  v[[paste0("flight_sd_", f, "_h90")]] <- r1(pmed(f, h90, "sd"))
  # Error as a share of height, averaged over the two reference heights.
  v[[paste0("share_medae_", f)]] <- r0(mean(
    100 * c(pt(f, h50, "medae") / h50, pt(f, h90, "medae") / h90)
  ))
  v[[paste0("share_p95_", f)]] <- r0(mean(
    100 * c(pt(f, h50, "p95_abs") / h50, pt(f, h90, "p95_abs") / h90)
  ))
}
v$flight_p95_virtual_h50 <- r0(pt("virtual", h50, "p95_abs"))
# Lowest height at which the corrected conversion's 95th percentile exceeds 100 m.
v$virtual_p95_100m_km <- r1(
  ptl[formula == "virtual" & p95_abs > 100, min(agl)] / 1000
)
v$flight_p95_virtual_100_250 <- r0(
  tab("flight_tails.csv")[formula == "virtual" & hbin == "(100,250]"]$p95_abs
)
fb <- tab("flight_bird.csv")[variant == "all_flight"]
for (f in c("isa", "standard", "virtual")) {
  v[[paste0("bird_medae_", f)]] <- r1(fb[formula == f]$medae)
}

# Mean signed error by climate zone, half-year and time of day at the 90th-percentile height.
fcl <- tab("flight_climate_profile.csv")[agl == h90]
fdn <- tab("flight_daynight_profile.csv")[agl == h90 & season == "summer half"]
v$climate_isa_tropical_summer <- r0(
  fcl[formula == "isa" & climate == "A tropical" & season == "summer half"]$bias
)
v$climate_isa_polar_winter <- r0(
  fcl[formula == "isa" & climate == "E polar" & season == "winter half"]$bias
)
v$climate_standard_min <- r0(-max(fcl[formula == "standard"]$bias))
v$climate_standard_max <- r0(-min(fcl[formula == "standard"]$bias))
v$climate_virtual_max <- r0(max(abs(fcl[formula == "virtual"]$bias)))
for (f in c("standard", "virtual")) {
  for (d in c("day", "night")) {
    v[[paste0("summer_", d, "_", f)]] <- r0(
      fdn[formula == f & daynight == d]$bias
    )
  }
}
v$temperature_r <- sprintf("%.2f", tab("flight_temperature_explanation.csv")$r)

# ---- Horizontal position (virtual temperature + GPT3) ----------------------------------------
loc <- fread("results/position-sensitivity/results.csv")[formula == "virtual"]
lv <- function(m, d, col) loc[metric == m & distance == d][[col]]
abs_m <- "Absolute altitude: level"
rel_m <- "Surface-referenced height"
v$position_50_max <- r0(ceiling(max(abs(c(
  lv(abs_m, 50, "medae_increment"),
  lv(rel_m, 50, "medae_increment")
)))))
v$position_abs_50 <- r1(lv(abs_m, 50, "medae_increment"))
v$position_rel_50 <- r1(lv(rel_m, 50, "medae_increment"))
v$position_abs_50_change <- r1(lv(abs_m, 50, "change_median"))
v$position_abs_50_change_p95 <- r0(lv(abs_m, 50, "change_p95"))
v$position_abs_200 <- r1(lv(abs_m, 200, "medae_increment"))
v$position_abs_200_change <- r1(lv(abs_m, 200, "change_median"))

# ---- Station selection (supplement S1) ------------------------------------------------------
go <- tab("ground_selection_outcomes.csv")
so <- tab("sounding_selection_outcomes.csv")
v$ground_cells <- r0(tab("ground_selection_summary.csv")$cells)
v$ground_spikes <- r0(tab("ground_selection_summary.csv")$spikes_removed)
v$ground_assessed <- r0(sum(go$candidates))
for (r in c(
  "terrain",
  "reference_exclusion",
  "review_exclusion",
  "coverage",
  "jump",
  "unverifiable",
  "reference_height",
  "timestamp",
  "accepted"
)) {
  v[[paste0("ground_", r)]] <- r0(sum(go[reason == r]$candidates))
}
v$review_stations <- r0(nrow(fread(file.path(
  dir_curated,
  "ghcnh_review_exclusions.csv"
))))
v$sounding_assessed <- r0(sum(so$candidates))
for (r in c("coverage", "consistency", "accepted")) {
  v[[paste0("sounding_", r)]] <- r0(sum(so[reason == r]$candidates))
}
# Expected station SD from the elevation-gap fit (supplement S2).
gfit <- tab("ground_gap_fit.csv")
v$gap_sd_0 <- r1(approx(gfit$adz, gfit$sd, 0)$y)
v$gap_sd_1000 <- r1(approx(gfit$adz, gfit$sd, 1000)$y)

fwrite(
  data.table(name = names(v), value = vapply(v, as.character, "")),
  "results/manuscript_values.csv"
)
cli::cli_alert_success("{length(v)} manuscript values written")

# Draft figures for discussion; manuscript figures are not overwritten.
# Run from the repository root with Rscript scripts/23_draft_atmospheric_figures.R.
source("R/utils.R")
source("R/palette.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})
setDTthreads(2)
out <- "output/drafts/atmospheric-figures"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
theme_set(theme_minimal(base_size = 10, base_family = "Helvetica Neue") +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = pal[["grid"]]),
    plot.title = element_text(face = "bold", colour = pal[["ink"]]),
    plot.subtitle = element_text(size = 9, colour = "#4B5563"),
    strip.text = element_text(face = "bold", hjust = 0), legend.position = "bottom",
    legend.title = element_blank(), plot.title.position = "plot"))
formulas <- c(isa = "Standard atmosphere", standard = "ERA5 surface conditions",
  virtual = "ERA5 + humidity + GPT3")
conversion_colours <- scale_colour_manual(values = pal_conversion, breaks = names(formulas), labels = formulas)
save_draft <- function(p, name, width, height) {
  ggsave(file.path(out, paste0(name, ".png")), p, width = width, height = height, dpi = 180, bg = "white")
  ggsave(file.path(out, paste0(name, ".pdf")), p, width = width, height = height, device = cairo_pdf)
}
st <- load_stations()
gpt3 <- gpt3_read(1)

# Representative weather record --------------------------------------------
# Select a flat temperate station near the median temporal SD of both conversions.
gs <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh"]
candidates <- dcast(gs[formula %in% c("isa", "standard")], id ~ formula, value.var = "sd")
candidates <- merge(candidates, st[network == "ghcnh" & koppen_main == "C" & sdor < 20,
  .(id, name, elev)], by = "id")
candidates[, distance := ((isa - median(isa)) / IQR(isa))^2 +
  ((standard - median(standard)) / IQR(standard))^2]
site <- candidates[order(distance, id)][1]
W <- as.data.table(read_parquet(file.path(analysis_dir, "errors", paste0("ghcnh_", site$id, ".parquet"))))
setorder(W, date)
W[, block := as.integer(difftime(date, min(date), units = "days")) %/% 14]
blocks <- W[, .(n = .N, span = as.numeric(difftime(max(date), min(date), units = "days")),
  pressure_range = diff(range(pressure))), by = block][span > 13 & n >= .9 * max(n)]
chosen <- blocks[order(abs(pressure_range - median(pressure_range)), block)][1]
W <- W[block == chosen$block]
weather_errors <- melt(W, id.vars = "date", measure.vars = paste0("err_", names(formulas)),
  variable.name = "formula", value.name = "error")
weather_errors[, formula := sub("err_", "", formula)]
weather_errors[, formula := factor(formula, names(formulas))]
pw <- ggplot(W, aes(date, pressure)) + geom_line(colour = pal[["ink"]], linewidth = .6) +
  labs(title = "A  Pressure at a stationary sensor",
    subtitle = sprintf("%s | elevation %.0f m | %s", tools::toTitleCase(tolower(site$name)), site$elev,
      format(min(W$date), "%Y")), x = NULL, y = "Measured pressure (hPa)") +
  scale_x_datetime(date_breaks = "3 days", date_labels = "%d %b")
pe <- ggplot(weather_errors, aes(date, error, colour = formula)) +
  geom_hline(yintercept = 0, colour = pal[["slate"]], linetype = 2) + geom_line(linewidth = .6) +
  conversion_colours + scale_x_datetime(date_breaks = "3 days", date_labels = "%d %b") +
  labs(title = "B  Apparent vertical movement",
    subtitle = "Dashed line: actual altitude (zero error)",
    x = NULL, y = "Altitude error (m)")

# Existing representative radiosonde examples ------------------------------
picks <- fread(file.path(dir_tables, "paper_fig1_soundings.csv"))
profiles <- list()
profile_errors <- list()
for (i in seq_len(nrow(picks))) {
  k <- picks[i]
  d <- as.data.table(read_parquet(file.path(analysis_dir, "errors", paste0("igra_", k$id, ".parquet"))))
  d <- d[sounding == k$sounding][order(agl)]
  k0 <- d[which.min(abs(agl - k$agl))]
  s <- st[network == "igra" & id == k$id]
  L <- gpt3_lapse(gpt3, s$lon, s$lat, as.POSIXlt(k0$level_time, tz = "UTC")$yday + 1)
  heights <- seq(0, 3000, 25)
  z <- heights + k0$gph_s
  profiles[[i]] <- rbind(
    d[temp > -8000 & agl <= 3000, .(height = agl, temperature = temp / 10, formula = "Observed temperature")],
    data.table(height = heights, temperature = 15 - .0065 * z, formula = "isa"),
    data.table(height = heights, temperature = k0$t2m_sl - 273.15 - .0065 * (z - k0$z_sl), formula = "standard"),
    data.table(height = heights, temperature = virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl) -
      273.15 + L * (z - k0$z_sl), formula = "virtual"))[, example := k$class]
  d[, `:=`(illustration_isa = altitude_lapse(press, 101325, 288.15, 0) -
      altitude_lapse(press_s, 101325, 288.15, 0) - agl,
    illustration_standard = altitude_lapse(press, k0$sp_sl, k0$t2m_sl, k0$z_sl) -
      altitude_lapse(press_s, k0$sp_sl, k0$t2m_sl, k0$z_sl) - agl,
    illustration_virtual = altitude_lapse(press, k0$sp_sl,
      virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl), k0$z_sl, L) -
      altitude_lapse(press_s, k0$sp_sl,
        virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl), k0$z_sl, L) - agl)]
  profile_errors[[i]] <- melt(d[agl <= 3000, .(height = agl, isa = illustration_isa,
    standard = illustration_standard, virtual = illustration_virtual)], id.vars = "height",
    variable.name = "formula", value.name = "error")[, example := k$class]
}
P <- rbindlist(profiles)
E <- rbindlist(profile_errors)
fwrite(P, file.path(out, "example_temperature_profiles.csv"))
fwrite(E, file.path(out, "example_flight_height_errors.csv"))
P[, example := factor(example, picks$class)]
E[, example := factor(example, picks$class)]
pp <- ggplot(P, aes(temperature, height / 1000, colour = formula)) +
  geom_path(aes(linetype = formula), linewidth = .7) + facet_wrap(~example) +
  scale_colour_manual(values = c(pal_conversion, "Observed temperature" = "#333333"),
    breaks = c(names(formulas), "Observed temperature"), labels = c(formulas, "Radiosonde temperature"),
    guide = guide_legend(nrow = 2, byrow = TRUE,
      override.aes = list(linetype = c("solid", "solid", "solid", "22")))) +
  scale_linetype_manual(values = c(isa = "solid", standard = "solid", virtual = "solid", "Observed temperature" = "22"), guide = "none") +
  labs(title = "C  Assumed temperature profiles",
    subtitle = "Teal: virtual temperature incorporates humidity",
    x = "Temperature used in conversion (°C)", y = "Height above launch surface (km)")
px <- ggplot(E, aes(error, height / 1000, colour = formula)) +
  geom_vline(xintercept = 0, colour = pal[["slate"]], linetype = 2) +
  geom_path(linewidth = .7) + facet_wrap(~example) + conversion_colours +
  labs(title = "D  Consequences for flight height",
    subtitle = "Launch-surface errors subtracted; dashed line: zero error",
    x = "Flight-height error (m)", y = "Height above launch surface (km)")
pe <- pe + theme(legend.position = "none")
px <- px + theme(legend.position = "none")
main <- ((pw + pp + plot_layout(widths = c(1, 1.5))) /
  (pe + px + plot_layout(widths = c(1, 1.5)))) + plot_layout(guides = "collect") &
  theme(legend.text = element_text(size = 9),
    plot.title = element_text(size = 10), plot.subtitle = element_text(size = 8))
save_draft(main, "figure1_draft", 11, 6.5)
fwrite(data.table(id = site$id, name = site$name, elevation = site$elev,
  start = min(W$date), end = max(W$date), n = nrow(W), pressure_range_hpa = diff(range(W$pressure))),
  file.path(out, "weather_example.csv"))
fwrite(weather_errors[, .(min = min(error), max = max(error), sd = sd(error)), by = formula],
  file.path(out, "weather_example_errors.csv"))

# Variation of inputs across and within accepted station records -----------
# Each station contributes one median and one temporal P90-P10 span per input.
G <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet"),
  col_select = c("id", "date", "sp_sl", "t2m_sl", "d2m", "z_sl")))
G <- merge(G, st[network == "ghcnh", .(id, lon, lat)], by = "id")
G[, lapse := gpt3_lapse(gpt3, lon, lat, as.POSIXlt(date, tz = "UTC")$yday + 1)]
G[, tv := virtual_temperature(t2m_sl, d2m, sp_sl)]
G[, q := (tv / t2m_sl - 1) / .608]
G[, t_isa := 288.15 - .0065 * z_sl]
G[, p_isa := 101325 * (t_isa / 288.15)^(-9.80665 * .0289644 / (8.31432 * -.0065))]
G[, pressure_anomaly := (sp_sl - p_isa) / 100]
inputs <- c("pressure_anomaly", "t2m_sl", "lapse", "q")
input_labels <- c("Pressure departure from ISA (hPa)", "Surface temperature (°C)",
  "GPT3 lapse rate (K/km)", "Specific humidity (g/kg)")
input_colours <- c("#C46532", "#315B91", "#7656A3", "#007F86")
S <- rbindlist(lapply(seq_along(inputs), function(j) {
  G[, .(median = median(get(inputs[j])), span = diff(quantile(get(inputs[j]), c(.1, .9)))), by = id][, input := j]
}))
S[input == 2, median := median - 273.15]
S[input %in% c(3, 4), `:=`(median = median * 1000, span = span * 1000)]
fwrite(S, file.path(out, "input_variation_by_station.csv"))

# Conditional sensitivity, holding all other inputs at their local values ---
# Use 12 evenly spaced accepted timestamps per station to keep equal station weight.
# Generate pressures at known heights in the full model, then omit one input.
setorder(G, id, date)
H <- G[, .SD[unique(round(seq(1, .N, length.out = 12)))], by = id]
rm(G)
gc()
effects <- list()
for (h in seq(0, 6000, 250)) {
  p <- H$sp_sl * (1 + H$lapse * h / H$tv)^(-9.80665 * .0289644 / (8.31432 * H$lapse))
  omitted <- list(
    altitude_lapse(p, H$p_isa, H$tv, H$z_sl, H$lapse),
    altitude_lapse(p, H$sp_sl, H$t_isa * (1 + .608 * H$q), H$z_sl, H$lapse),
    altitude_lapse(p, H$sp_sl, H$tv, H$z_sl, -.0065),
    altitude_lapse(p, H$sp_sl, H$t2m_sl, H$z_sl, H$lapse))
  effects[[as.character(h)]] <- rbindlist(lapply(seq_along(omitted), function(j) {
    x <- H$z_sl + h - omitted[[j]]
    data.table(input = j, height = h, p10 = quantile(x, .1), median = median(x), p90 = quantile(x, .9))
  }))
}
F <- rbindlist(effects)
fwrite(F, file.path(out, "conditional_altitude_sensitivity.csv"))
fwrite(H, file.path(out, "sensitivity_atmospheric_states.csv"))
replacements <- c("Local pressure vs ISA at the same elevation", "Local temperature vs ISA at the same elevation",
  "GPT3 lapse rate vs -6.5 K/km", "Moist air vs dry air")
units <- c("hPa", "°C", "K/km", "g/kg")
rows <- list()
for (j in seq_along(inputs)) {
  a <- ggplot(S[input == j], aes(median)) +
    geom_histogram(bins = 28, fill = input_colours[j], alpha = .75) +
    labs(title = if (j == 1) "A  Between locations" else NULL,
      subtitle = input_labels[j], x = sprintf("Station median (%s)", units[j]), y = "Stations")
  b <- ggplot(S[input == j], aes(span)) +
    geom_histogram(bins = 28, fill = input_colours[j], alpha = .75) +
    labs(title = if (j == 1) "B  Through time" else NULL,
      subtitle = if (j == 3) "Seasonal climatology only" else "Within-station P90-P10 span",
      x = sprintf("Temporal span (%s)", units[j]), y = NULL)
  c <- ggplot(F[input == j], aes(height / 1000, median)) +
    geom_hline(yintercept = 0, colour = pal[["slate"]], linetype = 2) +
    geom_ribbon(aes(ymin = p10, ymax = p90), fill = input_colours[j], alpha = .2) +
    geom_line(colour = input_colours[j], linewidth = .8) +
    scale_x_continuous(breaks = c(0, 2, 4, 6)) +
    labs(title = if (j == 1) "C  Effect on altitude" else NULL,
      subtitle = replacements[j], x = "Height above ERA5 surface (km)", y = "Absolute-altitude change (m)")
  rows[[j]] <- a + b + c
}
supp <- wrap_plots(rows, ncol = 1) + plot_annotation(
  title = "Atmospheric variability and its consequences for altitude conversion",
  subtitle = sprintf("ERA5 reference conditions at %s accepted GHCNh stations; GPT3 seasonal lapse rates", uniqueN(S$id)),
  caption = "A-B: one summary per station over its accepted record. C: model sensitivity, not observed error.\nLine: median; shading: P10-P90. One input replaced at a time; effects are not additive.")
save_draft(supp, "supplement_sensitivity_draft", 11, 11)
print(F[height %in% c(0, 2000, 6000)])
cli::cli_alert_success("Drafts saved in {out}")

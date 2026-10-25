# Figure 5: mean flight-height error by climate zone, half-year and time of day.
source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages(library(patchwork))
theme_set(theme_paper(10.5))
update_geom_defaults("line", list(linewidth = 0.7))
tab <- function(f) fread(file.path(dir_tables, f))

formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate",
  virtual = "ERA5, virtual temperature + GPT3")

# Mean signed error from the surface to 5 km for each conversion (columns), with one line per
# climate zone (map colours of Figure 2) in (a) and per day (07-19 local solar time) or night in
# (b); line type gives the half-year. All panels share one horizontal scale: column widths follow
# the error range of each conversion.
short_f <- setNames(c("Standard\natmosphere", "ERA5\nstandard lapse rate", "ERA5\nvirtual + GPT3"),
  formulas)
prep_cond <- function(d, key) {
  d <- d[agl <= 5000, c("formula", "agl", key, "season", "bias"), with = FALSE]
  d <- rbind(d, unique(d[, c("formula", key, "season"), with = FALSE])[, `:=`(agl = 0, bias = 0)])
  d[, formula := factor(short_f[formulas[formula]], short_f)]
  d[, season := factor(season, c("summer half", "winter half"), c("Summer half-year", "Winter half-year"))]
  setorderv(d, c(key, "season", "formula", "agl"))
}
fc <- prep_cond(tab("flight_climate_profile.csv"), "climate")
fc[, climate := factor(climate, names(pal_climate), tools::toTitleCase(sub("^[A-E] ", "", names(pal_climate))))]
fdn <- prep_cond(tab("flight_daynight_profile.csv"), "daynight")
fdn[, daynight := factor(daynight, c("day", "night"), c("Day", "Night"))]
# Common horizontal range of each column in (a) and (b), padded to whole 50 m
xr <- rbind(fc[, .(formula, bias)], fdn[, .(formula, bias)])[,
  .(bias = c(50 * floor(min(bias, 0) / 50 - 0.3), 50 * ceiling(max(bias, 0) / 50 + 0.3))), by = formula]
cond_panel <- function(d, key, colours, tag, title) {
  ggplot(d, aes(bias, agl / 1000, colour = .data[[key]], linetype = season,
      group = interaction(.data[[key]], season))) +
    geom_blank(data = xr, aes(bias, 0), inherit.aes = FALSE) +
    geom_vline(xintercept = 0, colour = pal[["ink"]], linewidth = 0.4) +
    geom_path(linewidth = 0.65) +
    facet_grid(cols = vars(formula), scales = "free_x", space = "free_x") +
    scale_x_continuous(breaks = seq(-400, 400, 100), expand = c(0, 0)) +
    scale_colour_manual(values = colours, name = title) +
    scale_linetype_manual(values = c("solid", "22"), name = NULL) +
    scale_y_continuous(breaks = 0:5, limits = c(0, 5), expand = expansion(mult = 0.01)) +
    labs(y = "Height (km)", x = NULL, tag = tag) +
    guides(colour = guide_legend(order = 1, override.aes = list(linewidth = 1.2)),
      linetype = guide_legend(order = 2)) +
    theme(panel.spacing = unit(1.1, "lines"), legend.position = "right",
      strip.text = element_text(hjust = 0.5, lineheight = 0.95), legend.key.width = unit(16, "pt"),
      axis.text.x = element_text(size = 8))
}
pc <- cond_panel(fc, "climate", setNames(pal_climate, levels(fc$climate)), "a", "Climate zone") /
  (cond_panel(fdn, "daynight", c(Day = "#E9A23B", Night = "#1E2F57"), "b", "Time of day") +
    labs(x = "Mean surface-referenced error (m)") + theme(strip.text = element_blank()))
save_figure(pc, "fig5_conditions", 7.2, 5.6)

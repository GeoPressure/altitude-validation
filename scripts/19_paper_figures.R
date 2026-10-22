# Figures of the paper (paper/), from the tables of 18_three_formulas.R and, for the example soundings
# of Figure 1, the radiosonde and ERA5 files. Same theme and colours as the report (17_figures.R).

invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))
source("R/utils.R")
source("R/palette.R")
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

font <- if ("Helvetica Neue" %in% systemfonts::system_fonts()$family) "Helvetica Neue" else "sans"
theme_set(
  theme_minimal(base_size = 10.5, base_family = font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal[["grid"]], linewidth = 0.3),
      axis.title = element_text(colour = "#374151"),
      axis.text = element_text(colour = "#4B5563"),
      plot.title = element_text(face = "bold", size = 10.5, colour = pal[["ink"]]),
      plot.title.position = "plot",
      strip.text = element_text(face = "bold", hjust = 0, colour = pal[["ink"]]),
      legend.position = "bottom",
      legend.title = element_text(size = 9.5, colour = "#374151"),
      plot.tag = element_text(face = "bold", size = 12)
    )
)
update_geom_defaults("line", list(linewidth = 0.7))
dir_paper_fig <- "paper/figures"
dir.create(dir_paper_fig, showWarnings = FALSE)
save_fig <- function(p, name, w, h) {
  ggsave(file.path(dir_paper_fig, paste0(name, ".pdf")), p, width = w, height = h,
    device = grDevices::cairo_pdf)
  ggsave(file.path(dir_paper_fig, paste0(name, ".png")), p, width = w, height = h, dpi = 300,
    bg = "white", device = ragg::agg_png)
}
tab <- function(f) fread(file.path(dir_tables, f))

formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate",
  virtual = "ERA5, virtual temperature + GPT3")
# Conversion identities: solid lines in burnt orange, blue and teal; reference profiles are thicker.
pal_f <- setNames(pal_conversion[names(formulas)], formulas)
fform <- function(x) factor(formulas[x], formulas)

# ---- Figure 1: the column temperature assumed by each formula, two typical soundings ------------
# The two soundings are chosen by a fixed rule, not by eye. For each of two classes, a temperate
# (Koppen C) summer day and a continental (Koppen D) winter night, we take every radiosonde sounding
# of the analysis (load_radiosondes()) in the core of the season (seasonal day of year, i.e. the
# southern hemisphere shifted by six months, in June-August or December-February) and in that half
# of the day (local solar time 07-19 h or not, as in the paper), and its level closest to 2 km above
# the ground (1.7-2.3 km). We compute the error of the height above the ground of the three formulas
# at that level (as in 18_three_formulas.R) and keep the sounding whose three errors are jointly
# closest (Euclidean distance, m) to the medians of its class: the sounding is typical of the class
# for all three formulas at once.
gpt3 <- gpt3_read(1)
st <- load_stations()
alt_isa <- function(p) altitude_lapse(p, 101325, 288.15, 0, -0.0065)
lapse_gpt3 <- function(lon, lat, date) {
  L <- gpt3_lapse(gpt3, lon, lat, as.POSIXlt(date, tz = "UTC")$yday + 1)
  fifelse(abs(L) < 1e-5, -1e-5, L)
}
B <- load_radiosondes(st)
B <- B[is.finite(err_sl_rel) & is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m)]
B[st[network == "igra"], on = "id", `:=`(lon = i.lon, lat = i.lat)]
classes <- data.table(
  cls = c("summer", "winter"), climate = c("C temperate", "D continental"),
  daynight = c("day", "night"), title = c("Temperate summer day", "Continental winter night")
)
B[, cls := fifelse(sdoy >= 152 & sdoy <= 243, "summer", fifelse(sdoy >= 335 | sdoy <= 59,
  "winter", NA_character_))]
B <- B[classes, on = .(cls, climate, daynight), nomatch = NULL]
K <- B[agl >= 1700 & agl <= 2300][order(abs(agl - 2000))][, .SD[1], by = .(id, sounding)]
rm(B)
K[, L := lapse_gpt3(lon, lat, level_time)]
K[, `:=`(e_isa = err_isa, e_standard = err_standard, e_virtual = err_virtual)]
ecols <- c("e_isa", "e_standard", "e_virtual")
K[, paste0("m_", ecols) := lapply(.SD, median), by = cls, .SDcols = ecols]
K[, dist := sqrt((e_isa - m_e_isa)^2 + (e_standard - m_e_standard)^2 +
  (e_virtual - m_e_virtual)^2)]
pick <- K[order(dist)][, .SD[1], by = cls][classes, on = "cls"]
pick[, n_class := K[, .N, by = cls][pick, on = "cls", N]]
pick[st[network == "igra"], on = "id", name := i.name]
print(pick[, .(cls, id, name, sounding, lsh, agl, e_isa, e_standard, e_virtual, m_e_isa,
  m_e_standard, m_e_virtual, n_class)])
fwrite(pick[, .(class = title, id, name, sounding, local_solar_hour = lsh, agl, e_isa, e_standard,
  e_virtual, median_isa = m_e_isa, median_standard = m_e_standard, median_virtual = m_e_virtual,
  n_soundings_class = n_class)], file.path(dir_tables, "paper_fig1_soundings.csv"))

source("scripts/23_figure1.R", local = new.env())
# Rebuild Figure 1 alone during design review; a normal run still creates all figures.
if (Sys.getenv("FIGURE_ONLY") == "1") quit(save = "no")

# ---- Figure 2: where the reference stations are -------------------------------------------------
suppressPackageStartupMessages(library(sf))
crs_map <- "+proj=eqearth"
world <- rnaturalearth::ne_countries(scale = 110, returnclass = "sf")
ref <- tab("paper_ground_station.csv")[formula == "standard"]
igra_used <- tab("flight_stations_used.csv")$id
pts <- rbind(ref[reference == "GHCNh", .(lon, lat, what = reference)], st[network == "igra" & id %in% igra_used, .(lon, lat, what = "IGRA2")])
n_ref <- pts[, .N, by = what]
lab_ref <- setNames(sprintf("%s (%s)", n_ref$what, format(n_ref$N, big.mark = ",", trim = TRUE)), n_ref$what)
pts[, what := factor(what, c("GHCNh", "GNSS", "IGRA2"))]
sf_pts <- st_as_sf(pts, coords = c("lon", "lat"), crs = 4326)
shp_ref <- c(GHCNh = 16, GNSS = 15, MeteoSwiss = 18, IGRA2 = 17)
size_ref <- c(GHCNh = 0.45, GNSS = 1.4, MeteoSwiss = 1.3, IGRA2 = 0.75)
p2 <- ggplot() + geom_sf(data = world, fill = "#EEF0F3", colour = "white", linewidth = 0.15) + geom_sf(aes(colour = what, shape = what, size = what), data = sf_pts, alpha = 0.85) + scale_colour_manual(values = pal_reference, labels = lab_ref, name = NULL) + scale_shape_manual(values = shp_ref, labels = lab_ref, name = NULL) + scale_size_manual(values = size_ref, labels = lab_ref, name = NULL) + coord_sf(crs = crs_map, expand = FALSE) + theme(axis.text = element_blank(), panel.grid.major = element_line(colour = "#F3F4F6", linewidth = 0.2), legend.text = element_text(size = 9.5)) + guides(colour = guide_legend(override.aes = list(size = 2.6)))
save_fig(p2, "fig2_stations", 7.2, 3.2)

# ---- Figure 3: observation-level errors and station-level distributions -------------------------
gs <- tab("paper_ground_station.csv")[reference == "GHCNh"]
qs <- function(x, w) as.list(setNames(vapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) {
  wquant(x, w, p)
}, 1), c("q10", "q25", "q50", "q75", "q90")))
G <- as.data.table(read_parquet(file.path(analysis_dir, "ground_comparison.parquet")))[reference == "GHCNh"]
obs <- rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
  x <- abs(G[[paste0("err_", f)]])
  as.data.table(c(list(metric = "observation", formula = f),
    as.list(setNames(vapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) wquant(x, G$w, p), 1),
      c("q10", "q25", "q50", "q75", "q90")))))
}))
station_q <- rbind(cbind(metric = "abs_bias", gs[, qs(abs(bias), cw), by = formula]),
  cbind(metric = "sd", gs[, qs(sd, cw), by = formula]))
ql <- rbindlist(list(obs, station_q), use.names = TRUE, fill = TRUE)
form_order <- c("Standard atmosphere", "ERA5, standard lapse rate", "ERA5, virtual temperature + GPT3")
form_legend <- c("Standard atmosphere" = "ISA", "ERA5, standard lapse rate" = "ERA5 lapse rate",
  "ERA5, virtual temperature + GPT3" = "ERA5 virtual T + GPT3")
ql[, formula := factor(formulas[formula], form_order)]
ql[, metric := factor(metric, c("observation", "abs_bias", "sd"),
  c("Hourly |error|", "Station |bias|", "Station SD"))]
ql[, row := 2 + (as.numeric(formula) - 2) * 0.36]
ql[, `:=`(label_y = row - 0.24, label = sprintf("%.1f", q50))]
# Shared interval geometry and a quiet observation-panel background.
p3 <- ggplot(ql, aes(q50, row, colour = formula)) +
  geom_rect(data = ql[metric == "Hourly |error|"][1],
    aes(xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf), inherit.aes = FALSE,
    fill = "#F1F5F9", colour = NA) +
  geom_segment(aes(x = q10, xend = q90, yend = row), linewidth = 0.55) +
  geom_segment(aes(x = q25, xend = q75, yend = row), linewidth = 3.2, lineend = "butt") +
  geom_point(shape = 21, fill = "white", size = 2.2, stroke = 0.7) +
  geom_text(aes(x = 175, label = label), hjust = 1, colour = "#374151",
    fontface = "bold", size = 2.9) +
  facet_grid(metric ~ ., switch = "y") +
  scale_colour_manual(values = pal_f, labels = form_legend, name = NULL,
    guide = guide_legend(override.aes = list(linewidth = 1.2, size = 2))) +
  scale_y_continuous(breaks = NULL, limits = c(1.35, 2.65), trans = scales::reverse_trans()) +
  scale_x_continuous(trans = scales::pseudo_log_trans(sigma = 1),
    breaks = c(0, 1, 3, 10, 30, 100), limits = c(0, 180), expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = "Error magnitude (m)", y = NULL) +
  theme(legend.position = "top", legend.text = element_text(size = 8.5),
    strip.placement = "outside", strip.background = element_blank(),
    strip.text.y.left = element_text(angle = 0, hjust = 1, face = "bold", size = 9),
    panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(linewidth = 0.2),
    panel.spacing.y = unit(0.7, "lines"), plot.margin = margin(2, 4, 2, 4))
save_fig(p3, "fig3_ground", 7.2, 3.7)

# ---- Figure 4: error of the height above the ground in flight --------------------------------
# Equally weighted station medians and IQRs in 250 m bands of observed levels.
fs <- tab("paper_flight_profile_station.csv")[agl_mid <= 4000]
fsq <- rbind(cbind(metric = "bias", fs[, qs(bias, cw), by = .(formula, agl_mid)]),
  cbind(metric = "sd", fs[is.finite(sd), qs(sd, cw), by = .(formula, agl_mid)]))
fsq[, formula := fform(formula)]
setorder(fsq, metric, formula, agl_mid)
bq <- tab("bird_height_quantiles.csv")[flight == TRUE]
bird_lines <- geom_hline(yintercept = c(bq$p50, bq$p90) / 1000, colour = "#A5B4CB",
  linewidth = 0.6, alpha = 0.6)
flight_panel <- function(m, xlab, tag, xlim, xbreaks) {
  d <- fsq[metric == m]
  ggplot(d, aes(q50, agl_mid / 1000, colour = formula, fill = formula)) +
    bird_lines +
    geom_vline(xintercept = 0, colour = pal[["ink"]], linewidth = 0.4) +
    geom_ribbon(aes(xmin = q25, xmax = q75), alpha = 0.12, colour = NA, orientation = "y") +
    geom_path(linewidth = 0.75) +
    scale_colour_manual(values = pal_f, name = NULL) +
    scale_fill_manual(values = pal_f, guide = "none") +
    scale_y_continuous(breaks = 0:4, limits = c(0, 4), expand = expansion(mult = 0.01)) +
    scale_x_continuous(breaks = xbreaks) +
    coord_cartesian(xlim = xlim) +
    labs(y = "Height above sounding surface (km)", x = xlab, tag = tag)
}
bh <- tab("bird_height_hist.csv")
n_tags <- tab("bird_height_distribution.csv")[flight == TRUE, n_tags][1]
bird_panel <- ggplot(bh[lo < 4000], aes(100 * prop, (lo + 50) / 1000)) +
  geom_col(width = 0.1, fill = pal[["slate"]], colour = "white", linewidth = 0.2,
    orientation = "y") +
  bird_lines +
  annotate("text", x = Inf, y = c(bq$p50, bq$p90) / 1000, label = c("median", "90%"),
    hjust = 1.05, vjust = -0.4, size = 2.9, colour = "#4B5563", family = font) +
  scale_y_continuous(breaks = 0:4, limits = c(0, 4), expand = expansion(mult = 0.01)) +
  labs(y = NULL, x = sprintf("Flight time\n(%%, %d birds)", n_tags), tag = "c")
p4 <- flight_panel("bias", "Station bias (m)", "a", c(-200, 150),
    seq(-200, 150, 50)) +
  (flight_panel("sd", "Within-station SD (m)", "b", c(0, 125), seq(0, 125, 25)) +
    labs(y = NULL)) +
  bird_panel + plot_layout(guides = "collect", widths = c(1.15, 1, 0.55)) &
  theme(legend.position = "bottom", legend.text = element_text(size = 9.5))
save_fig(p4, "fig4_flight", 7.2, 3.9)

# ---- Figure 5: in-flight bias by climate zone and season ---------------------------------------
fc <- tab("paper_flight_climate.csv")[agl_mid <= 4000]
fc[, formula := fform(formula)]
setorder(fc, climate, season, formula, agl_mid)
fc[, season := factor(season, c("summer half", "winter half"), c("Summer half", "Winter half"))]
p5 <- ggplot(fc, aes(bias, agl_mid / 1000, colour = formula)) +
  geom_vline(xintercept = 0, colour = pal[["ink"]], linewidth = 0.4) +
  geom_path() +
  facet_grid(season ~ climate) +
  scale_colour_manual(values = pal_f, name = NULL) +
  scale_x_continuous(breaks = c(-100, 0, 100), limits = c(-185, 195)) +
  scale_y_continuous(breaks = 0:4, limits = c(0, 4), expand = expansion(mult = 0.01)) +
  labs(y = "Height above sounding surface (km)", x = "Mean profile-level error (m)") +
  theme(panel.spacing = unit(0.8, "lines"),
    legend.text = element_text(size = 9.5), panel.border = element_rect(fill = NA,
    colour = pal[["grid"]], linewidth = 0.4))
save_fig(p5, "fig5_climate", 7.2, 4.4)

jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), source_md5 = as.list(tools::md5sum(c("R/palette.R", "scripts/19_paper_figures.R", "scripts/23_figure1.R")))), file.path(dir_tables, "paper_figures_provenance.json"), pretty = TRUE, auto_unbox = TRUE)

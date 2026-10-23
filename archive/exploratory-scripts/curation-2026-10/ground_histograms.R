# Temporary Figure 3 alternative; run from the repository root.
source("R/utils.R")
source("R/palette.R")
library(ggplot2)
library(patchwork)

# Read station summaries ---------------------------------------------------
terrain_screen <- "terrain" %in% commandArgs(trailingOnly = TRUE)
pressure_window <- terrain_screen | "pressure_window" %in% commandArgs(trailingOnly = TRUE)
prefix <- if (terrain_screen) "ground_terrain_window" else "ground_pressure_window"
coverage_only <- "coverage_only" %in% commandArgs(trailingOnly = TRUE)
no_era5_screen <- "no_era5_screen" %in% commandArgs(trailingOnly = TRUE)
out <- "output/drafts/atmospheric-figures"
ground <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh"]
labels <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate",
  virtual = "ERA5, virtual temperature + GPT3")
if (coverage_only) ground <- fread(file.path(out, "ground_coverage_only_stations.csv"))
if (no_era5_screen) ground <- fread(file.path(out, "ground_no_era5_screen_stations.csv"))
if (pressure_window) ground <- fread(file.path(out, paste0(prefix, "_stations.csv")))
ground[, formula := factor(formula, names(labels))]
summary <- ground[, .(abs_bias = wquant(abs(bias), cw, .5), sd = wquant(sd, cw, .5)), by = formula]
if (pressure_window) {
  observation_hist <- fread(file.path(out, paste0(prefix, "_observation_hist.csv")))
  observation_medians <- fread(file.path(out, paste0(prefix, "_observation_medians.csv")))
} else if (no_era5_screen) {
  observation_hist <- fread(file.path(out, "ground_no_era5_screen_observation_hist.csv"))
  observation_medians <- fread(file.path(out, "ground_no_era5_screen_observation_medians.csv"))
} else if (coverage_only) {
  observation_hist <- fread(file.path(out, "ground_coverage_only_observation_hist.csv"))
  observation_medians <- fread(file.path(dir_tables, "paper_selection_sensitivity.csv"))[selection == "coverage_only", .(formula, q50 = medae)]
} else {
observations <- as.data.table(read_parquet(file.path(analysis_dir, "ground_comparison.parquet"),
  col_select = c("id", "w", "err_isa", "err_standard", "err_virtual")))
stopifnot(setequal(observations$id, ground$id))
observation_hist <- rbindlist(lapply(names(labels), function(f) {
  observations[, .(weight = sum(w)), by = .(bin = pmin(floor(abs(get(paste0("err_", f))) / 5) * 5, 450))][,
    `:=`(formula = f, percent = 100 * weight / sum(weight))]
}))
observation_medians <- fread(file.path(dir_tables, "paper_ground_observation_quantiles.csv"))
rm(observations)
}
font <- "Helvetica Neue"
theme_set(theme_minimal(base_size = 10, base_family = font) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = pal[["grid"]], linewidth = .25),
    axis.text = element_text(colour = "#4B5563"),
    plot.title = element_text(size = 10, face = "bold", colour = pal[["ink"]]),
    plot.subtitle = element_text(size = 9, colour = "#4B5563"),
    plot.margin = margin(5, 8, 5, 5)))

# Compare offsets across stations and variability within stations ----------
panels <- list()
for (i in seq_along(labels)) {
  f <- names(labels)[i]
  d <- ground[formula == f]
  q <- summary[formula == f]
  d[, bias_plot := pmax(-200, pmin(bias, 430))]
  d[, sd_plot := pmin(sd, 134)]
  panels[[3 * i - 2]] <- ggplot(observation_hist[formula == f], aes(bin + 2.5, percent)) +
    geom_col(width = 5, fill = pal_conversion[f], colour = "white", linewidth = .12) +
    annotate("text", x = Inf, y = Inf,
      label = sprintf("Median |error| %.1f m", observation_medians[formula == f]$q50),
      hjust = 1.05, vjust = 1.6, size = 3, family = font, colour = pal[["ink"]]) +
    scale_x_continuous(limits = c(0, 455), breaks = c(0, 100, 200, 300, 452.5),
      labels = c("0", "100", "200", "300", "≥450"), expand = expansion(mult = 0)) +
    scale_y_continuous(limits = c(0, 60), breaks = c(0, 5, 20, 50), transform = "sqrt", expand = expansion(mult = c(0, .04))) +
    labs(title = if (i == 1) "Overall error" else NULL,
      subtitle = unname(labels[i]), x = if (i == 3) "Hourly |error| (m)" else NULL, y = "Weighted observations (%)")
  panels[[3 * i - 1]] <- ggplot(d, aes(bias_plot, weight = cw)) +
    geom_histogram(binwidth = 5, boundary = 0, fill = pal_conversion[f], colour = "white", linewidth = .12) +
    geom_vline(xintercept = 0, colour = pal[["ink"]], linewidth = .35) +
    annotate("text", x = Inf, y = Inf, label = sprintf("Median |bias| %.1f m", q$abs_bias),
      hjust = 1.05, vjust = 1.6, size = 3, family = font, colour = pal[["ink"]]) +
    scale_x_continuous(limits = c(-205, 435), breaks = c(-200, -100, 0, 100, 200, 300, 430), labels = c("≤−200", "−100", "0", "100", "200", "300", "≥430"), expand = expansion(mult = 0)) +
    scale_y_continuous(limits = c(0, 1050), breaks = c(0, 100, 500, 1000), transform = "sqrt", expand = expansion(mult = c(0, .04))) +
    labs(title = if (i == 1) "Persistent offsets" else NULL,
      subtitle = unname(labels[i]), x = if (i == 3) "Station bias (m)" else NULL, y = "Stations")
  panels[[3 * i]] <- ggplot(d, aes(sd_plot, weight = cw)) +
    geom_histogram(binwidth = 2, boundary = 0, fill = pal_conversion[f], colour = "white", linewidth = .12) +
    annotate("text", x = Inf, y = Inf, label = sprintf("Median SD %.1f m", q$sd),
      hjust = 1.05, vjust = 1.6, size = 3, family = font, colour = pal[["ink"]]) +
    scale_x_continuous(limits = c(0, 138), breaks = c(0, 25, 50, 75, 100, 134), labels = c("0", "25", "50", "75", "100", "≥134"), expand = expansion(mult = 0)) +
    scale_y_continuous(limits = c(0, 1400), breaks = c(0, 100, 500, 1000), transform = "sqrt", expand = expansion(mult = c(0, .04))) +
    labs(title = if (i == 1) "Variation through time" else NULL,
      subtitle = unname(labels[i]), x = if (i == 3) "Within-station SD (m)" else NULL, y = NULL)
}
for (j in c(2, 3, 5, 6, 8, 9)) stopifnot(sum(ggplot_build(panels[[j]])$data[[1]]$count, na.rm = TRUE) == nrow(ground) / 3)
for (j in c(1, 4, 7)) stopifnot(abs(sum(ggplot_build(panels[[j]])$data[[1]]$y^2) - 100) < 1e-8)
p <- wrap_plots(panels, ncol = 3)
out <- "output/drafts/atmospheric-figures"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
name <- if (terrain_screen) "figure3_histograms_terrain_window_draft" else if (pressure_window) "figure3_histograms_pressure_window_draft" else if (no_era5_screen) "figure3_histograms_no_era5_screen_draft" else if (coverage_only) "figure3_histograms_coverage_only_draft" else "figure3_histograms_draft"
ggsave(file.path(out, paste0(name, ".png")), p, width = 11.8, height = 6.2, dpi = 220, device = ragg::agg_png, bg = "white")
ggsave(file.path(out, paste0(name, ".pdf")), p, width = 11.8, height = 6.2, device = cairo_pdf)
writeLines(sprintf("Ground conversion errors at %s GHCNh stations. Left: hourly absolute errors, weighted so each station contributes equally; 5 m bins, with all errors at or above 450 m in the final bin. Middle: signed station bias (mean error), with zero marking agreement with reported station elevation. Right: within-station error SD, measuring temporal variability around each station's mean error. Station histograms use 5 m bins for bias and 2 m bins for SD; values outside the displayed range enter the labelled edge bins. Rows compare the three conversions using the same observations and stations. Labels give median absolute hourly error, median absolute station bias and median station SD. Axes are shared within each column; vertical axes use square-root scales. Ground discrepancies include uncertainty in reported reference elevation as well as atmospheric conversion errors.", format(nrow(ground) / 3, big.mark = ",")), file.path(out, paste0(name, "_caption.txt")))

if (coverage_only) cat("\nCoverage-only selection in the same represented cells as the primary sample: station-level offset, outlier-fraction and step checks are omitted. Source quality checks, ERA5 input completeness, extreme hourly-outlier removal and year-round coverage requirements are retained.\n", file = file.path(out, paste0(name, "_caption.txt")), append = TRUE)

if (no_era5_screen) cat("\nSelection without ERA5-residual screening, within the same represented cells and frozen candidate order. Archive pressure quality flags, valid pressure range, hourly deduplication, complete atmospheric inputs and year-round coverage are retained. No ERA5-residual outlier removal, outlier-fraction rejection, mean-offset rejection or step check is applied.\n", file = file.path(out, paste0(name, "_caption.txt")), append = TRUE)

if (pressure_window) cat("\nPressure-only backwards selection: retain the latest 12-month window satisfying year-round coverage and containing no pressure jumps >20 hPa within three hours or >50 hPa across gaps up to seven days. Archive pressure quality, valid pressure range and hourly deduplication are retained, with complete atmospheric conversion inputs. No ERA5-residual selection is used. Candidates are assessed in the frozen order within the original represented cells.\n", file = file.path(out, paste0(name, "_caption.txt")), append = TRUE)

if (terrain_screen) cat("\nBefore pressure-window selection, station elevation must lie within 50 m of the range of independently sampled SRTM/ASTER terrain heights at its coordinates and eight surrounding positions at offsets of 500 m in each horizontal axis. The same criterion applies to every candidate, without using ERA5 or conversion residuals. Candidates are assessed in the frozen order, including replacements beyond previously cached attempts, within the original represented cells.\n", file = file.path(out, paste0(name, "_caption.txt")), append = TRUE)

if (terrain_screen) cat("\nIndependent reference conflicts are excluded before candidate assessment. The latest year must pass pressure-only spike, jump, repeated-noise, frozen-value and coverage checks; reference exclusions are listed in docs/methods/ghcnh_reference_exclusions.csv.\n", file = file.path(out, paste0(name, "_caption.txt")), append = TRUE)

if (terrain_screen) cat("\nIsolated pressure spikes are removed before coverage and continuity checks: a report must differ by more than 5 hPa from each adjacent report, both adjacent reports must lie within three hours, and their pressures must agree within 2 hPa. This observation-level rule uses pressure and time only.\n", file = file.path(out, paste0(name, "_caption.txt")), append = TRUE)

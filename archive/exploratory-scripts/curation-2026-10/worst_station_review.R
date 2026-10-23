# Visual review of the selected GHCNh station years with the largest ERA5 errors.
source("R/utils.R")
source("R/ghcnh_consistency.R")
library(ggplot2)
library(patchwork)
args <- commandArgs(trailingOnly = TRUE)
n_review <- if (length(args)) as.integer(args[1]) else 48L
out <- "output/drafts/worst-stations"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# Station errors as written by the selection stage, so a review needs no downstream rebuild.
st <- merge(fread("output/drafts/atmospheric-figures/ground_terrain_window_stations.csv")[formula == "standard", .(id, bias_sl = bias, sd_sl = sd)],
  fread("data/interim/ghcnh/selection-curated-2026-10-22/full-accepted.csv"), by = "id")
st[, score := sqrt(bias_sl^2 + sd_sl^2)]
worst <- st[order(-score)][seq_len(n_review)]
fwrite(worst[, .(rank = .I, id, name, lat, lon, elev, window_start, window_end, bias = round(bias_sl, 1), sd = round(sd_sl, 1))],
  file.path(out, "worst_stations.csv"))

theme_set(theme_minimal(base_size = 8) + theme(panel.grid.minor = element_blank(), legend.position = "right",
  plot.title = element_text(size = 8, face = "bold"), legend.key.size = grid::unit(.3, "cm")))
panels <- list()
for (i in seq_len(nrow(worst))) {
  s <- worst[i]
  d <- as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-curated-2026-10-22/accepted", paste0(s$id, ".parquet")),
    col_select = c("date", "pressure", "source_code", "err_standard")))
  ref <- as.data.table(read_parquet(file.path("data/interim/ghcnh/selection-2026-10-13/reference", paste0(s$id, ".parquet"))))
  x <- ghcnh_consistency_inputs(d[, .(date, pressure)], ref, s)
  d <- merge(d, x[, .(date, h_alt, h_slp)], by = "date")
  d[, height := fifelse(is.finite(h_alt), h_alt, h_slp) - s$elev]
  daily <- d[, .(err = median(err_standard), height = median(height, na.rm = TRUE)), by = .(day = as.POSIXct(as.Date(date)))]
  lim <- quantile(d$err_standard, c(.002, .998))
  title <- sprintf("%d %s %s (%.0f m)  bias %.0f  sd %.0f", i, s$id, s$name, s$elev, s$bias_sl, s$sd_sl)
  p1 <- ggplot(d, aes(date, err_standard)) + geom_point(aes(colour = source_code), size = .15, alpha = .4) +
    geom_line(data = daily, aes(day, err), linewidth = .3) + geom_hline(yintercept = 0, linewidth = .2) +
    coord_cartesian(ylim = range(c(lim, -20, 20))) + labs(title = title, x = NULL, y = "ERA5 error (m)", colour = "source") +
    guides(colour = guide_legend(override.aes = list(size = 1.5, alpha = 1)))
  p2 <- ggplot(daily, aes(day, height)) + geom_line(linewidth = .3, colour = "#7a3b8f") + geom_hline(yintercept = 0, linewidth = .2) +
    labs(x = NULL, y = "Implied height - elev (m)")
  panels[[i]] <- p1 + p2 + plot_layout(widths = c(2.2, 1))
}
for (page in split(seq_along(panels), ceiling(seq_along(panels) / 8))) {
  ggsave(file.path(out, sprintf("worst_%02d-%02d.png", min(page), max(page))), wrap_plots(panels[page], ncol = 1),
    width = 11, height = 14, dpi = 110, bg = "white")
}

# Visual review of the selected IGRA station years with the largest ERA5 errors at 1-3 km.
source("R/utils.R")
library(ggplot2)
library(patchwork)
args <- commandArgs(trailingOnly = TRUE)
n_review <- if (length(args)) as.integer(args[1]) else 48L
out <- "output/drafts/worst-soundings"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
acc <- fread(file.path(selection_dir("igra"), "full-accepted.csv"))
read_station <- function(id) {
  d <- as.data.table(read_parquet(file.path(selection_dir("igra"), "accepted", paste0(id, ".parquet")),
    col_select = c("sounding", "launch", "press", "press_s", "temp", "agl", "err_standard", "p_source")))
  setorder(d, sounding, -press)
  d[, tmean := sonde_mean_temperature(press, press_s, temp), by = sounding]
  d[, mismatch := agl - 287.05 / 9.80665 * tmean * log(press_s / press)]
  d[agl > 1000 & agl <= 3000]
}
st <- rbindlist(parallel::mclapply(acc$id, function(id) read_station(id)[, .(id = id, bias = mean(err_standard), sd = sd(err_standard))], mc.cores = 8))
st <- merge(st, acc[, .(id, name, lat, lon, elev)], by = "id")
st[, score := sqrt(bias^2 + sd^2)]
worst <- st[order(-score)][seq_len(n_review)]
fwrite(worst[, .(rank = .I, id, name, lat, lon, elev, bias = round(bias, 1), sd = round(sd, 1))], file.path(out, "worst_soundings.csv"))

theme_set(theme_minimal(base_size = 8) + theme(panel.grid.minor = element_blank(), legend.position = "right",
  plot.title = element_text(size = 8, face = "bold"), legend.key.size = grid::unit(.3, "cm")))
panels <- list()
for (i in seq_len(nrow(worst))) {
  s <- worst[i]
  d <- read_station(s$id)
  daily <- d[, .(err = median(err_standard), mismatch = median(mismatch, na.rm = TRUE)), by = .(day = as.POSIXct(as.Date(launch)))]
  title <- sprintf("%d %s %s (%.0f m, %.0f°)  1-3 km bias %.0f  sd %.0f", i, s$id, s$name, s$elev, s$lat, s$bias, s$sd)
  p1 <- ggplot(d, aes(launch, err_standard)) + geom_point(aes(colour = p_source), size = .15, alpha = .4) +
    geom_line(data = daily, aes(day, err), linewidth = .3) + geom_hline(yintercept = 0, linewidth = .2) +
    labs(title = title, x = NULL, y = "ERA5 error (m)", colour = "source") +
    guides(colour = guide_legend(override.aes = list(size = 1.5, alpha = 1)))
  p2 <- ggplot(daily, aes(day, mismatch)) + geom_line(linewidth = .3, colour = "#7a3b8f") + geom_hline(yintercept = 0, linewidth = .2) +
    labs(x = NULL, y = "Height - hypsometric (m)")
  panels[[i]] <- p1 + p2 + plot_layout(widths = c(2.2, 1))
}
for (page in split(seq_along(panels), ceiling(seq_along(panels) / 8))) {
  ggsave(file.path(out, sprintf("worst_%02d-%02d.png", min(page), max(page))), wrap_plots(panels[page], ncol = 1),
    width = 11, height = 14, dpi = 110, bg = "white")
}

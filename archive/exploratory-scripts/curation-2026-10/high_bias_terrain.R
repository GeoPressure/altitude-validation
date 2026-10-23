# Compare high-bias station metadata with terrain independently of ERA5.
source("R/utils.R")
source("R/palette.R")
library(ggplot2)
library(httr2)
out <- "output/drafts/atmospheric-figures"
s <- fread(file.path(out, "high_bias_stations_review.csv"))

# Sample SRTM at the coordinate and eight surrounding points, 500 m apart.
q <- s[, .(north_m = rep(c(-500, 0, 500), each = 3), east_m = rep(c(-500, 0, 500), 3)), by = .(id, lat, lon)]
q[, `:=`(query_lat = lat + north_m / 111320, query_lon = lon + east_m / (111320 * cos(lat * pi / 180)))]
q[, batch := ceiling(.I / 54)]
for (b in unique(q$batch)) {
  file <- file.path(out, paste0("high_bias_srtm30m_batch", b, ".json"))
  if (!file.exists(file)) request("https://api.opentopodata.org/v1/srtm30m") |>
    req_url_query(locations = paste(sprintf("%.7f,%.7f", q[batch == b]$query_lat, q[batch == b]$query_lon), collapse = "|"), interpolation = "bilinear") |>
    req_perform(path = file)
  r <- jsonlite::read_json(file, simplifyVector = TRUE)
  stopifnot(r$status == "OK")
  q[batch == b, dem := r$results$elevation]
}
fwrite(q, file.path(out, "high_bias_terrain_samples.csv"))
terrain <- q[, .(dem_at_coordinate = dem[north_m == 0 & east_m == 0], sampled_min = min(dem), sampled_max = max(dem)), by = id]
s <- merge(s, terrain, by = "id")[order(-abs(bias))]
s[, `:=`(listed_minus_dem = elev - dem_at_coordinate, inferred_minus_dem = inferred_height - dem_at_coordinate)]
fwrite(s, file.path(out, "high_bias_terrain_review.csv"))

# Show the three heights on the same scale within each station.
s[, label := sprintf("%s\n%s", name, id)]
p <- melt(s, id.vars = c("id", "label"), measure.vars = c("dem_at_coordinate", "elev", "inferred_height"), variable.name = "height_source", value.name = "height")
p[, x := match(height_source, c("dem_at_coordinate", "elev", "inferred_height"))]
p[, label := factor(label, levels = s$label)]
p <- ggplot(p, aes(x, height, colour = height_source)) +
  geom_segment(aes(x = x - .27, xend = x + .27, yend = height), linewidth = .8) +
  geom_text(aes(label = round(height)), vjust = -1, size = 3.1, show.legend = FALSE) +
  facet_wrap(~label, scales = "free_y", ncol = 3) +
  scale_colour_manual(values = c(dem_at_coordinate = pal_conversion[["virtual"]], elev = "#67727E", inferred_height = pal_conversion[["standard"]]), guide = "none") +
  scale_x_continuous(breaks = 1:3, labels = c("Terrain", "Listed", "Pressure"), limits = c(.5, 3.5)) +
  scale_y_continuous(expand = expansion(mult = c(.1, .25))) +
  labs(x = NULL, y = "Elevation / altitude (m above sea level)") +
  theme_minimal(base_family = "Helvetica Neue", base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(), strip.text = element_text(face = "bold", size = 9), panel.spacing = grid::unit(1.2, "lines"))
ggsave(file.path(out, "high_bias_terrain_comparison.png"), p, width = 11, height = 10, dpi = 200, bg = "white", device = ragg::agg_png)
ggsave(file.path(out, "high_bias_terrain_comparison.pdf"), p, width = 11, height = 10, device = cairo_pdf)
print(s[, .(name, elev, dem_at_coordinate, inferred_height = round(inferred_height), listed_minus_dem, sampled_min, sampled_max)])

# Figure 2: geographic and environmental extent of the reference comparisons.
# Run from the repository root; called by Rscript run_all.R figures.
source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages({ library(ggplot2); library(patchwork); library(sf) })
st <- load_stations()
ground_ids <- fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GHCNh" & formula == "standard", id]
flight_ids <- fread(file.path(dir_tables, "flight_stations_used.csv"))$id
sites <- rbind(st[network == "ghcnh" & id %in% ground_ids], st[network == "igra" & id %in% flight_ids])
sites[, dataset := factor(fifelse(network == "ghcnh", "GHCNh", "IGRA2"), c("GHCNh", "IGRA2"))]
counts <- sites[, .N, by = dataset]
colours <- pal_reference[c("GHCNh", "IGRA2")]

# Compact dataset cards keep the map as the main element.
cards <- list()
for (i in 1:2) {
  cards[[i]] <- ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = .03, ymax = .97,
      fill = "#F8FAFC", colour = pal[["grid"]], linewidth = .3) +
    annotation_custom(grid::rasterGrob(png::readPNG(paste0("paper/figures/icons/",
      c("radio-tower", "balloon")[i], ".png"), native = TRUE),
      x = .13, y = .52, width = grid::unit(6, "mm"), height = grid::unit(6, "mm"))) +
    annotate("text", x = .27, y = .72, hjust = 0, label = format(counts$N[i], big.mark = ",", trim = TRUE),
      colour = unname(colours[i]), fontface = "bold", family = font, size = 4.5) +
    annotate("text", x = .27, y = .28, hjust = 0,
      label = c("Weather stations\nGHCNh", "Sounding sites\nIGRA2")[i],
      colour = "#4B5563", family = font, size = 2.5, lineheight = .9) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void() + theme(plot.margin = margin(2, 2, 2, 2))
}

world <- rnaturalearth::ne_countries(scale = 110, returnclass = "sf")
# Main Koppen-Geiger zones (kgc, 0.5 deg) as a light background, as used to group the stations.
data("climatezones", package = "kgc", envir = environment())
kz <- as.data.table(climatezones)[, main := match(substr(Cls, 1, 1), LETTERS[1:5])][!is.na(main)]
kz_rast <- terra::rast(kz[, .(Lon, Lat, main)], type = "xyz", crs = "EPSG:4326")
climate <- st_as_sf(terra::as.polygons(kz_rast, dissolve = TRUE))
climate$zone <- factor(names(pal_climate)[climate$main], names(pal_climate))
sf_use_s2(FALSE)
climate <- suppressMessages(suppressWarnings(st_intersection(st_make_valid(climate),
  st_union(st_make_valid(world)))))
map <- ggplot() +
  geom_sf(data = world, fill = "#EEF0F3", colour = NA) +
  geom_sf(data = climate, aes(fill = zone), colour = NA, alpha = .28) +
  geom_sf(data = world, fill = NA, colour = "white", linewidth = .15) +
  scale_fill_manual(values = pal_climate, labels = tools::toTitleCase(sub("^[A-E] ", "", names(pal_climate))),
    name = NULL, guide = guide_legend(nrow = 1, override.aes = list(alpha = .45))) +
  geom_sf(data = st_as_sf(sites, coords = c("lon", "lat"), crs = 4326),
    aes(colour = dataset, shape = dataset, size = dataset), alpha = .8) +
  scale_colour_manual(values = colours) + scale_shape_manual(values = c(GHCNh = 16, IGRA2 = 17)) +
  scale_size_manual(values = c(GHCNh = .4, IGRA2 = .65)) +
  coord_sf(crs = "+proj=eqearth", expand = FALSE) +
  guides(colour = "none", shape = "none", size = "none") +
  theme_void(base_family = font) + theme(legend.position = "bottom", legend.text = element_text(size = 7, colour = "#4B5563"),
    legend.key.size = unit(7, "pt"), legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(2, "pt"),
    panel.grid.major = element_line(colour = "#F3F4F6", linewidth = .2),
    plot.margin = margin(0, 5, 0, 5))
# Common 250 m bins; percentages normalize the different network sizes.
elevations <- sites[, .N, by = .(dataset, bin = floor(elev / 250) * 250)]
elevations[, percent := 100 * N / sum(N), by = dataset]
elevation <- ggplot(elevations, aes((bin + 125) / 1000, percent, fill = dataset, colour = dataset)) +
  geom_col(width = .25, position = "identity", alpha = .2, linewidth = .3) +
  scale_fill_manual(values = colours) + scale_colour_manual(values = colours) +
  scale_x_continuous(breaks = c(0, 2, 4), limits = c(-.25, 4.5), expand = c(0, 0)) +
  scale_y_continuous(breaks = c(0, 25, 50), limits = c(0, 75), expand = expansion(mult = c(0, .02))) +
  labs(x = "Station elevation (km)", y = "Stations (%)") +
  theme_minimal(base_size = 8, base_family = font) +
  theme(legend.position = "none", panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(colour = pal[["grid"]], linewidth = .25),
    axis.text = element_text(colour = "#566476"), plot.margin = margin(8, 3, 2, 3))
sidebar <- cards[[1]] / cards[[2]] / elevation + plot_layout(heights = c(.65, .65, 1.7))
p2 <- map + sidebar + plot_layout(widths = c(3.25, 1))
save_figure(p2, "fig2_stations", 7.2, 3.3)
fwrite(elevations, file.path(dir_tables, "paper_fig2_coverage.csv"))

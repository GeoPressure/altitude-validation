# Additional file 1, S3: ground errors with ERA5 single-level and ERA5-Land surface conditions.
source("R/utils.R")
source("R/figures.R")
suppressPackageStartupMessages(library(patchwork))
theme_set(theme_paper(10.5))
update_geom_defaults("line", list(linewidth = 0.7))
tab <- function(f) fread(file.path(dir_tables, f))

# Same quantities as the rows of Figure 3, standard lapse rate, hours with both products: (a) joint
# distribution of hourly absolute errors (equal total weight per station), (b, c) one point per
# station. Shading separates the stations or hours where ERA5-Land is worse (upper left) or better
# (lower right) than ERA5, with their shares. Axis bars: median, 25-75% (thick) and 10-90% (thin).
gl <- tab("ground_station_products.csv")[
  is.finite(bias_land) &
    is.finite(bias_sl_paired) &
    is.finite(sd_land) &
    is.finite(sd_sl_paired)
]
hh <- tab("ground_land_hourly_hist.csv")
# Merge the stored bins in pairs for a smoother display
e <- sort(unique(c(hh$x0, hh$x1)))
hh[, `:=`(ix = (match(x0, e) + 1) %/% 2, iy = (match(y0, e) + 1) %/% 2)]
hh <- hh[, .(w = sum(w)), by = .(ix, iy)][, `:=`(
  x0 = e[2 * ix - 1],
  x1 = e[pmin(2 * ix + 1, length(e))],
  y0 = e[2 * iy - 1],
  y1 = e[pmin(2 * iy + 1, length(e))]
)]
hq <- tab("ground_land_hourly_quantiles.csv")
plog <- function(x) asinh(x / 2) / log(10)
iplog <- function(t) 2 * sinh(t * log(10))
col_sl <- pal_conversion[["standard"]]
col_land <- pal_product[["ERA5-Land"]]
qv <- function(v) {
  setNames(
    as.list(quantile(v, c(0.1, 0.25, 0.5, 0.75, 0.9), names = FALSE)),
    c("q10", "q25", "q50", "q75", "q90")
  )
}
land_panel <- function(title, lim, breaks, qx, qy, larger, layer) {
  t0 <- plog(lim[1])
  t1 <- plog(lim[2])
  off <- iplog(t0 - 0.05 * (t1 - t0))
  at <- function(f) iplog(t0 + f * (t1 - t0))
  bar <- function(m, col, horizontal) {
    seg <- function(a, b, lw, al = 1) {
      if (horizontal) {
        annotate(
          "segment",
          x = a,
          xend = b,
          y = off,
          yend = off,
          colour = col,
          linewidth = lw,
          alpha = al
        )
      } else {
        annotate(
          "segment",
          y = a,
          yend = b,
          x = off,
          xend = off,
          colour = col,
          linewidth = lw,
          alpha = al
        )
      }
    }
    list(
      seg(m$q10, m$q90, 0.4),
      seg(m$q25, m$q75, 2, 0.6),
      if (horizontal) {
        annotate("point", x = m$q50, y = off, colour = col, size = 1.3)
      } else {
        annotate("point", y = m$q50, x = off, colour = col, size = 1.3)
      }
    )
  }
  sc <- list(trans = scales::pseudo_log_trans(sigma = 1), breaks = breaks)
  ggplot() +
    annotate(
      "polygon",
      x = lim[c(1, 1, 2)],
      y = lim[c(1, 2, 2)],
      fill = col_land,
      alpha = 0.09
    ) +
    annotate(
      "polygon",
      x = lim[c(1, 2, 2)],
      y = lim[c(1, 1, 2)],
      fill = col_sl,
      alpha = 0.09
    ) +
    layer +
    geom_abline(
      slope = 1,
      intercept = 0,
      colour = pal[["ink"]],
      linewidth = 0.3,
      linetype = "dashed"
    ) +
    annotate(
      "text",
      x = at(0.05),
      y = at(0.95),
      label = sprintf("%.0f%%", 100 * larger),
      hjust = 0,
      vjust = 1,
      size = 4,
      fontface = "bold",
      colour = col_land,
      family = font
    ) +
    annotate(
      "text",
      x = at(0.95),
      y = at(0.05),
      label = sprintf("%.0f%%", 100 * (1 - larger)),
      hjust = 1,
      vjust = 0,
      size = 4,
      fontface = "bold",
      colour = col_sl,
      family = font
    ) +
    bar(qx, col_sl, TRUE) +
    bar(qy, col_land, FALSE) +
    do.call(scale_x_continuous, sc) +
    do.call(scale_y_continuous, sc) +
    coord_cartesian(xlim = lim, ylim = lim, expand = FALSE, clip = "off") +
    labs(title = title, x = "ERA5 single levels", y = "ERA5-Land") +
    theme(
      aspect.ratio = 1,
      panel.grid.major = element_blank(),
      axis.text.x.bottom = element_text(margin = margin(t = 12)),
      axis.text.y.left = element_text(margin = margin(r = 12)),
      axis.title.x = element_text(colour = col_sl),
      axis.title.y = element_text(colour = col_land),
      plot.title = element_text(size = 10, hjust = 0.5)
    )
}
pts <- function(x, y) {
  geom_point(
    aes(x, y),
    data = data.table(x = x, y = y),
    size = 0.6,
    alpha = 0.4,
    colour = pal[["ink"]],
    stroke = 0
  )
}
hourly_tiles <- geom_rect(
  aes(
    xmin = iplog(x0),
    xmax = iplog(x1),
    ymin = iplog(y0),
    ymax = iplog(y1),
    alpha = w
  ),
  data = hh,
  fill = pal[["ink"]]
)
log_breaks <- c(0, 1, 3, 10, 30, 100, 300)
pl <- land_panel(
  "Hourly absolute error (m)",
  c(0, 400),
  log_breaks,
  hq[product == "sl"],
  hq[product == "land"],
  hq$land_larger[1],
  list(
    hourly_tiles,
    scale_alpha_continuous(
      range = c(0.04, 0.75),
      trans = "sqrt",
      guide = "none"
    )
  )
) +
  (land_panel(
    "Absolute station bias (m)",
    c(0, 400),
    log_breaks,
    qv(abs(gl$bias_sl_paired)),
    qv(abs(gl$bias_land)),
    mean(abs(gl$bias_land) > abs(gl$bias_sl_paired)),
    pts(abs(gl$bias_sl_paired), abs(gl$bias_land))
  ) +
    labs(y = NULL)) +
  (land_panel(
    "Within-station SD (m)",
    c(1, 30),
    c(1, 3, 10, 30),
    qv(gl$sd_sl_paired),
    qv(gl$sd_land),
    mean(gl$sd_land > gl$sd_sl_paired),
    pts(gl$sd_sl_paired, gl$sd_land)
  ) +
    labs(y = NULL)) +
  plot_annotation(tag_levels = "a")
save_figure(pl, "supp_land", 7.2, 2.9)

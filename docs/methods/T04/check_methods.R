# Check the equations and current implementation --------------------------------
# Run from the repository root: Rscript docs/methods/T04/check_methods.R
source("R/utils.R")
load_geopressurer()

# Independent integration of a linear temperature profile ------------------------
cases <- expand.grid(T0 = c(260, 288.15, 310), p0 = c(80000, 101325), L = c(-0.0098, -0.0065, 0.002), dz = c(100, 2000, 6000))
cases$p <- with(cases, p0 * (1 + L * dz / T0)^(-9.80665 * 0.0289644 / (8.31432 * L)))
cases$retrieved <- with(cases, altitude_lapse(p, p0, T0, 0, L))
cases$integrated <- vapply(seq_len(nrow(cases)), function(i) {
  d <- cases[i, ]
  8.31432 / (9.80665 * 0.0289644) * integrate(function(lp) d$T0 * (exp(lp) / d$p0)^(-8.31432 * d$L / (9.80665 * 0.0289644)), log(d$p), log(d$p0))$value
}, numeric(1))
stopifnot(max(abs(cases$retrieved - cases$dz)) < 1e-7, max(abs(cases$integrated - cases$dz)) < 1e-7)

# Agreement with the actual package, including poles and longitude wrap -----------
gpt3 <- gpt3_read(1)
points <- expand.grid(lon = c(-180, -0.1, 0, 0.5, 8.2, 359.9), lat = c(-89.75, -45.2, 0, 47.1, 89.75), day = c("2024-01-01", "2024-02-29", "2024-12-31"))
points$date <- as.POSIXct(points$day, tz = "UTC") + 43200
points$L <- gpt3_lapse(gpt3, points$lon, points$lat, as.POSIXlt(points$date, tz = "UTC")$yday + 1)
points$L_safe <- ifelse(abs(points$L) < 1e-5, -1e-5, points$L)
points$ours <- altitude_lapse(80000, 101325, virtual_temperature(288.15, 280, 101325), 0, points$L_safe)
points$package <- pressure_to_altitude(80000, 101325, 288.15, 0, dewpoint = 280, lon = points$lon, lat = points$lat, date = points$date, altitude_formula = "virtual")
stopifnot(max(abs(points$ours - points$package)) < 1e-8)

# Two documented differences from TU Wien's full reference routine ---------------
# TU Wien retains fractional day; current R uses calendar day only.
points$L_fractional <- gpt3_lapse(gpt3, points$lon, points$lat, as.POSIXlt(points$date, tz = "UTC")$yday + 1.5)
# At |latitude| >= 89.5°, TU Wien chooses a single nearest grid cell.
polar <- points[abs(points$lat) >= 89.5, ]
row <- pmin(floor(90 - polar$lat), 179)
col <- floor(polar$lon %% 360)
phase <- 2 * pi * (as.POSIXlt(polar$date, tz = "UTC")$yday + 1) / 365.25
polar$L_nearest <- rowSums(gpt3$dT[row * 360 + col + 1, ] * cbind(1, cos(phase), sin(phase), cos(2 * phase), sin(2 * phase)))

# Height convention and residual effect of a constant pressure offset -------------
height <- data.frame(geopotential_m = c(100, 2000, 6000))
height$geometric_minus_geopotential_m <- with(height, 6371000 * geopotential_m / (6371000 - geopotential_m) - geopotential_m)
p2000 <- 101325 * (1 - 0.0065 * 2000 / 288.15)^(9.80665 * 0.0289644 / (8.31432 * 0.0065))
offset_residual <- altitude_lapse(p2000 + 100, 101325, 288.15, 0) - altitude_lapse(101425, 101325, 288.15, 0) - 2000

results <- data.frame(check = c("linear_profile_inverse_max_error_m", "independent_quadrature_max_error_m", "package_agreement_max_error_m", "sample_half_day_lapse_change_K_per_m", "sample_polar_interpolation_difference_K_per_m", "one_hPa_offset_residual_at_2km_m"), value = c(max(abs(cases$retrieved - cases$dz)), max(abs(cases$integrated - cases$dz)), max(abs(points$ours - points$package)), max(abs(points$L_fractional - points$L)), max(abs(polar$L - polar$L_nearest)), offset_residual))
write.csv(results, "docs/methods/T04/check-results.csv", row.names = FALSE)
write.csv(height, "docs/methods/T04/height-convention.csv", row.names = FALSE)
print(results)
print(height)

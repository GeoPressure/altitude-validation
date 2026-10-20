# Check the proposed sampling design on synthetic examples -----------------
library(dplyr)
library(lubridate)
library(readr)

# Exhaustive candidate permutations give exact selection probabilities.
permutations <- expand.grid(a = 1:5, b = 1:5, c = 1:5, d = 1:5, e = 1:5) |>
  filter(a != b, a != c, a != d, a != e, b != c, b != d, b != e, c != d, c != e, d != e)
selection <- integer(nrow(permutations))
for (i in seq_len(nrow(permutations))) {
  order <- unlist(permutations[i, ], use.names = FALSE)
  selection[i] <- order[order %in% c(2, 4, 5)][1]
}
primary_counts <- table(selection)
stopifnot(nrow(permutations) == factorial(5), all(primary_counts == 40))

# Calendar years and half-open UTC boundaries include leap days correctly.
windows <- tibble(end = as.Date(c('2026-10-13', '2024-03-01', '2025-03-01'))) |>
  mutate(start = end %m-% years(1), days = as.integer(end - start))
stopifnot(identical(windows$days, c(365L, 366L, 365L)))

# The coverage threshold can pass with all observations in half of the year.
days <- seq(as.Date('2025-01-01'), by = 'day', length.out = 183)
stopifnot(length(days) >= 183, 4 * length(days) / length(days) >= 4, length(unique(quarter(days))) < 4)

# Monthly coverage gives every month representation without a total-day rule.
monthly <- tibble(date = seq(as.Date('2025-01-01'), as.Date('2025-12-31'), by = 'day')) |>
  mutate(month = month(date), accepted_hours = if_else(day(date) <= 15, 4L, 0L)) |>
  group_by(month) |>
  summarise(qualifying_days = sum(accepted_hours >= 4), .groups = 'drop')
sparse <- tibble(date = days) |>
  count(month = month(date)) |>
  right_join(tibble(month = 1:12), by = 'month') |>
  mutate(n = coalesce(n, 0L))
stopifnot(all(monthly$qualifying_days >= 15), sum(monthly$qualifying_days) == 180,
  !all(sparse$n >= 15))

# Every station has equal total weight despite different reporting schedules.
hours <- tibble(station = rep(c('a', 'b'), c(4, 12))) |>
  group_by(station) |>
  mutate(weight = 1 / n()) |>
  summarise(total_weight = sum(weight), .groups = 'drop')
stopifnot(all(hours$total_weight == 1))

write_csv(tibble(check = c('Primary: first passing among three eligible candidates',
  'Leap-year windows use calendar months', '183-day coverage can omit a quarter',
  'Stations have equal total observation weight',
  '180 qualifying dates distributed over 12 months', '183 consecutive dates under monthly coverage'),
  result = c('Each selected in 40 of 120 permutations',
  paste(windows$days, collapse = ', '), 'Confirmed: threshold alone does not ensure seasonal coverage',
  'Each station sums to one', 'Passes proposed 15-day monthly rule',
  'Fails proposed 15-day monthly rule')), 
  'docs/methods/ghcnh-sampling-review/check_results.csv')
write_csv(windows, 'docs/methods/ghcnh-sampling-review/window_examples.csv')
cat('Six synthetic design checks passed. No station data or analysis outputs changed.\n')

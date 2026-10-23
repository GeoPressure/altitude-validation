# Inspect pressure-only rules on known failures and ordinary cached records.
source("R/utils.R")
source("R/ghcnh_sampling.R")
library(ggplot2)
setDTthreads(1)
set.seed(23)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
known <- c("BTM00044517", "NZU093800-1", "CII0000SCIP", "THM00048563", "BRM00086674", "CDU004756-1", "AYM00089003")
cached <- tools::file_path_sans_ext(list.files(file.path(run_dir, "pressure"), pattern = "parquet$"))
ids <- unique(c(known, sample(setdiff(cached, known), 50)))
metrics <- list()
examples <- list()
for (id_value in ids) {
  raw <- as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(id_value, ".parquet"))))
  d <- ghcnh_pressure_spikes(raw)
  episodes <- ghcnh_pressure_episodes(d)
  metrics[[length(metrics) + 1L]] <- data.table(id = id_value, reports = nrow(raw), spikes_removed = nrow(raw) - nrow(d),
    jumps = sum(episodes$reason == "jump"), noisy_windows = sum(episodes$reason == "noise"), frozen_runs = sum(episodes$reason == "frozen"))
  if (id_value %in% known && nrow(episodes)) {
    episode <- episodes[order(reason == "jump", start)][1]
    examples[[id_value]] <- raw[date >= episode$start - 12 * 3600 & date <= min(episode$end, episode$start + 72 * 3600) + 12 * 3600,
      .(id = id_value, date, pressure, failure = date >= episode$start & date <= episode$end)]
  }
}
metrics <- merge(rbindlist(metrics), candidates[, .(id, name)], by = "id")
fwrite(metrics, "output/drafts/pressure-filter/pressure_metrics.csv")
print(metrics[jumps > 0 | noisy_windows > 0 | frozen_runs > 0])
p <- ggplot(rbindlist(examples), aes(date, pressure)) + geom_line(linewidth = .3) +
  geom_point(aes(colour = failure), size = .7) + facet_wrap(~id, scales = "free", ncol = 2) +
  scale_colour_manual(values = c("FALSE" = "#333333", "TRUE" = "#C64736"), guide = "none") +
  labs(x = "Date (UTC)", y = "Station pressure (hPa)") + theme_bw(base_size = 10)
ggsave("output/drafts/pressure-filter/pressure_examples.png", p, width = 11, height = 8, dpi = 150)

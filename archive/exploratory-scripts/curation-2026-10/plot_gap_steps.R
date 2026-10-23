source("R/utils.R")
library(ggplot2)
library(patchwork)
x <- unique(fread("output/drafts/pattern-application/gap_step_candidates.csv")[flag == TRUE], by = "id")
p <- list()
for (id_value in x$id) {
  d <- as.data.table(read_parquet(file.path(selection_dir("ghcnh"), "accepted", paste0(id_value, ".parquet"))))
  p <- c(p, list(ggplot(d, aes(date, pressure)) + geom_line(linewidth = .2) + labs(title = id_value, y = "Pressure (hPa)") + theme_bw(),
    ggplot(d, aes(date, err_standard)) + geom_line(linewidth = .2) + labs(y = "ERA5 height error (m)") + theme_bw()))
}
for (i in seq_len(ceiling(nrow(x) / 4))) ggsave(paste0("output/drafts/pattern-application/gap_review", i, ".png"), wrap_plots(p[((i - 1) * 8 + 1):min(i * 8, length(p))], ncol = 2), width = 14, height = 10, dpi = 110)

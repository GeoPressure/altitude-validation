# Thin the Tier A station set to keep the ERA5 download manageable (~2 MB per ARCO chunk read).
#
# From the stations with adequate station pressure, keep one random station per 5 x 5 degree cell
# (spatial balance) plus one random station per 2.5 x 2.5 degree cell above 1000 m (mountains,
# where errors are expected to be largest). A few hundred stations are plenty for stable medians
# and driver models; doubling the set would mostly add European and North American stations.
#
# ERA5-Land is only needed to confirm, globally, how much worse it is than single-levels, so it is
# read for a random subset (`land = TRUE`) of 200 Tier A stations.

source("R/utils.R")
set.seed(6)

s <- fread(file.path(dir_interim, "stations_A_all.csv"))
s[, cell := paste(floor(lat / 5), floor(lon / 5))]
base <- s[, .SD[sample(.N, 1)], by = cell]
high <- s[elev > 1000, .SD[sample(.N, 1)], by = .(cell2 = paste(floor(lat / 2.5), floor(lon / 2.5)))]
keep <- unique(c(base$id, high$id))
sel <- s[id %in% keep, !"cell"]
sel[, land := id %in% sample(id, min(.N, 200))]
fwrite(sel, file.path(dir_interim, "stations_A.csv"))
cat(nrow(sel), "Tier A stations kept of", nrow(s), "(", sum(sel$land), "with ERA5-Land )\n")

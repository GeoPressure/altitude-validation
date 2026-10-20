# Thin the surface stations for spatial balance.
#
# Dense national networks (Europe, North America, East Asia) would otherwise dominate every global
# summary, since each station weighs equally. From the stations with adequate station pressure,
# keep one random station per 2 x 2 degree cell, plus every station above 1000 m: mountain stations
# are scarce and are where errors are expected to be largest. The same rule is used for the
# radiosondes (04_igra_download.R).

source("R/utils.R")
set.seed(6)

s <- fread(file.path(dir_interim, "hadisd_stations_all.csv"))
sel <- thin_stations(s)
fwrite(sel, file.path(dir_interim, "hadisd_stations.csv"))
cat(nrow(sel), "surface stations kept of", nrow(s), "(", sum(sel$elev > 1000), "above 1000 m )\n")

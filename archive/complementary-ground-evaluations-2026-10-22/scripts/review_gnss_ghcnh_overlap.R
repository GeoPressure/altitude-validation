# Audit whether nearby GHCNh stations carry the GNSS barometer observations.
# The candidate inventory includes all sites within 5 km, or the nearest active site.
source("R/utils.R")
suppressPackageStartupMessages(library(sf))
setDTthreads(1)
cache <- "data/interim/gnss-ghcnh-overlap"
dir.create(cache,recursive=TRUE,showWarnings=FALSE)
gnss <- fread("output/tables/paper_ground_station.csv")[reference == "GNSS" & formula == "standard"]
gnss[, id := sub("^GNSS ", "", id)]
raw <- readLines(file.path(dir_raw, "ghcnh-station-list.txt"), warn = FALSE)
inventory <- data.table(ghcnh_id = trimws(substr(raw, 1, 11)), ghcnh_lat = as.numeric(substr(raw, 13, 20)),
  ghcnh_lon = as.numeric(substr(raw, 22, 30)), name = trimws(substr(raw, 42, 71)), wmo = trimws(substr(raw, 81, 85)))
catalogue <- rbindlist(lapply(years_main, function(y) readRDS(file.path(selection_dir("ghcnh"), "catalogue", paste0(y, ".rds")))))
inventory <- inventory[ghcnh_id %in% catalogue$id & is.finite(ghcnh_lat) & is.finite(ghcnh_lon)]
g <- st_as_sf(gnss, coords = c("lon", "lat"), crs = 4326)
h <- st_as_sf(inventory, coords = c("ghcnh_lon", "ghcnh_lat"), crs = 4326)
nearby <- st_is_within_distance(g, h, dist = 5000)
matches <- rbindlist(lapply(seq_len(nrow(gnss)), function(i) {
  j <- nearby[[i]]
  if (!length(j)) j <- st_nearest_feature(g[i, ], h)
  cbind(gnss[i, .(id, lat, lon, elev)], inventory[j],
    distance_km = as.numeric(st_distance(g[i, ], h[j, ])) / 1000)
}))
matches[, year := vapply(ghcnh_id, function(s) max(catalogue[id == s, year]), integer(1))]
annuals <- unique(matches[,.(ghcnh_id,year)])
prepare <- function(i) {
 a <- annuals[i]
 file <- file.path(cache,sprintf("%s_%d.parquet",a$ghcnh_id,a$year))
 if(!file.exists(file)) {
  old <- file.path("data/interim/ghcnh/annual",basename(file))
  if(file.exists(old)) file <- old else {
   curl_download(sprintf("https://www.ncei.noaa.gov/oa/global-historical-climatology-network/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet",a$year,a$ghcnh_id,a$year),paste0(file,".tmp"))
   stopifnot(file.rename(paste0(file,".tmp"),file))
  }
 }
 file
}
r <- par_map(seq_len(nrow(annuals)),prepare,cores=4,export=c("annuals","cache"))
check_failures(r,annuals$ghcnh_id,"overlap downloads",fatal=TRUE)
annuals[,file:=unlist(r)]
results <- list()
for(i in seq_len(nrow(matches))) {
 m <- matches[i]
 file <- annuals[ghcnh_id==m$ghcnh_id & year==m$year,file]
 schema <- names(open_dataset(file)$schema)
 keep <- schema[tolower(schema)%in%c("date","station_level_pressure","station_level_pressure_quality_code","station_level_pressure_source_code")]
 d <- as.data.table(read_parquet(file,col_select=tidyselect::all_of(keep)))
 setnames(d,tolower(names(d)))
 if(!"station_level_pressure"%in%names(d)) next
 q<-as.character(d$station_level_pressure_quality_code);src<-as.character(d$station_level_pressure_source_code)
 d <- d[is.finite(station_level_pressure)&station_level_pressure>300&station_level_pressure<1100&
  !q%in%c("2","3","6","7")&!(q%in%"5"&src%in%c("220","221","222","223","347","348"))&
  (is.na(q)|!grepl("[a-z]",q)),.(date=as.POSIXct(date,format="%Y-%m-%dT%H:%M:%S",tz="UTC"),ghcnh=station_level_pressure)]
 d[,hour:=era5_hour(date)]
 d[,delta:=abs(as.numeric(difftime(date,hour,units="secs")))]
 setorder(d,hour,delta,date)
 d<-unique(d,by="hour")[,.(date=hour,ghcnh)]
 g<-as.data.table(read_parquet(file.path("data/interim/indep",paste0("GNSS_",m$id,".parquet")),col_select=c("date","pressure")))
 g<-g[,.(gnss=mean(pressure)),by=date]
 x<-merge(d,g,by="date")
 if(!nrow(x)) next
 x[,difference:=ghcnh-gnss]
 results[[i]]<-cbind(m,x[,.(n=.N,median_difference=median(difference),sd_difference=sd(difference),
  p95_absolute_difference=quantile(abs(difference),.95),round01_match=mean(abs(ghcnh-round(gnss,1))<1e-6),
  within01=mean(abs(difference)<=.100001),correlation=cor(ghcnh,gnss))])
}
results <- rbindlist(results)
results <- merge(matches, results[, c("id", "ghcnh_id", "n", "median_difference", "sd_difference",
  "p95_absolute_difference", "round01_match", "within01", "correlation"), with = FALSE],
  by = c("id", "ghcnh_id"), all.x = TRUE)
results[is.na(n), n := 0L]
setorder(results,-round01_match)
fwrite(results,"output/tables/gnss_ghcnh_overlap.csv")
print(results[,.(id,ghcnh_id,distance_km,n,median_difference,sd_difference,round01_match,correlation)])

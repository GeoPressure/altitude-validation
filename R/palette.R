# Colours shared by every figure (17_figures.R) and the interactive maps of the report. Each
# colour has one meaning throughout:
#   metric     accuracy (bias) and precision (SD), when a figure shows one series per panel
#   reference  the four reference datasets
#   product    the two ERA5 products; ERA5 single-levels is the GeoPressureR default, drawn in ink
#   formula    GeoPressureR's formula (ink, as above) and the changes tested
#   climate    main Koppen-Geiger zones
pal <- c(ink = "#1F2937", grid = "#E5E7EB", slate = "#94A3B8", light = "#E8ECF2")
pal_metric <- c(accuracy = "#3B6FB6", precision = "#2A9D8F")
pal_reference <- c(HadISD = "#3B6FB6", GNSS = "#7E57C2", MeteoSwiss = "#D1495B",
  IGRA2 = "#E9A23B")
pal_product <- c(`ERA5 single-levels` = "#1F2937", `ERA5-Land` = "#E4572E")
pal_formula <- c(current = "#1F2937", tv = "#E9A23B", tv_lapse = "#7E57C2",
  tv_lapse_var = "#D1495B")
pal_climate <- c(`A tropical` = "#4DAF4A", `B arid` = "#E6AB02", `C temperate` = "#D95F02",
  `D continental` = "#7570B3", `E polar` = "#8D99AE")
# Diverging (negative blue, positive red) and sequential scales for maps
pal_diverging <- c("#1E2F57", "#3B6FB6", "#E8ECF2", "#E4572E", "#8C2A12")
pal_sequential <- c("#F1F5FB", "#B9CDEB", "#6E97D0", "#3B6FB6", "#1E2F57")

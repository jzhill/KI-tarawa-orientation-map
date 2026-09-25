# Sentinel-2 composite and imagery fade for panel A
# Scene list: reference/tarawa_s2_scenes.csv, written from the catalogue search on the first run and reused after, so the composite does not change as new scenes are acquired
# Outputs: data-processed/tarawa_s2_median_20m.tif (red, green, blue), data-processed/tarawa_s2_fade_20m.tif (tight, smooth)

library(tidyverse)
library(httr)
library(jsonlite)
library(terra)
library(here)

source(here("R", "sentinel2.R"))
source(here("R", "atoll_fade.R"))

# map frame plus the fade margin: xmin, ymin, xmax, ymax in degrees
map_box <- c(172.82, 1.22, 173.27, 1.73)
template <- s2_template(map_box)

scenes_file <- here("reference", "tarawa_s2_scenes.csv")
if (!file.exists(scenes_file)) {
  s2_search(map_box, start = "2023-06-01", end = "2025-12-31", n_per_tile = 8, max_cloud = 10) %>%
    write_csv(scenes_file)
}
scenes <- read_csv(scenes_file, show_col_types = FALSE)

composite <- s2_composite(scenes, template)
writeRaster(composite, here("data-processed", "tarawa_s2_median_20m.tif"), overwrite = TRUE, datatype = "INT1U", NAflag = 0)
writeRaster(atoll_fade(composite), here("data-processed", "tarawa_s2_fade_20m.tif"), overwrite = TRUE)

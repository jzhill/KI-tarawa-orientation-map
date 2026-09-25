# Globe locator (panel B): Kiribati in the Pacific
# Builds the globe layers in screen coordinates, for the map layout (script 04) and for standalone use
# Needs data-processed/pacific_groupings_polygons.gpkg (script 01) and the Marine Regions contiguous zone file in data-raw/marine_regions/
# Outputs: data-processed/globe.rds, outputs/globe_preview.png (transparent background)

library(tidyverse)
library(sf)
library(terra)
library(here)

source(here("R", "natural_earth.R"))
source(here("R", "globe.R"))
source(here("R", "globe_base.R"))
source(here("R", "contiguous_zone.R"))

sf_use_s2(FALSE)

# TRUE downloads the shaded-relief raster (88 MB) if missing; FALSE uses the flat-colour vector globe; NA asks when run interactively
download_raster <- NA

# target 12 18 12.08 N, 174 21 21.31 E; camera 18,000 km away, tilted 21 degrees, picture rolled 10 degrees anticlockwise
view <- globe_view(lon = 174 + 21 / 60 + 21.31 / 3600, lat = 12 + 18 / 60 + 12.08 / 3600, range_km = 18000, tilt_deg = 21, roll_deg = 10)
base <- globe_base(download_raster)
lim <- 1.10

kiribati <- st_read(here("data-processed", "pacific_groupings_polygons.gpkg"), quiet = TRUE) %>%
  filter(name == "Kiribati") %>%
  st_transform(4326) %>%
  st_shift_longitude()
symbols <- read_contiguous_zone("KIR") %>% island_group_symbols()

# label positions by hand; sizes are for the standalone plot
labels <- tribble(
  ~label,             ~lon,  ~lat,  ~hjust, ~vjust, ~size,
  "KIRIBATI",         186.3,   4.6,  0.5,    0.5,    3.6,
  "Gilbert\nIslands", 173,    -5.5,  0.5,    1,      2.6,
  "Phoenix\nIslands", 187.5,  -9.5,  0.5,    1,      2.6,
  "Line\nIslands",    205,   -13.5,  0.5,    1,      2.6
)

globe <- list(
  view = view,
  lim = lim,
  image = globe_image(view, base$raster, lim = lim, saturation = base$saturation, value = base$value),
  graticule = bind_rows(
    tibble(lon = seq(-180, 180, 0.5), lat = 0, line = "equator"),
    tibble(lon = 180, lat = seq(-90, 90, 0.5), line = "antimeridian")
  ) %>% bind_cols(globe_project(view, .$lon, .$lat)),
  kiribati = globe_rings(view, kiribati),
  symbols = globe_rings(view, symbols),
  labels = labels %>% bind_cols(globe_project(view, .$lon, .$lat)),
  tarawa = globe_project(view, 173.0, 1.45)
)

dir.create(here("data-processed"), showWarnings = FALSE)
saveRDS(globe, here("data-processed", "globe.rds"))
dir.create(here("outputs"), showWarnings = FALSE)
ggsave(here("outputs", "globe_preview.png"), globe_plot(globe), width = 6, height = 6, dpi = 250, bg = "transparent")

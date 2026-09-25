# Tarawa land polygons with zones
# Land from OpenStreetMap coastline (Overpass API, pinned to a date), each polygon given its zone (Betio, Rest of South Tarawa, North Tarawa) from the nearest census zone
# Needs data-raw/KIR_EA_Census2020FINAL.geojson (Kiribati National Statistics Office; not redistributable), used only to assign zones and not drawn
# Polygons more than 1 km from any census zone (Abaiang atoll to the north, a shoal in the lagoon) are left out
# The islet near Bonriki (173.133 E, 1.384 N) is nearest Tanaea (South Tarawa) and is flagged for review by assign_zones(); it stays in South Tarawa (nearest Buota, North Tarawa, is further)
# Output: data-processed/tarawa_land_zones.gpkg

library(tidyverse)
library(sf)
library(httr)
library(jsonlite)
library(here)

source(here("R", "tarawa_land.R"))

sf_use_s2(FALSE)

# same box as the imagery; OpenStreetMap as it was at the date below
map_box <- c(172.82, 1.22, 173.27, 1.73)
osm_date <- "2026-09-25T07:30:00Z"

land <- fetch_osm_coastline(map_box, osm_date) %>% coastline_land()
zones <- census_areas(here("data-raw", "KIR_EA_Census2020FINAL.geojson"))
tarawa_land <- assign_zones(land, zones)

print(tarawa_land %>% st_drop_geometry() %>% group_by(area) %>% summarise(polygons = n(), km2 = round(sum(km2), 1)))

dir.create(here("data-processed"), showWarnings = FALSE)
st_write(tarawa_land, here("data-processed", "tarawa_land_zones.gpkg"), layer = "tarawa_land", delete_dsn = TRUE, quiet = TRUE)

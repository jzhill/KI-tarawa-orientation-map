# Pacific groupings polygons
# Natural Earth Pacific groupings lines closed into named polygons
# Stored in WGS 84 / PDC Mercator (EPSG:3832), centred on 150E, so faces crossing the antimeridian stay in one piece
# Output: data-processed/pacific_groupings_polygons.gpkg

library(tidyverse)
library(sf)
library(here)

source(here("R", "natural_earth.R"))
source(here("R", "pacific_groupings.R"))

sf_use_s2(FALSE)

lines <- st_read(fetch_natural_earth("ne_10m_admin_0_pacific_groupings"), quiet = TRUE)
map_units <- st_read(fetch_natural_earth("ne_10m_admin_0_map_units"), quiet = TRUE)

# faces holding no Natural Earth map unit
reference_points <- tribble(
  ~name,                   ~lon,    ~lat,
  "Easter Island (Chile)", -109.35, -27.12
)

polygons <- lines %>%
  groupings_faces() %>%
  name_faces(map_units, reference_points) %>%
  st_transform(3832) %>%
  st_cast("MULTIPOLYGON", warn = FALSE) %>%
  st_make_valid()

dir.create(here("data-processed"), showWarnings = FALSE)
st_write(polygons, here("data-processed", "pacific_groupings_polygons.gpkg"), layer = "pacific_groupings", delete_dsn = TRUE, quiet = TRUE)

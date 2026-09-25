# read_contiguous_zone()
# Contiguous zone (24 NM) polygons of one territory, read straight from the Marine Regions zip in data-raw/ (no need to unzip)
# Only the territory's features are read; column names are lower-cased and the geometry column is called geometry
# Stops with the download address unless there is exactly one zip with "24NM" in its name
#   iso: ISO territory code, matched to ISO_TER1
#   dir: folder holding the download

read_contiguous_zone <- function(iso = "KIR", dir = here("data-raw")) {
  zips <- list.files(dir, pattern = "24NM.*\\.zip$", ignore.case = TRUE, full.names = TRUE)
  if (length(zips) != 1) {
    stop(str_glue("Expected one Marine Regions zip (*24NM*.zip) in {dir}, found {length(zips)}. Download 'Contiguous Zones (24NM)' from https://www.marineregions.org/downloads.php (https://doi.org/10.14284/630) and put the zip there."))
  }
  shp <- str_subset(unzip(zips, list = TRUE)$Name, "\\.shp$")
  layer <- tools::file_path_sans_ext(basename(shp))
  zones <- st_read(str_c("/vsizip/", zips, "/", shp), query = str_glue("SELECT * FROM {layer} WHERE ISO_TER1 = '{iso}'"), quiet = TRUE)
  st_sf(rename_with(st_drop_geometry(zones), tolower), geometry = st_geometry(zones))
}

# island_group_symbols()
# Island-group symbols: contiguous zone polygons buffered and merged by group, longitudes 0-360
# The buffer is planar in longitude/latitude (0.7 degrees is about 78 km at the equator), so the symbols are enlarged and show position only, not zone extent
#   zones: from read_contiguous_zone()
#   buffer_deg: buffer distance, degrees

island_group_symbols <- function(zones, buffer_deg = 0.7) {
  zones %>%
    st_shift_longitude() %>%
    st_buffer(buffer_deg) %>%
    group_by(geoname) %>%
    summarise(geometry = st_union(geometry), .groups = "drop") %>%
    st_cast("MULTIPOLYGON", warn = FALSE)
}

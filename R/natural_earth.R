# fetch_natural_earth()
# Path to a Natural Earth shapefile, downloaded from naciscdn.org and unzipped into data-raw/ne/ on first use
# Later calls reuse the unzipped files
#   layer: file stem, e.g. "ne_10m_admin_0_map_units" (scale is read from the "ne_10m_" part)
#   category: Natural Earth folder, "cultural" or "physical"

fetch_natural_earth <- function(layer, category = "cultural") {
  scale <- str_extract(layer, "(?<=^ne_)[0-9]+m")
  dir <- here("data-raw", "ne", layer)
  shp <- file.path(dir, str_c(layer, ".shp"))
  if (!file.exists(shp)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    zip <- str_c(dir, ".zip")
    download.file(str_glue("https://naciscdn.org/naturalearth/{scale}/{category}/{layer}.zip"), zip, mode = "wb")
    unzip(zip, exdir = dir)
  }
  shp
}

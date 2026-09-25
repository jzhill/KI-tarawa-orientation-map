# fetch_natural_earth()
# Path to a Natural Earth file, downloaded from naciscdn.org and unzipped into data-raw/ne/<layer>/ on first use
# Later calls reuse the unzipped files
# Downloads can be large (the 1:50m raster is 88 MB), so the timeout is raised to 10 minutes
#   layer: file stem, e.g. "ne_10m_admin_0_map_units" or "NE1_50M_SR_W"
#   category: Natural Earth folder, "cultural", "physical" or "raster"
#   scale: "10m", "50m" or "110m"; read from the layer name when it starts with "ne_10m_" etc.
#   extension: file to return, "shp" or "tif"

fetch_natural_earth <- function(layer, category = "cultural", scale = str_extract(layer, "(?<=^ne_)[0-9]+m"), extension = "shp") {
  dir <- here("data-raw", "ne", layer)
  find_file <- function() list.files(dir, pattern = str_c("^", layer, "\\.", extension, "$"), recursive = TRUE, full.names = TRUE)
  if (length(find_file()) == 0) {
    old <- options(timeout = max(600, getOption("timeout")))
    on.exit(options(old))
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    zip <- str_c(dir, ".zip")
    download.file(str_glue("https://naciscdn.org/naturalearth/{scale}/{category}/{layer}.zip"), zip, mode = "wb")
    unzip(zip, exdir = dir)
  }
  find_file()
}

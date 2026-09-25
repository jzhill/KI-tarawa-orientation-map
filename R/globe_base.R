# globe_base_raster()
# Natural Earth I with Shaded Relief and Water (1:50m) as a red, green, blue raster, or NULL if it is not available
# The file is an 88 MB download (175 MB on disk), so it is fetched only with permission
#   download: TRUE downloads if missing, FALSE never does, NA asks in an interactive session and otherwise does not download

globe_base_raster <- function(download = NA) {
  layer <- "NE1_50M_SR_W"
  found <- list.files(here("data-raw", "ne", layer), pattern = str_c("^", layer, "\\.tif$"), recursive = TRUE, full.names = TRUE)
  if (length(found) == 0) {
    if (is.na(download)) {
      download <- interactive() && isTRUE(askYesNo("Download the Natural Earth raster for the globe (88 MB download, 175 MB on disk)? No uses the flat-colour vector globe instead.", default = FALSE))
    }
    if (!download) return(NULL)
    found <- fetch_natural_earth(layer, category = "raster", scale = "50m", extension = "tif")
  }
  rast(found)[[1:3]]
}

# globe_base_vector()
# Flat-colour land and ocean raster from the Natural Earth 1:50m land polygons (0.4 MB), on a longitude/latitude grid
# Fallback for when the shaded-relief raster is not used; it goes through the same projection
#   res: cell size in degrees
#   ocean, land: colours

globe_base_vector <- function(res = 0.05, ocean = "#6FB3E3", land = "#E9E5C9") {
  land_polygons <- vect(fetch_natural_earth("ne_50m_land", category = "physical"))
  grid <- rast(xmin = -180, xmax = 180, ymin = -90, ymax = 90, resolution = res, crs = "EPSG:4326")
  is_land <- rasterize(land_polygons, grid, field = 1, background = 0)
  channel <- function(i) ifel(is_land == 1, col2rgb(land)[i, 1], col2rgb(ocean)[i, 1])
  c(channel(1), channel(2), channel(3))
}

# globe_base()
# Base raster for the globe and the colour adjustment that suits it
# Uses the shaded-relief raster if available (brightened and made more saturated), otherwise the flat-colour vector version, and says which
#   download: passed to globe_base_raster()

globe_base <- function(download = NA) {
  base_raster <- globe_base_raster(download)
  if (is.null(base_raster)) {
    message("Natural Earth raster not available: using the flat-colour vector globe. Set download_raster = TRUE in scripts/03_globe.R (or answer Yes when asked) for the shaded-relief globe.")
    list(raster = globe_base_vector(), saturation = 1, value = 1)
  } else {
    list(raster = base_raster, saturation = 1.35, value = 1.18)
  }
}

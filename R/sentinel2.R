# s2_template()
# Empty raster on the UTM 59N grid (EPSG:32659) covering a longitude/latitude box
#   bbox: c(xmin, ymin, xmax, ymax) in degrees
#   res: cell size in metres

s2_template <- function(bbox, res = 20) {
  box <- vect(matrix(bbox, ncol = 2, byrow = TRUE), crs = "EPSG:4326") %>% project("EPSG:32659")
  rast(ext(box), resolution = res, crs = "EPSG:32659")
}

# s2_search()
# Sentinel-2 L2A scenes from the Element 84 Earth Search catalogue that intersect a box
# Keeps the n_per_tile scenes with the lowest tile-level cloud cover in each MGRS tile
# Drops tiles covering less than min_overlap of the box
#   bbox: c(xmin, ymin, xmax, ymax) in degrees
#   start, end: acquisition dates, "YYYY-MM-DD"
#   max_cloud: tile-level cloud cover ceiling, percent

s2_search <- function(bbox, start, end, n_per_tile, min_overlap = 0.5, max_cloud = 40) {
  body <- list(
    collections = list("sentinel-2-l2a"), bbox = as.list(bbox), limit = 200L,
    datetime = str_glue("{start}T00:00:00Z/{end}T23:59:59Z"),
    query = list("eo:cloud_cover" = list(lt = max_cloud))
  )
  response <- POST("https://earth-search.aws.element84.com/v1/search", body = toJSON(body, auto_unbox = TRUE), content_type_json())
  result <- fromJSON(content(response, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  if (result$numberMatched > length(result$features)) {
    stop(str_glue("Search matched {result$numberMatched} scenes but the catalogue returned {length(result$features)}; lower max_cloud or narrow the dates"))
  }
  box_area <- (bbox[3] - bbox[1]) * (bbox[4] - bbox[2])
  overlap <- function(scene_box) {
    width <- min(scene_box[[3]], bbox[3]) - max(scene_box[[1]], bbox[1])
    height <- min(scene_box[[4]], bbox[4]) - max(scene_box[[2]], bbox[2])
    max(width, 0) * max(height, 0) / box_area
  }
  result$features %>%
    map_dfr(function(scene) {
      tibble(
        id = scene$id, date = as.Date(str_sub(scene$properties$datetime, 1, 10)), tile = scene$properties$`grid:code`,
        cloud = scene$properties$`eo:cloud_cover`, overlap = overlap(scene$bbox),
        visual = scene$assets$visual$href, scl = scene$assets$scl$href
      )
    }) %>%
    filter(overlap >= min_overlap) %>%
    group_by(tile) %>%
    slice_min(cloud, n = n_per_tile, with_ties = FALSE) %>%
    ungroup() %>%
    arrange(tile, date)
}

# s2_read_scene()
# True-colour scene cut to the template grid, with no-data, saturated or defective, cloud shadow, cloud, thin cirrus and snow pixels set to NA
# Reads the 10 m visual (TCI) asset and the scene classification (SCL) asset over HTTP, resampled to the template by nearest neighbour
# Cached as data-processed/s2_scenes/<id>.tif, so each scene is downloaded once; 0 is the no-data value
#   scene: one row of the scene list (id, visual, scl)
#   template: from s2_template()
#   bad_scl: SCL classes to mask

s2_read_scene <- function(scene, template, bad_scl = c(0, 1, 3, 8, 9, 10, 11)) {
  file <- here("data-processed", "s2_scenes", str_c(scene$id, ".tif"))
  if (!file.exists(file)) {
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    visual <- rast(str_c("/vsicurl/", scene$visual)) %>% project(template, method = "near")
    scl <- rast(str_c("/vsicurl/", scene$scl)) %>% project(template, method = "near")
    visual[scl %in% bad_scl] <- NA
    writeRaster(visual, file, datatype = "INT1U", NAflag = 0, gdal = "COMPRESS=DEFLATE")
  }
  rast(file)
}

# s2_composite()
# Per-pixel median of the scenes, by band (red, green, blue), on the template grid
# Pixels with no usable scene are NA
#   scenes: scene list (id, visual, scl)
#   template: from s2_template()

s2_composite <- function(scenes, template) {
  layers <- scenes %>% split(seq_len(nrow(scenes))) %>% map(s2_read_scene, template)
  bands <- map(1:3, function(band) median(rast(map(layers, function(layer) layer[[band]])), na.rm = TRUE))
  composite <- rast(bands)
  names(composite) <- c("red", "green", "blue")
  composite
}

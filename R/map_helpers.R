# utm_xy()
# WGS 84 / UTM zone 59N (EPSG:32659) coordinates in metres of longitude/latitude points, as a tibble of x and y
#   lon, lat: degrees

utm_xy <- function(lon, lat) {
  st_sfc(st_multipoint(cbind(lon, lat)), crs = 4326) %>%
    st_transform(32659) %>%
    st_coordinates() %>%
    as_tibble() %>%
    select(x = X, y = Y)
}

# census_areas()
# Tarawa census enumeration areas dissolved into Betio, rest of South Tarawa and North Tarawa, in UTM 59N
# Betio is the Betio_East village (all Betio enumeration areas); the area factor levels set the drawing and legend order
#   file: 2020 census enumeration area boundaries (geojson)

census_areas <- function(file) {
  st_read(file, quiet = TRUE) %>%
    filter(iid_name %in% c("North Tarawa", "South Tarawa")) %>%
    mutate(area = case_when(
      vid_name == "Betio_East" ~ "Betio",
      iid_name == "South Tarawa" ~ "Rest of South Tarawa",
      TRUE ~ "North Tarawa"
    )) %>%
    group_by(area) %>%
    summarise(geometry = st_union(geometry), .groups = "drop") %>%
    st_make_valid() %>%
    st_transform(32659) %>%
    mutate(area = factor(area, levels = c("Betio", "Rest of South Tarawa", "North Tarawa")))
}

# imagery_matrix()
# Sentinel-2 composite as an RGBA colour matrix, with its extent, for annotation_raster
# Colours are stretched (gamma 0.5), partly desaturated, lightened towards white, and shifted towards pale water where the coast-following fade is below 1, so the fade reads as a light halo
# Transparency is the convex-hull fade times opacity; pixels with no data are dark and transparent
#   composite: red, green, blue layers from script 02
#   fade: layers "tight" (coast-following, drives the colour shift) and "smooth" (convex hull, drives transparency)
#   opacity: opacity over the atoll, 0-1

imagery_matrix <- function(composite, fade, opacity = 0.8) {
  colour <- t(values(composite)) / 255
  colour[is.na(colour)] <- 0
  n <- ncol(colour)
  grey <- (0.3 * colour[1, ] + 0.59 * colour[2, ] + 0.11 * colour[3, ])^0.55
  soft <- 0.75 * colour^0.5 + 0.25 * matrix(grey, 3, n, byrow = TRUE)
  soft <- 0.8 * soft + 0.2 * col2rgb("#CFE6F2")[, 1] / 255
  soft <- 0.72 * soft + 0.28
  tight <- values(fade[["tight"]])[, 1]
  smooth <- values(fade[["smooth"]])[, 1]
  tight[is.na(tight)] <- 0
  smooth[is.na(smooth)] <- 0
  shift <- (1 - tight)^0.6
  pale <- col2rgb("#A9D3E6")[, 1] / 255
  soft <- soft * matrix(1 - shift, 3, n, byrow = TRUE) + matrix(pale, 3, n) * matrix(shift, 3, n, byrow = TRUE)
  list(
    image = matrix(rgb(soft[1, ], soft[2, ], soft[3, ], smooth * opacity), nrow = nrow(composite), ncol = ncol(composite), byrow = TRUE),
    extent = as.vector(ext(composite))
  )
}

# halo_text()
# Text layers with a white halo, for legibility over imagery: eight white copies nudged around the text, then the text on top
#   data: tibble with x, y, label, hjust
#   halo_m: halo width in map units (metres)

halo_text <- function(data, size = 2.4, colour = "#042C53", fontface = "bold", halo_m = 45) {
  nudges <- expand.grid(dx = c(-1, 0, 1), dy = c(-1, 0, 1)) %>% filter(dx != 0 | dy != 0)
  text_layer <- function(colour, position) {
    geom_text(data = data, aes(x, y, label = label, hjust = hjust), size = size, colour = colour, fontface = fontface, lineheight = 0.9, position = position)
  }
  halos <- map2(nudges$dx, nudges$dy, function(dx, dy) text_layer("white", position_nudge(x = dx * halo_m, y = dy * halo_m)))
  c(halos, list(text_layer(colour, "identity")))
}

# place_globe()
# Globe layers rescaled from screen coordinates (radius 1) into map coordinates
# Adds extent, the image's corners in map units, and centre and radius
#   globe: list from script 03
#   centre: c(x, y) of the globe's centre in map units
#   radius: globe radius in map units

place_globe <- function(globe, centre, radius) {
  move <- function(layer) mutate(layer, x = centre[1] + x * radius, y = centre[2] + y * radius)
  list(
    view = globe$view, image = globe$image, centre = centre, radius = radius,
    extent = c(centre[1] - globe$lim * radius, centre[1] + globe$lim * radius, centre[2] - globe$lim * radius, centre[2] + globe$lim * radius),
    graticule = move(globe$graticule), kiribati = move(globe$kiribati), symbols = move(globe$symbols),
    labels = move(globe$labels), tarawa = move(globe$tarawa)
  )
}

# curved_arrow()
# Points along a quadratic curve from start to end that passes through mid at its midpoint
#   start, mid, end: c(x, y) in map units
#   n: number of points

curved_arrow <- function(start, mid, end, n = 150) {
  control <- 2 * mid - 0.5 * (start + end)
  t <- seq(0, 1, length.out = n)
  tibble(
    x = (1 - t)^2 * start[1] + 2 * (1 - t) * t * control[1] + t^2 * end[1],
    y = (1 - t)^2 * start[2] + 2 * (1 - t) * t * control[2] + t^2 * end[2]
  )
}

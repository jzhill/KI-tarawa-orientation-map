# lonlat_to_xyz()
# Unit-sphere coordinates (one row per point) of longitude/latitude in degrees

lonlat_to_xyz <- function(lon, lat) {
  lon <- lon * pi / 180
  lat <- lat * pi / 180
  cbind(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
}

cross3 <- function(a, b) c(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])

unit_vector <- function(a) a / sqrt(sum(a^2))

roll_xy <- function(roll, x, y) list(x = cos(roll) * x - sin(roll) * y, y = sin(roll) * x + cos(roll) * y)

# globe_view()
# Camera for a near-side perspective view of a spherical Earth
# The camera looks at the target point from range_km away, on the south side, so north stays roughly up
# Screen coordinates are scaled so the silhouette of the globe fits within -1 to 1
#   lon, lat: target point, degrees
#   range_km: camera distance from the target point
#   tilt_deg: angle of the view axis from the local vertical at the target
#   roll_deg: picture rotated anticlockwise, so the equator rises to the right
#   earth_km: sphere radius

globe_view <- function(lon, lat, range_km, tilt_deg, roll_deg, earth_km = 6371) {
  target <- lonlat_to_xyz(lon, lat)[1, ]
  north <- c(0, 0, 1)
  north_at_target <- unit_vector(north - sum(north * target) * target)
  tilt <- tilt_deg * pi / 180
  towards_camera <- cos(tilt) * target - sin(tilt) * north_at_target
  cam <- target + (range_km / earth_km) * towards_camera
  forward <- -towards_camera
  up <- unit_vector(north_at_target - sum(north_at_target * forward) * forward)
  right <- cross3(forward, up)
  roll <- roll_deg * pi / 180
  # frame the whole globe: bounding box of the silhouette after the roll
  axis <- unit_vector(-cam)
  e1 <- unit_vector(cross3(axis, north))
  e2 <- cross3(axis, e1)
  half_angle <- asin(1 / sqrt(sum(cam^2)))
  phi <- seq(0, 2 * pi, length.out = 720)
  rays <- cos(half_angle) * matrix(axis, 720, 3, byrow = TRUE) + sin(half_angle) * (outer(cos(phi), e1) + outer(sin(phi), e2))
  depth <- as.vector(rays %*% forward)
  silhouette <- roll_xy(roll, as.vector(rays %*% right) / depth, as.vector(rays %*% up) / depth)
  list(
    cam = cam, forward = forward, up = up, right = right, roll = roll,
    cx = mean(range(silhouette$x)), cy = mean(range(silhouette$y)),
    scale = max(diff(range(silhouette$x)), diff(range(silhouette$y))) / 2
  )
}

# globe_project()
# Screen coordinates (x, y) of longitude/latitude points; NA for points on the far side
#   view: from globe_view()
#   lon, lat: degrees, longitudes -180 to 180 or 0 to 360

globe_project <- function(view, lon, lat) {
  points <- lonlat_to_xyz(lon, lat)
  visible <- as.vector(points %*% view$cam) > 1
  ray <- sweep(points, 2, view$cam)
  depth <- as.vector(ray %*% view$forward)
  screen <- roll_xy(view$roll, as.vector(ray %*% view$right) / depth, as.vector(ray %*% view$up) / depth)
  tibble(
    x = ifelse(visible, (screen$x - view$cx) / view$scale, NA),
    y = ifelse(visible, (screen$y - view$cy) / view$scale, NA)
  )
}

# globe_image()
# Globe as a colour matrix (RGBA, top row first), drawn by inverse mapping: each pixel ray is intersected with the sphere and the base raster is sampled there
# Colours are pushed towards pale blue at grazing angles, with a thin glow outside the limb; pixels beyond the glow are transparent
#   view: from globe_view()
#   base_raster: SpatRaster in longitude/latitude with red, green and blue layers (0-255)
#   n_px: pixels along each side of the square image, which covers -lim to lim in screen units
#   lim: half-width of the image in screen units (the globe has radius 1)
#   saturation, value: multipliers applied to the sampled colours (1 leaves them unchanged)

globe_image <- function(view, base_raster, n_px = 1600, lim = 1.10, saturation = 1, value = 1) {
  edge <- seq(-lim, lim, length.out = n_px)
  grid <- expand.grid(x = edge, y = rev(edge))
  # undo the framing and the roll to get camera-plane coordinates
  plane_x <- grid$x * view$scale + view$cx
  plane_y <- grid$y * view$scale + view$cy
  unrolled <- roll_xy(-view$roll, plane_x, plane_y)
  ray <- matrix(view$forward, nrow(grid), 3, byrow = TRUE) + outer(unrolled$x, view$right) + outer(unrolled$y, view$up)
  ray <- ray / sqrt(rowSums(ray^2))
  along <- as.vector(ray %*% view$cam)
  cam_dist2 <- sum(view$cam^2)
  discriminant <- along^2 - (cam_dist2 - 1)
  on_globe <- discriminant >= 0
  hit <- matrix(view$cam, nrow(grid), 3, byrow = TRUE) + (-along - sqrt(pmax(discriminant, 0))) * ray
  lon <- atan2(hit[, 2], hit[, 1]) * 180 / pi
  lat <- asin(pmin(pmax(hit[, 3], -1), 1)) * 180 / pi
  colour <- matrix(NA_real_, nrow(grid), 3)
  colour[on_globe, ] <- pmin(pmax(as.matrix(terra::extract(base_raster, cbind(lon[on_globe], lat[on_globe]), method = "bilinear")), 0), 255)
  if (saturation != 1 || value != 1) {
    hsv_values <- rgb2hsv(t(colour[on_globe, ]), maxColorValue = 255)
    hsv_values["s", ] <- pmin(1, hsv_values["s", ] * saturation)
    hsv_values["v", ] <- pmin(1, hsv_values["v", ] * value)
    colour[on_globe, ] <- t(col2rgb(hsv(hsv_values["h", ], hsv_values["s", ], hsv_values["v", ])))
  }
  rim <- c(190, 225, 245)
  limb_weight <- pmax(0, 1 - pmax(0, -rowSums(ray * hit)) / 0.45)^2.5 * 0.75
  glow <- pmax(0, 1 - (sqrt(pmax(cam_dist2 - along^2, 0)) - 1) / 0.05)^2 * 0.6
  channel <- function(i) ifelse(on_globe, colour[, i] * (1 - limb_weight) + rim[i] * limb_weight, rim[i])
  colours <- rgb(channel(1), channel(2), channel(3), ifelse(on_globe, 1, glow) * 255, maxColorValue = 255)
  matrix(colours, nrow = n_px, ncol = n_px, byrow = TRUE)
}

# densify_ring()
# Ring or line vertices with points added so no segment exceeds step degrees (planar in longitude/latitude)

densify_ring <- function(x, y, step) {
  n_seg <- pmax(1, ceiling(pmax(abs(diff(x)), abs(diff(y))) / step))
  idx <- rep(seq_along(n_seg), n_seg)
  frac <- sequence(n_seg) / rep(n_seg, n_seg) - 1 / rep(n_seg, n_seg)
  tibble(
    lon = c(x[idx] + frac * (x[idx + 1] - x[idx]), x[length(x)]),
    lat = c(y[idx] + frac * (y[idx + 1] - y[idx]), y[length(y)])
  )
}

# globe_rings()
# Polygon rings or lines projected to screen coordinates, one row per vertex
# Vertices are added so no segment exceeds step degrees, so long straight edges follow the curve of the globe
# Columns: lon, lat, x, y (NA on the far side, which breaks lines there), part (one per polygon or line), ring (1 = outer ring, then holes)
#   view: from globe_view()
#   shape: sf polygons or lines
#   step: longest segment, degrees

globe_rings <- function(view, shape, step = 0.25) {
  coords <- st_coordinates(shape) %>% as_tibble()
  group_cols <- names(coords)[startsWith(names(coords), "L")]
  part_cols <- setdiff(group_cols, "L1")
  rings <- coords %>%
    group_by(across(all_of(group_cols))) %>%
    reframe(densify_ring(X, Y, step)) %>%
    mutate(part = if (length(part_cols) == 0) "1" else str_c(!!!syms(part_cols), sep = "_"), ring = L1)
  bind_cols(select(rings, lon, lat, part, ring), globe_project(view, rings$lon, rings$lat))
}

# globe_plot()
# Standalone plot of the globe layers on a transparent background
#   globe: list with image, lim, graticule, kiribati, symbols, labels and tarawa, as built by scripts/03_globe.R
#   teal, dark_teal: colours of the Kiribati outline and of the island-group symbols and labels

globe_plot <- function(globe, teal = "#1B9E9E", dark_teal = "#0B5D5D") {
  lim <- globe$lim
  ggplot() +
    annotation_raster(globe$image, -lim, lim, -lim, lim, interpolate = TRUE) +
    geom_path(data = globe$graticule, aes(x, y, group = line), colour = "white", linewidth = 0.25, linetype = "dashed", alpha = 0.7, na.rm = TRUE) +
    geom_polygon(data = globe$kiribati, aes(x, y, group = part, subgroup = ring), fill = teal, alpha = 0.25) +
    geom_path(data = globe$kiribati, aes(x, y, group = interaction(part, ring)), colour = teal, linewidth = 0.9) +
    geom_polygon(data = globe$symbols, aes(x, y, group = part, subgroup = ring), fill = dark_teal, alpha = 0.55, colour = "white", linewidth = 0.25) +
    geom_text(data = globe$labels, aes(x, y, label = label, hjust = hjust, vjust = vjust, size = size), colour = dark_teal, fontface = "bold", lineheight = 0.9) +
    geom_point(data = globe$tarawa, aes(x, y), shape = 21, size = 1.8, fill = "white", colour = "black") +
    scale_size_identity() +
    coord_fixed(xlim = c(-lim, lim), ylim = c(-lim, lim), expand = FALSE) +
    theme_void()
}

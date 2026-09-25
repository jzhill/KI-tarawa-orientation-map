# groupings_faces()
# Polygons closed from the Natural Earth Pacific groupings lines
# Longitudes shifted to 0-360 so the antimeridian is continuous
# Coordinates rounded to 0.001 degrees so line ends that almost meet (mostly at the antimeridian) join exactly
# Faces are numbered in polygonize order, which can change with the data version, so identify them by name_faces()
#   lines: sf lines, ne_10m_admin_0_pacific_groupings

groupings_faces <- function(lines) {
  lines %>%
    st_geometry() %>%
    map(function(line) {
      coords <- unclass(line)
      coords[, 1] <- ifelse(coords[, 1] < 0, coords[, 1] + 360, coords[, 1])
      st_linestring(round(coords, 3))
    }) %>%
    st_sfc(crs = 4326) %>%
    st_union() %>%
    st_polygonize() %>%
    st_collection_extract("POLYGON") %>%
    st_cast("POLYGON") %>%
    st_sf(geometry = .)
}

# name_faces()
# Faces named from the Natural Earth map units (NAME_LONG) with land inside them
# A face holding more than one unit is named with all of them, joined by " / "
# Faces holding no map unit are named from reference_points; stops if any face is still unnamed
# name_source records which route named each face
#   faces: from groupings_faces()
#   map_units: sf polygons, ne_10m_admin_0_map_units
#   reference_points: tibble of name, lon, lat (longitudes -180 to 180)

name_faces <- function(faces, map_units, reference_points) {
  # planar points on surface are fine here, the faces are hundreds of km across
  land_points <- map_units %>%
    st_make_valid() %>%
    st_shift_longitude() %>%
    select(name = NAME_LONG) %>%
    st_cast("POLYGON", warn = FALSE) %>%
    st_point_on_surface() %>%
    suppressWarnings()
  ref_points <- reference_points %>%
    mutate(lon = ifelse(lon < 0, lon + 360, lon)) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)
  faces <- faces %>% mutate(face = row_number())
  names_in <- function(points) {
    faces %>%
      st_join(points) %>%
      st_drop_geometry() %>%
      filter(!is.na(name)) %>%
      group_by(face) %>%
      summarise(name = str_c(sort(unique(name)), collapse = " / "))
  }
  from_units <- names_in(land_points) %>% mutate(name_source = "Natural Earth map units")
  from_reference <- names_in(ref_points) %>% filter(!face %in% from_units$face) %>% mutate(name_source = "reference point")
  face_names <- bind_rows(from_units, from_reference)
  stopifnot(setequal(face_names$face, faces$face))
  faces %>%
    left_join(face_names, by = "face") %>%
    select(name, name_source)
}

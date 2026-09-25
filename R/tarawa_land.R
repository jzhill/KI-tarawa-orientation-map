# fetch_osm_coastline()
# OpenStreetMap coastline ways (natural=coastline) in a box, from the Overpass API, as sf lines in longitude/latitude
# The query is pinned to a date, so the data are OpenStreetMap as it was at that moment and do not change as the map is edited
# The response is cached in data-raw/osm/, with the date in the file name
#   bbox: c(xmin, ymin, xmax, ymax) in degrees
#   date: ISO 8601 UTC, e.g. "2026-09-25T07:30:00Z"

fetch_osm_coastline <- function(bbox, date) {
  file <- here("data-raw", "osm", str_c("coastline_", str_remove_all(date, "[-:]"), ".json"))
  if (!file.exists(file)) {
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    query <- str_glue('[out:json][timeout:120][date:"{date}"]; way["natural"="coastline"]({bbox[2]},{bbox[1]},{bbox[4]},{bbox[3]}); out geom;')
    response <- POST(
      "https://overpass-api.de/api/interpreter", body = list(data = query), encode = "form",
      user_agent("KI-tarawa-orientation-map (research figure; https://github.com/jzhill/KI-tarawa-orientation-map)"), add_headers(Accept = "*/*")
    )
    stop_for_status(response)
    writeLines(content(response, "text", encoding = "UTF-8"), file)
  }
  ways <- fromJSON(file, simplifyVector = FALSE)$elements
  st_sfc(map(ways, function(way) st_linestring(cbind(map_dbl(way$geometry, "lon"), map_dbl(way$geometry, "lat")))), crs = 4326)
}

# coastline_land()
# Land polygons assembled from coastline lines, in UTM 59N (EPSG:32659), with area in km2
# Ways are noded and closed into rings, and every enclosed face is land because OpenStreetMap coastlines only enclose land
# Rings that continue beyond the query box stay open and give no polygon
#   lines: from fetch_osm_coastline()

coastline_land <- function(lines) {
  faces <- lines %>%
    st_transform(32659) %>%
    st_union() %>%
    st_polygonize() %>%
    st_collection_extract("POLYGON") %>%
    st_cast("POLYGON") %>%
    st_make_valid()
  st_sf(km2 = as.numeric(st_area(faces)) / 1e6, geometry = faces)
}

# census_areas()
# Tarawa census enumeration areas dissolved into Betio, rest of South Tarawa and North Tarawa, in UTM 59N
# Betio is the Betio_East village (all Betio enumeration areas); the area factor levels set the drawing and legend order
# Used only to give land polygons their zone, not drawn
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

# assign_zones()
# Zone (Betio, Rest of South Tarawa or North Tarawa) for each land polygon, taken from the nearest census zone
# Polygons more than max_distance_m from every zone are dropped (other atolls, lagoon shoals)
# A polygon touching two zones stops with its position, since it would need cutting by hand
# Polygons whose second-nearest zone is within twice the nearest distance are listed in a message for review
#   land: from coastline_land()
#   zones: from census_areas()
#   max_distance_m: distance beyond which a polygon is left out, metres

assign_zones <- function(land, zones, max_distance_m = 1000) {
  distance <- matrix(as.numeric(st_distance(land, zones)), nrow = nrow(land))
  nearest <- apply(distance, 1, which.min)
  nearest_m <- apply(distance, 1, min)
  second_m <- apply(distance, 1, function(d) sort(d)[2])
  centre <- st_coordinates(suppressWarnings(st_centroid(st_transform(land, 4326))))
  where <- str_glue("{round(centre[, 1], 3)} E, {round(centre[, 2], 3)} N, {round(land$km2, 3)} km2")
  touching_two <- rowSums(distance == 0) > 1
  if (any(touching_two)) stop(str_c("Land polygon(s) touch two zones and need cutting by hand: ", str_c(where[touching_two], collapse = "; ")))
  ambiguous <- nearest_m <= max_distance_m & second_m < 2 * nearest_m
  if (any(ambiguous)) message("Second-nearest zone within twice the nearest distance, check: ", str_c(where[ambiguous], collapse = "; "))
  land %>%
    mutate(area = zones$area[nearest], distance_m = round(nearest_m)) %>%
    filter(distance_m <= max_distance_m)
}

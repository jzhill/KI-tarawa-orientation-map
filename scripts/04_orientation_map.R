# Orientation map (Figure 1): Tarawa atoll (A) with the Kiribati globe (B)
# Needs data-raw/KIR_EA_Census2020FINAL.geojson (Kiribati National Statistics Office; not redistributable), the outputs of scripts 02 and 03, and reference/tarawa_landmarks.csv
# Outputs: outputs/orientation_map.pdf, outputs/orientation_map.png (300 dpi, white), outputs/orientation_map_transparent.png (300 dpi)
# Everything in this script is figure design: positions are longitude/latitude or UTM 59N metres, tuned by eye

library(tidyverse)
library(sf)
library(terra)
library(here)

source(here("R", "globe.R"))
source(here("R", "map_helpers.R"))
source(here("R", "orientation_map.R"))

sf_use_s2(FALSE)

style <- list(
  navy = "#042C53", teal = "#1B9E9E", dark_teal = "#0B5D5D",
  area_fill = c("Betio" = "#C2410C", "Rest of South Tarawa" = "#F4A62A", "North Tarawa" = "#FFFFFF"),
  area_edge = c("Betio" = "#3B1305", "Rest of South Tarawa" = "#5A3A00", "North Tarawa" = "#4A4A48"),
  globe_text_scale = 0.77   # the globe is drawn smaller here than standalone, so its text and outline scale down with it
)

# map frame, with the atoll on the left and the globe tucked into the open ocean north-east of it
frame <- list(x = utm_xy(c(172.865, 173.235), 1.25)$x, y = utm_xy(172.865, c(1.25, 1.765))$y)
globe_centre <- utm_xy(173.12, 1.645)
globe_radius <- utm_xy(173.12 + 0.10, 1.645)$x - globe_centre$x

imagery <- imagery_matrix(rast(here("data-processed", "tarawa_s2_median_20m.tif")), rast(here("data-processed", "tarawa_s2_fade_20m.tif")))
areas <- census_areas(here("data-raw", "KIR_EA_Census2020FINAL.geojson"))
globe <- readRDS(here("data-processed", "globe.rds")) %>% place_globe(c(globe_centre$x, globe_centre$y), globe_radius)
globe_halo <- tibble(t = seq(0, 2 * pi, length.out = 400)) %>%
  mutate(x = globe_centre$x + 1.03 * globe_radius * cos(t), y = globe_centre$y + 1.03 * globe_radius * sin(t))

lagoon <- bind_cols(tibble(label = "Lagoon", hjust = 0.5), utm_xy(173.00, 1.46))

# callouts below South Tarawa: a short arm straight down from the landmark, then an angled line to the label
landmarks <- read_csv(here("reference", "tarawa_landmarks.csv"), show_col_types = FALSE)
callouts <- tribble(
  ~landmark,                  ~text,                       ~arm_m, ~label_lon, ~label_lat, ~hjust,
  "Betio Hospital",           "Betio\nHospital",           1300,   172.905,    1.312,      1,
  "Betio Port",               "Betio\nPort",               2400,   172.955,    1.308,      0,
  "Tungaru Central Hospital", "Tungaru Central\nHospital", 1800,   173.105,    1.322,      1,
  "Bonriki Airport",          "Bonriki\nAirport",          3200,   173.175,    1.322,      0
) %>%
  left_join(landmarks, by = c("landmark" = "label")) %>%
  bind_cols(rename(utm_xy(.$lon, .$lat), px = x, py = y), rename(utm_xy(.$label_lon, .$label_lat), lx = x, ly = y)) %>%
  mutate(x = lx + if_else(hjust == 0, 150, -150), y = ly, label = text)
callout_layers <- list(
  lines = transmute(callouts, x1 = px, y1 = py, x2 = px, y2 = py - arm_m, x3 = lx, y3 = ly),
  labels = select(callouts, x, y, label, hjust)
)

# legend (left) and scale bar (right) under South Tarawa, mirrored about its centre axis
axis_lon <- 173.045
legend_rows <- 1.2905 - 0.0105 * 0:2
legend <- list(
  keys = bind_cols(
    tibble(area = factor(names(style$area_fill), levels = names(style$area_fill)), label = names(style$area_fill)),
    rename(utm_xy(axis_lon - 0.108, legend_rows), kx = x, ky = y),
    tibble(tx = utm_xy(axis_lon - 0.0925, legend_rows[1])$x)
  ),
  key_w = 900, key_h = 650
)
scale_start <- utm_xy(axis_lon + 0.030, 1.2765)
scale_bar <- list(
  line = tibble(x = scale_start$x, xend = scale_start$x + 10000, y = scale_start$y),
  ticks = tibble(km = c(0, 5, 10), x = scale_start$x + km * 1000, y = scale_start$y, tick_h = 350, label = c("0", "5", "10 km"))
)

north_base <- utm_xy(172.885, 1.598)
north_arrow <- tibble(x = north_base$x, y = north_base$y, yend = north_base$y + 3200)
titles <- bind_cols(tibble(label = c("(A) Tarawa Atoll", "(B) Kiribati")), utm_xy(c(172.87, 173.02), c(1.672, 1.745)))

# thin curved arrow from the Tarawa dot on the globe to the atoll's north tip, passing over the Asian coast (first candidate visible in this view)
china_candidates <- tibble(lon = c(112, 116, 120, 122, 125), lat = c(33, 33, 32, 32, 35))
china <- globe_project(globe$view, china_candidates$lon, china_candidates$lat) %>% filter(!is.na(x)) %>% slice(1)
arrow_tip <- utm_xy(172.973, 1.633)
arrow <- curved_arrow(
  start = c(globe$tarawa$x, globe$tarawa$y),
  mid = c(globe_centre$x + china$x * globe_radius, globe_centre$y + china$y * globe_radius),
  end = c(arrow_tip$x, arrow_tip$y)
)

layers <- list(
  imagery = imagery, areas = areas, lagoon = lagoon, callouts = callout_layers, globe = globe, globe_halo = globe_halo,
  arrow = arrow, titles = titles, legend = legend, scale_bar = scale_bar, north_arrow = north_arrow, frame = frame
)
fig <- orientation_map(layers, style)

fig_w <- 5.8
fig_h <- fig_w * diff(frame$y) / diff(frame$x)
dir.create(here("outputs"), showWarnings = FALSE)
ggsave(here("outputs", "orientation_map.pdf"), fig, width = fig_w, height = fig_h, bg = "white")
ggsave(here("outputs", "orientation_map.png"), fig, width = fig_w, height = fig_h, dpi = 300, bg = "white")
ggsave(here("outputs", "orientation_map_transparent.png"), fig, width = fig_w, height = fig_h, dpi = 300, bg = "transparent")

# orientation_map()
# Orientation map: Tarawa atoll on satellite imagery (A) with the Kiribati globe placed over the open ocean (B), all in UTM 59N map units
# Draws only; every position and colour comes in through layers and style (see scripts/04_orientation_map.R)
# Layer order, bottom to top: imagery, census areas, lagoon label, callouts, globe (halo, image, graticule, Kiribati, symbols, labels, Tarawa dot), curved arrow, titles, legend, scale bar, north arrow
#   layers: list of imagery (image, extent), areas (sf), lagoon (x, y, label, hjust), callouts (lines, labels), globe (from place_globe()), globe_halo, arrow, titles, legend (keys), scale_bar (line, ticks), north_arrow, frame (x, y limits)
#   style: list of navy, teal, dark_teal, area_fill, area_edge, globe_text_scale

orientation_map <- function(layers, style) {
  lines <- layers$callouts$lines
  globe <- layers$globe
  key_w <- layers$legend$key_w
  key_h <- layers$legend$key_h
  ggplot() +
    annotation_raster(layers$imagery$image, layers$imagery$extent[1], layers$imagery$extent[2], layers$imagery$extent[3], layers$imagery$extent[4], interpolate = TRUE) +
    geom_sf(data = layers$areas, aes(fill = area, colour = area), linewidth = 0.4, alpha = 0.88) +
    halo_text(layers$lagoon, size = 2.6, colour = style$navy, fontface = "bold.italic") +
    geom_segment(data = lines, aes(x = x1, y = y1, xend = x2, yend = y2), colour = "white", linewidth = 1.0, alpha = 0.7, lineend = "round") +
    geom_segment(data = lines, aes(x = x2, y = y2, xend = x3, yend = y3), colour = "white", linewidth = 1.0, alpha = 0.7, lineend = "round") +
    geom_segment(data = lines, aes(x = x1, y = y1, xend = x2, yend = y2), colour = style$navy, linewidth = 0.35) +
    geom_segment(data = lines, aes(x = x2, y = y2, xend = x3, yend = y3), colour = style$navy, linewidth = 0.35) +
    halo_text(layers$callouts$labels, size = 2.3, colour = style$navy) +
    geom_polygon(data = layers$globe_halo, aes(x, y), fill = "white", colour = NA) +
    annotation_raster(globe$image, globe$extent[1], globe$extent[2], globe$extent[3], globe$extent[4], interpolate = TRUE) +
    geom_path(data = globe$graticule, aes(x, y, group = line), colour = "white", linewidth = 0.25, linetype = "dashed", alpha = 0.7, na.rm = TRUE) +
    geom_polygon(data = globe$kiribati, aes(x, y, group = part, subgroup = ring), fill = style$teal, alpha = 0.25, colour = NA) +
    geom_path(data = globe$kiribati, aes(x, y, group = interaction(part, ring)), colour = style$teal, linewidth = 0.9 * style$globe_text_scale) +
    geom_polygon(data = globe$symbols, aes(x, y, group = part, subgroup = ring), fill = style$dark_teal, alpha = 0.55, colour = "white", linewidth = 0.25) +
    geom_text(data = globe$labels, aes(x, y, label = label, hjust = hjust, vjust = vjust, size = size * style$globe_text_scale), colour = style$dark_teal, fontface = "bold", lineheight = 0.9) +
    geom_point(data = globe$tarawa, aes(x, y), shape = 21, size = 1.8, fill = "white", colour = "black") +
    geom_path(data = layers$arrow, aes(x, y), colour = style$navy, linewidth = 0.3, alpha = 0.8, arrow = grid::arrow(length = grid::unit(0.08, "in"), type = "open", angle = 25)) +
    geom_text(data = layers$titles, aes(x, y, label = label), hjust = 0, size = 3.6, fontface = "bold", colour = style$navy) +
    geom_rect(data = layers$legend$keys, aes(xmin = kx, xmax = kx + key_w, ymin = ky - key_h / 2, ymax = ky + key_h / 2, fill = area, colour = area), linewidth = 0.4, alpha = 0.88) +
    geom_text(data = layers$legend$keys, aes(x = tx, y = ky, label = label), hjust = 0, size = 2.3, colour = style$navy) +
    geom_segment(data = layers$scale_bar$line, aes(x = x, y = y, xend = xend, yend = y), colour = style$navy, linewidth = 0.4) +
    geom_segment(data = layers$scale_bar$ticks, aes(x = x, y = y, xend = x, yend = y + tick_h), colour = style$navy, linewidth = 0.4) +
    geom_text(data = layers$scale_bar$ticks, aes(x = x, y = y - 250, label = label), size = 2.2, colour = style$navy, vjust = 1) +
    geom_segment(data = layers$north_arrow, aes(x = x, y = y, xend = x, yend = yend), colour = style$navy, linewidth = 0.5, arrow = grid::arrow(length = grid::unit(0.1, "in"), type = "closed")) +
    geom_text(data = layers$north_arrow, aes(x = x, y = yend + 500, label = "N"), colour = style$navy, size = 2.8, fontface = "bold", vjust = 0) +
    scale_fill_manual(values = style$area_fill, guide = "none") +
    scale_colour_manual(values = style$area_edge, guide = "none") +
    scale_size_identity() +
    coord_sf(crs = 32659, xlim = layers$frame$x, ylim = layers$frame$y, expand = FALSE) +
    theme_void(base_size = 8) +
    theme(legend.position = "none", plot.margin = margin(2, 2, 2, 2))
}

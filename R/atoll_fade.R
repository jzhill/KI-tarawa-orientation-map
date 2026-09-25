# atoll_fade()
# Transparency masks for imagery around an atoll, two layers on the composite grid
# "tight" follows the coast, "smooth" follows the convex hull of the atoll; each is 1 over the atoll and fades to 0 over fade_m metres
# Atoll pixels are the bright ones (reef, lagoon, land); specks under 5 km2 are dropped, gaps up to 2 x close_m closed, holes filled, and only the largest polygon kept
# Computed on a 100 m grid, then resampled to the composite grid
#   composite: from s2_composite()
#   luminance_min: brightness (0-1) above which a pixel counts as atoll
#   close_m: buffer distance used to close gaps, metres
#   fade_m: fade width, metres

atoll_fade <- function(composite, luminance_min = 0.22, close_m = 1500, fade_m = 5000) {
  rgb <- values(composite) / 255
  rgb[is.na(rgb)] <- 0
  bright <- composite[[1]]
  values(bright) <- as.numeric(as.vector(rgb %*% c(0.3, 0.59, 0.11)) > luminance_min)
  coarse <- aggregate(bright, fact = 5, fun = "max")
  atoll <- as.polygons(coarse, dissolve = TRUE)
  atoll <- atoll[atoll[[1]][, 1] == 1, ] %>% disagg()
  atoll <- atoll[expanse(atoll) > 5e6, ] %>%
    buffer(close_m) %>%
    aggregate() %>%
    buffer(-close_m) %>%
    fillHoles() %>%
    disagg()
  atoll <- atoll[which.max(expanse(atoll)), ]
  fade_from <- function(polygon) {
    inside <- rasterize(polygon, coarse, field = 1, background = NA)
    clamp(1 - distance(inside) / fade_m, 0, 1)^1.6
  }
  fade <- c(fade_from(atoll), fade_from(convHull(atoll)))
  names(fade) <- c("tight", "smooth")
  resample(fade, composite[[1]], method = "bilinear")
}

# KI-tarawa-orientation-map

R code to build an orientation map of Tarawa Atoll, Kiribati: a satellite-imagery map of the atoll (panel A) with a globe locator showing the extent of Kiribati (panel B). Built for a leprosy epidemiology paper (see [KI-lep-epi-paper](https://github.com/jzhill/KI-lep-epi-paper)), but written to be reused for any Tarawa or Kiribati output.

Status: in development. Code is being added in stages; see the commit history.

## Layout

- `R/`: functions (sourced, not run directly). `natural_earth.R` fetches Natural Earth layers; `pacific_groupings.R` builds the named Pacific polygons; `sentinel2.R` searches, reads and composites Sentinel-2 scenes; `atoll_fade.R` builds the imagery transparency masks; `globe.R` (camera, projection, image, plot), `globe_base.R` (base raster or vector fallback) and `contiguous_zone.R` build the globe; `tarawa_land.R` builds the land polygons and their zones; `map_helpers.R` (imagery colours, placing the globe, curved arrow) and `orientation_map.R` (the drawing function) assemble the figure.
- `scripts/`: numbered scripts, run in order from the project root.
- `reference/`: small hand-checked reference data that is committed (`tarawa_s2_scenes.csv`: the Sentinel-2 scenes used, frozen so the composite does not change as new scenes are acquired; `tarawa_landmarks.csv`: four landmark points (three from OpenStreetMap, frozen at the retrieval date so the figure does not change if OSM is edited; ways are positioned at the Overpass `out center` point; Betio Hospital was supplied by the author because OSM still shows the old site).
- `data-raw/`, `data-processed/`, `outputs/`: never committed (git-ignored). Inputs are fetched or supplied as described below.

## Data manifest

The code is MIT-licensed (`LICENSE`). The data are not covered by that licence; each dataset keeps its own terms.

| Dataset | Used for | Source | Terms | In this repo? |
|---|---|---|---|---|
| Sentinel-2 Level-2A imagery | Panel A base image | Copernicus Sentinel-2, via the Element 84 Earth Search catalogue (Sentinel-2 Cloud-Optimized GeoTIFFs, AWS Open Data) | Free, full and open. Attribute: "Contains modified Copernicus Sentinel data 2024-2025" | Scene list only (`reference/tarawa_s2_scenes.csv`); imagery is fetched by script and cached |
| 2020 census enumeration areas | Giving each land polygon its zone (Betio, rest of South Tarawa, North Tarawa); not drawn | Kiribati National Statistics Office | Supplied with permission. **Do not redistribute** | Never |
| OpenStreetMap coastline (`natural=coastline`) | Tarawa land polygons | OpenStreetMap via the Overpass API, pinned to the data as at 25 September 2026 07:30 UTC | ODbL. Attribute: "© OpenStreetMap contributors" | No (the response is cached in `data-raw/osm/`) |
| Kiribati contiguous zone (24 nautical miles) | Island-group symbols | Flanders Marine Institute (2023). Maritime Boundaries Geodatabase: Contiguous Zones (24NM), version 4. https://www.marineregions.org/ https://doi.org/10.14284/630 (features with `iso_ter1 == "KIR"`) | CC BY 4.0. Cite as given; Marine Regions asks to be told of publications (info@marineregions.org) and says the data have no legal value | No |
| Natural Earth I with Shaded Relief and Water, 1:50m (raster) | Panel B globe base | https://www.naturalearthdata.com (88 MB download; fetched by `scripts/03_globe.R` only with permission) | Public domain | No |
| Natural Earth land polygons, 1:50m | Flat-colour fallback for the globe base if the raster is not used | https://www.naturalearthdata.com (0.4 MB; downloaded by `scripts/03_globe.R`) | Public domain | No |
| Natural Earth "Pacific groupings" lines, 1:10m, v5.0.0 | Schematic Kiribati extent polygon | https://www.naturalearthdata.com (downloaded by `scripts/01_pacific_groupings.R`) | Public domain | No |
| Natural Earth admin-0 map units, 1:10m, v5.1.1 | Naming the Pacific groupings polygons | https://www.naturalearthdata.com (downloaded by `scripts/01_pacific_groupings.R`) | Public domain | No |
| OpenStreetMap landmarks (Betio Port, Tungaru Central Hospital, Bonriki Airport); Betio Hospital position supplied by the author (new building, moved 2025) | Panel A callouts | OpenStreetMap via the Overpass API, retrieved 25 September 2026 | ODbL. Attribute: "© OpenStreetMap contributors" | Yes: 4 points in `reference/tarawa_landmarks.csv` (OSM IDs where applicable) |

The contiguous-zone polygons are Marine Regions' 12-24 NM band. A copy on the Pacific Data Hub has the same outer extent but is licensed CC BY-NC-SA 4.0, so it is not used. The SPREP "Pacific islands region land" layer (CC BY-NC-SA 4.0) matches the OpenStreetMap coastline to 97% on Tarawa and is not used for the same reason.

The Kiribati extent polygon and the island-group symbols are schematic, for orientation only. They are not legal maritime boundaries.

## Software

R 4.6.1 with sf, terra, ggplot2 and the tidyverse. Package versions are pinned with renv: run `renv::restore()` once after cloning.

## Running

From the project root, in order:

```
Rscript scripts/01_pacific_groupings.R
Rscript scripts/02_sentinel2_composite.R
Rscript scripts/03_globe.R
Rscript scripts/04_tarawa_land_zones.R
Rscript scripts/05_orientation_map.R
```

- `01`: downloads the Natural Earth layers (first run only) and writes `data-processed/pacific_groupings_polygons.gpkg`: 22 named polygons in EPSG:3832. Faces are named from Natural Earth map units. Easter Island, which has no map unit, is named from a reference coordinate, and the Tuvalu polygon also holds Wallis and Futuna.
- `02`: on the first run, searches the Earth Search catalogue and writes the scene list (the 8 lowest-cloud scenes per tile, July 2024 to October 2025; tiles covering under half of the map frame are dropped, which leaves tile 59NQB only). Each scene is read over HTTP, cut to a 20 m UTM 59N grid, cloud-masked with the scene classification layer, and cached in `data-processed/s2_scenes/`. Pixels masked in every scene are filled from their neighbours (median within 180 m, then 540 m). Writes the per-pixel median composite and a two-layer fade mask (`tight` follows the coast, `smooth` follows the convex hull, each fading over 5 km). First run needs internet and takes about 2.5 minutes; later runs reuse the scene list and the cache.
- `03`: builds the globe layers (panel B) in screen coordinates and saves them to `data-processed/globe.rds`, with a transparent preview at `outputs/globe_preview.png`. Needs `data-processed/pacific_groupings_polygons.gpkg` (from `01`) and the Marine Regions contiguous zone download: get 'Contiguous Zones (24NM)' from https://www.marineregions.org/downloads.php (https://doi.org/10.14284/630) and put the zip in `data-raw/` (no need to unzip; the script reads the shapefile inside it). The shaded-relief base is an 88 MB download, so the script asks first when run interactively; a non-interactive run uses a flat-colour land and ocean globe (same projection, same layers) unless `download_raster <- TRUE` is set at the top of the script.
- `04`: fetches the OpenStreetMap coastline (pinned to a date; the response is cached in `data-raw/osm/`), closes it into land polygons, and gives each polygon its zone from the nearest census zone. Polygons more than 1 km from any census zone (Abaiang atoll, a shoal in the lagoon) are left out, and a polygon touching two zones stops the script (none does). One islet near Bonriki is nearly equidistant from two zones; it is nearest Tanaea, so it stays in South Tarawa. Needs the census enumeration areas in `data-raw/KIR_EA_Census2020FINAL.geojson` (Kiribati National Statistics Office; supplied with permission, never committed), used only to assign zones. Writes `data-processed/tarawa_land_zones.gpkg`.
- `05`: assembles Figure 1 and writes `outputs/orientation_map.pdf` (vector, imagery embedded), `outputs/orientation_map.png` and `outputs/orientation_map_transparent.png` (300 dpi), 5.8 in wide and about 8.1 in tall. Needs the outputs of `02`, `03` and `04`, and `reference/tarawa_landmarks.csv`. All figure design (frame, callout positions, colours, titles) is set at the top of the script.

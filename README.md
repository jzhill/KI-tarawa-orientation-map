# KI-tarawa-orientation-map

R code to build an orientation map of Tarawa Atoll, Kiribati: a satellite-imagery map of the atoll (panel A) with a globe locator showing the extent of Kiribati (panel B). Built for a leprosy epidemiology paper (see [KI-lep-epi-paper](https://github.com/jzhill/KI-lep-epi-paper)), but written to be reused for any Tarawa or Kiribati output.

Status: in development. Code is being added in stages; see the commit history.

## Layout

- `R/`: functions (sourced, not run directly).
- `scripts/`: numbered scripts, run in order from the project root.
- `data-raw/`, `data-processed/`, `outputs/`: never committed (git-ignored). Inputs are fetched or supplied as described below.

## Data manifest

The code is MIT-licensed (`LICENSE`). The data are not covered by that licence; each dataset keeps its own terms.

| Dataset | Used for | Source | Terms | In this repo? |
|---|---|---|---|---|
| Sentinel-2 Level-2A imagery | Panel A base image | Copernicus Sentinel-2, via the Element 84 Earth Search catalogue (Sentinel-2 Cloud-Optimized GeoTIFFs, AWS Open Data) | Free, full and open. Attribute: "Contains modified Copernicus Sentinel data [years]" | No (fetched by script, cached) |
| 2020 census enumeration areas | Betio, rest of South Tarawa, North Tarawa units | Kiribati National Statistics Office | Supplied with permission. **Do not redistribute** | Never |
| Kiribati contiguous zone (24 nautical miles), April 2022 | Island-group symbols | Pacific Data Hub (SPREP): https://pacific-data.sprep.org/dataset/kiribati-contiguous-zone-24-nautical-miles | Licence to be confirmed from the dataset page | No |
| Natural Earth I with Shaded Relief and Water, 1:50m (raster) | Panel B globe base | https://www.naturalearthdata.com | Public domain | No (167 MB) |
| Natural Earth "Pacific groupings" lines, 1:10m, v5.0.0 | Schematic Kiribati extent polygon | https://www.naturalearthdata.com | Public domain | No |
| OpenStreetMap landmarks (Betio Hospital, Betio Port, Tungaru Central Hospital, Bonriki Airport) | Panel A callouts | OpenStreetMap via the Overpass API (25 September 2026) | ODbL. Attribute: "© OpenStreetMap contributors" | OSM IDs only |

The Kiribati extent polygon and the island-group symbols are schematic, for orientation only. They are not legal maritime boundaries.

## Software

R 4.6.1 with sf, terra, ggplot2 and the tidyverse. Package versions will be pinned with renv once code is added.

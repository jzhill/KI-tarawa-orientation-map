# AGENTS.md

R scripts that build Figure 1 (orientation map: Tarawa Atoll on satellite imagery with a Kiribati globe locator) for a leprosy epidemiology paper. Written to be reused for any Tarawa or Kiribati output.

## Commands

Run from the project root (renv activates via `.Rprofile`), in order:

```
Rscript scripts/01_pacific_groupings.R
Rscript scripts/02_sentinel2_composite.R
Rscript scripts/03_globe.R
Rscript scripts/04_orientation_map.R
```

- Packages: `renv::restore()`; after adding one, `renv::snapshot()`; verify with `renv::status()` (must be consistent).
- `02` needs internet and takes a few minutes the first time (scenes are cached after that). `03` asks before downloading the 88 MB raster; a non-interactive run uses the flat-colour vector globe unless `download_raster <- TRUE`.

## Structure

- `R/`: functions only, sourced by the scripts. `scripts/`: numbered scripts, run in order.
- `reference/`: small committed reference data (landmarks, Sentinel-2 scene list).
- `data-raw/`, `data-processed/`, `outputs/`: git-ignored. Inputs and their sources are in the README data manifest.

## Conventions

- tidyverse with the `%>%` pipe (never `|>`); `here()` for paths; explicit code over clever code; minimal defensive code.
- Function comments: `# name()`, then a one-line description with no leading article, one line per further point, parameters last and indented two spaces, blank line before the definition.
- Match existing style. No numbered subheadings in code. Change only what the task needs; no unrequested functions, refactors or options.
- Figure design (positions, colours, sizes) lives at the top of `scripts/04_orientation_map.R`, not in the functions.
- Map layers are in UTM 59N (EPSG:32659). Globe layers are in screen coordinates (globe radius 1) until `place_globe()` moves them into map coordinates.

## Data and licences

- The 2020 census enumeration areas belong to the Kiribati National Statistics Office and were supplied with permission: never commit or redistribute them.
- The README data manifest lists source, terms and attribution for every dataset. Update it when a source changes. Sources with terms that clash with an open-access article were dropped (a CC BY-NC-SA contiguous-zone copy, GADM).
- The Kiribati extent polygon and island-group symbols are schematic: never describe them as legal boundaries.
- After regenerating a figure, check its file modification time. If an output will not overwrite, ask the user to close it in their viewer.
- Do not push without asking.

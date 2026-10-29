# Remove islands

Keeps only the largest group of neighbouring polygons (queen
contiguity), i.e. the one with the most polygons, and drops the polygons
outside it. This is useful before calling
[`uci()`](https://ipea.github.io/uci/reference/uci.md) with
`dist_type = "spatial_link"`, which requires the polygons to form one
contiguous area.

## Usage

``` r
remove_islands(sf_object, var_name = NULL, showProgress = TRUE)
```

## Arguments

- sf_object:

  A `POLYGON sf data.frame`.

- var_name:

  An optional `string`. The name of a numeric column in `sf_object`. If
  given, the message also reports how many activities were dropped (`NA`
  values are considered to be equal to `0`). Only used for the message.
  Defaults to `NULL`.

- showProgress:

  A `logical`. If `TRUE` (Default), a message reports how many polygons
  were removed.

## Value

`sf_object` with only the polygons of the largest contiguous group (same
CRS, columns, row order and row names).

## Details

If several groups tie for the most polygons, the group with the earliest
row is kept. Objects with fewer than 2 rows are returned as they are.
Contiguity is computed in the CRS of `sf_object`, which is not changed.
`uci(remove_islands = TRUE)` applies this function after reprojecting to
EPSG:3857, so for exactly the same result on geographic (lon/lat) data,
reproject `sf_object` first.

## See also

Other urban centrality index:
[`uci()`](https://ipea.github.io/uci/reference/uci.md)

## Examples

``` r
# load data
data_dir <- system.file("extdata", package = "uci")
grid <- readRDS(file.path(data_dir, "grid_bho.rds"))

# add an island: a copy of the first cell, shifted away from the grid
island <- grid[1, ]
sf::st_geometry(island) <- sf::st_geometry(island) + c(0.5, 0)
#> Error in st_geometry.sf(island): attr(obj, "sf_column") does not point to a geometry column.
#> Did you rename it, without setting st_geometry(obj) <- "newname"?
sf::st_crs(island) <- sf::st_crs(grid)
#> Error in UseMethod("st_crs<-"): no applicable method for 'st_crs<-' applied to an object of class "list"
grid_island <- rbind(grid, island)
#> Error in st_geometry.sf(x): attr(obj, "sf_column") does not point to a geometry column.
#> Did you rename it, without setting st_geometry(obj) <- "newname"?
nrow(grid_island)
#> Error: object 'grid_island' not found

# remove the island
grid_main <- remove_islands(grid_island, var_name = 'jobs')
#> Error: object 'grid_island' not found
nrow(grid_main)
#> Error: object 'grid_main' not found
```

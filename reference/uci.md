# Urban Centrality Index

Calculates the Urban Centrality Index (UCI) as in Pereira et al., (2013)
[doi:10.1111/gean.12002](https://doi.org/10.1111/gean.12002) . The UCI
measures the extent to which the spatial organization of a city or
region varies from extreme monocentric to extreme polycentric in a
continuous scale from 0 to 1. Values close to 0 indicate more
polycentric patterns and values close to 1 indicate a more monocentric
urban form.

Calculate Urban Centrality Index

## Usage

``` r
uci(
  sf_object,
  var_name,
  dist_type = "euclidean",
  bootstrap_border = FALSE,
  showProgress = TRUE,
  parallel = FALSE,
  remove_islands = FALSE,
  max_method = NULL
)
```

## Arguments

- sf_object:

  A `POLYGON sf data.frame` of the study area, with at least two
  polygons. Distances and areas are computed in EPSG:3857 (Web
  Mercator), which distorts very large regions.

- var_name:

  A `string`. The name of the column in `sf_object` with the number of
  activities/opportunities/resources/services to be considered when
  calculating urban centrality levels. `NA` values are considered to be
  equal to `0`.

- dist_type:

  A `string` indicating whether calculations should be based on
  `"euclidean"` distances (Default) or `"spatial_link"` distances.
  Spatial link distances consider Euclidean distances along the links of
  spatial neighbor links. In the case of areas with a concave shape
  (like a bay), it is strongly recommended to use `"spatial_link"`
  distances (even though they are computationally more costly) because
  simple Euclidean distances can bias UCI estimates in those cases.
  `uci()` warns when the study area is markedly concave or has a large
  gap inside it (e.g. a lake) and `dist_type = "euclidean"`.

- bootstrap_border:

  A `logical`. Deprecated, use `max_method = "bootstrap"`. If `TRUE` and
  `max_method` is `NULL`, the bootstrap is used; an explicit
  `max_method` takes precedence.

- showProgress:

  A `logical`. If `TRUE` (Default) and the session is interactive,
  `uci()` reports the progress of each step, with a progress bar for the
  spatial separation on large grids. It also controls the message on how
  many polygons were removed by `remove_islands`.

- parallel:

  A `logical`. Only used when `dist_type = "spatial_link"`. If `FALSE`
  (Default), shortest-path distances are computed on a single thread
  (any thread setting made with
  [`RcppParallel::setThreadOptions()`](https://rdrr.io/pkg/RcppParallel/man/setThreadOptions.html)
  is restored on exit). If `TRUE`, they are computed in parallel using
  the number of threads set by {RcppParallel} (all available cores by
  default, see
  [`RcppParallel::setThreadOptions()`](https://rdrr.io/pkg/RcppParallel/man/setThreadOptions.html)).

- remove_islands:

  A `logical`. Defaults to `FALSE`. If `TRUE`, only the largest group of
  neighbouring polygons (queen contiguity), i.e. the one with the most
  polygons, is kept, and polygons outside it, along with their
  activities, are dropped before any calculation. When there are
  isolated islands, `"spatial_link"` distances only works with
  `remove_islands = TRUE`. Defaults to `FALSE`. See
  [`remove_islands()`](https://ipea.github.io/uci/reference/remove_islands.md).

- max_method:

  A `string`, or `NULL` (Default), which means `"exact"` unless
  `bootstrap_border = TRUE`. How to find the maximum value of the
  Venables spatial separation index that the study area admits
  (`spatial_separation_max`), which normalises the index. `"exact"`
  searches for the distribution of activities among the border polygons
  that maximises the spatial separation. The search is done on the
  distances between polygon centroids, where the maximum is global for
  Euclidean distances, and the result is then refined with the self
  distance of each polygon included in the distances, so that it is a
  stationary point of the same quantity as `spatial_separation`. UCI is
  0 (up to the solver tolerance) when the activities sit on that
  maximising configuration. With `"spatial_link"` distances the same
  procedure gives a stationary point. `"heuristic"` is the approach of
  Pereira et al. (2013), which assumes that the maximum occurs when all
  activities are equally distributed along the border of the study area.
  It is fast, but it does not reach the maximum spatial separation, so
  it underestimates UCI by an amount that depends on the shape of the
  area. `"bootstrap"` simulates 20000 random distributions of activities
  along the border and uses the largest spatial separation found; it
  gets closer to the maximum than the heuristic but does not reach it
  either. Options `"heuristic"` and `"bootstrap"` two are kept so that
  results of previous versions can be reproduced.

## Value

A one-row `data.frame` with the columns `UCI`, `location_coef` (LC),
`spatial_separation` (the Venables index V of the observed distribution)
and `spatial_separation_max` (its maximum for the study area, as found
by `max_method`), so that `UCI = LC * (1 - V / V_max)`.

## Usage

Please check the vignettes and data documentation on the
[website](https://ipea.github.io/uci/index.html).

## See also

Useful links:

- <https://github.com/ipea/uci>

- <https://ipea.github.io/uci/>

- Report bugs at <https://github.com/ipea/uci/issues>

Other urban centrality index:
[`remove_islands()`](https://ipea.github.io/uci/reference/remove_islands.md)

## Author

**Maintainer**: Rafael H. M. Pereira <rafa.pereira.br@gmail.com>
([ORCID](https://orcid.org/0000-0003-2125-7465))

Authors:

- Rafael H. M. Pereira <rafa.pereira.br@gmail.com>
  ([ORCID](https://orcid.org/0000-0003-2125-7465))

## Examples

``` r
# load data
data_dir <- system.file("extdata", package = "uci")
grid <- readRDS(file.path(data_dir, "grid_bho.rds"))

# calculate UCI
df <- uci(
        sf_object = grid,
        var_name = 'jobs',
        dist_type = "spatial_link"
        )

head(df)
#>         UCI location_coef spatial_separation spatial_separation_max
#> 1 0.2609465     0.5278007           4281.819               8468.847
```

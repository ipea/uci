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
  remove_islands = FALSE
)
```

## Arguments

- sf_object:

  A `POLYGON sf data.frame` of the study area. Distances and areas are
  computed in EPSG:3857 (Web Mercator), which distorts very large
  regions.

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

- bootstrap_border:

  A `logical`. The calculation of UCI requires one to find the maximum
  value of the Venables spatial separation index of the study area. If
  `bootstrap_border = FALSE` (Default), the function uses a heuristic
  approach that assumes that the max spatial separation would occur when
  all activities were equally distributed along the border of the study
  area. This is a fast approach, but it does not reach the maximum
  spatial separation. Alternatively, if `bootstrap_border = TRUE`, the
  function uses a bootstrap approach that simulates 20000 random
  distributions of activities along the border and uses the max spatial
  separation found. This approach is more computationally expensive and
  although it might not return the maximum theoretical value of spatial
  separation, it is probably very close to it.

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

  A `logical`. If `TRUE`, only the largest group of neighbouring
  polygons (queen contiguity), i.e. the one with the most polygons, is
  kept, and polygons outside it, along with their activities, are
  dropped before any calculation. This applies to both `dist_type`s, and
  it lets `"spatial_link"` distances be used in areas with islands.
  Defaults to `FALSE`. See
  [`remove_islands()`](https://ipea.github.io/uci/reference/remove_islands.md).

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
        dist_type = "euclidean",
        bootstrap_border = FALSE
        )
head(df)
#>         UCI location_coef spatial_separation spatial_separation_max
#> 1 0.2538635     0.5278007           3880.114               7475.899

# calculate UCI with bootstrap
df2 <- uci(
        sf_object = grid,
        var_name = 'jobs',
        dist_type = "euclidean",
        bootstrap_border = TRUE,
        showProgress = TRUE
        )
head(df2)
#>         UCI location_coef spatial_separation spatial_separation_max
#> 1 0.2553067     0.5278007           3880.114               7515.494
```

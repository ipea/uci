# uci (development version)

* Major changes
  * `uci()` is faster and uses much less memory. With `bootstrap_border = TRUE`, each of the 20,000 simulated border configurations is now evaluated algebraically from the border distance matrix instead of by a full matrix product. With `dist_type = "spatial_link"`, distances are built from the sparse neighbour list, and the full distance matrix is never held in memory, so large grids no longer need several n × n matrices. Results are unchanged (up to floating-point rounding).
  * The `parallel` argument now controls the number of threads used to compute shortest-path distances when `dist_type = "spatial_link"`, and it has no effect with `"euclidean"`. With `parallel = FALSE` (default) these distances are computed on a single thread. Previously {cppRouting} silently used all cores. For mid-size grids this default can be slower than before, so use `parallel = TRUE` to use all cores (or the number set with `RcppParallel::setThreadOptions()`). `uci()` no longer uses {future}/{furrr}, so a `future::plan()` set by the user has no effect.

* Minor changes
  * New sample data set `inst/extdata/grid_rio.rds`: a hexagonal grid of Rio de Janeiro with a concave outline, islands and isolated cells, based on data from the Access to Opportunities Project (Ipea, 2019).
  * `uci()` now raises informative errors when `var_name` has negative, infinite or non-numeric values, when all its values are 0 or `NA`, and, with `dist_type = "spatial_link"`, when the polygons don't form one contiguous area. These cases previously returned `NaN`/`NA` or a cryptic error from {spdep}.
  * `showProgress` is kept for backward compatibility but no longer shows a progress bar.
  * {furrr}, {future} and {pbapply} are no longer dependencies.


# uci 0.3.1

* Bug fix
  * Avoid errors when detecting the number of available cores for parallel processing.


# uci 0.3.0

* Major changes
  * `uci()` now accepts columns with `NA` values. In such cases, `NA`s are replaced with zero as they represent zero activities.
  * improved documentation
  * The package now uses Queen contiguity (`spdep::poly2nb(geo, queen=TRUE)`) to determine neighboring polygons whe considering spatial link distances.
  * Update vignette


# uci 0.2.0

* Major changes

  * The `uci` function now has a new parameter `dist_type` that allows users to choose  whether calculations should be based on `"euclidean"` distances (Default) or `"spatial_link"` distances. Spatial link distances consider Euclidean distances along the links of spatial neighbour links. In the case of areas with a concave shape (like a bay), it is strongly recommended to use `"spatial_link"` distances (even though they are computationally more costly) because simple Euclidean distances can bias UCI estimates in those cases.
  * The `uci` function now has a new parameter `parallel` that speeds up calculations for large areas comprised with many polygons.

* Minor changes
  * Minor updates to documentation
  * Performance improvments


# uci 0.1.0

* Initial CRAN release.

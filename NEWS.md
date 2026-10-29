# uci (development version)

* Major changes
  * New argument `max_method` in `uci()` selects how the maximum spatial separation of the study area (`spatial_separation_max`, which normalises the index) is found. The new default, `"exact"`, searches for the distribution of activities among the border polygons that maximises the spatial separation: the search runs on the distances between polygon centroids, where the maximum is global for Euclidean distances (the problem is concave), and the result is then refined with the self distance of each polygon included, so that it is a stationary point of the same quantity as `spatial_separation`. The two previous approaches are lower bounds: `"heuristic"` (activities spread evenly along the border, the approach of Pereira et al. 2013, previously `bootstrap_border = FALSE`) and `"bootstrap"` (the best of 20,000 random border configurations, previously `bootstrap_border = TRUE`). Both remain available and reproduce the values of previous versions. **UCI values change with the new default**, and by an amount that depends on the shape of the area, which the previous approaches underestimated: the Belo Horizonte sample grid goes from 0.254 to 0.261 and the Rio de Janeiro grid from 0.330 to 0.420. `bootstrap_border` is deprecated and still selects the bootstrap when `max_method` is not given.
  * `uci()` now requires at least two polygons.
  * `uci()` is faster and uses much less memory. With `max_method = "bootstrap"` (previously `bootstrap_border = TRUE`), each of the 20,000 simulated border configurations is now evaluated algebraically from the border distance matrix instead of by a full matrix product. With `dist_type = "spatial_link"`, distances are built from the sparse neighbour list, and the full distance matrix is never held in memory, so large grids no longer need several n × n matrices. Results are unchanged (up to floating-point rounding).
  * The `parallel` argument now controls the number of threads used to compute shortest-path distances when `dist_type = "spatial_link"`, and it has no effect with `"euclidean"`. With `parallel = FALSE` (default) these distances are computed on a single thread. Previously {cppRouting} silently used all cores. For mid-size grids this default can be slower than before, so use `parallel = TRUE` to use all cores (or the number set with `RcppParallel::setThreadOptions()`). `uci()` no longer uses {future}/{furrr}, so a `future::plan()` set by the user has no effect.

* Minor changes
  * New argument `remove_islands` in `uci()`. If `TRUE`, only the largest group of neighbouring polygons is kept, so `dist_type = "spatial_link"` can be used in areas with islands. Polygons outside that group, and their activities, are dropped from the calculation, and a message reports how many (when `showProgress = TRUE`). The same step is available as the new function `remove_islands()`, which returns the filtered `sf` object, so it can be inspected or mapped before calling `uci()`.
  * New sample data set `inst/extdata/grid_rio.rds`: a hexagonal grid of Rio de Janeiro with a concave outline, islands and isolated cells, based on data from the Access to Opportunities Project (Ipea, 2019).
  * `uci()` now raises informative errors when `var_name` has negative, infinite or non-numeric values, when all its values are 0 or `NA`, and, with `dist_type = "spatial_link"`, when the polygons don't form one contiguous area. These cases previously returned `NaN`/`NA` or a cryptic error from {spdep}.
  * With `showProgress = TRUE`, `uci()` now reports the progress of each step with {cli}, plus a progress bar for the spatial separation on large grids. These progress messages appear only in interactive sessions, so knitted documents, scripts and tests don't show them; the `remove_islands` message is still controlled by `showProgress` alone. The old {pbapply}/{furrr} progress bar of the bootstrap is gone, as the bootstrap now takes well under a second.
  * {furrr}, {future} and {pbapply} are no longer dependencies.
  * Errors are now raised with {cli}: messages are reworded and formatted, and have class `rlang_error`. An all-`NA` `var_name` column now gives the informative "0 or NA" error instead of a {data.table} type error. {cli} and {rlang} are new dependencies.


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

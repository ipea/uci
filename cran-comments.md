## R CMD check results

── R CMD check results ───────────────────────────────────────────────────────────────────── uci 1.0.0 ────
Duration: 1m 54.3s

0 errors ✔ | 0 warnings ✔ | 0 notes ✔


# uci v1.0.0

* Breaking changes
  * **UCI values change.** New argument `max_method` sets how the maximum spatial separation (`spatial_separation_max`) is found. The new default, `"exact"`, searches for the true maximum, which is guaranteed for Euclidean distances between centroids (see `?uci`). The previous approaches underestimated it by an amount that depends on the shape of the area; they remain available as `"heuristic"` (old default) and `"bootstrap"`, and reproduce earlier results. The argument `bootstrap_border` is deprecated.

* Major changes
  * `uci()` is faster and uses much less memory, especially with `dist_type = "spatial_link"` and the bootstrap. Results are unchanged.
  * `parallel` now sets the number of threads for shortest-path distances (`dist_type = "spatial_link"` only). The default, `FALSE`, uses one thread; previously all cores were used.

* Minor changes
  * New function `remove_islands()` and argument `uci(remove_islands = TRUE)` keep only the largest group of contiguous polygons, so `"spatial_link"` works in areas with islands.
  * `uci()` now warns when `dist_type = "euclidean"` and the study area is markedly concave or has a large gap inside it (e.g. a bay or a lake), suggesting `"spatial_link"` (#11).
  * New sample data set `grid_rio.rds`, a hexagonal grid of Rio de Janeiro with a concave outline and islands.
  * Informative {cli} errors for invalid inputs: fewer than two polygons, negative, infinite or non-numeric values, all values 0 or `NA`, empty or non-polygon geometries, and non-contiguous polygons with `"spatial_link"`.
  * Progress messages with {cli}, shown only in interactive sessions.
  * {cli} and {rlang} are new dependencies; {furrr}, {future} and {pbapply} are no longer used.

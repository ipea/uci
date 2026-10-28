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

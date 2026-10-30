# Changelog

## uci v1.0.0

- Breaking changes
  - **UCI values change.** New argument `max_method` sets how the
    maximum spatial separation (`spatial_separation_max`) is found. The
    new default, `"exact"`, searches for the true maximum, which is
    guaranteed for Euclidean distances between centroids (see
    [`?uci`](https://ipea.github.io/uci/reference/uci.md)). The previous
    approaches underestimated it by an amount that depends on the shape
    of the area; they remain available as `"heuristic"` (old default)
    and `"bootstrap"`, and reproduce earlier results. The argument
    `bootstrap_border` is deprecated.
- Major changes
  - [`uci()`](https://ipea.github.io/uci/reference/uci.md) is faster and
    uses much less memory, especially with `dist_type = "spatial_link"`
    and the bootstrap. Results are unchanged.
  - `parallel` now sets the number of threads for shortest-path
    distances (`dist_type = "spatial_link"` only). The default, `FALSE`,
    uses one thread; previously all cores were used.
- Minor changes
  - New function
    [`remove_islands()`](https://ipea.github.io/uci/reference/remove_islands.md)
    and argument `uci(remove_islands = TRUE)` keep only the largest
    group of contiguous polygons, so `"spatial_link"` works in areas
    with islands.
  - [`uci()`](https://ipea.github.io/uci/reference/uci.md) now warns
    when `dist_type = "euclidean"` and the study area is markedly
    concave or has a large gap inside it (e.g. a bay or a lake),
    suggesting `"spatial_link"`
    ([\#11](https://github.com/ipea/uci/issues/11)).
  - New sample data set `grid_rio.rds`, a hexagonal grid of Rio de
    Janeiro with a concave outline and islands.
  - Informative {cli} errors for invalid inputs: fewer than two
    polygons, negative, infinite or non-numeric values, all values 0 or
    `NA`, empty or non-polygon geometries, and non-contiguous polygons
    with `"spatial_link"`.
  - Progress messages with {cli}, shown only in interactive sessions.
  - {cli} and {rlang} are new dependencies; {furrr}, {future} and
    {pbapply} are no longer used.

## uci 0.3.1

CRAN release: 2025-11-07

- Bug fix
  - Avoid errors when detecting the number of available cores for
    parallel processing.

## uci 0.3.0

CRAN release: 2023-09-23

- Major changes
  - [`uci()`](https://ipea.github.io/uci/reference/uci.md) now accepts
    columns with `NA` values. In such cases, `NA`s are replaced with
    zero as they represent zero activities.
  - improved documentation
  - The package now uses Queen contiguity
    (`spdep::poly2nb(geo, queen=TRUE)`) to determine neighboring
    polygons whe considering spatial link distances.
  - Update vignette

## uci 0.2.0

CRAN release: 2023-06-14

- Major changes

  - The `uci` function now has a new parameter `dist_type` that allows
    users to choose whether calculations should be based on
    `"euclidean"` distances (Default) or `"spatial_link"` distances.
    Spatial link distances consider Euclidean distances along the links
    of spatial neighbour links. In the case of areas with a concave
    shape (like a bay), it is strongly recommended to use
    `"spatial_link"` distances (even though they are computationally
    more costly) because simple Euclidean distances can bias UCI
    estimates in those cases.
  - The `uci` function now has a new parameter `parallel` that speeds up
    calculations for large areas comprised with many polygons.

- Minor changes

  - Minor updates to documentation
  - Performance improvments

## uci 0.1.0

CRAN release: 2023-06-11

- Initial CRAN release.

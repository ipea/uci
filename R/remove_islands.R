#' Remove islands
#'
#' Keeps only the largest group of neighbouring polygons (queen contiguity),
#' i.e. the one with the most polygons, and drops the polygons outside it.
#' This is useful before calling [uci()] with `dist_type = "spatial_link"`,
#' which requires the polygons to form one contiguous area.
#'
#' @details If several groups tie for the most polygons, the group with the
#'   earliest row is kept. Objects with fewer than 2 rows are returned as they
#'   are. Contiguity is computed in the CRS of `sf_object`, which is not
#'   changed. `uci(remove_islands = TRUE)` applies this function after
#'   reprojecting to EPSG:3857, so for exactly the same result on
#'   geographic (lon/lat) data, reproject `sf_object` first.
#'
#' @param sf_object A `POLYGON sf data.frame`.
#' @param var_name An optional `string`. The name of a numeric column in
#'        `sf_object`. If given, the message also reports how many
#'        activities were dropped (`NA` values are considered to be equal to
#'        `0`). Only used for the message. Defaults to `NULL`.
#' @param showProgress A `logical`. If `TRUE` (Default), a message reports how
#'        many polygons were removed.
#'
#' @return `sf_object` with only the polygons of the largest contiguous group
#'         (same CRS, columns, row order and row names).
#'
#' @family urban centrality index
#'
#' @examples
#' # load data
#' data_dir <- system.file("extdata", package = "uci")
#' # sf::st_as_sf() loads {sf}, whose methods subset and bind sf objects
#' grid <- sf::st_as_sf(readRDS(file.path(data_dir, "grid_bho.rds")))
#'
#' # add an island: a copy of the first cell, shifted away from the grid
#' island <- grid[1, ]
#' sf::st_geometry(island) <- sf::st_geometry(island) + c(0.5, 0)
#' sf::st_crs(island) <- sf::st_crs(grid)
#' grid_island <- rbind(grid, island)
#' nrow(grid_island)
#'
#' # remove the island
#' grid_main <- remove_islands(grid_island, var_name = 'jobs')
#' nrow(grid_main)
#' @export
remove_islands <- function(sf_object, var_name = NULL, showProgress = TRUE){

  # check inputs
  abort_if_invalid(checkmate::check_class(sf_object, 'sf'), "sf_object")
  abort_if_invalid(
    checkmate::check_string(var_name, null.ok = TRUE),
    "var_name"
  )
  if (!is.null(var_name)) {
    abort_if_invalid(
      checkmate::check_names(names(sf_object), must.include = var_name),
      "sf_object"
    )
    abort_if_invalid(
      checkmate::check_numeric(sf_object[[var_name]]),
      paste0("sf_object$", var_name)
    )
  }
  abort_if_invalid(
    checkmate::check_logical(showProgress, len = 1, any.missing = FALSE),
    "showProgress"
  )

  # spdep::poly2nb() fails on a single polygon, which has no islands anyway
  if (nrow(sf_object) < 2) return(sf_object)

  # keep only the largest group of neighbouring polygons (if tied, the group
  # of the earliest row: n.comp.nb numbers groups in row order)
  nb <- suppressWarnings(
    spdep::poly2nb(sf::st_geometry(sf_object), queen = TRUE)
  )
  comp <- spdep::n.comp.nb(nb)$comp.id
  keep <- comp == which.max(table(comp))
  if (all(keep)) return(sf_object)

  if (isTRUE(showProgress)) {
    if (is.null(var_name)) {
      cli::cli_inform(
        "Removed {sum(!keep)} polygon{?s} outside the largest contiguous area
         of {.arg sf_object}."
      )
    } else {
      n_dropped <- prettyNum(
        sum(sf_object[[var_name]][!keep], na.rm = TRUE), big.mark = ","
      )
      cli::cli_inform(
        "Removed {sum(!keep)} polygon{?s} ({n_dropped} {.field {var_name}})
         outside the largest contiguous area of {.arg sf_object}."
      )
    }
  }

  return(sf_object[keep, ])
}

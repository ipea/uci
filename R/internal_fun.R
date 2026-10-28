#' @keywords internal
assert_var_name <- function(sf_object, var_name) {

  checkmate::assert_data_frame(sf_object)
  checkmate::assert_class(sf_object, 'sf')
  checkmate::assert_names(
    names(sf_object),
    must.include = var_name,
    .var.name = "sf_object"
  )

  return(invisible(TRUE))
}


# Location Coefficient (LC)
#' @keywords internal
location_coef <- function(x){
  cl <-(sum(abs(x-(1/length(x)))))/2
  return(cl)
}

# Venables, Spatial Separation index, b' D b
# D is built in blocks of rows, so the n x n distance matrix is never held in
# memory at once. dist_fun(rows) returns the distances between `rows` and all
# cells, without the self-distance (diagonal), which the caller adds
#' @keywords internal
venables_blockwise <- function(b, dist_fun, block_rows = NULL) {

  n <- length(b)
  if (is.null(block_rows)) block_rows <- max(1, floor(1e7 / n)) # ~80 MB
  blocks <- split(seq_len(n), ceiling(seq_len(n) / block_rows))

  v <- 0
  for (rows in blocks) {
    v <- v + sum(b[rows] * (dist_fun(rows) %*% b))
  }
  return(v)
}


# self distance >> REF Crafts & Mulatu (2006)
# IMPORTANT: the area must be in the same unit as the distance matrix
#' @keywords internal
get_self_distance <- function(sf_object) {
  self <- as.numeric((sf::st_area(sf_object) / pi)^(1 / 2))
  return(self)
}


# coordinates of polygon centroids
#' @keywords internal
get_centroid_coords <- function(sf_object) {
  coords <- suppressWarnings(sf::st_coordinates(sf::st_centroid(sf_object)))
  return(coords)
}


# calculate Euclidean distance matrix
#' @keywords internal
get_euclidean_dist_matrix <- function(sf_object){

  distance <- fields::rdist(get_centroid_coords(sf_object))

  # add self distance to the diagonal
  diag(distance) <- diag(distance) + get_self_distance(sf_object)
  return(distance)
}

# build graph of spatial links between neighbouring polygons. Node ids are the
# row positions of the polygons in sf_object
#' @keywords internal
get_spatial_link_graph <- function(sf_object) {
  
  # get distance between neighbors
  geo <- sf::st_geometry(sf_object)
  # plot(geo)
  
  ## using sfdep
    # nb <- sfdep::st_contiguity(geo)
    # suppressMessages( dists <- sfdep::st_nb_dists(geo, nb) )
  ## using spdep
    nb <- spdep::poly2nb(geo, queen=TRUE)

    # isolated polygons or separate clusters have no path between them
    if (spdep::n.comp.nb(nb)$nc > 1) {
      stop(
        "Polygons in 'sf_object' must form one contiguous area when ",
        "dist_type = 'spatial_link'. Use dist_type = 'euclidean' instead.",
        call. = FALSE
      )
    }

    point_surface <-  sf::st_point_on_surface(geo)
    suppressWarnings( dists <- spdep::nbdists(nb, point_surface, longlat = FALSE) )
    
  # links between neighbors in long format, built from the sparse nb list
  # (no n x n intermediate)
  od_df <- data.frame(
    from = rep(seq_along(nb), lengths(nb)),
    to = unlist(nb),
    dist = unlist(dists)
  )
  od_df <- od_df[od_df$dist > 0, ]

  # create graph
  graph  <-  cppRouting::makegraph(od_df, directed = FALSE)
  return(graph)
  }

# normalize distribution of variable
#' @keywords internal
normalize_distribution <- function(vec) {
  var_x <- matrix(vec, length(vec), 1)
  var_x_norm <- var_x / sum(var_x) # normalization
  return(var_x_norm)
}


# raise a failed checkmate check as a cli error, attributed to the caller.
# arg and res are passed as values, so braces in them are not interpolated
#' @keywords internal
abort_if_invalid <- function(res, arg, call = parent.frame()) {
  if (!isTRUE(res)) {
    cli::cli_abort("{.arg {arg}}: {res}", call = call)
  }
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
# cells, without the self-distance (diagonal), which the caller adds.
# progress = TRUE draws a cli bar over the blocks (shown after 2 s)
#' @keywords internal
venables_blockwise <- function(b, dist_fun, block_rows = NULL,
                               progress = FALSE) {

  n <- length(b)
  if (is.null(block_rows)) block_rows <- max(1, floor(1e7 / n)) # ~80 MB
  blocks <- split(seq_len(n), ceiling(seq_len(n) / block_rows))

  # cli only draws the bar if the loop takes longer than 2 s
  idx <- if (progress) cli::cli_progress_along(blocks) else seq_along(blocks)
  v <- 0
  for (i in idx) {
    v <- v + sum(b[blocks[[i]]] * (dist_fun(blocks[[i]]) %*% b))
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


# TRUE if the study area is markedly concave (e.g. a bay) or has a large gap
# inside it (e.g. a lake, ~10% of the area or more): its largest part covers
# less than 90% of its convex hull. A closing by about one cell
# diameter first removes the jagged edges and small gaps of a grid (so inlets
# narrower than ~2 cells are ignored by design); islands are ignored. Convex
# but narrow regions (< ~5 cells wide) running diagonally to a hexagonal grid
# keep a staircase edge and may still be flagged.
# sf_object: the grid (cell areas give the closing distance).
# area_union: sf::st_union(sf_object), the outline of the study area; passed
# in because uci() also uses it to find the border cells, so it is computed
# once. Lon/lat input is projected to EPSG:3857 (as in uci()), since a
# negative buffer on lon/lat data is read in degrees and empties the outline
#' @keywords internal
is_concave <- function(sf_object, area_union) {
  if (isTRUE(sf::st_is_longlat(area_union))) {
    sf_object <- sf::st_transform(sf_object, 3857)
    area_union <- sf::st_transform(area_union, 3857)
  }
  d <- 2 * sqrt(stats::median(as.numeric(sf::st_area(sf_object))) / pi)
  closed <- sf::st_buffer(sf::st_buffer(area_union, d), -d)
  parts <- sf::st_cast(closed, "POLYGON")
  main <- parts[which.max(sf::st_area(parts))]
  solidity <- as.numeric(sf::st_area(main) /
                           sf::st_area(sf::st_convex_hull(main)))
  return(isTRUE(solidity < 0.9))
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
# row positions of the polygons in sf_object. nb is the queen neighbour list of
# those rows (from remove_islands_nb()), or NULL to compute it here
#' @keywords internal
get_spatial_link_graph <- function(sf_object, nb = NULL) {
  
  # get distance between neighbors
  geo <- sf::st_geometry(sf_object)
  # plot(geo)
  
  ## using sfdep
    # nb <- sfdep::st_contiguity(geo)
    # suppressMessages( dists <- sfdep::st_nb_dists(geo, nb) )
  ## using spdep
    # spdep's warnings (no neighbours, sub-graphs) are reported by the
    # contiguity error below
    if (is.null(nb)) {
      nb <- suppressWarnings(spdep::poly2nb(geo, queen = TRUE))
    }

    # isolated polygons or separate clusters have no path between them
    nc <- spdep::n.comp.nb(nb)$nc
    if (nc > 1) {
      cli::cli_abort(
        c(
          "Polygons in {.arg sf_object} must form one contiguous area when
           {.arg dist_type} is {.val spatial_link}.",
          "i" = "Found {nc} separate groups of polygons.",
          "i" = "Small gaps between polygons that should touch can cause this.",
          "i" = "Use {.arg dist_type} = {.val euclidean} instead, or
                 {.arg remove_islands} = {.val {TRUE}} to keep only the
                 largest group."
        ),
        call = NULL
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

# maximum of b'Db over the simplex (b >= 0, sum(b) = 1) by replicator
# dynamics b <- b * (Db) / (b'Db): b'Db never decreases (Baum & Eagon 1967)
# and the limit satisfies the KKT conditions, gap = max(Db) - b'Db = 0. For
# a Euclidean D with zero diagonal the objective is concave on the simplex
# (Schoenberg 1938: Euclidean distance matrices are conditionally negative
# definite), so the KKT point is the global maximum and the true maximum is
# at most v + 2 * gap
#' @keywords internal
venables_max <- function(D, b = rep(1 / nrow(D), nrow(D))) {
  tol <- 1e-6      # relative gap: V_max within 2e-6 of the KKT value
  max_iter <- 1e5L
  prune <- 1e-12   # cells with b < prune * max(b) leave the iteration
  n <- nrow(D)
  active <- seq_len(n)
  D_a <- D
  Db <- as.vector(D_a %*% b)
  v <- sum(b * Db)
  for (i in seq_len(max_iter)) {
    if (v == 0 || max(Db) - v <= tol * v) break
    b <- b * Db / v
    # cells that have decayed to nothing are dropped; the certificate below
    # is computed on all cells, so a wrong drop shows up as non-convergence
    small <- b < prune * max(b)
    if (any(small)) {
      active <- active[!small]
      b <- b[!small] / sum(b[!small])
      D_a <- D_a[!small, !small, drop = FALSE]
    }
    Db <- as.vector(D_a %*% b)
    v <- sum(b * Db)
  }
  # certificate on all cells
  weights <- numeric(n)
  weights[active] <- b
  Db <- as.vector(D %*% weights)
  v <- sum(weights * Db)
  gap <- max(Db) - v
  return(list(v_max = v, weights = weights, gap = gap,
              converged = gap <= tol * v, iterations = i))
}

# exact maximum spatial separation. cand are the candidate cells (the
# border), n the number of cells, dist_pairs(from, to) the zero-diagonal
# distance matrix between two sets of cells and self the self distance of
# every cell. The search runs on the zero-diagonal matrix (concave for
# Euclidean distances), is polished on the matrix with the self distance
# (the functional of the observed V), and the result is checked against the
# cells outside cand: any cell that would raise b'Db is added and the search
# repeated once. Activities on one or two cells are covered in closed form,
# as the search can miss them on coarse grids
#' @keywords internal
max_venables_exact <- function(cand, n, dist_pairs, self) {
  tol <- 1e-6
  for (pass in 1:2) {
    D0 <- dist_pairs(cand, cand)
    sol0 <- venables_max(D0)
    sol <- venables_max(D0 + diag(self[cand], nrow = length(cand)),
                        b = sol0$weights)
    sol$converged <- sol$converged && sol0$converged
    other <- setdiff(seq_len(n), cand)
    violators <- integer(0)
    if (length(other) > 0) {
      busy <- sol$weights > 1e-12
      Db_other <- dist_pairs(other, cand[busy]) %*% sol$weights[busy]
      violators <- other[as.vector(Db_other) > sol$v_max * (1 + tol)]
    }
    # cand, D0 and sol must describe the same set after the loop
    if (length(violators) == 0 || pass == 2) break
    cand <- c(cand, violators)
  }
  if (length(violators) > 0) {
    cli::cli_warn(
      "{length(violators)} polygon{?s} outside the border would raise the
       maximum spatial separation; {.field spatial_separation_max} may be
       underestimated."
    )
  }
  if (!sol$converged) {
    cli::cli_warn(
      "The search for the maximum spatial separation did not converge;
       {.field spatial_separation_max} may be underestimated."
    )
  }

  # all activity in one cell, or split between two cells with the weight a
  # that maximises 2a(1-a)d + a^2 s_i + (1-a)^2 s_j
  best <- max(self)
  if (length(cand) >= 2) {
    s_i <- matrix(self[cand], length(cand), length(cand))
    s_j <- t(s_i)
    denom <- 2 * D0 - s_i - s_j
    # any a in [0, 1] is feasible, so the test only avoids 0 / 0
    a <- ifelse(denom != 0, (D0 - s_j) / denom, 0.5)
    a <- pmin(pmax(a, 0), 1)
    # when 2d < s_i + s_j the pair maximum is an endpoint, covered by best
    f <- 2 * a * (1 - a) * D0 + a^2 * s_i + (1 - a)^2 * s_j
    best <- max(best, f[upper.tri(f)])
  }
  return(list(v_max = max(sol$v_max, best), search = sol$v_max,
              small_support = best, gap = sol$gap, converged = sol$converged,
              iterations = sol$iterations, rounds = pass,
              violators = length(violators)))
}

# normalize distribution of variable
#' @keywords internal
normalize_distribution <- function(vec) {
  var_x <- matrix(vec, length(vec), 1)
  var_x_norm <- var_x / sum(var_x) # normalization
  return(var_x_norm)
}


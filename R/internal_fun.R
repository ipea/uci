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

# Venables, Spatial Separation index
#' @keywords internal
venables <- function(b, distance){
  
  # IF (Error in t(b) %*% distance : non-conformable arguments)
  # there are probalby islands of polygons in the input sf_object
  # dist_type spatial link
  # uci does 
  v <- t(b) %*% distance %*% b
  return(v[1])
}


# calculate Euclidean distance matrix
#' @keywords internal
get_euclidean_dist_matrix <- function(sf_object){
  
  coords <- suppressWarnings(sf::st_coordinates( sf::st_centroid(sf_object) ))
  distance <- fields::rdist(coords)
  # plot(coords)
  
  # self distance >> REF Crafts & Mulatu (2006)
  # IMPORTANT: the area must be in the same unit as the distance matrix####
  n_reg <- nrow(distance)
  poly_areas <- sf::st_area(sf_object)
  self <- diag((poly_areas/pi)^(1/2), nrow=n_reg, ncol=n_reg)
  distance <- distance+self ## Sum distance matrix and self-distance
  return(distance)
}

# calculate spatial link distance matrix
#' @keywords internal
get_spatial_link_dist_matrix <- function(sf_object){
  
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
    
  # fun to convert nb dist to a data.frame in long format
  nb_list_to_df <- function(nb, dists) {
    
    ## sfdep
    # mtrx <- sfdep::wt_as_matrix(nb, dists)
    ## spdep
    listw <- spdep::nb2listw(nb, dists, style = "B") # zero policy FALSE ?
    mtrx <- spdep::listw2mat(listw)
    
    matrix_length <- 1:length(mtrx[1,])
    
    # FULL MATRIX
    mtrx_long <- cbind(
      data.table::as.data.table(
        data.table::CJ(matrix_length, matrix_length)), # df two columns
      'dist' = as.vector(mtrx)  # matrix values in a vector
    )
    
    # keep only dist between neighbors
    data.table::setnames(mtrx_long, c('from', 'to', 'dist'))
    mtrx_long <- subset(mtrx_long, from != to)
    mtrx_long <- subset(mtrx_long, dist > 0)
    
    return(mtrx_long)
  }
  
  # convert nb dist to a data.frame in long format
  od_df <- nb_list_to_df(nb, dists)
  
  # create graph
  graph  <-  cppRouting::makegraph(od_df, directed = FALSE)
  
  # distances
  dist_link <- cppRouting::get_distance_matrix(Graph=graph, 
                                               from = unique(od_df$from), 
                                               to = unique(od_df$from), 
                                               algorithm = 'mch')
  
  # self distance >> REF Crafts & Mulatu (2006)
  # IMPORTANT: the area must be in the same unit as the distance matrix####
  n_reg <- nrow(dist_link)
  poly_areas <- sf::st_area(sf_object)
  self <- diag((poly_areas/pi)^(1/2), nrow=n_reg, ncol=n_reg)
  dist_link <- dist_link+self ## Sum distance matrix and self-distance
  return(dist_link)
  }

# normalize distribution of variable
#' @keywords internal
normalize_distribution <- function(vec) {
  var_x <- matrix(vec, length(vec), 1)
  var_x_norm <- var_x / sum(var_x) # normalization
  return(var_x_norm)
}


# sample positions
#' @keywords internal
sample_positions <- function(nbc, candidate_positions){ # nbc = 50
  
  postions <- sample(x = candidate_positions,
                     size = nbc, 
                     replace = TRUE)
  return(postions)
}




# simulate random spatial configurations / distributions along border
#' @keywords internal
simulate_border_config <- function(sf_object, nbc, output='vector', bootstrap_border=bootstrap_border){ # nbc = 100
  
  # find positions of cells in the border 
  candidate_positions <- which(sf_object$border == 1, arr.ind=TRUE)
  
  # sample spatial distribution of busy cells
  if( isFALSE(bootstrap_border) ) { positions <- candidate_positions; nbc <- length(candidate_positions) }
  if( isTRUE(bootstrap_border) ) { positions <- sample_positions(nbc = nbc, candidate_positions = candidate_positions) }
  
  if (output == 'spatial') { # nocov start
    # number of jobs per cell
    jobs_per_cell <- 1 / nbc
    
    # allocate jobs
    sf_object$jobs_sim <- 0
    sf_object[positions, ]$jobs_sim <- jobs_per_cell
    # plot(sf_object['jobs_sim'])
    sf_object$nbc <- nbc
    
    return(sf_object)
  } # nocov end
  
  if (output == 'vector') {
    # with all activities equally concentraded in 'positions'
    b <- rep(0, nrow(sf_object))
    b[c(positions)] <- 1
    b[b == 1] <- 1 / length(b[b == 1])
    return(b)
  }
  
}

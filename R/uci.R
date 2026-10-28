#' Urban Centrality Index
#'
#' Calculates the Urban Centrality Index (UCI) as in Pereira et al., (2013) \doi{10.1111/gean.12002}. 
#' The UCI measures the extent to which the spatial organization of a city or 
#' region varies from extreme monocentric to extreme polycentric in a continuous 
#' scale from 0 to 1. Values close to 0 indicate more polycentric patterns and 
#' values close to 1 indicate a more monocentric urban form.
#' 
#' @param sf_object A `POLYGON sf data.frame` of the study area.
#' @param var_name A `string`. The name of the column in `sf_object` with the 
#'        number of activities/opportunities/resources/services to be considered 
#'        when calculating urban centrality levels. `NA` values are considered 
#'        to be equal to `0`.
#' @param dist_type A `string` indicating whether calculations should be based 
#'        on `"euclidean"` distances (Default) or `"spatial_link"` distances. 
#'        Spatial link distances consider Euclidean distances along the links of 
#'        spatial neighbor links. In the case of areas with a concave shape 
#'        (like a bay), it is strongly recommended to use `"spatial_link"` 
#'        distances (even though they are computationally more costly) because 
#'        simple Euclidean distances can bias UCI estimates in those cases.
#' @param bootstrap_border A `logical`. The calculation of UCI requires one to 
#'        find the maximum value of the Venables spatial separation index of the 
#'        study area. If `bootstrap_border = FALSE` (Default), the function uses 
#'        a heuristic approach that assumes that the max spatial separation 
#'        would occur when all activities were equally distributed along the 
#'        border of the study  area. This is a fast approach, but it does not 
#'        reach the maximum spatial separation. Alternatively, if `bootstrap_border = TRUE`, 
#'        the function uses a bootstrap approach that simulates 20000 random 
#'        distributions of activities along the border and uses the max spatial 
#'        separation found. This approach is more computationally expensive and
#'        although it might not return the maximum theoretical value of spatial
#'        separation, it is probably very close to it.
#' @param showProgress A `logical`. Indicates whether to show a progress bar for 
#'        the bootstrap simulation. Defaults to `TRUE`.
#' @param parallel Decides whether the function should run in parallel. Defaults 
#'        is `FALSE.` When `TRUE`, it will use all cores available in 
#'        `future::plan()` with strategy `"multisession"` internally. Note that 
#'        it is possible to create your own plan before calling uci(). In this 
#'        case, do not use this argument.
#' 
#' @family urban centrality index
#'
#' @examples
#' # load data
#' data_dir <- system.file("extdata", package = "uci")
#' grid <- readRDS(file.path(data_dir, "grid_bho.rds"))
#'
#' # calculate UCI
#' df <- uci(
#'         sf_object = grid,
#'         var_name = 'jobs',
#'         dist_type = "euclidean",
#'         bootstrap_border = FALSE
#'         )
#' head(df)
#' 
#' # calculate UCI with bootstrap
#' df2 <- uci(
#'         sf_object = grid,
#'         var_name = 'jobs',
#'         dist_type = "euclidean",
#'         bootstrap_border = TRUE,
#'         showProgress = TRUE
#'         )
#' head(df2)
#' @export
uci <- function(sf_object, 
                var_name, 
                dist_type = "euclidean", 
                bootstrap_border = FALSE,
                showProgress = TRUE,
                parallel = FALSE){
  
  # check inputs
  checkmate::assert_class(sf_object, 'sf')
  checkmate::assert_string(var_name)
  checkmate::assert_logical(bootstrap_border, len = 1, any.missing = FALSE)
  checkmate::assert_logical(showProgress, len = 1, any.missing = FALSE)
  checkmate::assert_logical(parallel, len = 1, any.missing = FALSE)
  assert_var_name(sf_object, var_name)
  
  checkmate::assert_string(dist_type)
  if(isFALSE(dist_type %in% c('spatial_link', 'euclidean'))){
    stop("dist_type must be either 'spatial_link' or 'euclidean'")
    }
  
  # config progress bar
  pb_original <- pbapply::pboptions()
  if (isTRUE(showProgress)) {
    pbapply::pboptions(char = "-")
    on.exit(pbapply::pboptions(pb_original))
  } else {
    pbapply::pboptions(type = "none")
    on.exit(pbapply::pboptions(pb_original))
  }
  
  # config parallel computing
  if (parallel) {

    cores <- future::availableCores(constraints = "connections-16")
    message(paste('Using', cores, 'CPU cores'))

    with(
      future::plan(future::multisession), 
      local = TRUE
      )
    
    }
  
  
  # change projection to UTM
  sf_object <- suppressWarnings(sf::st_transform(sf_object, 3857))

  ###### observed Location Coefficient -----------------------------------------
  
  # replace NAs with 0
  var <- sf_object[var_name][[1]]
  var <- data.table::fifelse(is.na(var), 0, var)
  # var <- var[var > 0]
  
  # normalize distribution of variable
  var_x_norm <- normalize_distribution(var)
  
  # location coefficient
  LC <- location_coef(var_x_norm)
  
  
  
  ###### observed Venables -----------------------------------------------------
  
  if (dist_type == 'euclidean') {
    
    # keep non-empty cells
    sf_object_observed <- sf_object[ var > 0, var_name]
    # plot(sf_object_observed['job_count'])
    
    summary(sf_object$jobs)
    summary(sf_object_observed$jobs)
    
    # normalize distribution of variable
    var_x_norm <- normalize_distribution( var[var > 0] )
    
    # calculate distance matrix
    distance <- get_euclidean_dist_matrix(sf_object_observed)
    
  } else if (dist_type == 'spatial_link') {
    # plot(sf_object['jobs'])
    
    # normalize distribution of variable
    var_x_norm <- normalize_distribution( var )
    
    # calculate distance matrix
    distance <- get_spatial_link_dist_matrix(sf_object)
  }

  # Spatial separation index (venables)
  v_observed <- venables(var_x_norm, distance)
  
  
  ###### Find MAX venables spatial separation ----------------------------------
  
  # get perimeter of whole area
  boundary <- sf::st_boundary( sf::st_union(sf_object) )
  
  # Determine which polygons are on the border
  int <- sf::st_intersects(sf_object, boundary)
  border <- sapply(1:length(int),function(i){length(int[[i]])})
  sf_object$border <- border
  # plot(sf_object['border'])
  
  # keep only cells on the border
  sf_border <- subset(sf_object, border == 1)
  # plot(sf_border['border'])
  
  # Distance matrix between border cells
  if (dist_type == 'euclidean') {
    
    # calculate distance matrix
    distance_border <- get_euclidean_dist_matrix(sf_border)
  
    } else if (dist_type == 'spatial_link') {
    
      # find positions of cells in the border 
      border_positions <- which(sf_object$border == 1, arr.ind=TRUE)
      
      # filter dist matrix keeping only border cells
      distance_border <- distance[border_positions, border_positions]
    }
      
  
  ### HEURISTIC max venables considering full border
  if (isFALSE(bootstrap_border)) {
    
    b_bootstrap_border <- simulate_border_config(
      sf_object = sf_border,
      nbc = 1, # nbc does not matter here, only when bootstrap_border = TRUE
      output = 'vector',
      bootstrap_border = bootstrap_border
    )
    max_venables <- venables(b = b_bootstrap_border, distance = distance_border)
  }
  
  ### bootstrap simulations to find max venables
  if (isTRUE(bootstrap_border)) {
    
    # input for number of simulations
    max_value <- max(51, nrow(nrow(sf_border)))
    number_busy_cells <- 2:max_value
    all_sim_input <- rep(number_busy_cells, 400)
    

    #### calculate venables of all simulations and get the max value
    
    ## run spatial simulations
    all_sim <- lapply(
      X = all_sim_input,
      FUN = simulate_border_config,
      sf_object = sf_border,
      output = 'vector',
      bootstrap_border = bootstrap_border)
    
      
    ## calculate venables for all simulations
    
    # run sequentially
    if (isFALSE(parallel)) {
      all_sim_venables <- pbapply::pblapply(X = all_sim,
                                            FUN = venables,
                                            distance = distance_border)
    }
    # parallel
    if (isTRUE(parallel)) {
      all_sim_venables <- furrr::future_map(
        .x = all_sim,
        .f = venables,
        distance = distance_border,
        .progress = showProgress
      )
    }
    
    # get the max value of venables spatial separation from all simulations
    all_sim_venables <- unlist(all_sim_venables)
    max_venables <- max(all_sim_venables)
  }
  
  
  
  
  ###### Calculate UCI ---------------------------------------------------------
  
  # Proximity Index PI
  proximity_idex <- 1-(v_observed/max_venables)
  
  # UCI
  UCI <- LC * proximity_idex
  
  output_df <- data.frame(
    UCI = UCI,
    location_coef = LC,
    spatial_separation = v_observed,
    spatial_separation_max = max_venables
  )
  
  return(output_df)
}
  
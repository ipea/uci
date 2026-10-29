#' Urban Centrality Index
#'
#' Calculates the Urban Centrality Index (UCI) as in Pereira et al., (2013) \doi{10.1111/gean.12002}. 
#' The UCI measures the extent to which the spatial organization of a city or 
#' region varies from extreme monocentric to extreme polycentric in a continuous 
#' scale from 0 to 1. Values close to 0 indicate more polycentric patterns and 
#' values close to 1 indicate a more monocentric urban form.
#' 
#' @param sf_object A `POLYGON sf data.frame` of the study area. Distances and
#'        areas are computed in EPSG:3857 (Web Mercator), which distorts very
#'        large regions.
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
#' @param showProgress A `logical`. If `TRUE` (Default) and the session is
#'        interactive, `uci()` reports the progress of each step, with a
#'        progress bar for the spatial separation on large grids. It also
#'        controls the message on how many polygons were removed by
#'        `remove_islands`.
#' @param parallel A `logical`. Only used when `dist_type = "spatial_link"`.
#'        If `FALSE` (Default), shortest-path distances are computed on a
#'        single thread (any thread setting made with
#'        `RcppParallel::setThreadOptions()` is restored on exit). If `TRUE`,
#'        they are computed in parallel using the
#'        number of threads set by \{RcppParallel\} (all available cores by
#'        default, see `RcppParallel::setThreadOptions()`).
#' @param remove_islands A `logical`. If `TRUE`, only the largest group of
#'        neighbouring polygons (queen contiguity), i.e. the one with the most
#'        polygons, is kept, and polygons
#'        outside it, along with their activities, are dropped before any
#'        calculation. This applies to both `dist_type`s, and it lets
#'        `"spatial_link"` distances be used in areas with islands. Defaults
#'        to `FALSE`. See [remove_islands()].
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
                parallel = FALSE,
                remove_islands = FALSE){

  # check inputs
  abort_if_invalid(checkmate::check_class(sf_object, 'sf'), "sf_object")
  abort_if_invalid(checkmate::check_string(var_name), "var_name")
  abort_if_invalid(
    checkmate::check_logical(bootstrap_border, len = 1, any.missing = FALSE),
    "bootstrap_border"
  )
  abort_if_invalid(
    checkmate::check_logical(showProgress, len = 1, any.missing = FALSE),
    "showProgress"
  )
  abort_if_invalid(
    checkmate::check_logical(parallel, len = 1, any.missing = FALSE),
    "parallel"
  )
  abort_if_invalid(
    checkmate::check_logical(remove_islands, len = 1, any.missing = FALSE),
    "remove_islands"
  )
  abort_if_invalid(
    checkmate::check_names(names(sf_object), must.include = var_name),
    "sf_object"
  )
  abort_if_invalid(
    checkmate::check_numeric(sf_object[[var_name]], lower = 0, finite = TRUE),
    paste0("sf_object$", var_name)
  )
  abort_if_invalid(
    checkmate::check_choice(dist_type, c('spatial_link', 'euclidean')),
    "dist_type"
  )

  # progress steps and bar only in interactive sessions (not knitr/testthat)
  show_steps <- showProgress && rlang::is_interactive()
  
  # config parallel computing: shortest paths (cppRouting) run on
  # RcppParallel, which reads RCPP_PARALLEL_NUM_THREADS on every call
  if (dist_type == 'spatial_link' && isFALSE(parallel)) {
    threads_original <- Sys.getenv("RCPP_PARALLEL_NUM_THREADS", NA)
    # cli closes the open progress step via its own exit handler: keep
    # add = TRUE in every on.exit() of uci()
    on.exit(
      if (is.na(threads_original)) {
        Sys.unsetenv("RCPP_PARALLEL_NUM_THREADS")
      } else {
        Sys.setenv(RCPP_PARALLEL_NUM_THREADS = threads_original)
      },
      add = TRUE
    )
    Sys.setenv(RCPP_PARALLEL_NUM_THREADS = 1)
  }

  
  # change projection to Web Mercator (EPSG:3857)
  sf_object <- suppressWarnings(sf::st_transform(sf_object, 3857))

  # keep only the largest group of neighbouring polygons
  islands_removed <- FALSE
  if (isTRUE(remove_islands)) {
    n_before <- nrow(sf_object)
    # R skips non-function bindings in calls: this is remove_islands()
    sf_object <- remove_islands(sf_object, var_name = var_name,
                                showProgress = showProgress)
    islands_removed <- nrow(sf_object) < n_before
  }

  ###### observed Location Coefficient -----------------------------------------
  
  # replace NAs with 0
  # as.numeric() so that an all-NA logical column reaches the error below
  var <- as.numeric(sf_object[[var_name]])
  var <- data.table::fifelse(is.na(var), 0, var)
  if (sum(var) == 0) {
    cli::cli_abort(
      c(
        "All values of {.field {var_name}} in {.arg sf_object} are 0 or NA.",
        if (islands_removed) c(
          "i" = "Polygons outside the largest contiguous area were removed
                 by {.arg remove_islands}."
        )
      )
    )
  }
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

    # normalize distribution of variable
    var_x_norm <- normalize_distribution( var[var > 0] )

    # distances between centroids
    coords <- get_centroid_coords(sf_object_observed)
    self <- get_self_distance(sf_object_observed)
    dist_fun <- function(rows) {
      fields::rdist(coords[rows, , drop = FALSE], coords)
    }

  } else if (dist_type == 'spatial_link') {
    # plot(sf_object['jobs'])

    # normalize distribution of variable
    var_x_norm <- normalize_distribution( var )

    # shortest-path distances along spatial links, between non-empty cells
    if (show_steps) {
      cli::cli_progress_step("Building spatial links between polygons")
    }
    graph <- get_spatial_link_graph(sf_object)
    keep <- which(var_x_norm > 0)
    var_x_norm <- var_x_norm[keep]
    self <- get_self_distance(sf_object)[keep]
    dist_fun <- function(rows) {
      cppRouting::get_distance_matrix(Graph = graph,
                                      from = keep[rows],
                                      to = keep,
                                      algorithm = 'mch')
    }
  }

  # Spatial separation index (venables), plus the self distance
  if (show_steps) cli::cli_progress_step("Computing spatial separation")
  v_observed <- venables_blockwise(var_x_norm, dist_fun,
                                   progress = show_steps) +
    sum(var_x_norm^2 * self)
  
  
  ###### Find MAX venables spatial separation ----------------------------------
  
  if (show_steps) cli::cli_progress_step("Computing maximum spatial separation")

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

      # shortest-path distances between border cells, plus self distance
      distance_border <- cppRouting::get_distance_matrix(
        Graph = graph,
        from = border_positions,
        to = border_positions,
        algorithm = 'mch'
      )
      diag(distance_border) <- diag(distance_border) +
        get_self_distance(sf_border)
    }


  ### HEURISTIC max venables considering full border
  # with activities equally spread along the border, b'Db is the mean distance
  if (isFALSE(bootstrap_border)) {
    max_venables <- mean(distance_border)
  }
  
  ### bootstrap simulations to find max venables
  if (isTRUE(bootstrap_border)) {
    
    # input for number of simulations
    # 2 to 51 sampled border cells (with replacement), 400 draws each (20,000
    # simulations, as documented). On grid_bho the max spatial separation
    # peaks near 51 cells, so larger counts add run time without raising it
    number_busy_cells <- 2:51
    all_sim_input <- rep(number_busy_cells, 400)
    

    #### calculate venables of all simulations and get the max value

    # each simulation spreads activities equally among k randomly sampled
    # border cells, so b'Db is the mean distance among the (unique) busy cells
    n_border <- nrow(distance_border)
    if (show_steps) {
      n_sim <- prettyNum(length(all_sim_input), big.mark = ",")
      cli::cli_progress_step("Simulating {n_sim} border configurations")
    }
    all_sim_venables <- vapply(
      X = all_sim_input,
      FUN = function(k) {
        busy <- unique(sample.int(n_border, size = k, replace = TRUE))
        mean(distance_border[busy, busy])
      },
      FUN.VALUE = numeric(1)
    )

    # get the max value of venables spatial separation from all simulations
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
  
#' https://github.com/rafapereirabr/urban_centrality_index_2013/blob/master/uci_function_sf.R


library(sf)
library(fields)
library(accessibility)
library(data.table)
library(ggplot2)
library(furrr)
set.seed(42)

# read grid and land use data
grid <- system.file("extdata/grid_bho.rds", package = "accessibility")
grid <- readRDS(grid)

landuse <- system.file("extdata/land_use_data.rds", package = "accessibility")
landuse <- readRDS(landuse)

grid <- merge(grid, landuse, by = 'id')



uci2 <- function(sf_object, var_name, full_border=FALSE, parallel = FALSE){
  
  # sf_object = grid
  # var_name = 'jobs'
  # full_border = FALSE
  
  # change projection to UTM
  sf_object <- suppressWarnings(sf::st_transform(sf_object, 3857))
  
###### Support functions -----------------------------------------------------
  
  # calculate distance matrix
  get_distance_matrix <- function(sf_object){
    
    coords <- suppressWarnings(st_coordinates( st_centroid(sf_object) ))
    distance <- fields::rdist(coords)
    # plot(coords)
    
    # self distance >> REF Crafts & Mulatu (2006)
    # IMPORTANT: the area must be in the same unit as the distance matrix####
    n_reg <- nrow(distance)
    poly_areas <- st_area(sf_object)
    self <- diag((poly_areas/pi)^(1/2), nrow=n_reg, ncol=n_reg)
    distance <- distance+self ## Sum distance matrix and self-distance
    return(distance)
  }
  
  # Venables, Spatial Separation index
  venables <- function(b, distance){
    v <- t(b) %*% distance %*% b
    return(v[1])
  }
  
  # Location Coefficient (LC)
  location_coef <- function(x){
    cl <-(sum(abs(x-(1/length(x)))))/2
    return(cl)
  }
  
  # sample positions
  sample_positions <- function(nbc, candidate_positions){ # nbc = 50
    
    postions <- sample(x = candidate_positions,
                       size = nbc, 
                       replace = FALSE)
    return(postions)
  }
  
  # simulate random spatial configurations / distributions
  simulate_border_config <- function(sf_object, nbc, output='vector', full_border=full_border){ # nbc = 100
    
    # find positions of cells in the border 
    candidate_positions <- which(sf_object$border == 1, arr.ind=TRUE)
    
    # sample spatial distribution of busy cells
    if( isTRUE(full_border) ) { positions <- candidate_positions; nbc <- length(candidate_positions) }
    if( isFALSE(full_border) ) { positions <- sample_positions(nbc = nbc, candidate_positions = candidate_positions) }
    
    if (output == 'spatial') {
      # number of jobs per cell
      jobs_per_cell <- 1 / nbc
      
      # allocate jobs
      sf_object$jobs_sim <- 0
      sf_object[positions, ]$jobs_sim <- jobs_per_cell
      # plot(sf_object['jobs_sim'])
      sf_object$nbc <- nbc
      
      return(sf_object)
    }
    
    if (output == 'vector') {
      # with all activities equally concentraded in 'positions'
      b <- rep(0, nrow(sf_object))
      b[c(positions)] <- 1
      b[b == 1] <- 1 / length(b[b == 1])
      return(b)
      }
    
  }
  
  ### normalize distribution of variable
  normalize_distribution <- function(vec) {
    var_x <- matrix(vec, length(vec), 1)
    var_x_norm <- var_x / sum(var_x) # normalization
    return(var_x_norm)
  }
  
###### observed Location Coefficient -----------------------------------------------------
 
  # normalize distribution of variable
  var_x_norm <- normalize_distribution(sf_object[var_name][[1]])
  
  # location coefficient
  LC <- location_coef(var_x_norm)


  
###### observed Venables -----------------------------------------------------
  
  # observed values
  sf_object_observed <- sf_object[sf_object[var_name][[1]] >0, var_name]
  # plot(sf_object_observed['jobs'])
  
  # normalize distribution of variable
  var_x_norm <- normalize_distribution(sf_object_observed[var_name][[1]])
  
  # calculate distance matrix
  distance <- get_distance_matrix(sf_object_observed)

  # Spatial separation index (venables)
  v_observed <- venables(var_x_norm, distance)
  
  rm(sf_object_observed, distance, var_x_norm)
  
  
###### Find MAX venables spatial separation ------------------------------------
  
  # get perimeter of whole area
  boundary <- st_union(sf_object) |> sf::st_boundary()
  
  # Determine which polygons are on the border
  int <- st_intersects(sf_object, boundary)
  border <- sapply(1:length(int),function(i){length(int[[i]])})
  sf_object$border <- border
  # plot(sf_object['border'])
  
  # keep only cells on the border
  sf_border <- subset(sf_object, border ==1)
  # plot(sf_border['border'])
  
  # calculate distance matrix
  distance_border <- get_distance_matrix(sf_border)
  
  ### HEURISTIC max venables considering full border
  if(isTRUE(full_border)) {
    
    b_full_border <- simulate_border_config(
      sf_object = sf_border,
      nbc = 1, # nbc does not matter
      output = 'vector',
      full_border = full_border
    )
    max_venables <- venables(b = b_full_border, distance = distance_border)
  }
  
  ### BOOSTRAP simulations to find max venables
  if (isFALSE(full_border)) {
    
    # input for number of simulations
    number_busy_cells <- 2:51
    all_sim_input <- rep(number_busy_cells, 400)
    
    # linear
    if (isFALSE(parallel)) {
      
      # if progress == FALSE, pboptions(type = "none")
      set.seed(42)
      all_sim <- pbapply::pblapply(
        X = all_sim_input,
        FUN = simulate_border_config,
        sf_object = sf_border,
        output = 'vector',
        full_border = full_border
      )
    }
    
    # parallel
    if (isTRUE(parallel)) {

      with(future::plan(future::multisession), local = TRUE)
      
      oopts <- options()
      options(future.globals.maxSize = 1.0 * 1e9)  ## 1.0 GB
      on.exit(options(oopts))
      
      
      all_sim <- furrr::future_map(
        .x = all_sim_input,
        .f = simulate_border_config,
        sf_object = sf_border,
        output = 'vector',
        full_border = full_border,
        .progress = TRUE,
        .options = furrr_options(seed = 42)
      )
    }
    
    # calculate venables of all simulations and get the max value
    
    # linear
    if (isFALSE(parallel)) {
      all_sim_venables <- pbapply::pblapply(X = all_sim,
                                            FUN = venables,
                                            distance = distance_border)
      }
    
    # parallel
    if (isTRUE(parallel)) {
      all_sim_venables <- furrr::future_map(.x = all_sim,
                                            .f = venables,
                                            distance = distance_border,
                                            .progress = TRUE)
    }
    
    # get max venables spatial separation value from all simulations
    all_sim_venables <- unlist(all_sim_venables)
    max_venables <- max(all_sim_venables)
    }
  
  
  
  
  # 
  # ## explore
  # all_sim_LC <- pbapply::pblapply(X = all_sim, FUN = location_coef)
  # all_sim_LC <- unlist(all_sim_LC)
  # 
  # temp_df <- data.table('nbc' = all_sim_input,
  #                       'venables' = all_sim_venables,
  #                       'lc' = all_sim_LC)
  # 
  # temp_df[, v_max := max(venables), by = nbc]
  # temp_df[, proximity_idex  := 1-(venables/v_max)]
  # temp_df[, UCI := lc * proximity_idex]
  # 
  # # #6666 DOES IT MAKE a difference using boostrap or border? only in 3rd decimal case
  # # temp_df[, proximity_idex  := 1-(venables/max_venables)]
  # # temp_df[, UCI_global := lc * proximity_idex]
  # # 
  # # temp_df[, proximity_idex  := 1-(venables/venables_full_border)]
  # # temp_df[, UCI_border := lc * proximity_idex]
  # # 
  # # 
  # # temp_df[,  UCI_global - UCI_border ] |> summary()
  # # #6666
  # 
  # summary(temp_df$proximity_idex)
  # plot(density(temp_df$proximity_idex), col='red')
  # 
  # subset(temp_df, venables == max_venables)
  # subset(temp_df, UCI == max(temp_df$UCI))
  # subset(temp_df, UCI == min(temp_df$UCI))
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=nbc, y=lc), alpha=.3)
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=nbc, y=venables), alpha=.3)
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=nbc, y=proximity_idex), alpha=.3)
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=venables, y=lc), alpha=.3)
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=lc, y=proximity_idex), alpha=.3)
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=nbc, y=v_max), alpha=.3)
  # 
  #   ggplot(data=temp_df) +
  #     geom_point(aes(x=lc, y=v_max), alpha=.3)
  # 
  #   plotly::plot_ly(
  #                   x = temp_df$UCI,
  #                   y = temp_df$proximity_idex,
  #                   z = temp_df$nbc,
  #                   type = "scatter3d",
  #                   mode = "markers",
  #                   color = temp_df$UCI
  #                 )
  #   
  
  ###### Calculate UCI -----------------------------------------------------
  

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



b <- uci2(sf_object = grid, var_name = 'jobs', full_border = TRUE, parallel = F)
#         UCI location_coef spatial_separation spatial_separation_max
# 1 0.2538635     0.5278007           3880.114               7475.899


a <- uci2(sf_object = grid, var_name = 'jobs', full_border = F, parallel = F)
#         UCI location_coef spatial_separation spatial_separation_max
# 1 0.2557712     0.5278007           3880.114               7528.325


### TO DO

#' 1) how do can we retrieve from the simulations the 
#' spatial distribution that maximizes UCI or vmax ?

#' set.seed

#' progress bar


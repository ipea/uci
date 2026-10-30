
# load data
data_dir <- system.file("extdata", package = "uci")
grid <- readRDS(file.path(data_dir, "grid_bho.rds"))
grid_rio <- readRDS(file.path(data_dir, "grid_rio.rds"))

tester <- function(sf_object = grid,
                   var_name = 'jobs',
                   dist_type = 'euclidean',
                   bootstrap_border = FALSE,
                   showProgress = TRUE,
                   parallel = FALSE,
                   remove_islands = FALSE,
                   max_method = NULL) {
  uci(sf_object,
      var_name,
      dist_type,
      bootstrap_border,
      showProgress,
      parallel,
      remove_islands = remove_islands,
      max_method = max_method)
}


# Expected behavior  -----------------------
test_that("expected behavior", {

  result <- tester()
  testthat::expect_s3_class(result, "data.frame")

  result <- tester(dist_type = 'spatial_link')
  testthat::expect_s3_class(result, "data.frame")

})

test_that("expected behavior with parallel and bootstrap", {

  testthat::skip_on_cran()

  # parallel only changes the number of threads, not the result
  result <- tester(dist_type = 'spatial_link', parallel = TRUE)
  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_equal(result, tester(dist_type = 'spatial_link'))

  result <- tester(parallel = TRUE, max_method = 'bootstrap')
  testthat::expect_s3_class(result, "data.frame")

  result <- tester(max_method = 'bootstrap', showProgress = TRUE)
  testthat::expect_s3_class(result, "data.frame")

  result <- tester(max_method = 'bootstrap', showProgress = FALSE)
  testthat::expect_s3_class(result, "data.frame")

  # bootstrap_border = TRUE is deprecated but still selects the bootstrap,
  # unless max_method is given
  set.seed(42)
  testthat::expect_warning(
    result <- tester(bootstrap_border = TRUE), "deprecated"
  )
  set.seed(42)
  testthat::expect_equal(result, tester(max_method = 'bootstrap'))
  testthat::expect_equal(
    suppressWarnings(tester(bootstrap_border = TRUE, max_method = 'heuristic')),
    tester(max_method = 'heuristic')
  )

})

test_that("returns the expected values", {

  # exact maximum spatial separation (default): no convergence warning
  testthat::expect_no_warning(result <- tester())
  testthat::expect_equal(result$UCI, 0.2612104619, tolerance = 1e-5)
  testthat::expect_equal(result$spatial_separation_max, 7681.9268,
                         tolerance = 1e-5)
  testthat::expect_no_warning(result <- tester(dist_type = 'spatial_link'))
  testthat::expect_equal(result$UCI, 0.2609465432, tolerance = 1e-5)

  # heuristic of Pereira et al. (2013), values of uci <= 0.3.1
  testthat::expect_equal(tester(max_method = 'heuristic')$UCI,
                         0.2538635151, tolerance = 1e-6)
  testthat::expect_equal(
    tester(dist_type = 'spatial_link', max_method = 'heuristic')$UCI,
    0.2535891050, tolerance = 1e-6
  )

  # bootstrap values recorded with uci 0.3.1 (before the bootstrap rewrite)
  set.seed(42)
  testthat::expect_equal(tester(max_method = 'bootstrap')$UCI,
                         0.2556377105838858, tolerance = 1e-8)
  set.seed(42)
  testthat::expect_equal(
    tester(dist_type = 'spatial_link', max_method = 'bootstrap')$UCI,
    0.2555954951821428, tolerance = 1e-8
  )

})

test_that("returns the expected values on a grid with islands", {

  # Rio's coastline is concave: Euclidean distances raise a warning
  grid_rio2 <- grid_rio
  testthat::expect_warning(result <- tester(sf_object = grid_rio2), "concave")
  testthat::expect_identical(grid_rio2, grid_rio)
  testthat::expect_equal(result$UCI, 0.4201327235, tolerance = 1e-5)
  testthat::expect_equal(
    suppressWarnings(
      tester(sf_object = grid_rio, max_method = 'heuristic')
    )$UCI,
    0.3297768490, tolerance = 1e-6
  )

  # spatial_link needs one contiguous area: keep the largest component
  testthat::skip_on_cran()
  testthat::expect_message(
    result <- tester(sf_object = grid_rio, dist_type = 'spatial_link',
                     remove_islands = TRUE, max_method = 'heuristic'),
    "Removed 44 polygons"
  )
  testthat::expect_equal(result$UCI, 0.3166672492, tolerance = 1e-6)
  testthat::expect_no_warning(
    result <- suppressMessages(
      tester(sf_object = grid_rio, dist_type = 'spatial_link',
             remove_islands = TRUE)
    )
  )
  testthat::expect_equal(result$UCI, 0.4045098506, tolerance = 1e-5)

})

test_that("is_concave() ignores jagged edges of convex grids", {

  hex_grid <- function(shape, cellsize) {
    shape <- sf::st_sfc(shape, crs = 3857)
    g <- sf::st_make_grid(shape, cellsize = cellsize, square = FALSE)
    g <- g[lengths(sf::st_intersects(g, shape)) > 0]
    return(sf::st_sf(geometry = g))
  }
  check <- function(g) is_concave(g, sf::st_union(g))

  # coarse grid of a convex square and a narrow convex strip
  square <- sf::st_polygon(list(
    rbind(c(0, 0), c(1e4, 0), c(1e4, 1e4), c(0, 1e4), c(0, 0))
  ))
  strip <- sf::st_polygon(list(
    rbind(c(0, 0), c(3e4, 0), c(3e4, 2e3), c(0, 2e3), c(0, 0))
  ))
  testthat::expect_false(check(hex_grid(square, 2500)))
  testthat::expect_false(check(hex_grid(strip, 1000)))
  testthat::expect_false(check(sf::st_transform(grid, 3857)))
  testthat::expect_true(check(sf::st_transform(grid_rio, 3857)))
  # lon/lat input gives the same answer
  testthat::expect_true(check(grid_rio))
  testthat::expect_false(check(grid))

  # a lake covering ~13% of a convex square counts as a large gap
  lake <- sf::st_sfc(sf::st_buffer(sf::st_point(c(5e3, 5e3)), 2e3), crs = 3857)
  g <- hex_grid(square, 250)
  testthat::expect_true(check(g[lengths(sf::st_intersects(g, lake)) == 0, ]))

})

test_that("venables_max() finds the known maximum on a square grid", {

  # 21 x 21 points: the maximum puts 1/4 of the activity in each corner,
  # b'Db = 2 * (4 * 20 + 2 * 20 * sqrt(2)) / 16
  pts <- as.matrix(expand.grid(x = 0:20, y = 0:20))
  sol <- venables_max(fields::rdist(pts))
  testthat::expect_equal(sol$v_max, 10 + 5 * sqrt(2), tolerance = 1e-5)
  testthat::expect_true(sol$converged)
  testthat::expect_true(all(sol$weights >= 0))
  testthat::expect_equal(sum(sol$weights), 1)

})

test_that("max_venables_exact() warns when the border is not enough", {

  # a non-metric "distance" matrix on which cells outside the candidate set
  # keep raising b'Db: the warning is raised and the result is still returned
  set.seed(3)
  M <- matrix(stats::runif(64, 0, 10)^3, 8)
  D <- M + t(M)
  diag(D) <- 0
  dist_pairs <- function(from, to) D[from, to, drop = FALSE]
  testthat::expect_warning(
    result <- max_venables_exact(cand = 1:2, n = 8, dist_pairs = dist_pairs,
                                 self = rep(0.1, 8)),
    "outside the border"
  )
  testthat::expect_true(is.finite(result$v_max))
  testthat::expect_identical(result$rounds, 2L)

})

test_that("the maximising configuration gives UCI = 0", {

  # two adjacent squares of side L with the same activity: LC = 0, and the
  # maximum is 2 * (1/2)^2 * L + 2 * (1/2)^2 * L / sqrt(pi)
  L <- 1000
  cells <- sf::st_make_grid(
    sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0, xmax = 2 * L, ymax = L),
                              crs = 3857)),
    cellsize = L
  )
  two <- sf::st_sf(jobs = c(1, 1), geometry = cells)
  result <- uci(two, 'jobs', showProgress = FALSE)
  testthat::expect_equal(result$UCI, 0)
  testthat::expect_equal(result$spatial_separation_max,
                         L / 2 + L / (2 * sqrt(pi)), tolerance = 1e-6)
  testthat::expect_equal(result$spatial_separation,
                         result$spatial_separation_max, tolerance = 1e-6)

  # a 1 x 5 strip with all activity on the two end cells is the maximiser
  cells <- sf::st_make_grid(
    sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0, xmax = 5 * L, ymax = L),
                              crs = 3857)),
    cellsize = L
  )
  strip <- sf::st_sf(jobs = c(1, 0, 0, 0, 1), geometry = cells)
  for (dist_type in c('euclidean', 'spatial_link')) {
    result <- uci(strip, 'jobs', dist_type = dist_type, showProgress = FALSE)
    testthat::expect_equal(result$UCI, 0, tolerance = 1e-6)
    testthat::expect_gt(result$location_coef, 0)
  }

})

test_that("blockwise venables equals the dense b'Db", {

  set.seed(1)
  n <- 23
  coords <- matrix(stats::runif(2 * n), ncol = 2)
  distance <- fields::rdist(coords)
  b <- stats::runif(n)
  b[c(2, 5, 11)] <- 0
  b <- b / sum(b)
  dist_fun <- function(rows) distance[rows, , drop = FALSE]

  dense <- (t(b) %*% distance %*% b)[1]
  for (block_rows in c(1, 7, n)) {
    testthat::expect_equal(
      venables_blockwise(b, dist_fun, block_rows = block_rows), dense
    )
  }

  # spatial link, with blocks of rows indexing graph nodes as in uci()
  graph <- get_spatial_link_graph(sf::st_transform(grid, 3857))
  keep <- sort(sample(nrow(grid), 40))
  b <- stats::runif(40)
  b <- b / sum(b)
  distance <- cppRouting::get_distance_matrix(graph, from = keep, to = keep)
  dist_fun <- function(rows) {
    cppRouting::get_distance_matrix(graph, from = keep[rows], to = keep)
  }
  testthat::expect_equal(
    venables_blockwise(b, dist_fun, block_rows = 7),
    (t(b) %*% distance %*% b)[1],
    tolerance = 1e-12
  )

})

test_that("spatial_link caps and restores the number of threads", {

  var <- "RCPP_PARALLEL_NUM_THREADS"
  var_original <- Sys.getenv(var, NA)
  on.exit(
    if (is.na(var_original)) {
      Sys.unsetenv(var)
    } else {
      Sys.setenv(RCPP_PARALLEL_NUM_THREADS = var_original)
    },
    add = TRUE
  )
  threads_in_call <- NULL
  original_fun <- venables_blockwise
  testthat::local_mocked_bindings(
    venables_blockwise = function(...) {
      threads_in_call <<- Sys.getenv(var, NA)
      original_fun(...)
    }
  )

  # unset before the call -> 1 thread during the call, unset after
  Sys.unsetenv(var)
  tester(dist_type = 'spatial_link')
  testthat::expect_identical(threads_in_call, "1")
  testthat::expect_true(is.na(Sys.getenv(var, NA)))

  # set by the user before the call -> restored after
  Sys.setenv(RCPP_PARALLEL_NUM_THREADS = "3")
  tester(dist_type = 'spatial_link')
  testthat::expect_identical(Sys.getenv(var), "3")

})

test_that("does not change the input", {

  grid2 <- grid
  tester(sf_object = grid2)
  testthat::expect_identical(grid, grid2)

})



test_that("progress is reported only in interactive sessions", {

  # testthat runs non-interactively
  testthat::expect_no_message(tester())

  rlang::local_interactive(TRUE)
  msgs <- testthat::capture_messages(tester())
  testthat::expect_match(msgs, "Computing spatial separation", all = FALSE)
  testthat::expect_match(msgs, "maximum spatial separation", all = FALSE)
  testthat::expect_no_message(tester(showProgress = FALSE))

  # slow paths
  testthat::skip_on_cran()
  msgs <- testthat::capture_messages(
    tester(dist_type = 'spatial_link', max_method = 'bootstrap')
  )
  testthat::expect_match(msgs, "Building spatial links", all = FALSE)
  testthat::expect_match(msgs, "20,000 border configurations", all = FALSE)

})



# ERRORS and messages  -----------------------
test_that("raises errors due to incorrect input", {

  testthat::expect_error(tester(sf_object='banana'), class = "rlang_error")
  testthat::expect_error(tester(var_name = 'banana'))
  testthat::expect_error(tester(dist_type = 'banana'))
  testthat::expect_error(tester(dist_type = 123))
  testthat::expect_error(tester(dist_type = NULL), class = "rlang_error")
  testthat::expect_error(
    tester(dist_type = c('euclidean', 'spatial_link')), class = "rlang_error"
  )
  testthat::expect_error(tester(bootstrap_border = 'banana'))
  testthat::expect_error(tester(max_method = 'banana'), class = "rlang_error")
  testthat::expect_error(tester(max_method = NA), class = "rlang_error")
  testthat::expect_error(tester(showProgress = 'banana'))
  testthat::expect_error(tester(parallel = 'banana'))
  testthat::expect_error(tester(remove_islands = 'banana'))

})

test_that("raises errors due to invalid values in var_name", {

  grid_zero <- grid
  grid_zero$jobs <- 0
  testthat::expect_error(
    tester(sf_object = grid_zero), "0 or NA", class = "rlang_error"
  )

  grid_na <- grid
  grid_na$jobs <- NA
  testthat::expect_error(tester(sf_object = grid_na), "0 or NA")

  grid_neg <- grid
  grid_neg$jobs[1] <- -5
  testthat::expect_error(tester(sf_object = grid_neg), ">= 0")

  grid_chr <- grid
  grid_chr$jobs <- as.character(grid_chr$jobs)
  testthat::expect_error(tester(sf_object = grid_chr), "numeric")

})

test_that("raises error for non-contiguous polygons with spatial_link", {

  island <- grid[1, ]
  sf::st_geometry(island) <- sf::st_geometry(island) + c(0.5, 0)
  sf::st_crs(island) <- sf::st_crs(grid)
  grid_island <- rbind(grid, island)

  testthat::expect_no_warning(
    testthat::expect_error(
      tester(sf_object = grid_island, dist_type = 'spatial_link'),
      "contiguous"
    )
  )
  testthat::expect_error(
    tester(sf_object = grid_island, dist_type = 'spatial_link'),
    "2 separate groups"
  )
  testthat::expect_error(
    tester(sf_object = grid_island, dist_type = 'spatial_link'),
    "remove_islands"
  )

  # remove_islands drops the island cell, so results match the original grid
  grid_island2 <- grid_island
  testthat::expect_message(
    result <- tester(sf_object = grid_island2, dist_type = 'spatial_link',
                     remove_islands = TRUE),
    "Removed 1 polygon"
  )
  testthat::expect_identical(grid_island2, grid_island)
  testthat::expect_equal(result, tester(dist_type = 'spatial_link'))
  testthat::expect_equal(
    suppressMessages(tester(sf_object = grid_island, remove_islands = TRUE)),
    tester()
  )
  testthat::expect_no_message(
    tester(sf_object = grid_island, remove_islands = TRUE,
           showProgress = FALSE)
  )

  # all activity on the removed island: the error names remove_islands
  grid_only_island <- grid_island
  grid_only_island$jobs <- 0
  grid_only_island$jobs[nrow(grid_only_island)] <- 1
  testthat::expect_error(
    tester(sf_object = grid_only_island, remove_islands = TRUE,
           showProgress = FALSE),
    "remove_islands"
  )

  # a single polygon has no islands, and no maximum spatial separation
  testthat::expect_error(
    tester(sf_object = grid[1, ], remove_islands = TRUE),
    "at least two polygons"
  )
  testthat::expect_error(tester(sf_object = grid[1, ]), "at least two")
  testthat::expect_error(
    tester(sf_object = grid[1, ], dist_type = 'spatial_link'),
    "at least two"
  )

})

test_that("remove_islands() keeps the largest contiguous group", {

  island <- grid[1, ]
  sf::st_geometry(island) <- sf::st_geometry(island) + c(0.5, 0)
  sf::st_crs(island) <- sf::st_crs(grid)
  grid_island <- rbind(grid, island)

  # drops the island cell only, without changing the input
  grid_island2 <- grid_island
  testthat::expect_message(
    result <- remove_islands(grid_island2, var_name = 'jobs'),
    "Removed 1 polygon (180 jobs) outside the largest contiguous area",
    fixed = TRUE
  )
  testthat::expect_s3_class(result, "sf")
  testthat::expect_identical(result, grid)
  testthat::expect_identical(grid_island2, grid_island)

  # messages
  testthat::expect_message(
    remove_islands(grid_island),
    "Removed 1 polygon outside the largest contiguous area",
    fixed = TRUE
  )
  grid_na <- grid_island
  grid_na$jobs[nrow(grid_na)] <- NA
  testthat::expect_message(
    remove_islands(grid_na, var_name = 'jobs'),
    "(0 jobs)",
    fixed = TRUE
  )
  testthat::expect_no_message(
    result <- remove_islands(grid_island, showProgress = FALSE)
  )
  testthat::expect_identical(result, grid)

  # nothing to remove
  testthat::expect_no_message(result <- remove_islands(grid, 'jobs'))
  testthat::expect_identical(result, grid)
  testthat::expect_identical(remove_islands(grid[1, ]), grid[1, ])
  testthat::expect_identical(remove_islands(grid[0, ]), grid[0, ])

  # contiguity is computed in the input CRS, which is kept
  grid_island_3857 <- sf::st_transform(grid_island, 3857)
  result <- suppressMessages(remove_islands(grid_island_3857))
  testthat::expect_identical(sf::st_crs(result), sf::st_crs(3857))
  testthat::expect_identical(nrow(result), nrow(grid))

  # input errors
  testthat::expect_error(remove_islands(1), class = "rlang_error")
  testthat::expect_error(remove_islands(grid, var_name = 'banana'), "banana")
  grid_chr <- grid
  grid_chr$jobs <- as.character(grid_chr$jobs)
  testthat::expect_error(remove_islands(grid_chr, var_name = 'jobs'),
                         "numeric")
  testthat::expect_error(remove_islands(grid, showProgress = 'banana'))

})

test_that("braces in user text are not interpolated in error messages", {

  grid_brace <- grid
  names(grid_brace)[names(grid_brace) == "jobs"] <- "a{b}"
  grid_brace[["a{b}"]][1] <- -1
  testthat::expect_error(
    tester(sf_object = grid_brace, var_name = "a{b}"),
    "a{b}", fixed = TRUE, class = "rlang_error"
  )
  testthat::expect_error(tester(var_name = "{zz}"), "{zz}", fixed = TRUE)

})

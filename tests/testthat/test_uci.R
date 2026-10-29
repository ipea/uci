
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
                   remove_islands = FALSE) {
  uci(sf_object,
      var_name,
      dist_type,
      bootstrap_border,
      showProgress,
      parallel,
      remove_islands = remove_islands)
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

  result <- tester(parallel = TRUE, bootstrap_border = TRUE)
  testthat::expect_s3_class(result, "data.frame")

  result <- tester(bootstrap_border = TRUE, showProgress = TRUE)
  testthat::expect_s3_class(result, "data.frame")

  result <- tester(bootstrap_border = TRUE, showProgress = FALSE)
  testthat::expect_s3_class(result, "data.frame")

})

test_that("returns the expected values", {

  testthat::expect_equal(tester()$UCI, 0.2538635151, tolerance = 1e-6)
  testthat::expect_equal(tester(dist_type = 'spatial_link')$UCI, 0.2535891050, tolerance = 1e-6)

  # bootstrap values recorded with uci 0.3.1 (before the bootstrap rewrite)
  set.seed(42)
  testthat::expect_equal(tester(bootstrap_border = TRUE)$UCI,
                         0.2556377105838858, tolerance = 1e-8)
  set.seed(42)
  testthat::expect_equal(
    tester(dist_type = 'spatial_link', bootstrap_border = TRUE)$UCI,
    0.2555954951821428, tolerance = 1e-8
  )

})

test_that("returns the expected values on a grid with islands", {

  testthat::expect_equal(tester(sf_object = grid_rio)$UCI, 0.3297768490, tolerance = 1e-6)

  # spatial_link needs one contiguous area: keep the largest component
  testthat::skip_on_cran()
  testthat::expect_message(
    result <- tester(sf_object = grid_rio, dist_type = 'spatial_link',
                     remove_islands = TRUE),
    "Removed 44 polygons"
  )
  testthat::expect_equal(result$UCI, 0.3166672492, tolerance = 1e-6)

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
    tester(dist_type = 'spatial_link', bootstrap_border = TRUE)
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

  # a single polygon has no islands
  testthat::expect_equal(
    tester(sf_object = grid[1, ], remove_islands = TRUE),
    tester(sf_object = grid[1, ])
  )

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

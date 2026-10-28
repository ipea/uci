context("uci")

# load data
data_dir <- system.file("extdata", package = "uci")
grid <- readRDS(file.path(data_dir, "grid_bho.rds"))

tester <- function(sf_object = grid,
                   var_name = 'jobs',
                   dist_type = 'euclidean',
                   bootstrap_border = FALSE,
                   showProgress = TRUE,
                   parallel = FALSE) {
  uci(sf_object,
      var_name,
      dist_type,
      bootstrap_border,
      showProgress,
      parallel)
}


# Expected behavior  -----------------------
test_that("expected behavior", {

  result <- tester()
  testthat::expect_is(result, "data.frame")

  result <- tester(dist_type = 'spatial_link')
  testthat::expect_is(result, "data.frame")

})

test_that("expected behavior with parallel and bootstrap", {

  testthat::skip_on_cran()

  result <- tester(parallel = TRUE)
  testthat::expect_is(result, "data.frame")

  result <- tester(parallel = TRUE, bootstrap_border = TRUE)
  testthat::expect_is(result, "data.frame")

  result <- tester(bootstrap_border = TRUE, showProgress = TRUE)
  testthat::expect_is(result, "data.frame")

  result <- tester(bootstrap_border = TRUE, showProgress = FALSE)
  testthat::expect_is(result, "data.frame")

})

test_that("returns the expected values", {

  testthat::expect_equal(tester()$UCI, 0.2538635151, tolerance = 1e-6)
  testthat::expect_equal(tester(dist_type = 'spatial_link')$UCI, 0.2535891050, tolerance = 1e-6)

})

test_that("does not change the input", {

  grid2 <- grid
  tester(sf_object = grid2)
  testthat::expect_identical(grid, grid2)

})



# ERRORS and messages  -----------------------
test_that("raises errors due to incorrect input", {

  testthat::expect_error(tester(sf_object='banana'))
  testthat::expect_error(tester(var_name = 'banana'))
  testthat::expect_error(tester(dist_type = 'banana'))
  testthat::expect_error(tester(dist_type = 123))
  testthat::expect_error(tester(bootstrap_border = 'banana'))
  testthat::expect_error(tester(showProgress = 'banana'))
  testthat::expect_error(tester(parallel = 'banana'))

})

test_that("raises errors due to invalid values in var_name", {

  grid_zero <- grid
  grid_zero$jobs <- 0
  testthat::expect_error(tester(sf_object = grid_zero), "0 or NA")

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

  suppressWarnings(
    testthat::expect_error(
      tester(sf_object = grid_island, dist_type = 'spatial_link'),
      "contiguous"
    )
  )

})

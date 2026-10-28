# Build inst/extdata/grid_rio.rds
#
# Source: Access to Opportunities Project (AOP), Ipea, land use data for
# Rio de Janeiro, 2019, via {aopdata}. Original H3 resolution 9 cells are
# aggregated to resolution 8 to keep the file small.
#
# The grid is meant to be harder than grid_bho: a concave outline (Guanabara
# and Sepetiba bays) and 7 queen-contiguity components (mainland, Paqueta and
# smaller islands, including two single isolated cells). Islands are kept on
# purpose, so dist_type = "spatial_link" errors on the full grid.
#
# Run from the package root. Requires network access; aopdata, h3jsr and sf are not package dependencies.
# Built 2026-10-27 with aopdata 1.1.2, h3jsr 1.3.1, sf 1.1.2.

lu <- aopdata::read_landuse(
  city = "rio",
  year = 2019,
  geometry = FALSE,
  showProgress = FALSE
)

lu$id <- h3jsr::get_parent(lu$id_hex, res = 8)

grid_rio <- stats::aggregate(
  cbind(population = P001, jobs = T001, schools = E001) ~ id,
  data = lu,
  FUN = sum,
  na.rm = TRUE,
  na.action = stats::na.pass
)
grid_rio <- grid_rio[order(grid_rio$id), ]
grid_rio[c("population", "jobs", "schools")] <- lapply(
  grid_rio[c("population", "jobs", "schools")],
  as.integer
)
rownames(grid_rio) <- NULL

grid_rio <- sf::st_sf(
  grid_rio,
  geometry = h3jsr::cell_to_polygon(grid_rio$id),
  crs = 4326
)

saveRDS(grid_rio, "inst/extdata/grid_rio.rds", compress = "xz")

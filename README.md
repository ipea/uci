<img align="right" src="https://github.com/ipea/uci/raw/main/man/figures/uci_hex.png" alt="ipea" width="250">

# uci: Urban Centrality Index

[![CRAN
   status](https://www.r-pkg.org/badges/version/uci)](https://CRAN.R-project.org/package=uci)
   [![CRAN/METACRAN Total downloads](https://cranlogs.r-pkg.org/badges/grand-total/uci?color=orange)](https://CRAN.R-project.org/package=uci)
[![R-CMD-check](https://github.com/ipea/uci/actions/workflows/rcmdcheck.yaml/badge.svg)](https://github.com/ipea/uci/actions)
[![Codecov test
coverage](https://codecov.io/gh/ipea/uci/branch/main/graph/badge.svg)](https://app.codecov.io/gh/ipea/uci?branch=main) 
[![Lifecycle:
     experimental](https://img.shields.io/badge/lifecycle-stable-green.svg)](https://lifecycle.r-lib.org/articles/stages.html) 
[![DOI](https://img.shields.io/badge/DOI-10.1111/gean.12002-blue)](https://doi.org/10.1111/gean.12002)

**uci** is an `R` package to calculate the Urban Centrality Index (UCI) originally proposed by Pereira et al., (2013). The UCI measures the extent to which the spatial organization of a city or region varies from polycentric to monocentric in a continuous scale from 0 to 1. Values close to 0 indicate more polycentric patterns and values close to 1 indicate a more monocentric urban form. More info on [this vignette](https://ipea.github.io/uci/articles/uci.html).

* [Link to ungated PDF of the Pereira et al., (2013) paper](https://www.urbandemographics.org/publication/2013_urban_centrality_index/)

## Installation


```R
# from CRAN
install.packages('uci')

# or use the development version with latest features
utils::remove.packages('uci')
devtools::install_github("ipea/uci")
```


## Basic Usage

```R
library(uci)

# load data
data_dir <- system.file("extdata", package = "uci")
grid <- readRDS(file.path(data_dir, "grid_bho.rds"))

head(grid)
#> Simple feature collection with 6 features and 4 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -43.96438 ymin: -19.97414 xmax: -43.93284 ymax: -19.96717
#> Geodetic CRS:  WGS 84
#>                id population jobs schools                       geometry
#> 1 89a881a5a2bffff        439  180       0 POLYGON ((-43.9431 -19.9741...
#> 2 89a881a5a2fffff        266  134       0 POLYGON ((-43.94612 -19.972...
#> 3 89a881a5a67ffff       1069  143       0 POLYGON ((-43.94001 -19.972...
#> 4 89a881a5a6bffff        245   61       0 POLYGON ((-43.9339 -19.9728...
#> 5 89a881a5a6fffff        298   11       0 POLYGON ((-43.93691 -19.971...
#> 6 89a881a5b03ffff        555 1071       0 POLYGON ((-43.96136 -19.970...

# calculate UCI
df <- uci(
       sf_object = grid,
       var_name = 'jobs',
       showProgress = TRUE
       )

head(df)
#>         UCI location_coef spatial_separation spatial_separation_max
#> 1 0.2612105     0.5278007           3880.114               7681.927

```


# Citation <img align="right" src="https://github.com/ipea/uci/raw/main/man/figures/ipea_logo.png" alt="ipea" width="300">

 The R package **uci** is developed by a team at the Institute for Applied 
 Economic Research (Ipea), Brazil. If you use this package in research 
 publications, please cite it as:

* Pereira, R. H. M., Nadalin, V., Monasterio, L., & Albuquerque, P. H. (2013). **Urban centrality: a simple index**. *Geographical analysis*, 45(1), 77-89. [https://www.doi.org/10.1111/gean.12002](https://www.doi.org/10.1111/gean.12002)


BibTeX:
```
@article{pereira2013urbancentrality,
  title = {Urban {{Centrality}}: {{A Simple Index}}},
  author = {Pereira, Rafael H. M. and Nadalin, Vanessa and Monasterio, Leonardo and Albuquerque, Pedro H. M.},
  year = {2013},
  journal = {Geographical Analysis},
  volume = {45},
  number = {1},
  pages = {77--89},
  issn = {1538-4632},
  doi = {10.1111/gean.12002}
}
```

# Acknowledgement
The Hex image above illustrates Christaller’s Central Place Theory. It was adapted from an image originally created by Christaller and adapted by Becerra, 2015.

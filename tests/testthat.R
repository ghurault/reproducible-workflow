set.seed(1)

library(testthat)
library(tidyverse)
lapply(list.files(here::here("R"), pattern = ".R$", full.names = TRUE), source)

testthat::test_dir(here::here("tests", "testthat"))

# Initialisation -----------------------------------------------------------

library(tidyverse)

# Adapted from HuraultMisc package to avoid the dependencies
is_scalar_wholenumber <- function(x, tol = .Machine$double.eps^0.5) {
  (length(x) == 1)  && is.numeric(x) && (abs(x - round(x)) < tol)
}

# Fake data generation ----------------------------------------------------

#' Prepare training and testing dataframe
#'
#' @param df Full dataframe
#' @param N_train Number of training samples
#' @param prop_mis Proportion of missing values
#'
#' @return Named list containing the partition of  elements `Train` and `Test`
prepare_train_test <- function(df, N_train = round(0.1 * nrow(df)), prop_mis = 0.1) {

  stopifnot(is.data.frame(df),
            "Y" %in% colnames(df),
            is_scalar_wholenumber(N_train),
            between(N_train, 0, nrow(df)),
            is_scalar_double(prop_mis),
            between(prop_mis, 0, 1))

  N <- nrow(df)
  D <- ncol(df) - 1

  id_train <- sample(1:N, N_train, replace = FALSE)
  train <- df[id_train, ]
  test <- df[-id_train, ]

  mis <- matrix(rbinom(N_train * D, 1, prop_mis) == 1, nrow = N_train, ncol = D)
  train[, colnames(train) != "Y"][mis] <- NA

  out <- list(Train = train, Test = test)
  return(out)

}

#' Random generation of one sample from a zero-inflated poisson distribution
#'
#' @param n Number of observations
#' @param phi Parameter of the Bernoulli distribution
#' @param lambda Parameter of the Poisson distribution
#'
#' @return Numeric scalar
rzip <- function(n = 1, phi, lambda) {
  rbinom(n, 1, phi) * rpois(n, lambda)
}

#' Generate fake data
#'
#' - Data is generated from a zero-inflated Poisson regression (linear predictors are proportional, intercept fixed)
#' - Variables are correlated (e.g biomarkers) and some of them are binary (e.g sex, mutation)
#' - Parameters are horseshoe distributed
#' - Missing at random observations
#'
#' @param N Number of samples to generate
#' @param D Number of predictors
#' @param D_bin Number of binary predictors
#'
#' @return Named list with elements
#' - `Data`: contains the dataframe
#' - `Beta`: contains the true regression parameters
generate_fakedata <- function(N, D, D_bin) {

  stopifnot(is_scalar_wholenumber(N),
            N > 0,
            is_scalar_wholenumber(D),
            D > 0,
            is_scalar_wholenumber(D_bin),
            between(D_bin, 0, D))

  # Design matrix (multivariate normal)
  diag <- rep(1, D) # eigenvalues
  corr_matrix <- clusterGeneration::rcorrmatrix(D, 1) # Random matrix uniform over space of correlation matrices
  Sigma <- corr_matrix * tcrossprod(diag) # covariance matrix
  X <- MASS::mvrnorm(n = N, rep(0, D), Sigma)
  X[, 1:D_bin] <- as.numeric(X[, 1:D_bin] > 0) # Binary predictors

  # Regression parameters (horseshoe distribution)
  # Global shrinkage parameter is adjusted afterwards
  lambda <- abs(rt(D, 3)) # local shrinkage (to avoid very big coefficients, sample Student rather than Cauchy)
  beta <- rnorm(D) * lambda

  # Linear predictor
  linpred <- X %*% beta
  scl <- sd(linpred) # rescale beta
  beta <- beta / scl
  linpred <- linpred / scl

  # Outcome
  phi <- plogis(2 * linpred + 1) # plogis = inv_logit
  lambda <- exp(linpred + 1)
  Y <- vapply(seq_along(linpred), function(i) {rzip(1, phi[i], lambda[i])}, numeric(1))

  # Dataframe
  feat_names <- c(paste0("Xb", 1:D_bin),
                  paste0("Xc", 1:(ncol(X) - D_bin)))
  colnames(X) <- feat_names
  df <- bind_cols(tibble(Y = Y),
                  as_tibble(X))

  # Return
  out <- list(Data = df,
              Beta = tibble(Feature = feat_names, True = beta))
  return(out)
}

# Analysis ----------------------------------------------------------------

#' Compute RMSE and MAE
#'
#' @param y Vector of true values
#' @param y_pred Vector of predicted values
#'
#' @return Tibble with one row and two columns `MAE` and `RMSE`
compute_metrics <- function(y, y_pred) {
  tibble(MAE = mean(abs(y - y_pred)),
         RMSE = sqrt(mean((y - y_pred)^2)))
}

#' Extract glmnet coefficient
#'
#' @param fit `cv.glmnet` fit object
#'
#' @return Tibble with two columns `Feature` and `Coefficient`
get_glmnet_coef <- function(fit) {
  beta_enet <- coef(fit, s = "lambda.1se")
  beta_enet <- tibble(Feature = rownames(beta_enet),
                      Coefficient = as.numeric(beta_enet))
  return(beta_enet)
}

#' Extract gbm feature importance
#'
#' @param fit `gbm` object
#'
#' @return Tibble with two columns `Feature` and `Importance`
get_gbm_importance <- function(fit) {
  summary(fit, plotit = FALSE) %>%
    as_tibble() %>%
    rename(Feature = var, Importance = rel.inf)
}

options(tidyverse.quiet = TRUE)

library(targets)
library(tarchetypes)
library(tidyverse)
library(glmnet) %>% suppressMessages()
library(gbm) %>% suppressMessages()

source("R/functions.R")

set.seed(1)

list(
  tar_target(training_file, "data/train.csv", format = "file"),
  tar_target(beta_file, "data/beta.csv", format = "file"),
  tar_target(testing_file, "data/test.csv", format = "file"),

  tar_target(training_data, readr::read_csv(training_file, show_col_types = FALSE)),
  tar_target(beta_data, readr::read_csv(beta_file, show_col_types = FALSE)),
  tar_target(testing_data, readr::read_csv(testing_file, show_col_types = FALSE)),

  tar_target(glmnet_fit, {
    Y <- training_data[["Y"]]
    X <- as.matrix(training_data[, -1])
    # NB: features are already scaled

    X[is.na(X)] <- 0 # impute missing by 0 (mean for continuous variables, default for discrete)
    fit <- cv.glmnet(X, Y, family = "poisson", alpha = 0.5)

    return(fit)
  }),
  tar_target(glmnet_prediction, {
    predict(glmnet_fit,
            newx = testing_data %>% select(-Y) %>% as.matrix(),
            s = "lambda.1se",
            type = "response") %>%
      as.numeric()
  }),

  tar_target(gbm_fit, {
    train <- training_data
    # train[is.na(train)] <- 0 # impute missing values, optional
    fit <- gbm(Y ~ .,
               data = train,
               distribution = "poisson",
               cv.folds = 10,
               n.trees = 1e4,
               shrinkage = 0.01,
               interaction.depth = 1)
    return(fit)
  }),
  tar_target(gbm_prediction, {
    predict(gbm_fit, newdata = testing_data, type = "response")
  }),

  tar_target(performance, {
    bind_rows(
      compute_metrics(testing_data$Y, mean(training_data$Y)) %>%
        mutate(Model = "intercept-only"),
      compute_metrics(testing_data$Y, glmnet_prediction) %>%
        mutate(Model = "glmnet"),
      compute_metrics(testing_data$Y, gbm_prediction) %>%
        mutate(Model = "gbm")
    )
  }),

  tar_target(feature_importance, {
    # importance of feature in glm as absolute value of coefficients

    beta_imp <- beta_data %>%
      mutate(True = abs(True))

    glmet_imp <- get_glmnet_coef(glmnet_fit) %>%
      filter(Feature != "(Intercept)") %>%
      mutate(glmnet = abs(Coefficient)) %>%
      select(-Coefficient)

    gbm_imp <- get_gbm_importance(gbm_fit) %>%
      rename(gbm = Importance)

    imp <- left_join(beta_data, glmet_imp, by = "Feature") %>%
      left_join(gbm_imp, by = "Feature")

    return(imp)
  }),

  tar_render(exploration_report, "analysis/exploration.Rmd", output_dir = "docs"),
  tar_render(modelling_report, "analysis/modelling.Rmd", output_dir = "docs")
)

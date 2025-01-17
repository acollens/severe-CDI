schtools::log_snakemake()
library(furrr)
#library(mikropml)
devtools::load_all('../mikropml') # TODO remove after debugging finished
library(rsample)
library(tidyverse)
doFuture::registerDoFuture()
future::plan(future::multicore, workers = snakemake@threads)

wildcards <- schtools::get_wildcards_tbl()
train_indices <- readRDS(snakemake@input[['train']])
outcome_colname <- snakemake@wildcards[['outcome']]
ml_method <- snakemake@wildcards[["method"]]
seed <- as.numeric(snakemake@wildcards[["seed"]])
metric <- snakemake@wildcards[['metric']]
kfold <- as.numeric(snakemake@params[['kfold']])

data_processed <- readRDS(snakemake@input[["rds"]])$dat_transformed %>% 
  mutate(!!rlang::sym(outcome_colname) := factor(!!rlang::sym(outcome_colname), 
                                                 levels = c('yes','no'))
  )

set.seed(seed)
ml_results <- run_ml(
  dataset = data_processed,
  method = ml_method,
  outcome_colname = outcome_colname,
  find_feature_importance = FALSE,
  calculate_performance = FALSE,
  kfold = kfold,
  seed = seed,
  training_frac = train_indices,
  perf_metric_name = metric
)

trained_model <- ml_results$trained_model
yardstick_perf <- function(split) {
  test_dat <- analysis(split)
  preds <- stats::predict(trained_model,
                          newdata = test_dat,
                          type = "prob") %>%
    dplyr::mutate(actual = test_dat %>%
                    dplyr::pull(outcome_colname) %>%
                    factor(., levels = c('yes', 'no')))
  
  get_performance_tbl(
    trained_model,
    analysis(split),
    outcome_colname = outcome_colname,
    perf_metric_function = caret::multiClassSummary,
    perf_metric_name = metric,
    class_probs = TRUE,
    method = ml_method,
    seed = seed
  ) %>%
    select(cv_metric_AUC, AUC, Sensitivity, Specificity, Precision, Recall) %>%
    mutate(
      Precision = case_when(Sensitivity == 0 & Specificity == 1 ~ 1, 
                            TRUE ~ as.numeric(Precision)),
      pr_auc = yardstick::pr_auc(preds, yes,
                                 truth = actual,
                                 estimator = 'binary') %>% pull(.estimate),
      average_precision = yardstick::average_precision(preds, yes,
                                                       truth = actual,
                                                       estimator = 'binary') %>% pull(.estimate),
      average_precision_balanced = if_else(
        !is.na(average_precision),
        calc_balanced_precision(average_precision, prior),
        NA
      )
    ) %>% 
    pivot_longer(everything(), names_to = 'term', values_to = 'estimate')
}

calc_perf <- function(split) {
  get_performance_tbl(
    trained_model,
    analysis(split),
    outcome_colname = outcome_colname,
    perf_metric_function = caret::multiClassSummary,
    perf_metric_name = metric,
    class_probs = TRUE,
    method = ml_method,
    seed = seed
  ) %>% 
    select(-c(method, seed)) %>% 
    mutate(across(everything(), as.numeric)) %>% 
    pivot_longer(everything(), names_to = 'term', values_to = 'estimate')
}

test_dat <- ml_results$test_data
bootstrap_perf <- bootstraps(test_dat, times = 10000) %>% 
  mutate(perf = future_map(splits, ~ yardstick_perf(.x), seed = TRUE)) %>% 
  int_pctl(perf)

bootstrap_perf %>%
  bind_cols(wildcards) %>%
  readr::write_csv(snakemake@output[["perf"]])

get_feature_importance(ml_results$trained_model, 
                       ml_results$test_data, 
                       outcome_colname = outcome_colname, 
                       perf_metric_function = caret::multiClassSummary, 
                       perf_metric_name = metric, 
                       class_probs = TRUE, 
                       method = ml_method, 
                       seed = seed) %>%
  left_join(wildcards) %>%
  write_csv(snakemake@output[["feat"]])

test_dat %>%
  readr::write_csv(snakemake@output[['test']])

trained_model %>% saveRDS(file = snakemake@output[["model"]])

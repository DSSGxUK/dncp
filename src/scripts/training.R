library(mlr3verse)
library(stringr)
library(tidyverse)
library(yaml)

# ------------------------------------------------------------------------------
# SOURCE HELPER FUNCTIONS
# ------------------------------------------------------------------------------

source("src/functions/training_helpers.R")

# ------------------------------------------------------------------------------
# DATA IMPORT
# ------------------------------------------------------------------------------

message("Loading datasets and configs...")

conf <- yaml.load_file("conf/training_conf.yaml")

filename <- paste0(conf$data$loc, "training_set_", conf$data$last_run_date, ".rds")
dataset <- readRDS(filename)

message("Done loading datasets and configs.\n")

# ------------------------------------------------------------------------------
# TRAIN/TEST SPLIT
# ------------------------------------------------------------------------------

message("Conducting train/test split...")

id <- conf$features$id
target <- conf$features$target
predictors <- str_subset(colnames(dataset), paste(conf$features$predictors, collapse = ".*|"))

pruned_dataset <- dataset |>
  select(all_of(id), all_of(target), all_of(predictors)) |>
  # order the overall dataset by the target variable
  arrange(all_of(target)) |>
  # drop missing values (assuming they were dealt with in fe.R)
  drop_na()

# create stratified sample using Sturges' Rule
train_indices <- stratified_sample(nrow(pruned_dataset), conf$model$train_prop)

train_set <- pruned_dataset[train_indices, ]
test_set <- pruned_dataset[-train_indices, ]

rm(pruned_dataset, dataset)

message("Done conducting train/test split.\n")

# ------------------------------------------------------------------------------
# MODEL PREPARATION & HYPERPARAMETER TUNING
# ------------------------------------------------------------------------------

message("Setting up the model and tuning hyperparameters...")

task <- as_task_regr(train_set, target = target)

task$set_col_roles(predictors, roles = "feature")

# establish which type of model to fit
learner <- lrn(conf$model$type)

# set custom model parameters
parameters <- purrr::map(conf$model$parameters, \(p) {
  ifelse(is.character(p), paste0("\"", p, "\""), p)
})
parameter_list <- list()

if (!is.null(parameters)) {
  parameter_list_raw <- paste(names(parameters), parameters, sep = " = ", collapse = ", ")
  parameter_list <- eval(parse(text = (paste0("list(", parameter_list_raw, ")"))))
}

# tune hyperparameters
tuning_conf <- conf$model$hyperparameter_tuning
tuned_parameter_list <- list()

if (tuning_conf$run) {
  
  parameters_to_tune <- tuning_conf$parameters
  parameters_to_tune_names <- names(parameters_to_tune)
  
  search_space_raw <- purrr::map2(parameters_to_tune, parameters_to_tune_names, \(p, n) {
    paste0(
      n,
      " = ",
      switch(p$type, int = "p_int", dbl = "p_dbl", fct = "p_fct", lgl = "p_lgl"),
      "(lower = ",
      p$lower,
      ", upper = ",
      p$upper,
      ")"
    )
  }) |>
    paste(collapse = ", ")
  
  search_space <- eval(parse(text = (paste0("ps(", search_space_raw, ")"))))
  
  instance <- TuningInstanceSingleCrit$new(
    task = task,
    learner = learner,
    resampling = rsmp("holdout"),
    measure = msr("regr.rmse"),
    search_space = search_space,
    terminator = trm("evals", n_evals = tuning_conf$n_evals)
  )
  
  tuner <- tuning_conf$tuner
  tt <- tnr(tuner)
  
  # modifies the instance by reference
  tt$optimize(instance)
  
  # returns best configuration and best performance
  tuned_parameter_list <- instance$result_learner_param_vals[parameters_to_tune_names]
}

# tuned parameters overwrite user-set values
learner$param_set$values <- modifyList(parameter_list, tuned_parameter_list)

message("Done setting up the model and tuning hyperparameters.\n")

# ------------------------------------------------------------------------------
# MODEL TRAINING
# ------------------------------------------------------------------------------

message("Training the model...")

learner$train(task)

message("Done training the model.\n")

# ------------------------------------------------------------------------------
# MODEL PREDICTIONS
# ------------------------------------------------------------------------------

message("Generating predictions on test set...")


#save model (as .rds and artifact for now - crate to be tested)
saveRDS(learner, file =  paste0(conf$data$loc,"/model_inter.rds"))

predictions <- learner$predict_newdata(test_set)
test_set <- mutate(test_set, pred = predictions$response)

message("Done generating predictions on test set.\n")

# ------------------------------------------------------------------------------
# SAVE MODEL PREDICTIONS
# ------------------------------------------------------------------------------


#save model predictions (as .rds and artifact for now - crate to be tested)
saveRDS(predictions, file = paste0(conf$data$loc,"/modelpredictions.rds"))


# save model
saveRDS(learner, file = paste0(conf$data$loc,conf$model$name,"_",Sys.Date(),".rds"))


# ------------------------------------------------------------------------------
# LOG METRICS
# ------------------------------------------------------------------------------

message("Logging metrics...")

# print logarithmic RMSE, MAE, and R squared
metrics <- map(conf$model$metrics, \(x) get_metric(predictions, x))

# if the target is log-transformed, print non-logarithmic RMSE as well
if (str_detect(target, "_log$")) {
  obs <- test_set[[target]]
  pred <- predictions$response
  non_log_rmse <- rmse(obs, pred, undo_log = TRUE)
  non_log_median_rmse <- rmse(obs, pred, undo_log = TRUE, median = TRUE)
  pyg_to_usd <- conf$model$pyg_to_usd
  cat(paste0("Non-Log RMSE: ", round(non_log_rmse, 5), " PYG",
             " (", round(pyg_to_usd * non_log_rmse, 5), " USD) ", "\n"))
  cat(paste0("Non-Log Median RMSE: ", round(non_log_median_rmse, 5), " PYG",
             " (", round(pyg_to_usd * non_log_median_rmse, 5), " USD) ", "\n"))
}

message("Done logging metrics.\n")

message("Training iteration finished.")

# ------------------------------------------------------------------------------
# Rendering Evaluation report
# ------------------------------------------------------------------------------

if(conf$Evaluation_report$run){
  
message("Rendering Evaluation...")

today <- as.character(Sys.Date())

rmarkdown::render(
  input = "reports/Evaluation.Rmd",
  output_file = paste0("Evaluation", today, ".pdf"),
)

message("Done Rendering...")

}

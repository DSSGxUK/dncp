library(caret)
library(lubridate)
library(solitude)
library(tidyverse)
library(yaml)
library(openxlsx)
library(glue)

# load model
# load new (raw) data
# apply feature engineering
# apply model on new set

# Source helper functions
source("src/functions/fe_helpers.R")
source("src/functions/predict_helpers.R")

# ------------------------------------------------------------------------------
# LOADING DATA
# ------------------------------------------------------------------------------

message("Loading datasets and configs...")

# Loading configs
fe_conf <- yaml.load_file("conf/fe_conf.yaml")
predict_conf <- yaml.load_file("conf/predict_conf.yaml")
merge_sparse <- yaml.load_file("conf/merge_sparse.yaml")
valid_categories <- yaml.load_file("conf/valid_categories.yaml")

# Loading input data; change data$loc in predict_conf to change raw data location
joined_dataset <- fe_conf$data$input_data |>
  # extract input data names
  names() |>
  # read in each file
  purrr::map(get_dataset, conf = fe_conf) |>
  # join all files on id columns
  reduce(left_join)

# ------------------------------------------------------------------------------
# FEATURE ENGINEERING
# ------------------------------------------------------------------------------

fe_dataset <- feature_prep(joined_dataset, fe_conf, predict_conf, merge_sparse, valid_categories)
rm(joined_dataset)

# ------------------------------------------------------------------------------
# LOADING MODEL AND GETTING PREDICTIONS
# ------------------------------------------------------------------------------
message("New dataset ready for prediction – model now being loaded and predictions generated")

# load winning model and generate predictions
# the winning model can be changed by replacing model$winning_model with a new rds in predict_conf
pruned_dataset <- make_predictions(fe_dataset, predict_conf)
rm(fe_dataset)

message("Saving predictions in .rds and .xlsx files...")

# saving dataset with predictions
save_predictions(pruned_dataset, predict_conf)

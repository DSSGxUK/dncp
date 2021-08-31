library(caret)
library(lubridate)
library(solitude)
library(tidyverse)
library(yaml)

# ------------------------------------------------------------------------------
# SOURCE HELPER FUNCTIONS
# ------------------------------------------------------------------------------
source("src/functions/fe_helpers.R")

# ------------------------------------------------------------------------------
# IMPORT AND JOIN THE DATA
# ------------------------------------------------------------------------------

fe_conf <- yaml.load_file("conf/fe_conf.yaml")

joined_dataset <- fe_conf$data$input_data |>
  # extract input data names
  names() |>
  # read in each file
  purrr::map(get_dataset, conf = fe_conf) |>
  # join all files on id columns
  reduce(left_join)

# ------------------------------------------------------------------------------
# CREATE GOODS/SERVICES INDICATOR
# ------------------------------------------------------------------------------

joined_dataset <- joined_dataset |>
  # create goods/services indicator (in case it's needed for filtering)
  # all observations with producto_n5 code >= 700000 are services
  mutate(service = codigo_producto_n5 > "7") # leverage lexicographic order

# ------------------------------------------------------------------------------
# FILTER
# ------------------------------------------------------------------------------

cond <- unlist(fe_conf$fe$filter)

if (!is.null(cond)) {
  # combine conditions using logical AND
  cond_combined <- paste(cond, collapse = "&")
  joined_dataset <- filter(joined_dataset, !!rlang::parse_expr(cond_combined))
}

# ------------------------------------------------------------------------------
# ADJUST CURRENCY AND INFLATION
# ------------------------------------------------------------------------------

currency <- fe_conf$fe$currency
inflation <- fe_conf$fe$inflation

joined_dataset <- joined_dataset |>
  mutate(
    # use fecha_ejecucion_pac as the date of the prices
    year = year(fecha_ejecucion_pac),
    month = month(fecha_ejecucion_pac),
    day = day(fecha_ejecucion_pac)
  ) |>
  prices_to_guarani(exchange_file = paste0(currency$loc, currency$file)) |>
  inflation_adjust_prices(
    ipc_file = paste0(inflation$loc, inflation$file),
    base_year = inflation$base_year,
    base_month = inflation$base_month
  ) |>
  select(-c(year, month, day))

# ------------------------------------------------------------------------------
# CREATE GROUPING VARIABLES
# ------------------------------------------------------------------------------

groups <- fe_conf$features$groups

# whether to use specific groups or not
use_buyer <- groups$buyer$use
use_context <- groups$context$use

joined_dataset <- joined_dataset |>
  # buyer group
  create_buyer_groups(use_buyer) |>
  # context groups
  create_context_groups(use_context)

# ------------------------------------------------------------------------------
# SELECT TARGET AND PREDICTORS
# ------------------------------------------------------------------------------

target <- fe_conf$features$target
id <- fe_conf$features$id

group_predictors <- fe_conf$features$groups |>
  map(\(x) if (x$use) x$names else NULL) |>
  unlist(use.names = FALSE)

predictors <- c(unlist(fe_conf$features$predictors), group_predictors)

training_set <- joined_dataset |>
  select(all_of(id), all_of(target), all_of(predictors))

# ------------------------------------------------------------------------------
# LOG-TRANSFORM SKEWED VARIABLES
# ------------------------------------------------------------------------------

log_transform <- fe_conf$fe$log_transform

if (!(is.null(log_transform) | log_transform == "")) {
  training_set <- training_set |>
    mutate(across(all_of(log_transform),
                  .fns = ~if_else(.x == 0 | is.na(.x), NA_real_, log10(.x)),
                  .names = "{col}_log")) |>
    # remove missing values resulting from the log transformation
    filter(across(all_of(paste0(log_transform, "_log")), ~!is.na(.x)))
}

# ------------------------------------------------------------------------------
# REMOVE OUTLIERS
# ------------------------------------------------------------------------------

no_outliers <- fe_conf$fe$outlier_detection$remove_outliers
anomaly_score_cutoff <- fe_conf$fe$outlier_detection$anomaly_score_cutoff

training_set_no_outliers <- training_set |>
  remove_outliers(no_outliers, target, anomaly_score_cutoff)

training_set_eda <- training_set_no_outliers # Keep this dataset for eda

# ------------------------------------------------------------------------------
# MERGE SPARSE CATEGORIES
# ------------------------------------------------------------------------------

cols_to_merge <- fe_conf$fe$merge_sparse_categories$variables
threshold <- fe_conf$fe$merge_sparse_categories$threshold

if (!is.null(cols_to_merge)) {

  training_set_no_outliers <- training_set_no_outliers |>
  mutate(across(all_of(cols_to_merge), ~forcats::fct_lump_prop(factor(.x), threshold)))

}

# ------------------------------------------------------------------------------
# ONE-HOT ENCODING
# ------------------------------------------------------------------------------

cols_to_encode <- fe_conf$fe$one_hot_encode

# Storing Valid Categories

get_mode <- function(x) {
  # Get the mode of a categorical variable
  # @Parameters
  #   x: categorical variable to get the mode of
  # @return
  #   most frequent category
  cats <- unique(na.omit(x))
  cats[which.max(tabulate(match(x, cats)))] %>% as.character()
}

valid_cats <- NULL
for (col in cols_to_encode) {
  valid_cats[[col]] <- if_else(col %in% cols_to_merge, "Other",
                               get_mode(training_set_no_outliers[,col]))
  }

write_yaml(valid_cats, "conf/valid_categories.yaml")

# convert character columns to factors (see https://github.com/topepo/caret/issues/992)
training_set_factors <- training_set_no_outliers |>
  mutate(across(all_of(cols_to_encode), ~factor(.x)))

ohe_model <- paste("~ ", paste(cols_to_encode, collapse = " + ")) |>
caret::dummyVars(data = training_set_factors)

# save one-hot encoding model
ohe_file <- paste0(fe_conf$data$dest, "one_hot_encoding_", Sys.Date(), ".rds")
saveRDS(ohe_model, file = ohe_file)

encoded_cols <- ohe_model |>
  predict(newdata = training_set_factors) |>
  data.frame() |>
  janitor::clean_names()

training_set_encoded <- training_set_factors |>
  bind_cols(encoded_cols) |>
  select(-all_of(cols_to_encode))

# ------------------------------------------------------------------------------
# IMPUTE MISSING VALUES
# ------------------------------------------------------------------------------

training_set_imputed <- training_set_encoded |>
  # remove missing values from target variable
  filter(across(all_of(target), ~!is.na(.x))) |>
  mutate(
    # replace NAs with FALSE in logical variables
    across(where(is.logical), ~ifelse(is.na(.x), FALSE, .x)),
    # replace NAs with 0s in one-hot encoded variables
    across(colnames(encoded_cols), ~ifelse(is.na(.x), 0, .x)),
    # turn TRUE/FALSE variables into 1/0
    across(where(is.logical), ~as.numeric(.x)),
    # any missing values in minimum-amount variables are set to 0
    across(matches("minim"), ~ifelse(is.na(.x), 0, .x))
  )

# ------------------------------------------------------------------------------
# SAVE ENCODED DATASET
# ------------------------------------------------------------------------------

today <- as.character(Sys.Date())

final_dataset_file <- paste0(fe_conf$data$dest, "training_set_", today, ".rds")
saveRDS(training_set_imputed, file = final_dataset_file)

# ------------------------------------------------------------------------------
# RUN AUTOMATED EDA
# ------------------------------------------------------------------------------

# will be deleted after the EDA is completed
eda_dataset_file <- paste0(fe_conf$data$dest, "eda-temp.rds")
saveRDS(training_set_eda, file = eda_dataset_file) # Dataset before OHE

eda_conf <- yaml.load_file("conf/eda_conf.yaml")
eda_conf$data$loc <- fe_conf$data$dest
write_yaml(eda_conf, "conf/eda_conf.yaml")

rmarkdown::render(
  input = "reports/training_set_eda.Rmd",
  output_file = paste0("training_set_eda_", today, ".pdf"),
)

file.remove(eda_dataset_file)

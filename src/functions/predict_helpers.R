# ==============================================================================
#
# FUNCTIONS:
#   - inflation_adjuster
#   - feature_prep
#   - make_predictions
#
# ==============================================================================

source("src/functions/fe_helpers.R")

inflation_adjuster <- function(dataset, currency, inflation){
  # Adjust for inflation
  # @Parameters
  #   dataset: dataset with prices to convert
  #   currency: file containing currency exchange rates
  #   inflation: file containing inflation rates over time
  # @return
  #   dataset with converted prices
  result <- dataset |>
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
  return(result)
}

feature_prep <- function(joined_dataset, fe_conf, predict_conf, merge_sparse, valid_categories){
  # Conduct full feature engineering
  # @Parameters
  #   joined_dataset: dataset with merged raw data
  #   fe_conf: feature engineering config file
  #   predict_conf: predict.R config file
  # @return
  #   dataset with feature engineering fully applied
  message("New data being filtered")
  
  ## create goods/services indicator (in case it's needed for filtering)
  # ------------------------------------------------------------------------------
  # all observations with producto_n5 code >= 700000 are services
  joined_dataset <- joined_dataset |>
    mutate(service = codigo_producto_n5 > "7") # leverage lexicographic order
  
  ## filtering
  # ------------------------------------------------------------------------------
  cond <- unlist(fe_conf$fe$filter)
  
  if (!is.null(cond)) {
    # combine conditions using logical AND
    cond_combined <- paste(cond, collapse = "&")
    joined_dataset <- filter(joined_dataset, !!rlang::parse_expr(cond_combined))
  }
  
  message("new data being adjusted for inflation")
  
  ## adjusting for currency/inflation
  # ------------------------------------------------------------------------------
  currency <- fe_conf$fe$currency
  inflation <- fe_conf$fe$inflation
  
  joined_dataset <- inflation_adjuster(joined_dataset, currency, inflation)
  
  message("grouping variables now being created in new data")
  
  ## creating grouping variables
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
  
  ## selecting predictors
  # ------------------------------------------------------------------------------
  message("variables being selected from new data")
  
  id <- fe_conf$features$id
  
  group_predictors <- fe_conf$features$groups |>
    map(\(x) if (x$use) x$names else NULL) |>
    unlist(use.names = FALSE)
  
  predictors <- c(unlist(fe_conf$features$predictors), group_predictors, unlist(predict_conf$features$extra_vars))
  
  joined_dataset <- joined_dataset |> 
    select(all_of(id), all_of(predictors))
  
  message("new data now being log-transformed")
  
  ## log-transforming
  # ------------------------------------------------------------------------------
  log_transform <- predict_conf$features$log_transforms
  
  if (!is.null(log_transform)) {
    joined_dataset <- joined_dataset |>
      mutate(across(all_of(log_transform),
                    .fns = ~if_else(.x == 0 | is.na(.x), NA_real_, log10(.x)),
                    .names = "{col}_log")) |>
      # remove missing values resulting from the log transformation
      filter(across(all_of(paste0(log_transform, "_log")), ~!is.na(.x)))
  }
  
  message("New data's sparse categories being merged")
  
  ## merging sparse categories
  # ------------------------------------------------------------------------------
  cols_to_merge <- fe_conf$fe$merge_sparse_categories$variables

  for(col in names(cols_to_merge)){
    joined_dataset[[col]] <- replace(joined_dataset[[col]], !(joined_dataset[[col]] %in% merge_sparse[[col]]), "Other")
  }

  message("new data now being one-hot encoded")
  
  ## one-hot encoding
  # ------------------------------------------------------------------------------
  
  # load one-hot encoding model
  ohe_model <- readRDS(paste0(predict_conf$ohe_model$loc, "one_hot_encoding_", 
                              predict_conf$ohe_model$last_run_date, ".rds"))
  
  for(col in names(valid_categories)){
    joined_dataset[[col]] <- replace(joined_dataset[[col]], !(joined_dataset[[col]] %in% ohe_model$lvls[[col]]), valid_categories[[col]])
  }

  # conduct one-hot encoding
  encoded_cols <- ohe_model |>
    predict(newdata = joined_dataset) |>
    data.frame() |>
    janitor::clean_names()

  joined_dataset <- joined_dataset |>
    bind_cols(encoded_cols)
  
  message("missing values now being imputed")
  
  ## imputing missing values
  # ------------------------------------------------------------------------------
  joined_dataset <- joined_dataset |>
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
  return(joined_dataset)
}

make_predictions <- function(fe_dataset, predict_conf){
  # Load model and make predictions on new dta
  # @Parameters
  #   fe_dataset: dataset with feature engineering done
  #   predict_conf: predict.R config file
  # @return
  #   dataset with predicted log price and price
  model_loc <- paste0(predict_conf$model$loc, predict_conf$model$winning_model)
  model <-readRDS(model_loc)
  
  id <- predict_conf$features$id
  predictors <- str_subset(colnames(fe_dataset), paste(model$state$train_task$feature_names, collapse = ".*|"))
  predictors <- c(predictors, predict_conf$features$extra_vars)
  
  pruned_dataset <- fe_dataset |>
    select(all_of(id), all_of(predictors)) |>
    # drop missing values (assuming they were dealt with in fe.R)
    drop_na()
  
  predictions <- model$predict_newdata(pruned_dataset)
  
  pruned_dataset$predicted_log_unit_price <- predictions$response
  pruned_dataset$predicted_unit_price <- 10**predictions$response
  
  return(pruned_dataset)
}

save_predictions <- function(pruned_dataset, predict_conf){
  # Save predictions in dataset
  # @Parameters
  #   pruned_dataset: dataset with predictions included
  #   predict_conf: predict.R config file
  # @return
  #  nothing, but rds and xlsx files are saved
  today <- as.character(Sys.Date())
  
  final_dataset_file <- paste0(predict_conf$data$dest, "dataset_", today, "_with_predictions.rds")
  saveRDS(pruned_dataset, file = final_dataset_file)
  
  dataset_with_predictions_xlsx <- pruned_dataset |>
    select(c("item_solicitado_id", "descripcion_item_solicitado", 
             "descripcion_llamado", "descripcion_llamado_grupo", 
             "fecha_ejecucion_pac", "predicted_log_unit_price", 
             "predicted_unit_price"))
  
  final_dataset_file_xlsx <- paste0(predict_conf$data$dest, "dataset_", today, "_with_predictions.xlsx")
  openxlsx::write.xlsx(dataset_with_predictions_xlsx, file = final_dataset_file_xlsx)
}
rmse <- function(obs, pred, undo_log = FALSE, median = FALSE) {
  # Calculate root mean squared error
  # @Parameters
  #   obs: observed values
  #   pred: predicted values
  #   undo_log: whether to undo a log transformation
  # @return
  #   root mean squared error
  if (undo_log) {
    obs <- 10^obs
    pred <- 10^pred
  }
  if (median) {
    sqrt(median((obs - pred)^2, na.rm = TRUE))
  } else {
    sqrt(mean((obs - pred)^2, na.rm = TRUE))
  }
}

mae <- function(obs, pred) {
  # Calculate mean average error
  # @Parameters
  #   obs: observed values
  #   pred: predicted values
  # @return
  #   mean average error
  mean(abs(obs - pred), na.rm = TRUE)
}

get_metric <- function(predictions, metric) {
  # Get metric from an mlr3 learner model (e.g. "regr.rmse")
  # @Parameters
  #   predictions: mlr3 prediction variable 
  #   metric: the name of the desired metric
  # @return
  #   The value of the given metric and a print out of the value
  metric_value <- unname(predictions$score(msr(metric)))
  metric_name <- switch(
    metric,
    "regr.rmse" = "RMSE",
    "regr.mae" = "MAE",
    "regr.rsq" = "R Squared",
    metric
  )
  cat(paste0(metric_name, ": ", round(metric_value, 5), "\n"))
  return(metric_value)
}

stratified_sample <- function(num_rows, train_prop, seed = 20) {
  # Stratified sampling based on Sturges' Rule to determine the number of strata
  # @Parameters
  #   num_rows: number of rows in the entire dataset
  #   train_prop: proportion of rows to be used as training dataset
  #   seed: seed for the random sampling
  # @return
  indices <- 1:num_rows
  num_bins <- ceiling(log2(num_rows)) + 1
  # split indices into equally-sized bins
  #   indices for training dataset 
  set.seed(seed)
  split(indices, cut(seq_along(indices), num_bins, labels = FALSE)) |>
    # sample a fixed proportion from each individual bin
    purrr::map(\(x) sample(x, size = floor(train_prop * length(x)))) |>
    unlist()
}

# ==============================================================================
# 
# FUNCTIONS:
#   - remove_outliers
#
# ==============================================================================

# outlier removal function
remove_outliers <- function(dataset, no_outliers, target, anomaly_score_cutoff) {
  # Remove target-based outliers from the dataset (e.g., extreme prices)
  # @Parameters
  #   dataset: dataset to remove outliers from
  #   no_outliers: whether to remove outliers or not (true or false)
  #   target: the target variable based on which to identify outliers
  #   anomaly_score_cutoff: the anomaly score past which observations are considered outliers
  # @return
  #   dataset with no outliers
  
  if (!no_outliers) {
    return(dataset)
  }
  
  # detect outliers only based on the target variable
  dataset_target <- select(dataset, all_of(target))
  
  # fit the isolation forest based on all observations
  iso <- isolationForest$new(sample_size = nrow(dataset_target))
  iso$fit(dataset_target)
  
  # predict the anomaly score of each observation
  predictions <- iso$predict(dataset_target)
  
  num_outliers <- sum(predictions$anomaly_score >= anomaly_score_cutoff)
  cat("Removing", num_outliers, "outliers...")
  
  # filter out observations with anomaly scores above the user-specified cutoff
  dataset |>
    bind_cols(select(predictions, anomaly_score)) |>
    filter(anomaly_score < anomaly_score_cutoff)
}

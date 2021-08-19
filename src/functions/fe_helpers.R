# ==============================================================================
#
# FUNCTIONS:
#   - prices_to_guarani
#   - inflation_adjust_prices
#   - homogenize_datasets
#   - get_dataset
#
# ==============================================================================

source("src/functions/fe_group_buyer.R")
source("src/functions/fe_group_context.R")
source("src/functions/fe_outlier_detection.R")

# ------------------------------------------------------------------------------

prices_to_guarani <- function(dataset, exchange_file) {
  # Convert USD prices to guarani
  # @Parameters
  #   dataset: dataset with prices to convert
  #   exchange_file: Timeseries data of USD to guarani conversion rates
  # @return
  #   dataset with converted prices
  exchange_data <- exchange_file |>
    read_csv() |>
    mutate(year = year(fecha), month = month(fecha), day = day(fecha)) |>
    distinct(year, month, day, .keep_all = TRUE) |>
    select(year, month, day, venta)
  dataset |>
    left_join(exchange_data, by = c("year", "month", "day")) |>
    mutate(
      precio_unitario_item_solicitado = ifelse(
        moneda_pac == "USD",
        precio_unitario_item_solicitado * venta,
        precio_unitario_item_solicitado
      )
    ) |>
    select(-venta)
}

# ------------------------------------------------------------------------------

inflation_adjust_prices <- function(dataset, ipc_file, base_year, base_month) {
  # inflation-adjust all prices to June 2021 PYG
  # @Parameters
  #   dataset: dataset to convert
  #   ipc_file: file with ipc inflation data
  #   base_year: year to adjust all prices to 
  #   base_month: month to adjust all prices to
  # @return
  #   adjusted dataset 
  ipc_data <- read_csv(ipc_file)
  base_ipc <- ipc_data |>
    filter(year == base_year, month == base_month) |>
    pull(ipc)
  dataset |> 
    left_join(ipc_data, by = c("year", "month")) |>
    mutate(
      precio_unitario_item_solicitado =
        precio_unitario_item_solicitado * (base_ipc / ipc)
    ) |>
    select(-ipc)
}

# ------------------------------------------------------------------------------
homogenize_datasets <- function(dataset, dataset_name) {
  # homogenize the column naming scheme of all datasets before joining
  # this is used in the function get_dataset
  # @Parameters
  #   dataset: dataset to homogenize
  #   dataset_name: name of dataset to homogenize
  # @return
  #   dataset with consistent column naming
  switch(
    dataset_name,
    "unidad_contratacion" = dataset |>
      # rename column for joining with entidad
      rename(entidad_id = entidad_codigo_sicp),
    "entidad" = dataset |>
      # keep one row per SICP code, using the most recent year available
      group_by(codigo_sicp) |>
      arrange(desc(anio)) |>
      distinct(codigo_sicp, .keep_all = TRUE) |>
      # rename columns for joining with with unidad_contratacion and nivel_entidad
      select(-id) |>
      rename(id = codigo_sicp, nivel_entidad_id = nivel_entidad_codigo),
    "nivel_entidad" = dataset |>
      # keep one row per entity level code, using the most recent year available
      group_by(nivel_entidad_codigo) |>
      arrange(desc(anio)) |>
      distinct(nivel_entidad_codigo, .keep_all = TRUE) |>
      # rename column for joining with entidad
      select(-id) |>
      rename(id = nivel_entidad_codigo) |>
      # clean up the entity level name
      mutate(nombre = clean_string(nombre)),
    dataset # default: return the unaltered dataset
  )
}

# ------------------------------------------------------------------------------

get_dataset <- function(dataset_name, conf) {
  # load in raw data and prepare data for merging
  # @Parameters
  #   dataset_name: name of dataset
  #   conf: configuration file with dataset names, file locations and join order
  # @return
  #   Dataset with consistent naming, correct column types that is ready to be merged
  dataset_names <- names(conf$data$input_data)
  joining_cols <- paste0(dataset_names, "_id")
  input_dir <- conf$data$loc
  filename <- conf$data$input_data[[dataset_name]]
  paste0(input_dir, filename) |>
    # load all columns as strings and then type convert because some files have
    # columns with many missing values, which are then interpreted as logical
    read_csv(na = c("", "NULL", "*"), col_types = cols(.default = "c")) |>
    type_convert() |>
    # custom pre-processing for buyer-related datasets
    homogenize_datasets(dataset_name) |> 
    # rename all "id" columns in the form "dataset_id"
    rename_with(~paste0(dataset_name, "_id"), matches("^id$")) |>
    # rename all non-joining columns in the form "column_dataset"
    rename_with(~paste0(.x, "_", dataset_name), !any_of(joining_cols))
}

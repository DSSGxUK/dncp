# ==============================================================================
# 
# FUNCTIONS:
#   - create_context_groups 
#
# ==============================================================================

# main context grouping function
create_context_groups <- function(dataset, use_context) {
  # Manually create groupings of buyers 
  # Grouping determined by word frequency analysis
  # @Parameters
  #   dataset: dataset to get groups
  #   use_buyer: whether to create these groups or not (true or false)
  # @return
  #   dataset with new variables indicating which group the buyer of a given tender
  #   falls into
  
  if (!use_context) {
    return(dataset)
  }
  
  # manually-identified context groups
  patterns <- c(
    food                  = "alimento|alimenticio",
    vehicle               = "vehiculo",
    construction          = "construccion|edificio|obra ",
    hardware              = "ferreteria|herramienta",
    preventive_corrective = "preventivo|correctivo",
    real_estate           = "inmuebl",
    office                = "oficina|tinta|toner|papel|fotocopiadora|impreso|impresion",
    specialized_supplies  = "insumo",
    cleaning              = "limpieza",
    politics              = "electoral|justicia",
    medical               = "hospital|medicamento|medico",
    chemical              = "reactivo|laboratorio|quimico|quimica",
    insurance             = "seguro",
    specific_brand        = "marca ",
    electricity           = "electric",
    kitchen               = "cocina|comedor|gastronomic",
    computer              = "informatico|computadora",
    air_conditioning      = "aire|acondicionado",
    spare_part            = "respuesto",
    machine               = "maquinaria",
    fuel                  = "combustible|diesel"
  )
  
  digits <- c("dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez")
  stopwords <- tibble(word = c(tm::stopwords("spanish"), digits, "nº", "lote", "lotetotal"))
  useless_patterns <- "^adq|^serv|^contrat|^mant|^equip|^repara|^prod"
  
  context_keywords <- dataset |>
    # keep track of each tender description using the item_solicitado id
    select(item_solicitado_id, detalle_llamado) |>
    # clean tender description
    mutate(detalle_llamado = clean_string(detalle_llamado)) |> 
    # unnest descriptions into one-row-per-word to remove stopwords
    tidytext::unnest_tokens(output = word, input = detalle_llamado) |>
    anti_join(stopwords, by = "word") |>
    # turn plurals into singulars
    mutate(word = str_replace_all(word, pattern = "es$|s$", replacement = "")) |>
    # remove short words and strings containing "paraguay"
    filter(nchar(word) > 3, !str_detect(word, useless_patterns)) |>
    # remove duplicate words from the same description
    distinct() |>
    # regroup words into original buyer descriptions
    group_by(item_solicitado_id) |>
    summarize(detalle_llamado_clean = paste(word, collapse = " "))
  
  # add context keywords to the items table
  dataset <- dataset |>
    left_join(context_keywords)
  
  # create indicators based on each pattern
  indicator_cols <- map_dfc(patterns, function(pattern) {
    grepl(pattern, dataset$detalle_llamado_clean)
  })
  
  colnames(indicator_cols) <- paste0(names(patterns), "_context")
  
  # add indicators to items table
  cbind(dataset, indicator_cols) |>
    select(-detalle_llamado_clean)
}

# ==============================================================================
# 
# FUNCTIONS:
#   - clean_string
#   - create_buyer_groups
#
# ==============================================================================

clean_string <- function(string) {
  # Clean string to be used for text analysis
  # @Parameters
  #   string: string to be cleaned
  # @return
  #   string without numbers, accents, capitalization, and whitespace
  string |>
    # remove all characters except letters
    str_replace_all(pattern = "[^[:alpha:] ]", replacement = " ") |>
    # make lowercase
    str_to_lower(locale = "es_PY") |>
    # remove non-ASCII characters (e.g. Spanish accents)
    iconv(to = "ASCII//TRANSLIT") |>
    # remove unnecessary whitespace
    str_squish()
}

# ------------------------------------------------------------------------------

create_buyer_groups <- function(dataset, use_buyer) {
  # Manually create groupings of buyers 
  # Grouping determined by word frequency analysis
  # @Parameters
  #   dataset: dataset to get groups
  #   use_buyer: whether to create these groups or not (true or false)
  # @return
  #   dataset with new variables indicating which group the buyer of a given tender
  #   falls into
  
  if (!use_buyer) {
    return(dataset)
  }
  
  # manually-identified buyer groups
  patterns <- c(
    police      = "policia",
    hospital    = "hospital|cancer",
    science     = "ciencia",
    health      = "salud",
    law         = "justicia|judicial",
    ministry    = "ministerio",
    education   = "universidad|facultad|educacion",
    army        = "defensa|comando|armada|ejercito",
    bank        = "banco",
    tech        = "tecnologia|aeronautica",
    electricity = "ande|electricidad"
  )
  
  digits <- c("dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez")
  
  # exclude toponyms (extraneous information)
  toponyms <- dataset |>
    mutate(nombre_entidad = nombre_entidad |>
             str_to_lower(locale = "es_PY") |>
             iconv(to = "ASCII//TRANSLIT")) |>
    filter(str_detect(nombre_entidad, "municipalidad de")) |>
    mutate(nombre_entidad = str_replace_all(nombre_entidad, "municipalidad de", "")) |>
    tidytext::unnest_tokens(output = municipalidad, input = nombre_entidad) |>
    pull(municipalidad) |>
    unique()
  
  stopwords <- tibble(word = c(tm::stopwords("spanish"), digits, toponyms))
  
  buyer_keywords <- dataset |>
    # merge the name and description fields into one, and clean the resulting string
    mutate(buyer = clean_string(paste(nombre_entidad, descripcion_unidad_contratacion))) |>
    # keep track of each buyer using the item_solicitado id
    select(item_solicitado_id, buyer) |>
    # unnest buyer descriptions into one-row-per-word to remove stopwords
    tidytext::unnest_tokens(output = word, input = buyer) |>
    anti_join(stopwords, by = "word") |>
    # turn plurals into singulars
    mutate(word = str_replace_all(word, pattern = "es$|s$", replacement = "")) |>
    # remove short words and strings containing "paraguay"
    filter(nchar(word) > 2, !str_detect(word, "paraguay")) |>
    # remove duplicate words from the same description
    distinct() |>
    # regroup words into original buyer descriptions
    group_by(item_solicitado_id) |>
    summarize(buyer = paste(word, collapse = " "))
  
  # add buyer keywords to the items table
  dataset <- dataset |>
    left_join(buyer_keywords)
  
  # create indicators based on each pattern
  indicator_cols <- map_dfc(patterns, function(pattern) {
    grepl(pattern, dataset$buyer)
  })
  
  colnames(indicator_cols) <- paste0(names(patterns), "_buyer")
  
  # add indicators to items table
  cbind(dataset, indicator_cols) |>
    select(-buyer)
}

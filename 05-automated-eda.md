# Exploratory Data Analysis {#eda}

## The PDF File {#eda-pdf}

The automated exploratory data analysis file, `reports/training_set_eda.Rmd`, is written in R Markdown and is re-knit automatically every time the user runs the feature engineering script `fe.R`. The result is `reports/training_set_eda_DATE.pdf`, which includes a number of summary statistics as well as uni- and multivariate visualizations of the variables in the training set.

### Types of EDA Performed {#eda-pdf-types}

#### Summary Statistics {#eda-pdf-summary-statistics}

Summary statistics are generated for all numerical variables. They include the minimum, first quartile, mean, median, third quartile, maximum, and percentage of missing values. This can help when assessing skew and choosing proper measures of center (e.g., if the mean and median differ significantly), and the percentage of missing values can help when deciding whether to impute missing values or to simply discard them.

#### Distribution Plots {#eda-pdf-distribution-plots}

Distribution plots (namely histograms and density plots) are created for all numerical variables. These plots help detect things like skew (which suggests the need for a logarithmic transformation) or whether parmetric assumptions (e.g., normality) are satisfied. The R Markdown script automatically detects whether a variable is highly skewed (based on the third sample moment), and in such a case it will log-transform the variable before plotting it. This eases visualization, and it is easy to notice thanks to the $x$-axis label, which will include the text *"(log)"* after the variable name.

#### Boxplots {#eda-pdf-boxplots}

Boxplots are created for all numerical variables, and they once again help detect skew. Further, boxplots are useful in that they can highlight the number and of outliers (i.e., observations more than 1.5 IQRs away from either quartile), which is something that might not be immediately visible in histograms or density plots.

#### Correlation Plots {#eda-pdf-correlation-plots}

Correlation plots are generated for all numerical variables, and their purpose is two-fold. First, they can help detect non-linear relationships between predictors and the response, which might cause us to rethink using a linear model. Further, they help detect predictors that are highly correlated with each other, which can lead to multicollinearity in some models (i.e., a high variance inflation factor). This is a sign that one of the predictors should be excluded from the model.

#### Barplots {#eda-pdf-barplots}

Barplots are created for all categorical variables. For each categorical variable, they display the number of observations in each category, ordered from highest to lowest count (with an exact label on top of each bar). The very last bin always displays the count of missing values, which can suggest the need for imputation or other handling methods if the missingness count is too high relative to other categories. The barplots can also help with detecting the sparse categories that are being merged within the feature engineering script, so that one can assess the soundness of this merging step and take action accordingly.

## The Data Dictionary {#eda-data-dictionary}

The data dictionary is required for the automated EDA to run properly, and it needs to list every single variable of interest. It can be found in `conf/meta/training_set_data_dict_VERSION.xlsx`:


| number|name                                 |description |type |binary |role      |use |comment |
|------:|:------------------------------------|:-----------|:----|:------|:---------|:---|:-------|
|      1|precio_unitario_item_solicitado      |NA          |num  |N      |target    |Y   |NA      |
|      2|presentacion_item_solicitado         |NA          |cat  |N      |predictor |N   |NA      |
|      3|agricultura_familiar_item_solicitado |NA          |cat  |Y      |predictor |Y   |NA      |
|      4|produccion_nacional_item_solicitado  |NA          |cat  |Y      |predictor |Y   |NA      |
|      5|contrato_abierto_llamado_grupo       |NA          |cat  |Y      |predictor |Y   |NA      |
|      6|forma_adjudicacion_llamado           |NA          |cat  |N      |predictor |Y   |NA      |
|      7|forma_pago_llamado                   |NA          |cat  |N      |predictor |Y   |NA      |
|      8|tipo_unidad_contratacion             |NA          |cat  |N      |predictor |Y   |NA      |
|      9|institucion_unidad_contratacion      |NA          |cat  |Y      |predictor |Y   |NA      |
|     10|nombre_nivel_entidad                 |NA          |cat  |N      |predictor |Y   |NA      |
|     11|service                              |NA          |cat  |Y      |predictor |Y   |NA      |
|     12|police_buyer                         |NA          |cat  |Y      |predictor |Y   |NA      |
|     13|hospital_buyer                       |NA          |cat  |Y      |predictor |Y   |NA      |
|     14|health_buyer                         |NA          |cat  |Y      |predictor |Y   |NA      |
|     15|law_buyer                            |NA          |cat  |Y      |predictor |Y   |NA      |
|     16|ministry_buyer                       |NA          |cat  |Y      |predictor |Y   |NA      |
|     17|education_buyer                      |NA          |cat  |Y      |predictor |Y   |NA      |
|     18|army_buyer                           |NA          |cat  |Y      |predictor |Y   |NA      |
|     19|tech_buyer                           |NA          |cat  |Y      |predictor |Y   |NA      |
|     20|electricity_buyer                    |NA          |cat  |Y      |predictor |Y   |NA      |
|     21|descripcion_ingles_producto_n1       |NA          |char |N      |predictor |Y   |NA      |
|     22|cantidad_item_solicitado             |NA          |num  |Y      |predictor |Y   |NA      |
|     23|food_context                         |NA          |cat  |Y      |predictor |Y   |NA      |
|     24|vehicle_context                      |NA          |cat  |Y      |predictor |Y   |NA      |
|     25|construction_context                 |NA          |cat  |Y      |predictor |Y   |NA      |
|     26|hardware_context                     |NA          |cat  |Y      |predictor |Y   |NA      |
|     27|preventive_corrective_context        |NA          |cat  |Y      |predictor |Y   |NA      |
|     28|real_estate_context                  |NA          |cat  |Y      |predictor |Y   |NA      |
|     29|office_context                       |NA          |cat  |Y      |predictor |Y   |NA      |
|     30|specialized_supplies_context         |NA          |cat  |Y      |predictor |Y   |NA      |
|     31|cleaning_context                     |NA          |cat  |Y      |predictor |Y   |NA      |
|     32|politics_context                     |NA          |cat  |Y      |predictor |Y   |NA      |
|     33|medical_context                      |NA          |cat  |Y      |predictor |Y   |NA      |
|     34|chemical_context                     |NA          |cat  |Y      |predictor |Y   |NA      |
|     35|insurance_context                    |NA          |cat  |Y      |predictor |Y   |NA      |
|     36|specific_brand_context               |NA          |cat  |Y      |predictor |Y   |NA      |
|     37|electricity_context                  |NA          |cat  |Y      |predictor |Y   |NA      |
|     38|kitchen_context                      |NA          |cat  |Y      |predictor |Y   |NA      |
|     39|computer_context                     |NA          |cat  |Y      |predictor |Y   |NA      |
|     40|air_conditioning_context             |NA          |cat  |Y      |predictor |Y   |NA      |
|     41|spare_part_context                   |NA          |cat  |Y      |predictor |Y   |NA      |
|     42|machine_context                      |NA          |cat  |Y      |predictor |Y   |NA      |
|     43|fuel_context                         |NA          |cat  |Y      |predictor |Y   |NA      |

The key fields in the data dictionary are:

- `name` (the variable name, as generated by the feature engineering script)
- `type` (`num` for numerical, `cat` for categorical or logical, and `char` for string)
- `role` (`predictor` or `target`)
- `use` (`Y` if to include the variable in the automated EDA, `N` otherwise)

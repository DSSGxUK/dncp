# Feature Engineering {#fe}

## The Script {#fe-script}

The feature engineering script, `fe.R`, performs a multitude of tasks to clean and prepare the input data for the tender and procurement process.

### Required Files {#fe-script-required-files}

The `fe.R` script is not a self contained script and requires the input data and other scripts containing helper functions. The following is a list of necessary files and the structure they should follow. Make sure the folders are already created in the directory before running the scripts:

- `src/`
    - `scripts/`
        - `fe.R` (encompassing script to run)
    - `functions/`
        - `fe_helpers.R` (set of helper functions to perform tasks in `fe.R`)
        - `fe_group_buyer.R` (script to create buyer groups)
        - `fe_group_context.R` (script to create context groups)
        - `fe_outlier_detection.R` (script to detect outliers)
- `data/`
    - `raw/`
        - `ipc.csv` (dataset with consumer price index data)
        - `cotizacion.csv` (dataset with USD to PYG exchange rates)
        - Any other input data to be included in the training dataset
- `conf/`
    -   `fe_conf.yaml` (configuration file for `fe.R`)
    -   `eda_conf.yaml` (configuration file for automated EDA)
    -   `meta/`
        -   `training_set_data_dict_VERSION.xlsx` (data dictionary)
- `reports/`
    - `training_set_eda.Rmd` (file to perform automated EDA on the training dataset)

### Required R Packages {#fe-script-required-r-packages}

The following is a list of R packages necessary for running `fe.R` and its associated scripts and reports:

- `caret`
- `cowplot`
- `janitor`
- `lubridate`
- `moments`
- `tidytext`
- `tidyverse`
- `tm`
- `wesanderson`
- `yaml`

### Tasks Performed {#fe-script-tasks-performed}

#### Joining the Data {#fe-script-join-data}

To perform an analysis on the database, a single dataset is necessary. Thus, after loading in all desired input data, they are merged together. How to specify desired input data is explained in the [Configuration Data Loading](#fe-conf-data-load) section. To merge them together, a few steps are necessary. The two most important are to rename the individual id columns to enable merging. For example, `producto_n1` has an **id** column and `producto_n2` has an **producto_n1_id** column which are clearly related. The script will rename **id** to be **producto_n1_id** and thus easily allow for merging. The second important step is to rename all variables to include information about the original input data. As multiple datasets have the same variable names, it is necessary to make this distinction for clarity and data provenance. For example, **monto_total** is present in both `pac` and `llamado`. In the joined dataset, there are two columns, **monto_total_pac** and **monto_total_llamado.** Once this task is complete, there is a single unified dataset with all variables from the desired input data

#### Creating Goods/Services Indicator {#fe-script-goods-services}

The level 5 (`producto_n5`) product descriptions contains the variable **codigo**, representing a unique code for each product in the product catalog. The catalog contains both goods and services, with goods being the products with codes below 700000, and services above 700000. We utilized this variable to create a new variable, **service**, that indicates whether a given product is a good or a service, with the value *TRUE* if a product is a service, or *FALSE* if it is a good. This variable can be used as a predictor, or as a way to create a model that focuses on either goods or services and not both.

#### Filtering {#fe-script-filter}

The merged dataset can then be filtered down to a desired level. Unlimited conditions can be added to the configuration file using the instructions in [Configuration Filtering](#fe-conf-filter) section. Some examples of desirable filter conditions are removing open contracts, choosing data after 2015, or removing services.

#### Adjusting for Currency and Inflation {#fe-script-currency-inflation}

The prices for the contracts are not uniform throughout the data. Inflation and deflation of currency impacts direct comparability of prices for different years. Additionally, some prices are presented in US dollars instead of PYG. To enable consistency in prices, we performed two tasks. First, all USD prices are converted into PYG for their given year using the daily conversion rates in `cotizacion.csv`. Then, the PYG prices are adjusted to their true value in a desired year and month using consumer price index (CPI) data from the Central Bank of Paraguay. In brief, the CPI accounts for inflation by measuring average changes in prices over time that consumers pay for goods and services. The base year will be given a value of 100, and every other year is assigned a value below or above 100 based on these changes in prices. The script allows for a dynamic selection of a base year and base month for inflation adjustment. This means prices can be adjusted to be in March 2021 PYG or June 2015 PYG, etc. Performing this selection is described in the [Configuration Inflation](#fe-conf-currency-inflation) section.

#### Creating Grouping Variables {#fe-script-grouping}

To enhance the training dataset, two new categories of indicator variables were created using text analysis: buyer groups and context groups.

Buyer group variables are created through text analysis on the buyer names for each tender, as recorded in the `descripcion` field of `unidad_contratacion.csv`. Each buyer group variable is associated to a specific string pattern:


|            |String Pattern                                 |
|:-----------|:----------------------------------------------|
|police      |policia                                        |
|hospital    |hospital&#124;cancer                           |
|science     |ciencia                                        |
|health      |salud                                          |
|law         |justicia&#124;judicial                         |
|ministry    |ministerio                                     |
|education   |universidad&#124;facultad&#124;educacion       |
|army        |defensa&#124;comando&#124;armada&#124;ejercito |
|bank        |banco                                          |
|tech        |tecnologia&#124;aeronautica                    |
|electricity |ande&#124;electricidad                         |

The `education` buyer variable will then be true for all items in a specific tender if the name of that tender's buyer includes any of the words *"universidad"*, *"facultad"*, or *"educacion"*.

Similarly, context group variables are created through text analysis on the tender descriptions, as recorded in the `detalle` field of `llamado.csv`. Each context group variable is once agai associated to a specific string pattern:


|                      |String Pattern                                                                          |
|:---------------------|:---------------------------------------------------------------------------------------|
|food                  |alimento&#124;alimenticio                                                               |
|vehicle               |vehiculo                                                                                |
|construction          |construccion&#124;edificio&#124;obra                                                    |
|hardware              |ferreteria&#124;herramienta                                                             |
|preventive_corrective |preventivo&#124;correctivo                                                              |
|real_estate           |inmuebl                                                                                 |
|office                |oficina&#124;tinta&#124;toner&#124;papel&#124;fotocopiadora&#124;impreso&#124;impresion |
|specialized_supplies  |insumo                                                                                  |
|cleaning              |limpieza                                                                                |
|politics              |electoral&#124;justicia                                                                 |
|medical               |hospital&#124;medicamento&#124;medico                                                   |
|chemical              |reactivo&#124;laboratorio&#124;quimico&#124;quimica                                     |
|insurance             |seguro                                                                                  |
|specific_brand        |marca                                                                                   |
|electricity           |electric                                                                                |
|kitchen               |cocina&#124;comedor&#124;gastronomic                                                    |
|computer              |informatico&#124;computadora                                                            |
|air_conditioning      |aire&#124;acondicionado                                                                 |
|spare_part            |respuesto                                                                               |
|machine               |maquinaria                                                                              |
|fuel                  |combustible&#124;diesel                                                                 |

More information about the buyer grouping process and the context grouping process can be found in the [Buyer Grouping](#buyer) section and the [Context Grouping](#context) section respectively.

#### Selecting Target and Predictors {#fe-script-select}

Only the desired target variables and predictors variables are selected from the training dataset to reduce memory usage.

#### Log-Transforming Skewed Variables {#fe-script-log-transform}

There are usually two reasons to log-transform variables. The first is when the distribution of the target variable is skewed. It is ideal to have a normally distributed target variable, so a transformation is desired, which is in this case, a log base 10 transformation. For prices, a log transformation is common in analyses. The second reason is that a given predictor appears to be logarithmically related to the target variable, which can be determined from correlation plots. Then, the predictor is transformed.

#### Removing Outliers {#fe-script-remove-outliers}

Really high outliers in terms of unit price are removed, since they may skew the model and make it inaccurate for more reasonable prices. To identify these outliers, an isolation forest was used, since it is one of the most scalable anomaly detection algorithms. The isolation forest assigns an anomaly score to each observation, ranging from 0 to 1 (with 0 being less anomalous and 1 very anomalous). Outliers were defined as having an anomaly score higher than 0.6 (value that can be customized in `fe_conf.yaml`), so all observations with an anomaly score higher than 0.6 were removed.

More information about the outlier detection and removal process can be found in the [Outlier Removal](#outlier) section.

#### Merging Sparse Categories {#fe-script-merge-sparse}

To facilitate prediction, uncommon values in categorical variables are grouped together into an *Other* group. For example, say a given categorical variable has six options: A, B, C, D, E, and F. The categories have 100, 200, 300, 200, 2, and 5 observations respectively. In this case, We would alter the variable to have 5 categories: A, B, C, D, and Other, where Other is comprised of the 2 and 5 observations from E and F. The threshold for determining what proportion of samples is too sparse can be easily changed in the configuration file.

#### One-Hot Encoding Categorical Variables {#fe-script-one-hot-encode}

Many machine learning algorithms do not support categorical/text inputs. So it is necessary to convert all categorical predictors to numerical data. This is accomplished through one-hot encoding, which creates a new variable for each category. For example, say a given categorical variable called "Cat" has three options: A, B, and C. One-hot encoding will create the three columns Cat_A, Cat_B, and Cat_C. Each column has two possible values: 1 if a given observation is in the category, or 0 if it is not. So an observation in category B, will have values 0, 1, 0 for the respective new columns. The model generated in order to create these new variables is stored, and should be used to reconstruct the one-hot encoding for future test datasets to guarantee the column specifications are the same.

#### Imputing/Removing Missing Values {#fe-script-impute-missing}

In any dataset/database, there are going to be missing values for certain variables. As many machine learning algorithms do not allow missing values, these need to be removed or imputed. For the target variable, we do not want to make assumptions about values, so all rows where the target variable has a missing value are removed. For *TRUE*/*FALSE* predictor variables, missing values were imputed to be *FALSE*. For categorical variables, all missing entries in one-hot encoded columns are set to 0, indicating that the value is none of those categories. Currently, we do not have any numeric variables with missing values, so if they should be included in the future, imputation methods need to be implemented.

#### Running Automated Exploratory Data Analysis {#fe-script-eda}

The `fe.R` script saves the training dataset before one-hot encoding, and inputs it into the automated exploratory data analysis file. A more in-depth look at the output can be found in the [Exploratory Data Analysis](#eda) section.

### Outputs {#fe-script-outputs}

The following are the outputs produced by running `fe.R` and the associated scripts and reports. Make sure these folders are already created in the directory before running the scripts.

- `reports/`
    - `training_set_eda_DATE.pdf` (report generated by the automated EDA)
- `data/`
    - `output/`
        - `training_set_DATE.rds` (training dataset generated from the script)
        - `one_hot_encoding_DATE.rds` (one-hot encoding model)

## The Configuration File {#fe-conf}

The configuration file `fe_conf.yaml` contains the inputs for the tasks outlined in Feature Engineering. This file needs to be altered for any desired change of input. The following sections describe how to make those alterations. Every value must be stored in quotation marks unless it is a number or boolean (*TRUE*/*FALSE*).

### Loading in Data {#fe-conf-data-load}

To load in the correct input data, the individual files must all be in the same directory, with the path location specified under *loc:*. Importantly, when the individual files are listed under *input_data:*, they must be in order of joining. The script will merge each input data file with the one listed prior, so there must be an id column relating the two. Below is the list of input data files that we have identified as the most useful; they are in correct merging order.


```yaml
data:
    loc: "/files/data/" # loc is input path
    dest: '~/dncp/data/output/' # dest is output path
    input_data:
        # listed in order of joining
        item_solicitado: 'item_solicitado.csv'
        llamado_grupo: 'llamado_grupo.csv'
        llamado: 'llamado.csv'
        pac: 'pac.csv'
        producto_n5: 'producto_n5.csv'
        producto_n4: 'producto_n4.csv'
        producto_n3: 'producto_n3.csv'
        producto_n2: 'producto_n2.csv'
        producto_n1: 'producto_n1.csv'
        unidad_contratacion: 'unidad_contratacion.csv'
        entidad: 'entidad.csv'
        nivel_entidad: 'nivel_entidad.csv'
```

The naming of each dataset is important as well. Using `pac` as an example, the following snippet explains the nomenclature of the configuration file for loading in the data.


```yaml
pac: 'pac.csv'

# pac:      is the name of the data file which will be attached to every
#           variable name in the file, as in monto_total_pac
#
# 'pac.csv' is the filename holding the input data
```

### Features

#### Selecting Features {#fe-conf-features}

Under the *feature:* section, the desired target variable and predictor variables should be specified as a single string and list of strings respectively. The `fe.R` script will rename all variables to be of the form variable_dataset, explained in the [Joining Data](#fe-script-join-data). In the configuration file, this naming conventions should be used at all locations. Additionally, a unique id column should be specified to maintain data provenance. For this training dataset, it is most commonly the id column in item solicitado: **item_solicitado_id**.

#### Specifying Groups for New Variable Creation {#fe-conf-grouping}

Almost all of the grouping section of the configuration file should not be touched. The names have been determined through text analysis (as explained in the [Creating Grouping Variables](#fe-script-grouping) section) and do not require alterations. The parts that can be changed are the *use:* section under each group. This value indicates whether or not the given group variable should be including in the dataset or not. If set to *false*, then the given group will not be created and vice versa for if set to *true*.


```yaml
groups:
    buyer:
        use: true # this line can be changed
```

#### Filtering {#fe-conf-filter}

To add filter conditions, add logical statements (i.e., ones that can be evaluated to be *TRUE* or *FALSE*) in quotations to the *filter:* section. If no conditions are desired, this section can be left blank. Unlimited conditions can be added in the same format as the examples below.


```yaml
filter:
    # the level 2 product description is "Fuels"
    condition_1: 'descripcion_ingles_producto_n2 == "Fuels"'
    
    # the price is above 10,000 PYG
    condition_2: 'precio_unitario_item_solicitado > 10000'
    
    # the publication year is after 2015
    condition_3: 'year(fecha_publicacion_llamado) => 2015'
    
    # only goods
    condition_4: 'service == FALSE'
    
    # no open contracts
    condition_5: 'contrato_abierto_llamado_grupo == FALSE'
```

#### Adjusting for Currency and Inflation {#fe-conf-currency-inflation}

To account for inflation and exchange currencies, two datasets are required. Cotizacion, which contains the exchange rate for USD to PYG over the years, and a dataset with Consumer Price Index data. The locations of these datasets must be specified in their corresponding locations in the configuration file. Under the *inflation:* section, the desired base year and base month for prices to be adjusted to can be specified.


```yaml
currency:
    loc: '/files/data/'
    file: 'cotizacion.csv'
inflation:
    loc: '/files/data/'
    file: 'ipc.csv'
    base_year: 2021
    base_month: 6
```

#### Log-Transforming and One-Hot Encoding {#fe-conf-log-transform-ohe}

To have variables be log transformed or one-hot encoded is as simple as writing them in a list under their given categories, making sure to maintain the naming scheme of **variable_dataset**.

#### Merging Sparse Categories {#fe-conf-merge-sparse}

The configuration file contains the structure to specify which variables require condensing as well as the threshold at which condensing in done. A threshold of 0.01 indicates that any category with less than a 1\% occurrence rate is reduced into an *Other* category.

#### Removing Outliers {#fe-conf-remove-outliers}

To remove outliers from the training dataset, simply set *outliers:* to *true*. Then the code to perform the isolation forest described in the [Feature Engineering Remove Outliers](#fe-script-remove-outliers) section.

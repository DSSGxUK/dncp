# Application & Prediction {#predict}

## The Script {#predict-script}

The prediction script takes new raw data as inputs, and performs necessary feature engineering on the data consistent with the feature engineering done before model training and then uses a previously trained model to predict the unit price of each row in the data. The output consists of an Excel file with the merged new raw data that also contains these predictions.

### Required Files {#predict-script-required-files}

The `predict.R` script is not a self-contained script and requires the input of new raw data and other scripts containing helper functions. The following is a list of necessary files and the structure they should follow within the `dncp` folder:

- `src/`
    - `scripts/`
        - `predict.R` (encompassing script to run)
    - `functions/`
        - `predict_helpers.R` (set of helper functions to perform tasks in `predict.R`)
        - `fe_helpers.R` (set of helper functions to conduct feature engineering tasks in `predict.R`)
- `conf/`
    - `predict_conf.yaml` (configuration file for `predict.R`)
    - `merge_sparse.yaml` (configuration file containing categories after merging sparse categories)
    - `valid_categories.yaml` (configuration file containing values to be used to replace new categories in categorical variables)

In addition to the above files, the `predict.R` script requires new raw data that the user wishes to generate predicted unit price values for. The required datasets are listed below, and they should all be stored in the same directory; the name of this directory should be inputted into the `predict_conf.yaml` file at `data$loc` (the default directory is `data/raw/`). 

- `data`
    - `item_solicitado.csv`
    - `llamado_grupo.csv`
    - `llamado.csv`
    - `pac.csv`
    - `producto_n5.csv`
    - `producto_n4.csv`
    - `producto_n3.csv`
    - `producto_n2.csv`
    - `producto_n1.csv`
    - `unidad_contratacion.csv`
    - `entidad.csv`
    - `nivel_entidad.csv`

### Required R Packages {#predict-script-required-r-packages}

The following is a list of R packages necessary for running `predict.R` and its associated scripts and reports.

- `caret`
- `lubridate`
- `solitude`
- `tidyverse`
- `yaml`
- `openxlsx`
- `glue`

### Tasks Performed in the Script {#predict-script-tasks}

The `predict.R` script takes in an already trained model that is used to predict unit price values for the new raw data. For more information on how such models are trained, please look at [Training Documentation](#train).

### Feature Engineering on New Data {#predict-script-fe}

Once the new raw datasets are loaded and merged in `predict.R`, they are adjusted through feature engineering tasks so that they are in the correct format to apply the model on them. The feature engineering tasks will be briefly reviewed in this section, but for more specific information on the separate tasks, please look at [Feature Engineering Documentation](#fe).

A new variable is first created in the dataset that indicates whether an item is a good or a service (denoted with a `1` if the item is a service and `0` otherwise). Then, any pre-set filters in the feature engineering configuration file are applied to the dataset, filtering out specific rows as desired. 

Next, prices in the dataset are adjusted for inflation, and new grouping variables indicating the buyer of each item and the context of each item (i.e. what they are used for) are added. Then, the predictor variables, as well as extra variables providing descriptions of each item and the date of their execution in public procurement, are selected from the overall dataset.

Next, any skewed numeric variables are log-transformed as specified in the feature engineering configuration file, after which sparse categories are merged based on which categories remained after merging in the feature engineering script; these categories are saved in the `merge_sparse.yaml` configuration file. The sparse categories are determined by first identifying in the feature engineering script which categories in each categorical variable have the lowest frequencies; those categories are then saved, and they are merged in the `predict.R` script regardless of their frequencies in the new raw input data. This is required in order to stay consistent with findings from the training dataset.

A one-hot encoding model previously saved from the `fe.R` script is then loaded and applied to the new raw data; the model can be specified in the `predict_conf.yaml` configuration file ([see below](#predict-conf-model)). The one-hot encoding creates a new binary indicator variable for each category in categorical variables in the data (i.e. if one category in the categorical variable `fruit` is `apple`, then one-hot encoding would create a new binary variable `apple` that is equal to 1 if the item is in the `apple` category and 0 otherwise). New categories in categorical variables are set to the corresponding category in `valid_categories.yaml`, which is either the "Other" category or the most frequent category in the categorical variable. Lastly, any missing values are imputed by assigning `NA` or `0` to appropriate missing feature variables values.

### Making Predictions on New Data {#predict-script-make-predictions}

After the feature engineering is complete, a previously saved model is loaded to make predictions on the completely adjusted new data. The saved model is loaded from an existing `RDS` file generated from the `training.R` script; the model can be specified in the `predict_conf.yaml` configuration file ([see below](#predict-conf-model)). Then, the new data is pruned by selecting all predictors and dropping any missing values. Lastly, the predicted values for the log unit price are calculated using the model, and both the log unit price and unit price are stored in the new dataset.

#### Storing Predictions {#predict-script-store-predictions}

The resulting predictions are then stored in two ways. First, an RDS file containing the full new dataset along with two additional new columns representing the predicted log unit price and predicted unit price are created; this file is stored in the `data/output/` directory. Second, an Excel file containing the item ID, the descriptions from `item_solicitado`, `llamado_grupo`, and `llamado`, the execution date, and predicted log unit price and unit price is created and stored in the `data/output/` directory.

### Outputs {#predict-script-outputs}

The following are the outputs produced by running `predict.R`.

- `data/`
    - `output/dataset_DATE_with_predictions.rds` (RDS file containing all predictors as columns as well as the predicted values for the log unit price and unit price for each row)
    - `output/dataset_DATE_with_predictions.xlsx` (Excel file containing some relevant description and date predictors as columns as well as the predictions for the log unit price and unit price)

## The Configuration File {#predict-conf}

The configuration file `predict_conf.yaml` contains the inputs for the tasks outlined [above](#predict-script-tasks). This file needs to be altered for any desired change of input, and instructions for how those alterations can be made are listed below. The application/prediction configuration file is broken down into three stages: the Data, the Features, and the Model.

### Data {#predict-conf-data}

To load in the correct new input data, the `data$loc` value should contain the directory in which the new input data files are located. The default value is `data/raw/`; however, to use a different data directory, the data files can simply be put into a new directory, and the path of the new directory can be listed at `loc`. Similarly, the `dest` directory should contain the directory where the user desires the outputs from `predict.R` to be stored. The `dest` directory can also be changed if the user wishes to have outputs stored somewhere other than the default directory.


```yaml
data:
    loc: 'data/raw/'
    dest: 'data/output/'
```

Other values in the `data` section of the configuration files are the required input CSV files; these values should not be changed.

### Features {#predict-conf-features}

The `features` section contains the merging ID and variables to be one-hot encoded and log-transformed. The ID should not be altered; however, to add any variables to be one-hot encoded or log-transformed, simply append them to the `one_hot_encoded_vars` list and `log_transforms` list respectively while ensuring that the variable names are enclosed in single quotations as shown.


```yaml
features:
    id: 'item_solicitado_id' # unique id
    one_hot_encoded_vars:
        ['tipo_unidad_contratacion',
         'nombre_nivel_entidad',
         'forma_adjudicacion_llamado',
         'forma_pago_llamado',
         'descripcion_ingles_producto_n1']
    log_transforms: 
```

Also included in the `features` section is the `extra_vars` list, which contains a list of non-predictor variables in the dataset that the user wishes to see in the final output. For example, `decripcion_item_solicitado` is not a predictor in the model training, but contains useful information on the nature of each item; thus, it could be included in `extra_vars`. To add variables to `extra_vars`, simply append them to the list and ensure that their names are enclosed in single quotations as shown below.


```yaml
extra_vars: ['item_solicitado_id',
			 'descripcion_item_solicitado',
			 'descripcion_llamado_grupo',
			 'descripcion_llamado',
			 'fecha_ejecucion_pac']
```

### Model {#predict-conf-model}

The `model` section contains the directory of the final  predictive model and one-hot encoding model to be used to generate predictions on the new raw data. The predictive model's directory and file name can be changed by writing the directory in the `loc` value of `model` and the file name in the `winning_model` value of `model`. The one-hot encoding model, which is generated by running the `fe.R` script, can have its directory and file name updated by changing the `loc` value in `ohe_model` to the directory the one-hot encoding model is located in and changing the `last_run_date` value in `ohe_model` to the most recent date when the `fe.R` script was run.


```yaml
model:
    loc: '/files/' # loc is input path
    winning_model: 'model_inter_final.rds'
ohe_model:
    loc: 'data/output/'
    last_run_date: '2021-08-11'
```

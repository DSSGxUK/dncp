# Training {#train}

## The Script {#train-script}

The training script, `training.R`, creates a stratified train/test split, performs hyperparameter tuning, trains a model, and outputs key performance indicators (KPIs).

### Required Files {#train-script-files}

The `training.R` script is not a self contained script and requires the input of a training dataset and other scripts containing helper functions. The following is a list of necessary files and the structure they should follow:

- `src/`
    - `scripts/`
        - `training.R` (encompassing script to run)
    - `functions/`
        - `training_helpers.R` (set of helper functions to perform tasks in `training.R`)
- `data/`
    - `output/`
        -   `training_set_DATE.rds` (most recent training dataset created by `fe.R`)
- `conf/`
    - `training_conf.yaml` (configuration file for `training.R`)

### Required R Packages {#train-script-required-r-packages}

The following is a list of R **VERSION 4.1.0** packages necessary for running `training.R` and its associated scripts and reports

- `yaml` 2.2.1
- `tidyverse` 1.3.1
- `mlr3verse` 0.2.1

### Tasks Performed by the Script {#train-script-tasks}

The `training.R` script takes in a cleaned and feature engineered dataset outputted by `fe.R`. To understand how to accomplish this output, please look at the [Feature Engineering Documentation](#fe).

#### Creating the Train/Test Split {#train-script-train-test-split}

For model creation, the dataset is split into two subsets: a training set and test/holdout set. The training set is used to train a model, while the testing set is withheld from the training to try to simulate unseen data. Once a model is created using the training set, it is used to predict the prices in the test/holdout set Since, we have the observed prices for the contracts in the test/holdout set, we can evaluate the predictions. It is ideal for the training set and test/holdout set to have similar distributions of the target variable. Thus, to create the train and test sets, a stratified sampling technique was used to split the dataset.

To do this, Sturges' Rule was used -- a principle providing guidelines on how many bins a dataset should be split up into. Using the formula for Sturges' Rule and the number of rows in the dataset, the stratified sampling technique was used such that first, the data was sorted by the target variable. Next, \(\big\lceil \log_2 n\big\rceil + 1\) strata were created from the sorted data with \(n\) rows. Lastly, a random proportion of each strata was selected to be part of the training set. This allows for the training set to have a target variable distribution similar to the original full dataset.

It is also important to note that all observations where the target value is missing are removed. We do not want to risk imputing the value of the target variable, so we drop missing values. To see how missing values are handled for predictor variables see the [Feature Engineering Documentation](#fe).

#### Setting Up the Model {#train-script-model-setup}

The modeling for this project was all conducted using the `mlr3` ecosystem. The ecosystem provides a universal framework for different models and enabled us to create a dynamic training script which can develop any type of model. The set up simply involves designating which variable is the target and which are predictors. Then choosing which type of model is going to be developed, and assigning values to desired parameters for the given model choice. A *random forest* and a *neural network* have vastly different parameter inputs such as number of trees vs learning rate, but we have implemented a system that enables for easy input of these values.

Once the inputs of the model are established, the desired algorithm is ran. Depending on the algorithm, this can take seconds to hours.

#### Hyperparameter Tuning {#train-script-hyperparameter-tuning}

Due to this high degree of choice in parametric values, it is common to choose values based on reputation, intuition, or just adhere to the defaults. But, there is an algorithmic approach to use hyperparameter tuning to identify the ideal values for the given hyperparameters instead of manually inputting and guessing. Note that hyperparameter can be used interchangable with parameter in this context as a hyperparameter is just a parameter for a machine learning model. Through a structured hyperparameter-tuning process, various parametric configurations are evaluated on the same data splits using a resampling holdout set. Eventually, the configuration with the best performance is outputted, which can then be used to train a model.

#### Storing Model and KPIs {#train-script-store-kpi}

Once the model is developed, the key performance indicators (KPIs) that are specified in `training_conf.yaml` are calculated and outputted to the console. The model is then stored to the output destination.

### Outputs {#train-conf-outputs}

The following are the outputs produced by running `training.R`:

- `output/MODELNAME_DATE.rds` (trained model where MODELNAME is the *name* section in the config file)
- printed model KPIs, e.g.

    ```
    Non-Log RMSE: 24298515.95595 PYG (3644.77739 USD)
    Non-Log Median RMSE: 33708.62962 PYG (5.05629 USD)

    ```

## The Configuration File {#train-conf}

The configuration file `training_conf.yaml` contains the inputs for the tasks outlined in the [Training Documentation](#train). This file needs to be altered for any desired change of input. The following sections describe how to make those alterations. Every value must be stored in quotation marks unless it is a number or boolean (*TRUE*/*FALSE*). The training configuration file is broken down into three stages: the Data, the Features, and the Model.

### Data {#train-conf-data}

To load in the correct training dataset, the file location is sepcified under "*loc:"*, and the most recent run date of `fe.R` is entered in the "*last_run_date*" section. The input location in this configuration file should be the same as the output location in `fe_conf.yaml`.


```yaml
data:
    loc: '~/dncp/data/output'
    last_run_date: '2021-07-29'
```

#### Features {#train-conf-features}

Under the *Features* section, the desired target, id, and predictor variables are specified explicitly using the naming convention variable_dataset. For one-hot encoded variables, it is not necessary to state each column created for each category, solely add the overall column name. However, it is important each variable is contained within quotation marks. Below is an example.


```yaml
features:
    id: 'item_solicitado_id' # unique id
    target: 'precio_unitario_item_solicitado_log'
    # all predictors to be used, including groups and one-hot encoded variables
    predictors:
        ['contrato_abierto_llamado_grupo',
         'agricultura_familiar_item_solicitado',
         'produccion_nacional_item_solicitado',
         'service',
         'descripcion_ingles_producto_n1',
         'police_buyer',
         'electricity_buyer',
         'food_context',
         'vehicle_context']
```

For variables that were one-hot encoded, explicitly specify their original name under the *one_hot_encoded_vars* section IN ADDITION to being in the *predictor* section.


```yaml
one_hot_encoded_vars:
    ['tipo_unidad_contratacion',
     'nombre_nivel_entidad',
     'forma_adjudicacion_llamado',
     'forma_pago_llamado',
     'descripcion_ingles_producto_n1']
```

### Model {#train-conf-model}

The model building section of `training_conf.yaml` has the most variation in terms of inputs. The *name* key is to uniquely identify the training run, and will be included in the filename of the stored model. It is recommended to include the model type in the name. Additionally, the *model* section is where the train/test split proportions are specified. Typical splits are 70\% (or 80\%) of the data used for training and the remaining 30\% (or 20\%) used for testing. Input the proportion for the training set under *train_prop* as a decimal value.


```yaml
model:
    name: 'ranger-no-outliers'
    train_prop: 0.8
```

In this *model* section, the desired algorithm can be specified under the *type* section. The selection must be an acceptable `mlr3` algorithm, where the list of possibilities can be found entering `mlr3verse::mlr_learners` into the R console or looking below:

```
classif.cv_glmnet, classif.debug, classif.featureless, classif.glmnet, 
classif.kknn, classif.lda, classif.log_reg, classif.multinom, 
classif.naive_bayes, classif.nnet,classif.qda, classif.ranger, 
classif.rpart, classif.svm, classif.xgboost, 
  
clust.agnes, clust.ap, clust.cmeans, clust.cobweb, clust.dbscan, clust.diana, 
clust.em, clust.fanny, clust.featureless, clust.ff, clust.kkmeans, clust.kmeans, 
clust.MBatchKMeans, clust.meanshift, clust.pam, clust.SimpleKMeans, clust.xmeans, 
  
dens.hist, dens.kde,
  
regr.cv_glmnet, regr.featureless, regr.glmnet, regr.kknn, regr.km, regr.lm, 
regr.ranger, regr.rpart, regr.svm, regr.xgboost, 
  
surv.coxph, surv.cv_glmnet, surv.glmnet, surv.kaplan, 
surv.ranger, surv.rpart, surv.xgboost
```

#### Parameter Choices {#train-conf-param}

The next and most important aspect of the model development is the parameters. Each algorithm has various different parameters that can be adjusted, so it was important to enable access to those options regardless of the algorithm. Say the desired model type is a random forest. In the `mlr3` ecosystem, a random forest regression is the model *'regr.ranger'*. To find the options for the parameters, enter `mlr3verse::lrn("regr.ranger")$param_set` into the R console.

The important information is the output are the **id**, **lower**, **upper**, and **default** columns. The **id** is the name of the parameter, the **lower** and **upper** values are the bounds for the parameter. When the bounds are `-Inf` to `Inf`, this means it can be any numeric value. When the bounds are `NA` and the **nlevels** is 2, then this is a *TRUE*/*FALSE* parameter. The **default** is what the parameter is automatically set to when running the algorithm. Parameters should only be customized if the default value is not desired.

The example output for `regr.ranger` is below:

```
                            id    class lower upper nlevels        default  
1:                        alpha ParamDbl  -Inf   Inf     Inf            0.5
2:       always.split.variables ParamUty    NA    NA     Inf <NoDefault[3]>
3:                      holdout ParamLgl    NA    NA       2          FALSE
4:                   importance ParamFct    NA    NA       4 <NoDefault[3]>
5:                   keep.inbag ParamLgl    NA    NA       2          FALSE
6:                    max.depth ParamInt  -Inf   Inf     Inf               
7:                min.node.size ParamInt     1   Inf     Inf              5
8:                     min.prop ParamDbl  -Inf   Inf     Inf            0.1
9:                      minprop ParamDbl  -Inf   Inf     Inf            0.1
10:                         mtry ParamInt     1   Inf     Inf <NoDefault[3]>
11:            num.random.splits ParamInt     1   Inf     Inf              1
12:                  num.threads ParamInt     1   Inf     Inf              1
13:                    num.trees ParamInt     1   Inf     Inf            500
14:                    oob.error ParamLgl    NA    NA       2           TRUE
15:                     quantreg ParamLgl    NA    NA       2          FALSE
16:        regularization.factor ParamUty    NA    NA     Inf              1
17:      regularization.usedepth ParamLgl    NA    NA       2          FALSE
18:                      replace ParamLgl    NA    NA       2           TRUE
19:    respect.unordered.factors ParamFct    NA    NA       3         ignore
20:              sample.fraction ParamDbl     0     1     Inf <NoDefault[3]>
21:                  save.memory ParamLgl    NA    NA       2          FALSE
22: scale.permutation.importance ParamLgl    NA    NA       2          FALSE
23:                    se.method ParamFct    NA    NA       2        infjack
24:                         seed ParamInt  -Inf   Inf     Inf               
25:         split.select.weights ParamDbl     0     1     Inf <NoDefault[3]>
26:                    splitrule ParamFct    NA    NA       3       variance
27:                      verbose ParamLgl    NA    NA       2           TRUE
28:                 write.forest ParamLgl    NA    NA       2           TRUE

```

Say that from the output of the parameters, it is decided that the parameters to customize are the number of trees, the number of variables randomly split on for each tree, and whether or not to replace samples. Their custom values are inputted into the *parameter* section using key-value pairs where the key is the **id** and the value is within the **upper** and **lower** bounds. 


```yaml
type: "regr.ranger"
parameters:
  num.trees: 501
  mtry: 10
  replace: FALSE
```

#### Hyperparameter Tuning {#train-conf-hyperparameter-tuning}

The next step is hyperparameter tuning, which, depending upon the grid size and parameter selection, might take hours to run. Thus, in the configuration file, this step can be ignored by setting *run* to *FALSE*. Using the *tuner* *'grid_search'*, all possible combinations of hyperparameters are tested between the specified *lower*, *upper* bounds for each parameter, and similarly, *'random_search'* will randomly choose values. The higher the number of discrete values for hyperparameters and the more hyperparameters, the more computationally expensive. We recommend also specifying a budget of 20 evaluations using *n_evals*. 


```yaml
hyperparameter_tuning:
    run: true
    tuner: 'random_search'
    n_evals: 20
```

As seen in the [Parameter Configuration](#train-conf-param) section, the individual parameters are model-dependent and thus need to be adjusted for each algorithm. Refer to that section on how to identify parameters and their bounds.

Once the desired parameters are identified, the configuration file should be filled out with three nested key value pairs of *type*, *lower* and *upper* for each parameter, where *type* is the data type (*'int'* is integer, *'dbl'* is double, *'fct'* is factor, and *'lgl'* is logical), and the *lower* and *upper* values are the desired bounds for the parameter. These bounds must be inbetween the overall bounds for the parameter, but should only be the range that is desired for testing. For example, the variable **x** may be allowed to be any value btween 0 and 100, but it is only desired to test values between 30 and 40, so the bounds are set at 30 and 40. Once the ideal parameters are determined, the script will add them to the model before it is trained. Below is an example configuration for an XGBoost model:


```yaml
parameters:
    eta:
        type: 'dbl'
        lower: 0
        upper: 1
    max_depth:
        type: 'int'
        lower: 1
        upper: 100
    subsample:
        type: 'dbl'
        lower: 0
        upper: 1
    nrounds:
        type: 'int'
        lower: 40
        upper: 400
```

Additionally, here is an example for a random forest algorithm:


```yaml
parameters:
    mtry:
        type: 'int'
        lower: 1
        upper: 15
    ntree:
        type: 'int'
        lower: 500
        upper: 1550
```

#### Metrics {#train-conf-metrics}

The final step is to list the key performance indicators for evaluation under the *metrics* section. Once again, these must be written in using the naming conventions of `mlr3`. 


```yaml
metrics:
    ["regr.rmse",
     "regr.mae",
     "regr.rsq"]
```

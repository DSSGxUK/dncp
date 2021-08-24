# Buyer Groupings {#buyer}







## Buyer Information Fields {#buyer-information-fields}

Buyers will be considered at the tender level (i.e., one buyer for each row in the `llamado` table). The tables containing buyer/entity information are:

1. `unidad_contratacion`
             
    - left join onto pac by `pac.unidad_contratacion_id = unidad_contratacion.id`
    - **variable of interest:** `descripcion` (description of the buyer; probably easiest to do text mining on, since it includes exact institution names like "hospital" or "university")
    - **additional variables:** `tipo` (UOC, SUOC, or UEP) and `institucion` (whether the buyer is an institution or not)
    
2. `entidad`

    - left join onto `unidad_contratacion` by `unidad_contratacion.entidad_codigo_sicp = entidad.codigo_sicp`
    - **NOTE:** `entidad` has multiple rows  for each value of `entidad.codigo_sicp` (one per year), so the left join must be performed using a reduced version of `entidad` with a single row for each value (see the code snippet below for implementation)
     - **variable of interest:** `nombre` (name of the buyer at a higher level; does not include specific institution names, only broad government and municipality information)

3. `nivel_entidad`

    - left join onto `entidad` by `(entidad.anio, entidad.nivel_entidad_codigo) = (nivel_entidad.anio, nivel_entidad.nivel_entidad_codigo)`
    - **variable of interest:** `nombre` (very broad buyer levels within the public sector)
    
**CONCLUSIONS:** Combine `unidad_contratacion.nombre` and `entidad.nombre` into a single string to perform text mining on. Since `nivel_entidad.nombre` has relatively few categories with little text, it does not lend itself well to text mining. Instead, experiment with it as a categorical variable in its own right.

## Adding Buyer Information to Tenders {#buyer-add-info-to-tenders}



**ISSUE:** The buyer joining process must somehow be incorporated into the feature engineering script, but relational column inconsistencies (in terms of naming and number) and the bidirectional joining order would significantly increase the complexity of the config file.

**IMPLEMENTED SOLUTION:** Perform the buyer joining process in a separate script, which then gets sourced within the feature engineering script if buyer-related variables are listed as predictors in the config file.

## Buyer Levels {#buyer-level}

We fit an OLS regression model for `log_precio_unitario` (our target) against `nivel_entidad` to see how much variability this predictor accounts for by itself.


```
MODEL FIT:
F(14,3282352) = 3566.7951, p = 0.0000
R² = 0.0150
Adj. R² = 0.0150 

Standard errors: OLS
-------------------------------------------------------------------------
                                        Est.     S.E.     t val.        p
---------------------------------- --------- -------- ---------- --------
(Intercept)                          12.4913   0.0184   678.0445   0.0000
nivel_entidadcapacitacion            -4.4322   1.9485    -2.2747   0.0229
dncp                                                                     
nivel_entidadcontraloria             -1.0160   0.0419   -24.2320   0.0000
general de la republica                                                  
nivel_entidaddefensoria del          -1.5444   0.0648   -23.8431   0.0000
pueblo                                                                   
nivel_entidadempresas                 0.3968   0.0224    17.6902   0.0000
mixtas                                                                   
nivel_entidadempresas                -0.3827   0.0193   -19.7782   0.0000
publicas                                                                 
nivel_entidadentes autonomos         -0.3336   0.0195   -17.0953   0.0000
y autarquicos                                                            
nivel_entidadentidades               -0.3138   0.0212   -14.8353   0.0000
financieras oficiales                                                    
nivel_entidadentidades               -0.2579   0.0202   -12.7640   0.0000
publicas de seguridad social                                             
nivel_entidadgobiernos               -0.2731   0.0193   -14.1613   0.0000
departamentales                                                          
nivel_entidadmunicipalidades         -0.5206   0.0188   -27.6727   0.0000
nivel_entidadpoder                   -0.9751   0.0186   -52.4557   0.0000
ejecutivo                                                                
nivel_entidadpoder                   -0.4177   0.0192   -21.7252   0.0000
judicial                                                                 
nivel_entidadpoder                   -0.3389   0.0218   -15.5240   0.0000
legislativo                                                              
nivel_entidaduniversidades           -1.1089   0.0190   -58.2084   0.0000
nacionales                                                               
-------------------------------------------------------------------------
```

By itself, `nivel_entidad` accounts for a statistically significant 1.5\% of the variability in `log_precio_unitario`, so we might consider including it in our model. But what about in conjunction with other predictors?

**ISSUE:** The `nivel_entidad` variable has 15 categories; we must find the best way to merge them.

## Buyer Names and Descriptions {#buyer-name-description}

We join the name and description of a buyer into a single string for each tender and perform text mining.



## Most Frequent Words {#buyer-frequent-words}

Below are the 30 most frequent words in the buyer descriptions, along with the proportion of items for which that buyer keyword appears:

<img src="02-buyer-grouping_files/figure-html/buyer-frequent-words-1.png" width="672" />

## Final Buyer Groupings {#buyer-groupings}

Since there may be overlap between the keywords present in each buyer name and description, we will be treating the buyer groupings as indicator variables (to which a buyer either belongs or not) -- mutually exclusive categories would not make sense here. Some potential indicator variable groupings are:

- Police: `"policia"`
- Hospital: `"hospital"` or `"cancer"`
- Science: `"ciencia"`
- Health: `"salud"`
- Law: `"justicia"` or `"judicial"`
- Ministry: `"ministerio"`
- Education: `"universidad"`, `"facultad"`, or `"educacion"`
- Army: `"defensa"`, `"comando"`, `"armada"`, or `"ejercito"`
- Bank: `"banco"`
- Tech: `"tecnologia"` or `"aeronautica"`
- Electricity: `"ande"` (administracion nacional de electricidad) or `"electricidad"`


|Grouping    |String Pattern                                 |Proportion |
|:-----------|:----------------------------------------------|:----------|
|police      |policia                                        |3.15%      |
|hospital    |hospital&#124;cancer                           |1.60%      |
|science     |ciencia                                        |5.82%      |
|health      |salud                                          |8.95%      |
|law         |justicia&#124;judicial                         |7.11%      |
|ministry    |ministerio                                     |34.52%     |
|education   |universidad&#124;facultad&#124;educacion       |10.95%     |
|army        |defensa&#124;comando&#124;armada&#124;ejercito |10.01%     |
|bank        |banco                                          |1.94%      |
|tech        |tecnologia&#124;aeronautica                    |3.39%      |
|electricity |ande&#124;electricidad                         |2.49%      |

## Variable Importance Exploration {#buyer-variable-importance}

Finally, we explore the importance of the above groupings when it comes to explaining the variability in `log_precio_unitario`. To find out which indicators might be worth keeping in the baseline regression model, we perform variable selection using the best subsets method. The importance of the different indicators might change once we include other variables, but this is a good first look at what might be most important.


|            |10 Vars |9 Vars  |8 Vars  |7 Vars  |6 Vars  |5 Vars  |4 Vars  |3 Vars   |2 Vars   |1 Vars   |
|:-----------|:-------|:-------|:-------|:-------|:-------|:-------|:-------|:--------|:--------|:--------|
|Adjr2       |0.0246  |0.0246  |0.0244  |0.0242  |0.0236  |0.0229  |0.0220  |0.0199   |0.0157   |0.0112   |
|Cp          |183.53  |366.21  |828.40  |1574.61 |3689.67 |5891.46 |8936.16 |16108.72 |30183.28 |45445.77 |
|Bic         |-81.63k |-81.46k |-81.01k |-80.28k |-78.18k |-75.99k |-72.97k |-65.84k  |-51.87k  |-36.8k   |
|Police      |*       |*       |*       |*       |*       |*       |*       |         |         |         |
|Hospital    |*       |*       |*       |*       |*       |*       |        |         |         |         |
|Science     |        |        |        |        |        |        |        |         |         |         |
|Health      |*       |*       |*       |*       |*       |*       |*       |*        |*        |         |
|Law         |*       |*       |*       |*       |*       |        |        |         |         |         |
|Ministry    |*       |*       |        |        |        |        |        |         |         |         |
|Education   |*       |*       |*       |*       |*       |*       |*       |*        |         |         |
|Army        |*       |*       |*       |*       |*       |*       |*       |*        |*        |*        |
|Bank        |*       |        |        |        |        |        |        |         |         |         |
|Tech        |*       |*       |*       |        |        |        |        |         |         |         |
|Electricity |*       |*       |*       |*       |        |        |        |         |         |         |

## Implementation Conclusions {#buyer-conclusions}

A total of 11 buyer indicator variables (listed [above](#buyer-groupings)) were created based on the cleaned-up and merged buyer descriptions. Each indicator variable corresponds to certain specific string patterns, and the variable will be *TRUE* for a particular observation if that observation's clean buyer description matches those patterns. Otherwise, the indicator variable will be *FALSE*.

# Conclusions

## Outcomes

Using various analytical and graphical tools, we evaluated the predictive performance of multiple models applied to actual data to predict the unit price of different items, including goods and services that governments and state-owned institutions purchased in the public procurement process.

In addition, our models helped identify which characteristics of the dataset were most strongly associated with unit item price and could explain most of the price variation. We then turned our attention to making our pipeline automated with our input data and input model, helping us construct an automatic process for making EDAs for new datasets, training new models, and generating predictions on new datasets.

Furthermore, we improved our models' prediction error rates by enhancing the feature engineering process using only a set of features available from approximately 3 million items over 10 years of public procurement conducted by the DNCP. We then employed clustering methods and text mining to find and evaluate new features for model prediction. The models used in this study consisted of simple linear regression, random forests, and Gradient Boosting to predict item prices. 

The models were compared and assessed using median root mean square error and $R^2$ as performance metric criteria. Linear regression achieved the lowest median root mean square error value when accounting for goods and service items (median RMSE at \$30). At the same time, the XGBoost ensemble method appeared to perform best with the predictors for the dataset consisting only of goods (median RMSE at \$3), which explains most variation in unit item prices. These findings are helpful to the DNCP in analysing the distribution of items across different tenders.

The results from our study can help provide answers to government and public institutions when making decisions such as how accurately the value of a tender can be assessed and what types of items should be scrutinized most when searching for anomalies in pricing.

## Limitations

Despite having produced a working automated pipeline that met our initial requirements for predicting unit item prices, various improvements can be made in the future. These include improvements we did not complete due to limited time on the project such as confidence intervals for more detailed anomaly detection in pricing by users and a lack of computational power to run more complex machine learning models. Most notably, however, a further segmentation of the training dataset into different categories to train multiple models may have been helpful, but was not completed due to time constraints. This may have decreased the overall percent deviation from the mean for pricing predictions.

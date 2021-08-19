---
output:
  pdf_document: default
  html_document: default
---
# Introduction

## Motivation

Our original motivation for this project lies in the work of the Paraguayan Department of Public Contracting (DNCP). The DNCP manages the public procurement process in Paraguay, through which goods and services are purchased by governments and state-owned institutions. The types of these goods and services vary immensely, ranging from automobile parts to electrical power systems. As a result, one of the DNCP's responsibilities is to look past the diverse item categories and ensure that all items are purchased at a fair price; if any purchases seem suspicious, the DNCP is able to launch investigations into them. 

Despite its best efforts, the DNCP can find itself in situations where precious time and effort is spent towards investigating items that ultimately were purchased through a lawful and fair procedure. Additionally, there is a chance that the DNCP misses an item that should have been investigated due to the sheer number of tenders that are processed through the public procurement process each year. Thus, this project aims to assist the DNCP in its efforts to coordinate public procurement in a fair manner by creating a model that estimates the prices of items involved in public procurement. Accomplishing this may help the DNCP to preserve time and resources by more easily identifying suspicious purchases and anomalies. 

## Objectives & Final Product

The primary objective of this project is to predict the unit prices of goods and services involved in the public procurement process. Additionally, there are some subgoals of this project that were implemented. First, we sought to create an automated exploratory data analysis of any input dataset containing information on goods and services, so that a user could easily analyze the distributions and summary statistics of all items involved in a tender or group of tenders. Second, we wished to automate an effective feature engineering process on new input datasets, such that the data would be manipulated appropriately and new grouping variables representing the contexts of items would be added. Lastly, we wished to train an accurate model that would output predictions for the unit prices of items based on previously collected information.

The final product of this project is a fully trained model that very closely approximates the unit prices of items (Median RMSE < 9 USD). Additionally, we have created an automated pipeline for the construction of an EDA for new datasets, the training of new models and the generation of predictions on new datasets.

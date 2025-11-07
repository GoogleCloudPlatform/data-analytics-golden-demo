/*##################################################################################
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###################################################################################*/


/*
Use Cases:
    - Need to import a custom trained model into BigQuery.  You might have a model that 
      is unique for your business or advanced data scientist that create models to be 
      scored on your warehouse data.

Note:
    - These models are samples and are not trained for accuracy or precission
    
Description: 
    - Train the model in the notebook "BigQuery-Create-TensorFlow-Model"
    - Use the below to import the model and score data in BigQuery.

Reference:
    - https://cloud.google.com/blog/products/data-analytics/bigquery-ml-unsupervised-anomaly-detection

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring`;
    DROP MODEL IF EXISTS `${bigquery_taxi_dataset}.model_tf_dnn_fare`;
    DROP MODEL IF EXISTS `${bigquery_taxi_dataset}.model_tf_linear_regression_fare`;
*/


-- Training SQL from notebook 
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring` AS
SELECT GENERATE_UUID() AS generated_primary_key,
       Fare_Amount,
       Trip_Distance,
       DATETIME_DIFF(Dropoff_DateTime, Pickup_DateTime, MINUTE) AS Minutes,
       CAST(NULL AS FLOAT64) AS predicted_linear_reg,
       CAST(NULL AS FLOAT64) AS predicted_dnn
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
 WHERE Pickup_DateTime BETWEEN '2020-01-01' AND '2020-01-31'  -- Small dataset
   AND DATETIME_DIFF(Dropoff_DateTime, Pickup_DateTime, MINUTE) BETWEEN 5 AND 60  -- Somewhat of a normal time
   AND Fare_Amount > 0
   AND Trip_Distance > 0
LIMIT 10000;  -- not too many so we are not here all day


-- Import the tensor flow model from storage
CREATE OR REPLACE MODEL ${bigquery_taxi_dataset}.model_tf_linear_regression_fare
       OPTIONS (MODEL_TYPE='TENSORFLOW',
       MODEL_PATH='gs://${bucket_name}/tensorflow/taxi_fare_model/linear_regression/*');


-- Run a prediction (note you can run the same prediction in your notebook and get the same result)
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.PREDICT(MODEL ${bigquery_taxi_dataset}.model_tf_linear_regression_fare,
     (
      SELECT [10.0,20.0] AS normalization_input
     ));
""";


-- Import the tensor flow model from storage
CREATE OR REPLACE MODEL ${bigquery_taxi_dataset}.model_tf_dnn_fare
       OPTIONS (MODEL_TYPE='TENSORFLOW',
       MODEL_PATH='gs://${bucket_name}/tensorflow/taxi_fare_model/dnn/*');


-- Run a prediction (note you can run the same prediction in your notebook and get the same result)
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.PREDICT(MODEL ${bigquery_taxi_dataset}.model_tf_dnn_fare,
     (
      SELECT [10.0,20.0] AS normalization_input
     ));
""";


-- Score using the imported Linear Regression model
-- NOTE: If you trained/exported your model several times you might see "dense" be called "dense2 or dense3, etc."
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring` AS tensorflow_scoring
   SET predicted_linear_reg = CAST(ScoredData.dense AS FLOAT64)
  FROM (SELECT *
         FROM ML.PREDICT (MODEL `${bigquery_taxi_dataset}.model_tf_linear_regression_fare`,
             (SELECT generated_primary_key, -- for matching to source data
                     [Trip_Distance, Minutes] AS normalization_input
               FROM `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring`))) AS ScoredData
 WHERE ScoredData.generated_primary_key = tensorflow_scoring.generated_primary_key;
""";


-- Score using the imported Deep Neural Network model
-- NOTE: If you trained/exported your model several times you might see "dense" be called "dense2 or dense3, etc."
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring` AS tensorflow_scoring
   SET predicted_dnn = CAST(ScoredData.dense_3 AS FLOAT64)
  FROM (SELECT *
         FROM ML.PREDICT (MODEL `${bigquery_taxi_dataset}.model_tf_dnn_fare`,
             (SELECT generated_primary_key, -- for matching to source data
                     [Trip_Distance, Minutes] AS normalization_input
               FROM `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring`))) AS ScoredData
 WHERE ScoredData.generated_primary_key = tensorflow_scoring.generated_primary_key;
""";


-- Let's see what the models predicted and which one is better
SELECT *,
       ROUND(Fare_Amount - predicted_linear_reg,3) AS diff_linear_reg_prediction,
       ROUND(Fare_Amount - predicted_dnn,3) AS diff_dnn_prediction,
       CASE WHEN ABS(ROUND(Fare_Amount - predicted_linear_reg,3)) <
                 ABS(ROUND(Fare_Amount - predicted_dnn,3))
            THEN 'Linear Reg Wins'
            ELSE 'DNN Wins'
        END AS Model_Winner
  FROM `${project_id}.${bigquery_taxi_dataset}.tensorflow_scoring`;


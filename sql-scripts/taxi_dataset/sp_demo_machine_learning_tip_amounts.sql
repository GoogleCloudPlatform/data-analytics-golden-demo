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
    - Want to predict your tip amounts
    
Note:
    - These models are samples and are not trained for accuracy or precission

Description: 
    - Create a training dataset and feature enginner your data
    - Train a linear regression model to predict a tip amount based upon the trip, day, hour of day, distance, fare and passengers
    - Score all the data in your table
    - Ingestigate the data

Reference:
    - https://cloud.google.com/bigquery-ml/docs/linear-regression-tutorial

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1`;
    DROP MODEL IF EXISTS `${project_id}.${bigquery_taxi_dataset}.model_predict_tip_v1`;
*/


-- Create a table for the training data.
-- Limit the amount of data, so training does not take a long time
-- Bucket the tip amounts into 25 cent increments (except for the high values)
-- You can do this with a view or other syntax, but in this example the data will be scored and updated.
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1` AS 
SELECT GENERATE_UUID() AS generated_primary_key, -- so we can match our scoring data
       CONCAT(CAST(PULocationID AS STRING),'-',CAST(DOLocationID AS STRING)) AS Trip,     
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       EXTRACT(HOUR FROM Pickup_DateTime) AS HourPart,
       TIMESTAMP_DIFF(Dropoff_DateTime, Pickup_DateTime, MINUTE) AS DurationMinutes,
       Fare_Amount,
       Passenger_Count,
       Tip_Amount,
       -- Bucket tip amounts (feature enginnering)
       CASE WHEN Tip_Amount < 10 
            THEN TRUNC(CAST(Tip_Amount AS NUMERIC)) + 
                 CASE WHEN MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) = 0   THEN 0
                      WHEN MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) > 0 
                       AND MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) <= .25 THEN .25
                      WHEN MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) > .25 
                       AND MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) <= .5  THEN .5
                      WHEN MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) > .5 
                       AND MOD(CAST(Tip_Amount AS NUMERIC), CAST(1 AS NUMERIC)) <= .75 THEN .75
             ELSE 1 
             END
        ELSE ROUND(Tip_Amount,0) -- round to nearest whole number and not each 25 cent increment
        END AS Tip,

        -- For updates
        CAST(NULL AS FLOAT64) AS predicted_tip_amount,
        CAST(NULL AS BOOLEAN) AS predicted_anomoly

   FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
  WHERE TaxiCompany = 'Yellow'
    AND (PULocationID = 161 AND DOLocationID = 237)
    AND Fare_Amount  > 0 
    AND Trip_Distance > 0
    AND Tip_Amount    > 0
    AND TIMESTAMP_DIFF(Dropoff_DateTime, Pickup_DateTime, MINUTE) > 0
    AND Passenger_Count > 0
    AND tip_amount < 20 ;
--ORDER BY WeekdayName,hourpart, DurationMinutes,Passenger_Count, Fare_Amount       



-- Create a model
-- Suffix the model with _v1 in case you develop many models
-- Query complete (19.2 sec elapsed, 12.1 MB (ML) processed) 
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_tip_v1`
OPTIONS(
  MODEL_TYPE = 'linear_reg',
  INPUT_LABEL_COLS = ['Tip']
) AS
SELECT *  EXCEPT(generated_primary_key, Tip_Amount, predicted_tip_amount, predicted_anomoly)
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1`;


-- NOTE: These commmands are dynamice.  strict_mode still checks for models existing
-- Score all the data with the predicted tip amount
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1` AS train_model_predict_tip_v1
   SET predicted_tip_amount = CAST(ScoredData.predicted_Tip AS NUMERIC)
  FROM (SELECT *
         FROM ML.PREDICT (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_tip_v1`,
             (SELECT generated_primary_key, -- for matching to source data
                     Trip,
                     WeekdayName,
                     HourPart,
                     DurationMinutes,
                     Fare_Amount,
                     Passenger_Count
               FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1`))) AS ScoredData
 WHERE ScoredData.generated_primary_key = train_model_predict_tip_v1.generated_primary_key;
""";

-- See the predictions
SELECT WeekdayName,
       HourPart,
       DurationMinutes,
       Passenger_Count,
       Fare_Amount,
       Tip_Amount, 
       predicted_tip_amount,
       predicted_tip_amount - Tip_Amount                AS TipPredictionDifference,
       (predicted_tip_amount - Tip_Amount) / Tip_Amount AS TipPredictionDifferencePct
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1`
 LIMIT 1000;


-- Low Tips
SELECT WeekdayName,
       HourPart,
       DurationMinutes,
       Passenger_Count,
       Fare_Amount,
       Tip_Amount,
       predicted_tip_amount,
       predicted_tip_amount - Tip_Amount                AS TipPredictionDifference,
       (predicted_tip_amount - Tip_Amount) / Tip_Amount AS TipPredictionDifferencePct
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1`
 WHERE (predicted_tip_amount - Tip_Amount) / Tip_Amount  > 1
 LIMIT 1000;


-- Total Training Data: 218559
-- 1: 10209
-- 2: 1883
-- 3: 664 (anomolies 300% +)
-- 4: 549
-- 5: 511
-- 6: 493
-- 7: 473
SELECT count(*)
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_tip_v1`
 WHERE (predicted_tip_amount - Tip_Amount) / Tip_Amount  > 7;


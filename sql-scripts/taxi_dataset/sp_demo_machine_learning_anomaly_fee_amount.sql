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
    - Want to see what fares looks like anomalies
    - Are people being charged wrong, broken meter or just bad data?

Note:
    - These models are samples and are not trained for accuracy or precission
    
Description: 
    - Create a training dataset and feature enginner your data
    - Train a model that detects anomalies base upon the trip, duration, distance and fare amount
    - Score all the data in your table
    - Train a second model
    - Score all the data in your table
    - Ingestigate the data

Reference:
    - https://cloud.google.com/blog/products/data-analytics/bigquery-ml-unsupervised-anomaly-detection

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`;
    DROP MODEL IF EXISTS `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v1`;
    DROP MODEL IF EXISTS `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v2`;    
*/

/*
-- https://www1.nyc.gov/site/tlc/passengers/taxi-fare.page
$2.50 initial charge.
Plus 50 cents per 1/5 mile when traveling above 12mph or per 60 seconds in slow traffic or when the vehicle is stopped.
Not modeling these:
- Plus 50 cents MTA State Surcharge for all trips that end in New York City or Nassau, Suffolk, Westchester, Rockland, Dutchess, Orange or Putnam Counties.
- Plus 30 cents Improvement Surcharge.
- Plus 50 cents overnight surcharge 8pm to 6am.
- Plus $1.00 rush hour surcharge from 4pm to 8pm on weekdays, excluding holidays.
*/

CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly` AS 
SELECT GENERATE_UUID() AS generated_primary_key, -- so we can match our scoring data
       CONCAT(CAST(PULocationID AS STRING),'-',CAST(DOLocationID AS STRING)) AS Trip,       
       TIMESTAMP_DIFF(Dropoff_DateTime, Pickup_DateTime, MINUTE) AS DurationMinutes,
       Trip_Distance,
       Fare_Amount,
       -- For updates
       CAST(NULL AS BOOLEAN) AS predicted_v1_is_anomaly,
       CAST(NULL AS FLOAT64) AS predicted_v1_normalized_distance,
       CAST(NULL AS INT)     AS predicted_v1_CENTROID_ID,
       CAST(NULL AS BOOLEAN) AS predicted_v2_is_anomaly,
       CAST(NULL AS FLOAT64) AS predicted_v2_normalized_distance,
       CAST(NULL AS INT)     AS predicted_v2_CENTROID_ID

   FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
  WHERE taxi_trips.TaxiCompany = 'Yellow'
    AND (
          --(PULocationID = 264 AND DOLocationID = 264) OR
          --(PULocationID = 237 AND DOLocationID = 236) OR
          --(PULocationID = 239 AND DOLocationID = 238) OR
          (PULocationID = 161 AND DOLocationID = 237) OR
          (PULocationID = 239 AND DOLocationID = 142)
        ) 
    AND Fare_Amount  > 0 
    AND Trip_Distance > 0
    AND TIMESTAMP_DIFF(Dropoff_DateTime, Pickup_DateTime, MINUTE) > 0;


-- VERSION 1: Train k-mean (for clustering and anomoly detection)
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v1`
OPTIONS(
  MODEL_TYPE = 'kmeans',
  KMEANS_INIT_METHOD = 'kmeans++',
  DISTANCE_TYPE = 'EUCLIDEAN'
) AS
SELECT Trip,
       DurationMinutes,
       Trip_Distance,
       Fare_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`;


-- NOTE: These commmands are dynamic.  strict_mode still checks for models existing
-- VERSION 1: Predict the Cluster
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.PREDICT (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v1`,
                  (SELECT generated_primary_key,
                          Trip,
                          DurationMinutes,
                          Trip_Distance,
                          Fare_Amount
                    FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
                    LIMIT 1000
                   ));
""";

-- VERSION 1: Predict Anomolies
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.DETECT_ANOMALIES (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v1`,
                            STRUCT(.2 AS contamination),
                            (SELECT generated_primary_key,
                                    Trip,
                                    DurationMinutes,
                                    Trip_Distance,
                                    Fare_Amount
                               FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
                              LIMIT 1000
                            ))
 WHERE is_anomaly = TRUE;    
""";

-- VERSION 1: Score all the data (detect anomalies and set the normalized distence/centriod)
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly` AS train_model_predict_anomoly
   SET predicted_v1_is_anomaly          = ScoredData.is_anomaly,
       predicted_v1_normalized_distance = ScoredData.normalized_distance,
       predicted_v1_CENTROID_ID         = CENTROID_ID
  FROM (SELECT *
         FROM ML.DETECT_ANOMALIES (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v1`,
                                   STRUCT(.2 AS contamination),
                                   (SELECT generated_primary_key,  -- for matching to source data
                                           Trip,
                                           DurationMinutes,
                                           Trip_Distance,
                                           Fare_Amount
                                      FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`))) AS ScoredData
 WHERE ScoredData.generated_primary_key = train_model_predict_anomoly.generated_primary_key;
""";

--------------------------------------------------------------------------------------------------
-- VERSION 2 (hyperparameter turning)
--------------------------------------------------------------------------------------------------

-- VERSION 2: Train k-mean (for clustering and anomoly detection)
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v2`
OPTIONS(
  MODEL_TYPE = 'kmeans',
  NUM_CLUSTERS = 10,                -- DIFFERENT
  KMEANS_INIT_METHOD = 'kmeans++',
  DISTANCE_TYPE = 'EUCLIDEAN'
) AS
SELECT Trip,
       DurationMinutes,
       Trip_Distance,
       Fare_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`;


-- NOTE: These commmands are dynamice.  strict_mode still checks for models existing
-- VERSION 2: Predict the Cluster
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.PREDICT (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v2`,
                  (SELECT generated_primary_key,
                          Trip,
                          DurationMinutes,
                          Trip_Distance,
                          Fare_Amount
                    FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
                    LIMIT 1000
                   ));
""";

-- VERSION 2: Predict Anomolies
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.DETECT_ANOMALIES (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v2`,
                            STRUCT(.2 AS contamination),
                            (SELECT generated_primary_key,
                                    Trip,
                                    DurationMinutes,
                                    Trip_Distance,
                                    Fare_Amount
                               FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
                              LIMIT 1000
                            ))
 WHERE is_anomaly = TRUE;     
""";

 -- VERSION 2: Score all the data (detect anomalies and set the normalized distence/centriod)
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly` AS train_model_predict_anomoly
   SET predicted_v2_is_anomaly          = ScoredData.is_anomaly,
       predicted_v2_normalized_distance = ScoredData.normalized_distance,
       predicted_v2_CENTROID_ID         = CENTROID_ID
  FROM (SELECT *
         FROM ML.DETECT_ANOMALIES (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v2`,
                                   STRUCT(.2 AS contamination),
                                   (SELECT generated_primary_key,  -- for matching to source data
                                           Trip,
                                           DurationMinutes,
                                           Trip_Distance,
                                           Fare_Amount
                                      FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`))) AS ScoredData
 WHERE ScoredData.generated_primary_key = train_model_predict_anomoly.generated_primary_key;
""";

-- See the differences in the model predictions
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
 WHERE (
         predicted_v1_is_anomaly = TRUE
         OR
         predicted_v2_is_anomaly = TRUE
       )
  AND DurationMinutes > 10; -- See some interesting data
   
-- Items you would want to investigate
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
 WHERE (
         predicted_v1_is_anomaly = TRUE
         OR
         predicted_v2_is_anomaly = TRUE
       )
  AND Fare_Amount = 2.5 AND DurationMinutes = 1;

SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.train_model_predict_anomoly`
 WHERE (
         predicted_v1_is_anomaly = TRUE
         OR
         predicted_v2_is_anomaly = TRUE
       )
  AND Fare_Amount = 2.5 AND DurationMinutes > 1;
   
-- Export the model to storage
-- You can then open the open in a notebook
EXPORT MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v2`
OPTIONS(URI = 'gs://${bucket_name}/tensorflow/predict_anomoly_v2/');


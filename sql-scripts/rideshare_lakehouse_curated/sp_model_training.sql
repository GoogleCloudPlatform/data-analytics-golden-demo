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
      - Trains the model to predict the high value rides
  
  Description: 
      - Trains the model with all the data
      - Uses the unstructed data for the model (processed images)
      - Uses shared weather data for the model (Analytics Hub)
      
  Show:
      - Training Data
      - Analytics Hub
      - Scoring data w/explainable AI
      - Vertex AI (Model Registry)
  
  References:
      - 
      
  Notes:
      - is holiday timeframe (need a list of holidays)
      - images of people with packages (need images based upon day of year and pickup location)
      - surge pricing
      - is rush hour
      -- short or long trip
      - show the probablity of being high values
      - Predict the dropoff location
      - Predict the total amount
      - Predict the tip amount

  Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data`
    DROP MODEL IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.model_predict_high_value`
    DROP VIEW IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.analytics_hub_weather_data`


  */

IF LOWER("${bigquery_region}") = "us" THEN
   -- NOTE: In 2024 you need to change this to ghcnd_2023
   CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.analytics_hub_weather_data` AS 
   SELECT * FROM `${project_id}.ghcn_daily.ghcnd_2022`;
ELSE
   -- NOTE: Analytics hub does not have this data in other regions (this keeps things from breaking)
   CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.analytics_hub_weather_data` AS 
   SELECT CAST (NULL AS STRING) AS id,
          CAST (NULL AS DATE) AS date,
          CAST (NULL AS STRING) AS element,
          CAST (NULL AS FLOAT64) AS value,
          CAST (NULL AS STRING) AS mflag,
          CAST (NULL AS STRING) AS qflag,
          CAST (NULL AS STRING) AS sflag,
          CAST (NULL AS STRING) AS time,
          CAST (NULL AS STRING) AS source_url,
          CAST (NULL AS TIMESTAMP) AS etl_timestamp;
END IF;


-- Train for the same period "last year"
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data`
AS
WITH RideshareData AS 
(
SELECT rideshare_trip_id,
       CAST(pickup_location_id AS STRING) AS pickup_location_id,
       pickup_location_id AS location_id,
       CAST(pickup_datetime AS DATE) AS pickup_date,
       CAST(EXTRACT(YEAR FROM pickup_datetime) AS STRING) AS pickup_year,
       CAST(EXTRACT(MONTH FROM pickup_datetime) AS STRING) AS pickup_month,
       CAST(EXTRACT(DAY FROM pickup_datetime) AS STRING) AS pickup_day,
       CAST(EXTRACT(DAYOFWEEK FROM pickup_datetime) AS STRING) AS pickup_day_of_week,
       CAST(EXTRACT(HOUR FROM pickup_datetime) AS STRING) AS pickup_hour,    
       ride_distance,
       is_airport,
       fare_amount,
       tip_amount,
       TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE) AS ride_duration,
       bigquery_rideshare_zone.borough
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip` AS bigquery_rideshare_trip
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone` AS bigquery_rideshare_zone
               ON bigquery_rideshare_trip.pickup_location_id = bigquery_rideshare_zone.location_id
              AND pickup_datetime BETWEEN CAST(DATETIME_SUB(CURRENT_DATETIME('America/New_York'),INTERVAL 24 MONTH) AS TIMESTAMP)
                  AND CAST(DATETIME_SUB(CURRENT_DATETIME('America/New_York'),INTERVAL 23 MONTH) AS TIMESTAMP)
              AND ride_distance < 100
)
, WeatherRainData AS 
(
  SELECT CASE WHEN id = 'USC00305679' THEN 'EWR'
              WHEN id = 'USW00094728' THEN 'Manhattan'
              WHEN id = 'US1NYQN0029' THEN 'Queens'
              WHEN id = 'USC00300961' THEN 'Bronx'
              WHEN id = 'USC00300958' THEN 'Brooklyn'
              WHEN id = 'US1NYRC0016' THEN 'Staten Island'
         END AS borough, 
         date, 
         element, 
         MAX(value) AS value
    FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.analytics_hub_weather_data` 
   WHERE date BETWEEN CAST(DATETIME_SUB(CURRENT_DATETIME('America/New_York'),INTERVAL 24 MONTH) AS DATE)
                  AND CAST(DATETIME_SUB(CURRENT_DATETIME('America/New_York'),INTERVAL 23 MONTH) AS DATE)  
     AND element = 'PRCP'
     AND id IN ('USC00305679','USW00094728','US1NYQN0029','USC00300961','USC00300958','US1NYRC0016')
   GROUP BY 1, 2, 3
)
, WeatherSnowData AS 
(
  SELECT CASE WHEN id = 'USC00305679' THEN 'EWR'
              WHEN id = 'USW00094728' THEN 'Manhattan'
              WHEN id = 'US1NYQN0029' THEN 'Queens'
              WHEN id = 'USC00300961' THEN 'Bronx'
              WHEN id = 'USC00300958' THEN 'Brooklyn'
              WHEN id = 'US1NYRC0016' THEN 'Staten Island'
         END AS borough, 
         date, 
         element, 
         MAX(value) AS value
    FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.analytics_hub_weather_data`
   WHERE date BETWEEN CAST(DATETIME_SUB(CURRENT_DATETIME('America/New_York'),INTERVAL 24 MONTH) AS DATE)
                  AND CAST(DATETIME_SUB(CURRENT_DATETIME('America/New_York'),INTERVAL 23 MONTH) AS DATE)  
     AND element = 'SNOW'
     AND id IN ('USC00305679','USW00094728','US1NYQN0029','USC00300961','USC00300958','US1NYRC0016')
   GROUP BY 1, 2, 3
)
, PeopleTraveling AS
(
   -- NOTE: The dates are not used since we require images for every day/hour of the year, which is a lot of images
   SELECT location_id, COUNT(1) AS cnt, AVG(score) as avg_score
     FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_images_ml_detection`
    WHERE name IN ('Luggage and bags','Rolling','Baggage','Suitcase')
  GROUP BY location_id       
)
, People AS
(
   -- NOTE: The dates are not used since we require images for every day/hour of the year, which is a lot of images
   SELECT location_id, COUNT(1) AS cnt, AVG(score) as avg_score
     FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_images_ml_detection`
    WHERE name IN ('Pedestrian','Person')
  GROUP BY location_id           
)
SELECT rideshare_trip_id,
       RideshareData.pickup_location_id AS location_id,
       RideshareData.pickup_year,
       RideshareData.pickup_month,
       RideshareData.pickup_day,
       RideshareData.pickup_day_of_week,
       RideshareData.pickup_hour,
       CASE WHEN RideshareData.ride_distance < 2 THEN "short"
            WHEN RideshareData.ride_distance < 4 THEN "medium"
            ELSE "long"
       END AS ride_distance,
       CASE WHEN IFNULL(WeatherRainData.value,0) > 0 THEN TRUE
            ELSE FALSE
       END AS is_raining,
       CASE WHEN IFNULL(WeatherSnowData.value,0) > 0 THEN TRUE
            ELSE FALSE
       END AS is_snowing,
       CAST(IFNULL(PeopleTraveling.cnt,0) AS STRING) AS people_traveling_cnt,      
       CAST(IFNULL(People.cnt,0)          AS STRING) AS people_cnt,
       CASE WHEN ride_distance > 5 AND fare_amount> 25 AND tip_amount > (fare_amount * .30) THEN 1
            WHEN ride_distance > 4 AND fare_amount> 20 AND tip_amount > (fare_amount * .25) THEN 1
            WHEN ride_distance > 3 AND fare_amount> 15 AND tip_amount > (fare_amount * .20) THEN 1
            WHEN ride_distance > 2 AND fare_amount> 10 AND tip_amount > (fare_amount * .15) THEN 1
            ELSE 0
       END AS is_high_value_ride,
       CAST(NULL AS NUMERIC) AS predicted_is_high_value_ride      
            
  FROM RideshareData
       LEFT JOIN WeatherRainData
              ON RideshareData.borough     = WeatherRainData.borough
             AND RideshareData.pickup_date = WeatherRainData.date
       LEFT JOIN WeatherSnowData
              ON RideshareData.borough     = WeatherSnowData.borough
             AND RideshareData.pickup_date = WeatherSnowData.date
       LEFT JOIN PeopleTraveling
              ON RideshareData.location_id = PeopleTraveling.location_id       
       LEFT JOIN People
              ON RideshareData.location_id = People.location_id;

SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data` 
 WHERE is_high_value_ride > 0
  LIMIT 100;


-- Train a model to predict high value rides
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.model_predict_high_value`
OPTIONS(
  MODEL_TYPE = 'linear_reg',
  INPUT_LABEL_COLS = ['is_high_value_ride'],
  MODEL_REGISTRY = "vertex_ai"
) AS
SELECT *  EXCEPT(rideshare_trip_id, predicted_is_high_value_ride)
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data`;


-- View a prediction with Explainable AI
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.EXPLAIN_PREDICT (MODEL `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.model_predict_high_value`,
      (SELECT '138' AS location_id,
              '2022' AS pickup_year,
              '3' AS pickup_month,
              '6' AS pickup_day,
              '1' AS pickup_day_of_week,
              '23' AS pickup_hour,
              'short' AS ride_distance,
              FALSE AS is_raining,
              FALSE AS is_snowing,
              '0' AS people_traveling_cnt,
              '0' AS people_cnt          
        ));
""";

-- Score all the results
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data` AS bigquery_model_training_data
    SET predicted_is_high_value_ride = CAST(ScoredData.predicted_is_high_value_ride AS NUMERIC)
  FROM (SELECT *
          FROM ML.PREDICT (MODEL `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.model_predict_high_value`,
              (SELECT rideshare_trip_id, -- for matching to source data
                      location_id,
                      pickup_year,
                      pickup_month,
                      pickup_day,
                      pickup_day_of_week,
                      pickup_hour,
                      ride_distance,
                      is_raining,
                      is_snowing,
                      people_traveling_cnt,
                      people_cnt          
                FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data`
                ))) AS ScoredData
  WHERE ScoredData.rideshare_trip_id = bigquery_model_training_data.rideshare_trip_id;
""";

-- See the best scored data
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data` 
ORDER BY predicted_is_high_value_ride DESC
LIMIT 500;

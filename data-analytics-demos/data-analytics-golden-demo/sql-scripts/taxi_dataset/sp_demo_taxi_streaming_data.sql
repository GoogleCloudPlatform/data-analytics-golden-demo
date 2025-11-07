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
Prerequisites: 
    - In Composer / Airflow start the DAG: sample-dataflow-streaming-bigquery
    - It will take several minutes for the DAG to start
    - To show machine learning on the stream run the following stored procedure at least 30 minutes before demoing
      - CALL `${project_id}.${bigquery_taxi_dataset}.sp_demo_machine_learning_anomaly_fee_amount`();

Use Cases:
    - Receive realtime data from streaming sources directly into BigQuery
    
Description: 
    - Shows streaming data from Pub/Sub -> Dataflow -> BigQuery
    - BigQuery has streaming ingestion where data is available as soon as it is ingested
    - Micro-batching is not used, the data is immediate

Reference:
    - https://cloud.google.com/bigquery/docs/write-api

Clean up / Reset script:
    n/a
*/

-- Open the table taxi_trips_streaming
-- Click on details to see the streaming buffer stats
-- Some of the data is in columnar format and some is in row format, but when we query
-- we do not need to worry about where the data is, BigQuery just queries the data.


-- Current data within past hour (run over and over again to show data streaming)
SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR);


-- Same SQL as above, just orders the data
-- Show current data in past hour (slower query due to ORDER BY)
SELECT *   
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
 WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR)
ORDER BY timestamp DESC;


-- Data older than last hour
SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR);


-- Show data from 1 hour ago to 2 hours ago (provided the streaming job has been running for the past 3 hours)
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 2 HOUR) AND TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR)
 LIMIT 100;


-- Same SQL as above, but does a Count
-- Show data from 1 hour ago to 2 hours ago (provided the streaming job has been running for the past 3 hours)
SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 2 HOUR) AND TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR);



------------------------------------------------------------------------------------
-- Self join the streaming data
-- The streaming data has a "pickup" record (message) and then a "dropoff" message
-- We need to match the pickup and dropoff seperate records (by ride_id) so we can compute the time and distance between pickup and dropoff
-- The distance is computed using Geospacial functions in BigQuery
------------------------------------------------------------------------------------

WITH LatestData AS 
(
  -- Get last 15 minutes of data
  SELECT ride_id, timestamp, longitude, latitude, meter_reading, ride_status
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
   WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 15 MINUTE)
)
, results AS 
(
  -- for the last 15 minutes match the pickup with dropoff
  -- compute miles since ST_DISTANCE is in meters (divide by 1609.34)
  SELECT enroute.ride_id,
         enroute.timestamp AS PickupTime,
         dropoff.timestamp AS DropoffTime, 
         ST_DISTANCE(ST_GEOGPOINT(enroute.longitude, enroute.latitude), 
                     ST_GEOGPOINT(dropoff.longitude, dropoff.latitude)) / 1609.34 AS Trip_Distance, 
         TIMESTAMP_DIFF(dropoff.timestamp, enroute.timestamp, MINUTE) AS DurationMinutes,
         dropoff.meter_reading AS Fare_Amount
    FROM LatestData AS enroute 
         INNER JOIN LatestData AS dropoff
                 ON enroute.ride_id = dropoff.ride_id
                AND enroute.ride_status = 'enroute'
                AND dropoff.ride_status = 'dropoff'
)
SELECT *
  FROM results;


------------------------------------------------------------------------------------
-- Run machine learning on the streaming data
-- NOTE You must run the sp_demo_machine_learning_anomaly_fee_amount procedure First in order to train the model!
------------------------------------------------------------------------------------
EXECUTE IMMEDIATE """
WITH LatestData AS 
(
  SELECT ride_id, timestamp, longitude, latitude, meter_reading, ride_status
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
   WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 15 MINUTE)
)
, results AS 
(
  SELECT enroute.ride_id,
         enroute.timestamp AS PickupTime,
         dropoff.timestamp AS DropoffTime, 
         ST_DISTANCE(ST_GEOGPOINT(enroute.longitude, enroute.latitude), 
                     ST_GEOGPOINT(dropoff.longitude, dropoff.latitude)) / 1609.34 AS Trip_Distance, 
         TIMESTAMP_DIFF(dropoff.timestamp, enroute.timestamp, MINUTE) AS DurationMinutes,
         dropoff.meter_reading AS Fare_Amount
    FROM LatestData AS enroute 
         INNER JOIN LatestData AS dropoff
                 ON enroute.ride_id = dropoff.ride_id
                AND enroute.ride_status = 'enroute'
                AND dropoff.ride_status = 'dropoff'
)
SELECT *
  FROM ML.DETECT_ANOMALIES (MODEL `${project_id}.${bigquery_taxi_dataset}.model_predict_anomoly_v1`,
                            STRUCT(.2 AS contamination),
                            (SELECT '161-237' AS Trip,
                                    DurationMinutes,
                                    Trip_Distance,
                                    Fare_Amount
                                FROM results
                              LIMIT 100
                            ))
  WHERE is_anomaly = TRUE;
""";


------------------------------------------------------------------------------------
-- Streaming delivery data
-- This is from the thelook_ecommerce dataset procedure "demo_queries"
-- It shows how we can using streaming data to see how our delivery times are increasing or remaining steady
------------------------------------------------------------------------------------
 WITH MaxStreamingDate AS
  (
     -- Use the max date (versus current time in case the streaming job is not started)
     SELECT MAX(delivery_time) AS max_delivery_time
       FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries_streaming`
  )
  -- SELECT max_delivery_time FROM MaxStreamingDate;
  , AverageDeliveryTime AS 
  (
    SELECT CASE WHEN delivery_time > TIMESTAMP_SUB(max_delivery_time, INTERVAL 60 MINUTE) 
                THEN 'CurrentWindow'
                ELSE 'PriorWindow'
            END AS TimeWindow,
            distribution_center_id,
            delivery_minutes,
            distance
      FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries_streaming`
            CROSS JOIN MaxStreamingDate
     WHERE delivery_time > TIMESTAMP_SUB(max_delivery_time, INTERVAL 5 DAY)
       AND delivery_minutes > 0
       AND distance > 0
  )
  --SELECT * FROM AverageDeliveryTime ORDER BY distribution_center_id, TimeWindow;
  , PivotData AS
  (
    SELECT *
      FROM AverageDeliveryTime
    PIVOT (AVG(delivery_minutes) avg_delivery_minutes, 
           AVG(distance) avg_distance, 
           COUNT(*) nbr_of_deliveries FOR TimeWindow IN ('CurrentWindow', 'PriorWindow'))
  )
  -- SELECT * FROM PivotData;
  SELECT distribution_centers.name AS distribution_center,
  
         nbr_of_deliveries_CurrentWindow AS deliveries_current,
         nbr_of_deliveries_PriorWindow AS deliveries_prior,
  
         ROUND(avg_distance_CurrentWindow,1) AS distance_current,
         ROUND(avg_distance_PriorWindow,1) AS distance_prior,
  
         CASE WHEN avg_distance_CurrentWindow > avg_distance_PriorWindow + (avg_distance_PriorWindow * .15) THEN 'High'
              WHEN avg_distance_CurrentWindow > avg_distance_PriorWindow + (avg_distance_PriorWindow * .10) THEN 'Med'
              WHEN avg_distance_CurrentWindow > avg_distance_PriorWindow + (avg_distance_PriorWindow * .05) THEN 'Low'
              ELSE 'Normal'
          END AS distance_trend,
  
         ROUND(avg_delivery_minutes_CurrentWindow,1) AS minutes_current,
         ROUND(avg_delivery_minutes_PriorWindow,1) AS minutes_prior,
  
         CASE WHEN avg_delivery_minutes_CurrentWindow > avg_delivery_minutes_PriorWindow + (avg_delivery_minutes_PriorWindow * .15) THEN 'High'
              WHEN avg_delivery_minutes_CurrentWindow > avg_delivery_minutes_PriorWindow + (avg_delivery_minutes_PriorWindow * .10) THEN 'Med'
              WHEN avg_delivery_minutes_CurrentWindow > avg_delivery_minutes_PriorWindow + (avg_delivery_minutes_PriorWindow * .05) THEN 'Low'
              ELSE 'Normal'
          END AS minutes_trend
  
    FROM PivotData
         INNER JOIN `${project_id}.${bigquery_thelook_ecommerce_dataset}.distribution_centers` AS distribution_centers
                 ON PivotData.distribution_center_id = distribution_centers.id
  ORDER BY distribution_center_id;

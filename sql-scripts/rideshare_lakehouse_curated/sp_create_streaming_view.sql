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
      - Creates a view over the streaming data so the data is summarized.
        The (raw) data consists of many messages per ride, this will rank and partition the data
        to find the ride start and ride end.       
  
  Description: 
      - 
  
  Show:
      - Analytic queries on lots of data arriving at a fast pace.
  
  References:
      - 
  
  Clean up / Reset script:
      DROP VIEW IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips`;

  */

CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips` AS
WITH PickupData AS 
  (
    SELECT rideshare_id, latitude, longitude, rideshare_timestamp, total_amount, ride_status,
           RANK() OVER (PARTITION BY rideshare_id
                            ORDER BY rideshare_timestamp) AS Ranking      
      FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.bigquery_streaming_rideshare_trips`
      WHERE ride_status = 'enroute'
  )
  , DropOffData AS
  (
    SELECT rideshare_id, latitude, longitude, rideshare_timestamp, total_amount, ride_status,
           RANK() OVER (PARTITION BY rideshare_id
                            ORDER BY rideshare_timestamp DESC) AS Ranking      
      FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.bigquery_streaming_rideshare_trips`
      WHERE ride_status = 'dropoff'
  )
  , results AS 
  (
    -- compute miles since ST_DISTANCE is in meters (divide by 1609.34)
    SELECT PickupData.rideshare_id,
           CAST(ROUND(1 + RAND() * (263 - 1)) AS INT) AS pickup_location_id,
           PickupData.rideshare_timestamp AS pickup_datetime,
           CAST(ROUND(1 + RAND() * (263 - 1)) AS INT) AS dropoff_location_id	,
           DropOffData.rideshare_timestamp AS dropoff_datetime, 
           ROUND(CAST (ST_DISTANCE(ST_GEOGPOINT(PickupData.longitude, PickupData.latitude), 
                       ST_GEOGPOINT(DropOffData.longitude, DropOffData.latitude)) / 1609.34 AS NUMERIC), 5, "ROUND_HALF_EVEN") AS ride_distance, 
           TIMESTAMP_DIFF(DropOffData.rideshare_timestamp, PickupData.rideshare_timestamp, MINUTE) AS ride_duration_minutes,
           ROUND(CAST (DropOffData.total_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") AS total_amount
      FROM PickupData 
           INNER JOIN DropOffData 
                   ON PickupData.rideshare_id = DropOffData.rideshare_id
                  AND PickupData.Ranking = 1
                  AND DropOffData.Ranking = 1
  )
  SELECT *
    FROM results;
  
 
-- Show the data
SELECT *
 FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips`;


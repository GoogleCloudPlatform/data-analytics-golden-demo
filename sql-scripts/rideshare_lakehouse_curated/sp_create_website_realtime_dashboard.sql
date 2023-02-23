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
      - This is a view on the streaming view that further combines the data so it can be presented
        on the Rideshare Plus website.
  
  Description: 
      - 
      
  Show:
      - 
  
  References:
      - 
  
  Clean up / Reset script:
    DROP VIEW IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.website_realtime_dashboard`;

  */

-- CALL `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.sp_website_streaming_data`(100);

CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.website_realtime_dashboard` AS
WITH Data AS
(
SELECT COUNT(1) AS ride_count,
       ROUND(CAST(IFNULL(AVG(ride_duration_minutes),0) AS NUMERIC), 2, "ROUND_HALF_EVEN") AS average_ride_duration_minutes,
       ROUND(CAST(IFNULL(AVG(total_amount),0) AS NUMERIC), 2, "ROUND_HALF_EVEN") AS average_total_amount,
       ROUND(CAST(IFNULL(AVG(ride_distance),0) AS NUMERIC), 2, "ROUND_HALF_EVEN") AS average_ride_distance
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips`
  WHERE pickup_datetime BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) AND CURRENT_TIMESTAMP()
)
, MostPickup AS
(
SELECT pickup_location_id,
       COUNT(1) AS ride_count,       
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips`
  WHERE pickup_datetime BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) AND CURRENT_TIMESTAMP()
  GROUP BY pickup_location_id
  ORDER BY 2 DESC
  LIMIT 1
)
, MostDropoff AS
(
SELECT dropoff_location_id,
       COUNT(1) AS ride_count,       
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips`
  WHERE dropoff_datetime BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) AND CURRENT_TIMESTAMP()
  GROUP BY dropoff_location_id
  ORDER BY 2 DESC
  LIMIT 1  
)
, AllData AS
(
SELECT Data.ride_count,
       Data.average_ride_duration_minutes,
       Data.average_total_amount,
       Data.average_ride_distance,
       MostPickup.pickup_location_id AS max_pickup_location_id,
       MostPickup.ride_count AS max_pickup_ride_count,
       MostDropoff.dropoff_location_id AS max_dropoff_location_id,
       MostDropoff.ride_count AS max_dropoff_ride_count       
  FROM Data, MostPickup, MostDropoff
)      
SELECT AllData.ride_count,
       AllData.average_ride_duration_minutes,
       AllData.average_total_amount,
       AllData.average_ride_distance,
       bigquery_rideshare_zone_pickup.zone AS max_pickup_location_zone,
       AllData.ride_count AS max_pickup_ride_count,
       bigquery_rideshare_zone_dropoff.zone AS max_dropoff_location_zone,
       AllData.ride_count AS max_dropoff_ride_count       
  FROM AllData
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone` AS bigquery_rideshare_zone_pickup
              ON AllData.max_pickup_location_id = bigquery_rideshare_zone_pickup.location_id
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone` AS bigquery_rideshare_zone_dropoff
              ON AllData.max_dropoff_location_id = bigquery_rideshare_zone_dropoff.location_id;

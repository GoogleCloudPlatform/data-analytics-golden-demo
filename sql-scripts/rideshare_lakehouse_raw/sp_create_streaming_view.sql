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
      - Creates a View over the streaming data
  
  Description: 
      - Bring the raw streaming data into this zone
  
  Show:
      - 
  
  References:
      - 
  
  Clean up / Reset script:
      DROP VIEW IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.bigquery_streaming_rideshare_trips`;

  */


CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.bigquery_streaming_rideshare_trips` AS
WITH rideshare_data AS (
  SELECT ride_id AS rideshare_id,
         latitude,
         longitude,
         timestamp AS rideshare_timestamp,
         CASE WHEN ride_status = 'enroute' THEN 0
              ELSE meter_reading
         END AS total_amount,
         ride_status
   FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming`
)
SELECT *
  FROM rideshare_data;
  
  
-- Show the data
SELECT *
 FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.bigquery_streaming_rideshare_trips`
ORDER BY rideshare_id, rideshare_timestamp;

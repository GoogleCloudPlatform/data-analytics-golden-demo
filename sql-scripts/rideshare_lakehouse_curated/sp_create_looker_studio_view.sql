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
      - Creates a View used by Looker that combines the AI/ML prediction results with the
        realtime streaming data
  
  Description: 
      - Creates a View used by Looker that combines the AI/ML prediction results with the
        realtime streaming data
  
  Show:
      - Realtime results combined with static data
  
  References:
      - 
  
  Clean up / Reset script:
      DROP VIEW IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.looker_high_value_rides`;

  */

CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.looker_high_value_rides` AS  
WITH AggregateData AS
(
SELECT high_value.location_id AS Location,
       high_value.ride_distance AS RideLength,
       high_value.is_raining AS isRaining,
       high_value.is_snowing AS isSnowing,
       COUNT(streaming_data.pickup_location_id) AS CurrentTrips
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides` AS high_value
       LEFT JOIN `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_streaming_rideshare_trips` AS streaming_data
              ON high_value.location_id = streaming_data.pickup_location_id
             AND streaming_data.pickup_datetime BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) AND CURRENT_TIMESTAMP()
  WHERE high_value.is_high_value_ride = TRUE
GROUP BY 1,2,3,4
)
SELECT AggregateData.Location,
       CASE WHEN AggregateData.RideLength = 'short' THEN 'Short'
            WHEN AggregateData.RideLength = 'medium' THEN 'Medium'
            ELSE 'Long' 
       END AS RideLength,
       AggregateData.isRaining,
       AggregateData.isSnowing,
       high_value.borough AS Borough,
       high_value.zone AS Zone,
       high_value.geo_point AS MapCoordinate,
       AggregateData.CurrentTrips
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides` AS high_value  
       INNER JOIN AggregateData
               ON high_value.location_id = AggregateData.Location;

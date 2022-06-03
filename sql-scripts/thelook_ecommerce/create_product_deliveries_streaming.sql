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
Author: Adam Paternostro

Use Cases:
    - Creating a view over streaming data to abstact the field names/values 

Description: 
    - This will create a view to simulate real time deliveries

Show:
    - New view will be created

References:
    - https://cloud.google.com/bigquery/docs/views

Clean up / Reset script:
    DROP VIEW IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries_streaming` ;
*/

CREATE OR REPLACE VIEW `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries_streaming` 
AS
WITH deliveries AS (
  SELECT timestamp AS delivery_time,
         meter_reading AS delivery_minutes,
         MOD(point_idx,10) + 1 as distribution_center_id,
         meter_increment AS distance,
         product_id,
         IFNULL(passenger_count,1) AS quantity_to_delivery
   FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming`
)
SELECT delivery_time,
       CASE WHEN distribution_center_id = 1 AND delivery_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60 MINUTE) THEN delivery_minutes / 1.2
            WHEN distribution_center_id = 5 AND delivery_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60 MINUTE) THEN delivery_minutes / 1.5
            ELSE delivery_minutes / 2
        END AS delivery_minutes,        
       CASE WHEN distribution_center_id = 1 AND delivery_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60 MINUTE) THEN distance * 150
            WHEN distribution_center_id = 5 AND delivery_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60 MINUTE) THEN distance * 175
            ELSE distance * 100
        END AS distance,
       distribution_center_id,
       product_id,
       quantity_to_delivery
  FROM deliveries
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
Author: Adam Paternostro / Jason Davenport

Use Cases:
    - Use the taxi data to create a set of delivery data

Description: 
    - This will create a new table with lots of deliveries of products
    - The table will be cluster by deliver time and distribution center

Show:
    - New table will be created

References:
    - https://cloud.google.com/bigquery/docs/tables

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries` ;
*/

-- Create the Delivered Products Table
CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries` 
CLUSTER BY delivery_time, distribution_center_id
AS
WITH deliveries AS (
  SELECT Dropoff_DateTime,
         Trip_Distance,
         PULocationID,
         Tip_Amount AS Shipping_Min,
         Fare_Amount AS Shipping_Max,
         IFNULL(Passenger_Count,1) * 20 AS quantity_to_delivery
   FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
)
SELECT TIMESTAMP_ADD(Dropoff_DateTime, INTERVAL 365 DAY) delivery_time,
       Trip_Distance AS distance,
       MOD(PULocationID,10) + 1  AS distribution_center_id,
       CASE WHEN Shipping_Min < 5 THEN Shipping_Max ELSE Shipping_Min END AS delivery_cost,
       CAST(ROUND(1+ RAND() * (29120 - 1)) as INT64) product_id,
       quantity_to_delivery
  FROM deliveries;
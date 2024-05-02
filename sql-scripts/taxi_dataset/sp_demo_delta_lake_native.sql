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
    Ability to read Delta.io data directly from BigQuery for BQML or analytics purposes.

Description: 
    Create a BigLake table over a Hive partitioned Delta.io table

Reference:
    - https://cloud.google.com/bigquery/docs/create-delta-lake-table

Clean up / Reset script:
    DROP SCHEMA IF EXISTS `${project_id}.delta_lake_dataset`;

*/

-- Automatically detects partitions (Rideshare_Vendor_Id, Pickup_Date)

-- Create a new schema so we can easily see all the delta lake tables
CREATE SCHEMA IF NOT EXISTS `${project_id}.delta_lake_dataset` OPTIONS(location = '${bigquery_region}');


-- Open Storge to view delta files:
-- https://console.cloud.google.com/storage/browser/${storage_bucket}/delta_io

-- Driver
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.driver`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/driver']
);

SELECT * FROM `${project_id}.delta_lake_dataset.driver`;


-- Location
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.location`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/location']
);

SELECT * FROM `${project_id}.delta_lake_dataset.location`;


-- Payment Type
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.payment_type`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/payment_type']
);

SELECT * FROM `${project_id}.delta_lake_dataset.payment_type`;


-- Rate Code
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.rate_code`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/rate_code']
);

SELECT * FROM `${project_id}.delta_lake_dataset.rate_code`;


-- Taxi Trips (Automatically detects the Year | Month partitions)
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.taxi_trips`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/taxi_trips']
);

SELECT * FROM `${project_id}.delta_lake_dataset.taxi_trips`;


-- Trip Type
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.trip_type`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/trip_type']
);

SELECT * FROM `${project_id}.delta_lake_dataset.trip_type`;


-- Vendor
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.delta_lake_dataset.vendor`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['gs://${storage_bucket}/delta_io/vendor']
);

SELECT * FROM `${project_id}.delta_lake_dataset.vendor`;


-- Query the table
SELECT driver.driver_name,

       pickup_location.borough AS pickup_location_borough,
       pickup_location.zone AS pickup_location_zone,

       dropoff_location.borough AS dropoff_location_borough,
       dropoff_location.zone AS dropoff_location_zone,

       FORMAT("%.*f",2,AVG(trips.passenger_count)) AS avg_passenger_count,
       FORMAT("%.*f",2,AVG(trips.fare_amount)) AS avg_fare_amount

  FROM `delta_lake_dataset.taxi_trips` AS trips
       INNER JOIN `delta_lake_dataset.driver` AS driver
               ON trips.driver_id = driver.driver_id
              AND trips.year >= 2023
       INNER JOIN `delta_lake_dataset.location` AS pickup_location
               ON trips.pickup_location_id = pickup_location.location_id
       INNER JOIN `delta_lake_dataset.location` AS dropoff_location
               ON trips.dropoff_location_id = dropoff_location.location_id
 GROUP BY ALL
 ORDER BY 1,2,3,4,5
 LIMIT 25;
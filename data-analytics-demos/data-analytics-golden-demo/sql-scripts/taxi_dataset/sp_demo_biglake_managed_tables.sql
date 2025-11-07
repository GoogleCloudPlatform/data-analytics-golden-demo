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
    - For when customers want to have full control of their BigLake tables and want support for full CRUD operations

Description: 
    - Full CRUD support for BigLake managed tables.
    - The underlying table is fully managed by BigQuery.
    - The table uses Iceberg for its file format
    - The table is fully managed: 
      - Auto-tuned File Sizing
      - Clustering Partition Pruning
      - Automatic Reclustering
      - Automatic File Compaction
      - Automatic Garbage Collection

Show:
    - Managed tables: Apache Iceberg
    - Create
    - LOAD
    - Insert, Update, Delete
    - Alter schema

YouTube:
    - https://youtu.be/D4BhIraXP-I

References:
    - TBD

Clean up / Reset script:
    -- NOTE: You must manually go to the bucket: gs://${biglake_managed_tables_bucket_name}/biglake-managed-tables/ and DELETE all the folders.
    DROP TABLE IF EXISTS `${project_id}.biglake_managed_tables.iceberg_mt_location`;
    DROP TABLE IF EXISTS `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;
    DROP TABLE IF EXISTS `${project_id}.biglake_managed_tables.iceberg_mt_random_name`;
    DROP TABLE IF EXISTS `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips`;
    DROP TABLE IF EXISTS `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips_streaming`;
    DROP SCHEMA IF EXISTS `${project_id}.biglake_managed_tables`;
*/

/*
CREATE SCHEMA `${project_id}.biglake_managed_tables`
    OPTIONS (
    location = "US"
    );

------------------------------------------------------------------------------------------------
-- Create a Managed Iceberg Table (and load with LOAD command)
-- Note: the storage uri in the OPTIONS
-- Note: We can cluster the table (not partition, currently)
-- Note: We do not say CREATE OR REPLACE **EXTERNAL** TABLE
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.biglake_managed_tables.iceberg_mt_random_name`
(
  string_field_0 STRING
)
CLUSTER BY string_field_0
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://${biglake_managed_tables_bucket_name}/biglake-managed-tables/iceberg_mt_random_name');


-- Load the data (batch) into the table
LOAD DATA INTO `${project_id}.biglake_managed_tables.iceberg_mt_random_name`
FROM FILES (
  uris=['gs://${raw_bucket_name}/random_names/random_names.csv'],
  format='CSV',
  field_delimiter = ',',
  skip_leading_rows = 0 
  );


SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_random_name`;


------------------------------------------------------------------------------------------------
-- Create a Managed Iceberg Table (and load with SELECT INTO)
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.biglake_managed_tables.iceberg_mt_location`
(
  location_id INT64,
  borough STRING,
  zone STRING,
  service_zone STRING,
  latitude FLOAT64,
  longitude FLOAT64
)
CLUSTER BY location_id
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://${biglake_managed_tables_bucket_name}/biglake-managed-tables/iceberg_mt_location');

INSERT INTO `${project_id}.biglake_managed_tables.iceberg_mt_location`
(
  location_id,
  borough,
  zone,
  service_zone,
  latitude,
  longitude
)
SELECT location_id,
       borough,
       zone,
       service_zone,
       latitude,
       longitude
  FROM `${project_id}.taxi_dataset.biglake_location`;

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_location`;



------------------------------------------------------------------------------------------------
-- Stream data from Pub/Sub using BQ Subscription with Pub/Sub Metadata
------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------
-- Open: https://console.cloud.google.com/cloudpubsub/subscription/list?project=${project_id}
-- Enter Topic Manually: projects/pubsub-public-data/topics/taxirides-realtime
-- Click off: Write metadata
-- grant service account: service-xxxxxxxxxxx@gcp-sa-pubsub.iam.gserviceaccount.com BigQuery Data Owner role to table
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips_streaming` 
(
  subscription_name STRING,
  message_id STRING,
  publish_time TIMESTAMP,
  data STRING,
  attributes STRING
)
CLUSTER BY publish_time
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://${biglake_managed_tables_bucket_name}/biglake-managed-tables/iceberg_mt_taxi_trips_streaming');

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips_streaming`
 LIMIT 1000;


------------------------------------------------------------------------------------------------
-- Create a large Iceberg table
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips`
(
    TaxiCompany           STRING,
    Vendor_Id             INT64, 
    Pickup_DateTime       TIMESTAMP,
    Dropoff_DateTime      TIMESTAMP,
    Store_And_Forward     STRING,
    Rate_Code_Id          INT64,
    PULocationID          INT64,
    DOLocationID          INT64,
    Passenger_Count       INT64,
    Trip_Distance         FLOAT64,
    Fare_Amount           FLOAT64,
    Surcharge             FLOAT64,
    MTA_Tax               FLOAT64,
    Tip_Amount            FLOAT64,
    Tolls_Amount          FLOAT64,
    Improvement_Surcharge FLOAT64,
    Total_Amount          FLOAT64,
    Payment_Type_Id       INT64,
    Congestion_Surcharge  FLOAT64,
    Trip_Type             INT64,
    Ehail_Fee             FLOAT64,
    PartitionDate         DATE
)
CLUSTER BY PartitionDate
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://${biglake_managed_tables_bucket_name}/biglake-managed-tables/iceberg_mt_taxi_trips');


------------------------------------------------------------------------------------------------
-- Insert 182+ million of rows
------------------------------------------------------------------------------------------------
INSERT INTO `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Store_And_Forward,
    Rate_Code_Id,
    PULocationID,
    DOLocationID,
    Passenger_Count,
    Trip_Distance,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Payment_Type_Id,
    Congestion_Surcharge,
    Trip_Type,
    Ehail_Fee,
    PartitionDate
)
SELECT  'Green' AS TaxiCompany,
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        Store_And_Forward,
        Rate_Code_Id,
        PULocationID,
        DOLocationID,
        Passenger_Count,
        Trip_Distance,
        Fare_Amount,
        Surcharge,
        MTA_Tax,
        Tip_Amount,
        Tolls_Amount,
        Improvement_Surcharge,
        Total_Amount,
        Payment_Type_Id,
        Congestion_Surcharge,
        SAFE_CAST(Trip_Type AS INTEGER),
        Ehail_Fee,
        DATE(year, month, 1) as PartitionDate
   FROM `${project_id}.taxi_dataset.ext_green_trips_parquet`
UNION ALL
   SELECT
        'Yellow' AS TaxiCompany, 
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        Store_And_Forward,
        Rate_Code_Id,
        PULocationID,
        DOLocationID,
        Passenger_Count,
        Trip_Distance,
        Fare_Amount,
        Surcharge,
        MTA_Tax,
        Tip_Amount,
        Tolls_Amount,
        Improvement_Surcharge,
        Total_Amount,
        Payment_Type_Id,
        Congestion_Surcharge,
        NULL AS Trip_Type,
        NULL AS Ehail_Fee,
        DATE(year, month, 1) as PartitionDate
   FROM `${project_id}.taxi_dataset.ext_yellow_trips_parquet`;


SELECT *
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_taxi_trips`
 WHERE PartitionDate = '2022-01-01'
 LIMIT 100;


------------------------------------------------------------------------------------------------
-- Updates / Inserts / Deletes 
------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
(
  Payment_Type_Id INT64,
  Payment_Type_Description STRING
)
CLUSTER BY Payment_Type_Id
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://${biglake_managed_tables_bucket_name}/biglake-managed-tables/iceberg_mt_payment_type');

INSERT INTO `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
(
  Payment_Type_Id,
  Payment_Type_Description
)
SELECT Payment_Type_Id,
       Payment_Type_Description
  FROM `${project_id}.taxi_dataset.biglake_payment_type`;

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;


-- Insert
INSERT INTO `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
(
  Payment_Type_Id,
  Payment_Type_Description
)
VALUES (99, 'Mistake');

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;


-- Update
UPDATE `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
   SET Payment_Type_Description = 'Correction'
 WHERE Payment_Type_Id = 99;

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;

-- Delete
DELETE
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
 WHERE Payment_Type_Id = 99;

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;

-- Schema Update
ALTER TABLE `${project_id}.biglake_managed_tables.iceberg_mt_payment_type` 
  ADD COLUMN isCredit BOOL;

UPDATE `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
   SET isCredit = CASE WHEN Payment_Type_Id = 1 THEN TRUE ELSE FALSE END
 WHERE TRUE;

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;

ALTER TABLE `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`
 DROP COLUMN isCredit;

SELECT * 
  FROM `${project_id}.biglake_managed_tables.iceberg_mt_payment_type`;
*/

-- Remove this an uncomment the above, this is a preview feature.
SELECT 1;
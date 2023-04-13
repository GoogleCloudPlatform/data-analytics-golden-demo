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
    - Shows Iceberg support for BigQuery
    - Iceberg provides insert, update, delete, schema changes and time travel on files on your data lake
    - The Iceberg tables are Partitioned, but Iceberg hides that from users.

Iceberg:
    - Review the Dataproc Spark code
    - convert_taxi_to_iceberg_create_tables.py (creates the tables)
    - convert_taxi_to_iceberg_data_updates (updates, deletes and alter schema)

Description: 
    - First run the Airflow DAG: sample-iceberg-create-tables-update-data
    - Second View and Explore the Cloud Storage Account in this Project
      - The bucket is named "${processed_bucket_name}"
      - There is a folder named "iceberg-warehouse"
      - In the folder you will see a "default" folder (think of this as your "database name/instance")
      - You will then see a green_taxi_trips and yellow_taxi_trips folders (these are your tables)
      - Inside the green_taxi_trips you will see a "data" and "metadata" folder
      - The "data" folder contains all your parquet files.  The files contain all your data, some of which is logically deleted (so you just cannot query all the files)
      - The "metadata" folder contains all your schema and information about your "data" folder.  The metadata allows you to time travel and 
      - query different versions of you "data" files.  BigQuery uses the "metadata" data to query the specific data files at a specific point in time.

Show:
    - BQ support for Iceberg
    - BQ querying different versions of the Iceberg metadata

References:
    - https://cloud.google.com/bigquery/docs/hive-partitioned-queries-gcs

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v2`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v3`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v4`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v5`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v2`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v3`;
*/


---------------------------------------------------------------
-- View Iceberg Metadata: Green V5 Metadata
--
-- Open seperate tab and goto storage location: gs://${processed_bucket_name}/iceberg-warehouse/default/green_taxi_trips/metadata
-- View the file: v5.metadata.json
---------------------------------------------------------------
-- NOTE: You need to "REPLACE-ME" in the line below so you can see the metadata within Iceberg 
--       You can choose any AVRO file.  The snap-* are different then the non-snap files
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v5_manifest`
    OPTIONS (
    format = "AVRO",
    uris = ['gs://${processed_bucket_name}/iceberg-warehouse/default/green_taxi_trips/metadata/REPLACE-ME.avro']
);

SELECT *
  FROM  `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v5_manifest`;


---------------------------------------------------------------
-- Iceberg table Green Taxi (v2 table)
---------------------------------------------------------------
-- Create the table in its orginal state before and updates or deletes
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v2`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://${processed_bucket_name}/iceberg-warehouse/default/green_taxi_trips/metadata/v2.metadata.json"]
);

-- Query the data. It acts as any normal external table.
-- Duration 3 sec 
-- Bytes processed 10.42 MB 
SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v2`
 WHERE year=2021
   AND month=1;


-- Duration 2 sec 
-- Bytes processed  0 B 
-- 9,390,186
SELECT COUNT(*) AS RecordCount FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v2`;


---------------------------------------------------------------
-- Green Data STEP 1: Delete some data
---------------------------------------------------------------
-- The Iceberg table will have the following SQL statement run:
-- DELETE FROM local.default.green_taxi_trips WHERE Vendor_Id != 1
---------------------------------------------------------------

-- BEFORE: Total Original Green records 9,390,186
SELECT COUNT(*) AS RecordCount FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v2`;

-- BEFORE: These records [8,138,815] will be deleted by Iceberg 
SELECT COUNT(*) AS RecordCount FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v2` WHERE Vendor_Id != 1;

-- To see the changes we need to create a V3 external table
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v3`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://${processed_bucket_name}/iceberg-warehouse/default/green_taxi_trips/metadata/v3.metadata.json"]
);

-- AFTER:  Remaining records after delete 1,251,371 [V3 TABLE]
SELECT COUNT(*) AS RecordCount FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v3`;

-- Check math
SELECT 9390186 - 8138815 As Result, 1251371 As Expected_Results;


---------------------------------------------------------------
-- Green Data STEP 2: Perform schema evolution the table (add a column)
---------------------------------------------------------------
-- The Iceberg table will have the following SQL statement run:
-- ALTER TABLE local.default.green_taxi_trips ADD COLUMNS (iceberg_data string comment 'Iceberg new column')
---------------------------------------------------------------

-- To see the changes we need to create a V4 external table
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v4`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://${processed_bucket_name}/iceberg-warehouse/default/green_taxi_trips/metadata/v4.metadata.json"]
);

-- There is a new column named "iceberg_data" and all the data is NULL (scroll to far right in the results)
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v4` LIMIT 100;


---------------------------------------------------------------
-- Green Data STEP 3: Update the newly added column
---------------------------------------------------------------
-- The Iceberg table will have the following SQL statement run:
-- UPDATE local.default.green_taxi_trips SET iceberg_data = 'Iceberg was here!'
---------------------------------------------------------------
-- To see the data update we need to create a V5 external table
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v5`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://${processed_bucket_name}/iceberg-warehouse/default/green_taxi_trips/metadata/v5.metadata.json"]
);

-- The new column "iceberg_data" is updated with data (scroll to far right in the results)
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_green_taxi_trips_v5` LIMIT 100;


---------------------------------------------------------------
-- Iceberg table Yellow Taxi (v2 table)
---------------------------------------------------------------
-- Create the table in its orginal state before and updates or deletes
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v2`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://${processed_bucket_name}/iceberg-warehouse/default/yellow_taxi_trips/metadata/v2.metadata.json"]
);

-- Query the data
-- Duration 9 sec 
-- Bytes processed 199.95 MB 
SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v2`
 WHERE year=2021
   AND month=1;

-- Duration 2 sec 
-- Bytes processed  0 B 
-- 140,150,371
SELECT COUNT(*) AS RecordCount FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v2`;


---------------------------------------------------------------
-- Yellow Data STEP 3: Update the newly added column
---------------------------------------------------------------
-- The Iceberg table will have the following SQL statement run:
-- UPDATE local.default.yellow_taxi_trips SET Surcharge = 100 WHERE Passenger_Count > 6
---------------------------------------------------------------
-- To see the data update we need to create a V3 external table
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v3`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://${processed_bucket_name}/iceberg-warehouse/default/yellow_taxi_trips/metadata/v3.metadata.json"]
);

-- Before data update
SELECT Passenger_Count, Surcharge FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v2` WHERE Passenger_Count > 6;

-- After data update (the surcharge is set to 100)
SELECT Passenger_Count, Surcharge FROM `${project_id}.${bigquery_taxi_dataset}.iceberg_yellow_taxi_trips_v3` WHERE Passenger_Count > 6;

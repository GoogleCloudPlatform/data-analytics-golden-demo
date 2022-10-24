CREATE OR REPLACE PROCEDURE `bigquery_preview_features.sp_demo_biglake_query_acceleration`()
BEGIN
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
    - Small files are a problem with you have external tables on data lakes
    - Most storage systems take ~ 1-5 minutes to list 1 million files
    - With Spark and other technologies this is referred to as the "small file problem"
    - You are typically forced to repartition or compact your files so you have "larger (1GB to 5GB)" sized files
    - This will Accelerate your Spark code!  You can query the files through BigQuery using our Spark
      connector and gain the benefits of acceleration.
    - Since this is a BigLake table you can do row and column level security.
    - Partition pruning (and Hive pruning) can be done on the cached set of files.

Data Size:
    - File Count = 5,068,912
    - Directory Count = 1,588,355
    - The taxi trip table was exported to cloud storage and partitioned by Year, Month, Day, Hour and Minute
    - About 75 GB of data was exported and created many small files 
    - It took a 3 node 16 core Spark cluster 6 hours to generate these files to local HSFS
    - It took 89hrs, 51mins, 6sec to "distcp" these files to GCS

Description: 
    - We create a BigLake table as normal
    - We add the following options
      - metadata_cache_mode="AUTOMATIC" 
      - max_staleness=INTERVAL '1' HOUR
    - These options tell BigQuery to storage the file metadata (the file listing) in an internal BigQuery table
    - This means instead of calling to Cloud Storage using an API and getting a list of files 
      back we can query the internal BigQuery table
    - BigQuery can quicky query its internal table and do all the file/folder partition elimination in 
      SQL (much faster that calling to storage)
    - Calling to Cloud Storage using an API returns on {x} files and you then have to call back to the 
      get the next set of {x} files using continuation tokens (very tedious)

Show:
    - BQ support for GCS
    - BQ importing models
    - BQ scoring image data using a model

References:
    - go/biglake-query-acceleration-preview-guide 

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `bigquery_preview_features.biglake_query_acceleration`;
    DROP EXTERNAL TABLE IF EXISTS `bigquery_preview_features.biglake_no_acceleration`;
*/


-- Create two tables one with and one without acceleration

-- External table WITH query acceleration
-- You need to wait for Cloud Storage to be indexed....
-- The metadata collection for < 10 million files should take < 30 minutes 
-- (we will have something in the future to help see into this)
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `bigquery_preview_features.biglake_query_acceleration`
  WITH PARTITION COLUMNS (
      year  INTEGER, 
      month INTEGER,
      day INTEGER,
      hour INTEGER,
      minute INTEGER
  )
  WITH CONNECTION `us.biglake-connection`
  OPTIONS(
    hive_partition_uri_prefix = "gs://sample-shared-data-query-acceleration/taxi-trips-query-acceleration/",
    uris=['gs://sample-shared-data-query-acceleration/taxi-trips-query-acceleration/*.parquet'], 
    metadata_cache_mode="AUTOMATIC", 
    max_staleness=INTERVAL '1' HOUR,
    format="PARQUET");


-- External table WITHOUT query acceleration
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `bigquery_preview_features.biglake_no_acceleration`
  WITH PARTITION COLUMNS (
      year  INTEGER, 
      month INTEGER,
      day INTEGER,
      hour INTEGER,
      minute INTEGER
  )
  OPTIONS(
    hive_partition_uri_prefix = "gs://sample-shared-data-query-acceleration/taxi-trips-query-acceleration/",
    uris=['gs://sample-shared-data-query-acceleration/taxi-trips-query-acceleration/*.parquet'], 
    format="PARQUET");


--------------------------------------------------------------------------------
-- Query 1
--------------------------------------------------------------------------------

-- NO ACCELERATION
-- Duration: 3 min 22 sec 
-- Bytes processed: 1.36 KB
SELECT *
  FROM `bigquery_preview_features.biglake_no_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1
   AND hour   = 0
   AND minute = 0;


-- WITH ACCELERATION
-- Duration 1 sec 
-- Bytes processed: 1.36 KB 
-- Bytes billed: 10 MB 
SELECT *
  FROM `bigquery_preview_features.biglake_query_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1
   AND hour   = 0
   AND minute = 0;


--------------------------------------------------------------------------------
-- Query 2
--------------------------------------------------------------------------------

-- NO ACCELERATION
-- Duration: 3 min 21 se
-- Bytes processed: 184.76 KB 
SELECT *
  FROM `bigquery_preview_features.biglake_no_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1
   AND hour   = 0;


-- WITH ACCELERATION
-- Duration: 3 sec 
-- Bytes processed: 184.76 KB 
SELECT *
  FROM `bigquery_preview_features.biglake_query_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1
   AND hour   = 0;


--------------------------------------------------------------------------------
-- Query 3
--------------------------------------------------------------------------------

-- NO ACCELERATION
-- Duration: 3 min 24 sec 
-- Bytes processed: 3.77 MB 
SELECT *
  FROM `bigquery_preview_features.biglake_no_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1;


-- WITH ACCELERATION
-- Duration: 3 sec 
-- Bytes processed: 3.77 MB 
SELECT *
  FROM `bigquery_preview_features.biglake_query_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1;

END;
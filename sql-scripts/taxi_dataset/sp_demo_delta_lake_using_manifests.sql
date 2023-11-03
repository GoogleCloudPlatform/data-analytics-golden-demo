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
  YouTube:
      - https://youtu.be/wLKlR211FUc
      
  Use Cases:
      - Customers that use Databricks typically use Delta.io (aka Delta Lake format)
      - This shows how BigQuery can read Delta.io using Manifest Support (Hive partitioning is supported for both the data and manifest files)
  
      - Delta.io format consists of parquet files (which BigQuery can read) along with logs files that track changes to the parquet files over time.  
        A delta directory has many parquet files some of which are logically deleted.
        So, if you read all the parquet files, you end up with too much data.  The manifest tells you which files contain the latest data (not logically deleted).
  
      - How it works:
        You will issue a Delta command to create a manifest file (or files if the data is partitioned)
        You are responsible for generating and keeping the manifest up to date.
              Databricks is capable of keeping the manifest file up to date automatically, but you need to issue a command like the following:
              ALTER TABLE delta.`<path-to-delta-table>` SET TBLPROPERTIES(delta.compatibility.symlinkFormatManifest.enabled=true)
        An external table will be created over the parquet files / manifest files
  
  Description: 
      - NOTE: Customers must generate a manifest file for this to work.  This is done in Databricks or with their Delta.io SDK.
  
  Reference:
      - https://cloud.google.com/blog/products/data-analytics/bigquery-manifest-file-support-for-open-table-format-queries
  
  Clean up / Reset script:
      DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.delta_io_trips`;
      DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`;
      DROP MATERIALIZED VIEW IF EXISTS `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached_mv`;
  
  Sample PySpark code to generate a manifest:
      %python
      from delta.tables import *
  
      spark.conf.set("spark.databricks.delta.symlinkFormatManifest.fileSystemCheck.enabled", False)
  
      # Generate manifest
      deltaTable = DeltaTable.forPath(spark,"gs://${bucket_name}/delta_io/rideshare_trips/")
      deltaTable.generate("symlink_format_manifest")
  */
  

-- Open this link in a new tab: https://console.cloud.google.com/storage/browser/${bucket_name}/delta_io?project=${project_id}
-- Here we have a Delta.io table that we want to query
-- The table is partitioned by 2 columns (see the partition columns and hive_partition_uri_prefix below)
-- Since the table is partitation the manifest files are also partitioned (see the "uris" below)
CREATE EXTERNAL TABLE IF NOT EXISTS `${project_id}.${bigquery_taxi_dataset}.delta_io_trips`
  WITH PARTITION COLUMNS (
    Rideshare_Vendor_Id INTEGER, 
    Pickup_Date         DATE-- column order must match the external path
    )
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
    hive_partition_uri_prefix = "gs://${bucket_name}/delta_io/rideshare_trips/",
    uris = ['gs://${bucket_name}/delta_io/rideshare_trips/_symlink_format_manifest/*/manifest'],
    file_set_spec_type = 'NEW_LINE_DELIMITED_MANIFEST',
    format="PARQUET");

-- Query the table just like a native table
-- You will get a metadata cache warning.  We will create a cached table in the next step.
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.delta_io_trips`;


-- Create the same table, but lets enable metadata caching.  
-- The metadata includes file names, partitioning information, and physical metadata from files such as row counts.
CREATE EXTERNAL TABLE IF NOT EXISTS `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`
  WITH PARTITION COLUMNS (
    Rideshare_Vendor_Id INTEGER, 
    Pickup_Date         DATE-- column order must match the external path
    )
WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
    hive_partition_uri_prefix = "gs://${bucket_name}/delta_io/rideshare_trips/",
    uris = ['gs://${bucket_name}/delta_io/rideshare_trips/_symlink_format_manifest/*/manifest'],
    file_set_spec_type = 'NEW_LINE_DELIMITED_MANIFEST',
    format="PARQUET",
    max_staleness=INTERVAL 30 MINUTE, 
    metadata_cache_mode="MANUAL" -- This can be setup to be 30 minutes or more
    );

-- Refresh can only be done for "manual" cache mode.  This is done since this is a demo.
CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached');


-- Now query the table again.  If this was a really large table we would see a speed improvement.
-- The reason we do caching is since Delta format can/will have lots of manifest files
-- Doing a storage listing and finding the manifest files slows down query performance
SELECT *
  FROM  `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`;


-- Understanding how to keep your data in sync
-- 1. Your process updates a delta.io table
-- 2. You need to trigger the manifest update from Databricks to GCS (the manifest directory)
-- 3. You need to trigger a BQ.REFRESH_EXTERNAL_METADATA_CACHE to update BigQuery

-- You can create a materialized view on the data
CREATE MATERIALIZED VIEW `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached_mv` 
OPTIONS (max_staleness=INTERVAL "0:30:0" HOUR TO SECOND)
AS
SELECT PULocationID,
       DOLocationID,
       AVG(Passenger_Count) AS Avg_Passenger_Count,
       AVG(Trip_Distance) AS Avg_Trip_Distance,
       AVG(Fare_Amount) AS Avg_Fare_Amount,
       AVG(Surcharge) AS Avg_Surcharge,
       AVG(MTA_Tax) AS Avg_MTA_Tax,
       AVG(Tip_Amount) AS Avg_Tip_Amount,
       AVG(Tolls_Amount) AS Avg_Tolls_Amount,
       AVG(Improvement_Surcharge) AS Avg_Improvement_Surcharge,
       AVG(Total_Amount) AS Avg_Total_Amount
FROM `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`
GROUP BY 1,2;


SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached_mv`;


-- Apply row level security (you can also do data masking and column level security)
CREATE OR REPLACE ROW ACCESS POLICY rls_delta_io_trips_cached
    ON `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`
    GRANT TO ("user:${gcp_account_name}") 
FILTER USING (PULocationID = 68);

-- See just the data you are allowed to access
SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`;

-- This also works through the materialized view
SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached_mv`;


-- Drop row level security
DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_taxi_dataset}.delta_io_trips_cached`;

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
    - Customers that use Databricks typically use Delta.io (aka Delta Lake format)
    - This shows how BigQuery can read Delta.io (Hive partitioning is supported for both the data and manifest files)
    - Time travel is not supported with this apporach

    - Delta.io format consists of parquet files (which BigQuery can read) along with logs files that track changes to the parquet files over time.  
      A delta directory has many parquet files some of which are logically deleted.
      So, if you read all the parquet files, you end up with too much data.  The delta logs tell you which files contain the latest data (not logically deleted).

    - How it works:
      You will issue a Delta command to create a manifest file (or files if the data is partitioned)
      You are responsible for generating and keeping the manifest up to date.
            Databricks is capable of keeping the manifest file up to date automatically, but you need to issue a command like the following:
            ALTER TABLE delta.`<path-to-delta-table>` SET TBLPROPERTIES(delta.compatibility.symlinkFormatManifest.enabled=true)
      An external table will be created over the parquet files
      An external table will be created over the manifest files
      A view will join the two tables together and filter the parquet files to the ones with the latest data.

Description: 
    - Shows creating a view that abtracts the Delta.io format
    - NOTE: Customers must generate a manifest file for this to work.  This is done in Databricks or with their Delta.io SDK.

Reference:
    - 

Clean up / Reset script:
    DROP VIEW IF EXISTS `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_raw_parquet`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_manifest`;

Sample PySpark code to generate a manifest:
    %python
    from delta.tables import *

    spark.conf.set("spark.databricks.delta.symlinkFormatManifest.fileSystemCheck.enabled", False)

    # Generate manifest
    deltaTable = DeltaTable.forPath(spark,"s3://${aws_omni_biglake_s3_bucket}/delta_io/rideshare_trips/")
    deltaTable.generate("symlink_format_manifest")
*/


-- Create an external table over the raw parquet files
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_aws"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_raw_parquet`
WITH PARTITION COLUMNS 
  (
  Rideshare_Vendor_Id INTEGER, 
  Pickup_Date         DATE-- column order must match the external path
  )
WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`
OPTIONS (
format = "PARQUET",
hive_partition_uri_prefix = "s3://${aws_omni_biglake_s3_bucket}/delta_io/rideshare_trips/",
uris = ['s3://${aws_omni_biglake_s3_bucket}/delta_io/rideshare_trips/*.snappy.parquet']
);

-- This shows all the data (including the logically deleted Delta.IO data which is incorrect)
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_raw_parquet` LIMIT 1000;

-- Returns 54521
SELECT COUNT(*) FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_raw_parquet`;

-- Create an external table over the generated manifest files which has pointers to the actual parquet files
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_aws"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_manifest`
WITH PARTITION COLUMNS (
  Rideshare_Vendor_Id INTEGER, 
  Pickup_Date         DATE-- column order must match the external path
)
WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`
OPTIONS (
format = "CSV", -- it is not really a CSV, it has just 1 column so CSV works
hive_partition_uri_prefix = "s3://${aws_omni_biglake_s3_bucket}/delta_io/rideshare_trips/_symlink_format_manifest/",
uris = ['s3://${aws_omni_biglake_s3_bucket}/delta_io/rideshare_trips/_symlink_format_manifest/*']
);

-- Show our manifest files
-- This will only have files that are not logically deleted by Delta.IO
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_manifest` LIMIT 100;


-- Create our Final View (This is what Users will work with in BigQuery)
-- This filter the parquet files by joining to the manifest (which only has pointers to non-logically deleted files)
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_aws"
CREATE OR REPLACE VIEW `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips` AS
SELECT *
FROM  `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_raw_parquet`
WHERE _FILE_NAME IN (SELECT REPLACE(string_field_0,'s3a://','s3://')
                      FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_manifest`) ;

/*
-- In Azure
CREATE OR REPLACE VIEW `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips` AS
SELECT *,
FROM  `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_raw_parquet`
WHERE REPLACE(_FILE_NAME, 
             'azure://STORAGE_ACCOUNT_NAME.blob.core.windows.net/CONTAINER_NAME', 
             'abfss://CONTAINER_NAME@STORAGE_ACCOUNT_NAME.dfs.core.windows.net')
           IN (SELECT string_field_0 FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_manifest`) ;

*/

-- This show the correct data (excludes logically deleted Delta.IO data)
-- The following query was done on the Delta data: DELETE FROM rideshare_trips WHERE PULocationID >= 100;
-- We should not have any PULocationIds >= 100 in our results

-- Show it works
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips` LIMIT 100;

-- Shows that we are not returning delete rows
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips` WHERE PULocationID >= 100 LIMIT 100;

-- Show the count 4521 as compared to the 54521 above
SELECT COUNT(*) FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips`;


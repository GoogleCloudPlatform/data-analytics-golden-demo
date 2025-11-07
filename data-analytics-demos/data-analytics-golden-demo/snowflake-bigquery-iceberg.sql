-- Step 1:
-- Login to Snowflake
-- Click the Create button on the top left
-- Select SQL Worksheet
-- Run this command to switch to an account admin since we have to run some commands that requires this role
USE ROLE accountadmin;


-- Step 2:
-- Create a warehouse to hold the data
-- https://docs.snowflake.com/en/sql-reference/sql/create-warehouse
CREATE OR REPLACE WAREHOUSE ICEBERG_WAREHOUSE WITH WAREHOUSE_SIZE='XSMALL';


-- Step 3:
-- Create a database (the database)
CREATE OR REPLACE DATABASE ICEBERG_DATABASE;


-- Step 4:
-- Create a bucket to hold your BigLake Managed Table
-- Open: https://console.cloud.google.com/storage/browser
-- Click the Create Bucket button
-- Enter your bucket name: iceberg-sharing-snowflake (you can choose a different name)
-- Click Next: Use Region: us-central1 <- must match your snowflake region
-- Click Create at the bottom


-- Step 5:
-- In Snowflake
-- Create our GCS volumne integration.  This will create a link between Snowflake and GCS. 
-- A service principal will be created and we will grant access to our GCS bucket.
-- https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration
CREATE STORAGE INTEGRATION bigquery_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://iceberg-sharing-snowflake');


-- Step 6:
-- Get the service principal that we will grant Storage Object Admin in our GCS bucket
DESC STORAGE INTEGRATION bigquery_integration;

-- Copy the STORAGE_GCP_SERVICE_ACCOUNT
-- e.g. xxxxxxxxx@gcpuscentral1-1dfa.iam.gserviceaccount.com


-- Step 7:
-- https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-external-volume-gcs?_fsi=YFzl41ld&_fsi=YFzl41ld&_fsi=YFzl41ld
-- Create a custom IAM role
-- Create a custom role that has the permissions required to access the bucket and get objects.
-- Open: https://console.cloud.google.com/iam-admin/roles
-- Select Create Role.
 -- Enter a Title and optional Description for the custom role. [e.g. Snowflake Storage Admin]
 -- Select Add Permissions.
 -- In Filter, select Service and then select storage.
   -- Filter the list of permissions, and add the following from the list:
   -- storage.buckets.get
   -- storage.objects.get
   -- storage.objects.create
   -- storage.objects.delete
   -- storage.objects.list
   -- Select Add.
 -- Select Create.


-- Step 8:
-- Open your storage account you created
-- Open: https://console.cloud.google.com/storage/browser
-- Click on: iceberg-sharing-snowflake (or whatever you named it)
-- Click on Permissions
-- Click Grant Access
-- Paste in the service account name (from Snowflake)
-- For the role select Custom | Snowflake Storage Admin
-- Click Save


-- Step 9:
-- In Snowflake
-- Create an external volume on GCS
-- https://docs.snowflake.com/en/sql-reference/sql/create-external-volume
CREATE EXTERNAL VOLUME snowflake_ext_volume
  STORAGE_LOCATIONS =
    (
      (
        NAME = 'us-central1'
        STORAGE_PROVIDER = 'GCS'
        STORAGE_BASE_URL = 'gcs://iceberg-sharing-snowflake/snowflake-volume/'
      )
    ),
    ALLOW_WRITES = TRUE;

-- Step 10:
-- Describe the volume
DESCRIBE EXTERNAL VOLUME snowflake_ext_volume

-- Step 11:
-- Set the current database
USE ICEBERG_DATABASE;
  
-- Step 12:
-- Create a schema in Snowflake
CREATE SCHEMA iceberg_schema;

-- Step 13:
-- Make the schema active
USE SCHEMA iceberg_schema;

-- Step 14:
-- Create Iceberg table using Snowflake Catalog
-- https://docs.snowflake.com/en/sql-reference/sql/create-iceberg-table-snowflake
CREATE ICEBERG TABLE driver (driver_id int, driver_name string)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'snowflake_ext_volume'
  BASE_LOCATION = 'driver';

-- Step 15:
-- This will show the table just created
SHOW TABLES

-- Step 16:
-- This will insert new data
INSERT INTO driver (driver_id, driver_name) VALUES (1, 'Driver 001');

SELECT * FROM driver;

-- Step 17:
-- This will tell us the latest metadata json file that Snowflake is pointing to
-- We need to point BigQuery to the same place
SELECT REPLACE(JSON_EXTRACT_PATH_TEXT(
          SYSTEM$GET_ICEBERG_TABLE_INFORMATION('ICEBERG_DATABASE.iceberg_schema.driver'),
          'metadataLocation'), 'gcs://', 'gs://');

-- Step 18:
-- Open your storage account you created
-- Open: https://console.cloud.google.com/storage/browser
-- Click on: iceberg-sharing-snowflake (or whatever you named it)
-- You can now browser the iceberg files


-- Step 19:
-- Create a BigQuery Dataset
CREATE SCHEMA IF NOT EXISTS snowflake_dataset OPTIONS(location = 'us-central1');


-- Step 20:
-- Navigate to BigQuery
-- Open: https://console.cloud.google.com/bigquery
-- Click the Add button
-- Select "Connections to external data sources"
   -- Select "Vertex AI remote models, remote functions and BigLake (Cloud Resource)"
   -- Select region: us-central1
   -- Enter a name: iceberg-connection-snowflake (use the for friendly name and description)


-- Step 21:
-- Expand your project in the left hand panel
-- Expand external connections
-- Double click on us-central1.iceberg-connection-snowflake
-- Copy the service account id: e.g. bqcx-xxxxxxxxxxxx-s3rf@gcp-sa-bigquery-condel.iam.gserviceaccount.com


-- Step 23:
-- Open your storage account you created
-- Open: https://console.cloud.google.com/storage/browser
-- Click on: blmt-snowflake-sharing (or whatever you named it)
-- Click on Permissions
-- Click Grant Access
-- Paste in the service account name
-- For the role select Cloud Storage | Storage Object Viewer [Since Snowflake is the write BigQuery just reads]
-- Click Save


-- Step 24:
-- The uris needs to be from the above Snowflake command
CREATE OR REPLACE EXTERNAL TABLE `snowflake_dataset.driver`
WITH CONNECTION `us-central1.iceberg-connection-snowflake`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://iceberg-sharing-snowflake/snowflake-volume/driver/metadata/00001-25a4ee54-8ebc-4551-b013-c3195b01d227.metadata.json"]
);


-- Step 25:
-- View the data in BQ
SELECT * FROM `snowflake_dataset.driver`;


-- Step 26:
-- Now if you add or update data in Snowflake, BigQuery will not see it since we are pointing to a specific snapshot or metadata json
-- You will need to run the "SYSTEM$GET_ICEBERG_TABLE_INFORMATION" command in Snowflake
-- You will then need to update BigQuery
-- https://cloud.google.com/bigquery/docs/iceberg-tables#update-table-metadata
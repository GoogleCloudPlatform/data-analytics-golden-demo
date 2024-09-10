-----------------------------------------------------------------------------------------------
-- Run this on Snowflake
-----------------------------------------------------------------------------------------------

-- Warehouse (this is the compute needed to run Snowflake)
-- https://docs.snowflake.com/en/sql-reference/sql/create-warehouse
CREATE OR REPLACE WAREHOUSE ICEBERG_WAREHOUSE WITH WAREHOUSE_SIZE='XSMALL';

-- Create a database (the database)
CREATE OR REPLACE DATABASE ICEBERG_DATABASE;

-- We need to run the below commands (for storage integration) as an Admin
USE ROLE accountadmin;

-- Create our GCS volumne integration.  This will create a link between Snowflake and GCS. 
-- A service principal will be created and we will grant access to our GCS bucket.
-- https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration
CREATE STORAGE INTEGRATION snowflake_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://data-analytics-preview-snowflake')
;

-- Get the service principal that we will grant Storage Object Admin in our GCS bucket
DESC STORAGE INTEGRATION snowflake_integration;

-- Copy the above store principal name
-- https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-external-volume-gcs?_fsi=YFzl41ld&_fsi=YFzl41ld&_fsi=YFzl41ld
-- Create a custom IAM role
-- Create a custom role that has the permissions required to access the bucket and get objects.
-- Log in to the Google Cloud Platform Console as a project editor.
-- From the home dashboard, select IAM & Admin » Roles.
-- Select Create Role.
  -- Enter a Title and optional Description for the custom role.
  -- Select Add Permissions.
  -- In Filter, select Service and then select storage.
    -- Filter the list of permissions, and add the following from the list:
    -- storage.buckets.get
    -- storage.objects.create
    -- storage.objects.delete
    -- storage.objects.get
    -- storage.objects.list
    -- Select Add.
  -- Select Create.

-- Assign the custom role to the GCS service account

-- Open your GCS bucket (e.g. data-analytics-preview-snowflake) click on Permissions and add the service principal
-- Select the role you just created

-- Create an external volume on GCS
-- https://docs.snowflake.com/en/sql-reference/sql/create-external-volume
CREATE EXTERNAL VOLUME snowflake_external_volume
  STORAGE_LOCATIONS =
    (
      (
        NAME = 'us-central1'
        STORAGE_PROVIDER = 'GCS'
        STORAGE_BASE_URL = 'gcs://data-analytics-preview-snowflake/snowflake-volume/'
      )
    ),
    ALLOW_WRITES = TRUE;

-- Describe the volume
DESCRIBE EXTERNAL VOLUME snowflake_external_volume

-- Set it to use the database
USE ICEBERG_DATABASE;
  
-- Create and use a schema
CREATE SCHEMA iceberg_schema;
USE SCHEMA iceberg_schema;

-- Create Iceberg table using Snowflake Catalog
-- https://docs.snowflake.com/en/sql-reference/sql/create-iceberg-table-snowflake
CREATE ICEBERG TABLE driver_iceberg (driver_id int, driver_name string)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'snowflake_external_volume'
  BASE_LOCATION = 'driver_iceberg';

-- This will show the table just created
SHOW TABLES

-- This will insert new data
INSERT INTO driver_iceberg (driver_id, driver_name) VALUES (1, 'Driver 001');

-- This will tell us the latest metadata json file that Snowflake is pointing to
-- We need to point BigQuery to the same place
SELECT JSON_EXTRACT_PATH_TEXT(
          SYSTEM$GET_ICEBERG_TABLE_INFORMATION('ICEBERG_DATABASE.iceberg_schema.driver_iceberg'),
          'metadataLocation')

          

-----------------------------------------------------------------------------------------------
-- Run this on BigQuery
-----------------------------------------------------------------------------------------------
-- The uris needs to be from the above Snowflake command
CREATE OR REPLACE EXTERNAL TABLE `snowflake_managed_tables.driver_iceberg`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://data-analytics-preview-snowflake/snowflake-volume/driver_iceberg/metadata/00001-3b2dc4b1-b873-48e4-ac4d-c1748e77dd4b.metadata.json"]
);

-- View the data in BQ
SELECT * FROM `snowflake_managed_tables.driver_iceberg`;

-- Now if you add or update data in Snowflake, BigQuery will not see it since we are pointing to a specific snapshot or metadata json
-- You will need to run the "SYSTEM$GET_ICEBERG_TABLE_INFORMATION" command in Snowflake
-- You will then need to update BigQuery
-- https://cloud.google.com/bigquery/docs/iceberg-tables#update-table-metadata

-- You can create a cloud function that Snowflake calls, run a cloud function on a timer that calls to Snowflake and then calls to BigQuery
-- The approach is up to you.
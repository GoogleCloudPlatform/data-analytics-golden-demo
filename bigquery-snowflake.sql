-----------------------------------------------------------------------------------------------
-- Run this on BigQuery
-----------------------------------------------------------------------------------------------
- Create Cloud Resource Connection
-- BigLake tables access Google Cloud Storage data using a Cloud Resource connection. 
-- A connection can be associated with multiple tables within a project.
-- This command creates a connection named "my-connection" in the "US" location.
bq mk --connection --location=US --project_id=my-project-id --connection_type=CLOUD_RESOURCE my-connection

-- Create GCS bucket in the same region as the BigQuery dataset.  This bucket will hold the Parquet files.
-- Note: Replace `mybucket` with your desired bucket name.

-- Grant the BigLake connection service account necessary IAM permissions to access the GCS bucket.
-- The 'storage.admin' role grants full control over the bucket. Consider using a more restrictive role
-- like 'storage.objectAdmin' if only object-level access is required.
gcloud storage buckets add-iam-policy-binding gs://mybucket --member=serviceAccount:connection-1234-9u56h9@gcp-sa-bigquery-condel.iam.gserviceaccount.com \
  --role=roles/storage.admin


-- Create a BigLake managed table named "driver".
-- This table uses the previously created Cloud Resource connection "biglake-notebook-connection".
-- It's configured to store data in Parquet format using the Iceberg table format.
-- Data will be stored in the specified GCS location.
CREATE OR REPLACE TABLE `mbettan-477-20240819200355.biglake_mt_dataset.driver`
(
  driver_id                 INT64,
  driver_name               STRING,
  driver_mobile_number      STRING,
  driver_license_number     STRING,
  driver_email_address      STRING,
  driver_dob                DATE,
  driver_ach_routing_number STRING,
  driver_ach_account_number STRING
)
CLUSTER BY driver_id
WITH CONNECTION `mbettan-477-20240819200355.us.biglake-notebook-connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://biglake-mbettan-477-20240819200355/biglake-managed-tables/driver'
);


-- Load data into the BigLake managed table from Parquet files in GCS.
-- Ensure the source data matches the table schema.
LOAD DATA INTO `biglake_mt_dataset.driver`
FROM FILES (
  format = 'parquet',
  uris = ['gs://data-analytics-golden-demo/biglake/v1-source/managed-table-source/driver/*.parquet']);


-- Export the Iceberg metadata for the BigLake managed table.
-- This generates metadata files in the "metadata" folder under the table's `storage_uri`.
-- This metadata is crucial for Iceberg's table management and time-travel capabilities.
EXPORT TABLE METADATA FROM biglake_mt_dataset.driver

-- The Iceberg metadata is now located in the GCS location specified by the table's `storage_uri` within a "metadata" folder.
--  Example: gs://biglake-mbettan-477-20240819200355/biglake-managed-tables/driver/metadata/
-- This path is important for any tools or systems that need to interact with the table using Iceberg.


-----------------------------------------------------------------------------------------------
-- Run this on Snowflake
-----------------------------------------------------------------------------------------------

-- We need to run the below commands (for storage integration) as an Admin
USE ROLE accountadmin;

-- Warehouse (this is the compute needed to run Snowflake)
-- https://docs.snowflake.com/en/sql-reference/sql/create-warehouse
CREATE OR REPLACE WAREHOUSE ICEBERG_WAREHOUSE WITH WAREHOUSE_SIZE='XSMALL';

-- Drop existing storage integration and external volume to avoid conflicts
USE SCHEMA INFORMATION_SCHEMA;
USE DATABASE ICEBERG_LAB2;
DROP ICEBERG TABLE IF EXISTS my_iceberg_table2;
DROP STORAGE INTEGRATION IF EXISTS gcs_storage_integration;
DROP EXTERNAL VOLUME IF EXISTS iceberg_volume;

-- Create our GCS volumne integration.  This will create a link between Snowflake and GCS. 
-- A service principal will be created and we will grant access to our GCS bucket.
-- https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration
CREATE STORAGE INTEGRATION gcs_storage_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://biglake-mbettan-477-20240819200355/');

-- Get the service principal that we will grant Storage Object Admin in our GCS bucket
DESC STORAGE INTEGRATION gcs_storage_integration;

-- Create an external volume on GCS
-- https://docs.snowflake.com/en/sql-reference/sql/create-external-volume
CREATE OR REPLACE EXTERNAL VOLUME iceberg_volume
   STORAGE_LOCATIONS =
      (
         (
            NAME = 'youriceberglab'
            STORAGE_PROVIDER = 'GCS'
            STORAGE_BASE_URL = 'gcs://biglake-mbettan-477-20240819200355/'
            )
      );

-- Describe the volume
DESCRIBE EXTERNAL VOLUME iceberg_volume

-- Create a catalog integration to manage Iceberg tables in the external volume
CREATE OR REPLACE CATALOG INTEGRATION gcs_catalog_integration
    CATALOG_SOURCE=OBJECT_STORE  -- Indicates that the catalog is backed by an object store
    TABLE_FORMAT=ICEBERG        -- Specifies the table format as Iceberg
    ENABLED=TRUE;               -- Enables the catalog integration

-- Create a database to hold the Iceberg table
CREATE DATABASE IF NOT EXISTS iceberg_lab2;
USE DATABASE iceberg_lab2;

-- Create the Iceberg table, pointing to the existing metadata file
CREATE OR REPLACE ICEBERG TABLE my_iceberg_table2
    CATALOG='gcs_catalog_integration'   -- The catalog where the table will reside
    EXTERNAL_VOLUME='iceberg_volume'      -- The external volume for table data
    BASE_LOCATION=''                      -- Optional: Subdirectory within the storage location
    METADATA_FILE_PATH='biglake-managed-tables/driver/metadata/v1726539996.metadata.json'; -- Path to the existing metadata file

-- This will show the table just created
SHOW TABLES

-- Query the Iceberg table 
SELECT * FROM my_iceberg_table2;

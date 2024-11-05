-- Step 1:
-- Create a bucket to hold your BigLake Managed Table
-- Open: https://console.cloud.google.com/storage/browser
-- Click the Create Bucket button
-- Enter your bucket name: blmt-snowflake-sharing (you can choose a different name)
-- Click Next: Use Multi-region: us
-- Click Create at the bottom


-- Step 2:
-- Navigate to BigQuery
-- Open: https://console.cloud.google.com/bigquery
-- Click the Add button
-- Select "Connections to external data sources"
   -- Select "Vertex AI remote models, remote functions and BigLake (Cloud Resource)"
   -- Enter a name: blmt-connection (use the for friendly name and description)


-- Step 3:
-- Expand your project in the left hand panel
-- Expand external connections
-- Double click on us.blmt-connection
-- Copy the service account id: e.g. bqcx-xxxxxxxxxxxx-s3rf@gcp-sa-bigquery-condel.iam.gserviceaccount.com


-- Step 4:
-- Open your storage account you created
-- Open: https://console.cloud.google.com/storage/browser
-- Click on: blmt-snowflake-sharing (or whatever you named it)
-- Click on Permissions
-- Click Grant Access
-- Paste in the service account name
-- For the role select Cloud Storage | Storage Object Admin [We want admin since we want Read/Write]
-- Click Save


-- Step 5:
-- Navigate to BigQuery
-- Open: https://console.cloud.google.com/bigquery
-- Open a query window:
-- Run this to create a dataset
CREATE SCHEMA IF NOT EXISTS blmt_dataset OPTIONS(location = 'us');


-- Step 6:
-- Run this to create a BigLake Managed table (change the storage account name below)
CREATE OR REPLACE TABLE `blmt_dataset.driver`
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
WITH CONNECTION `us.blmt-connection`
OPTIONS (
 file_format = 'PARQUET',
 table_format = 'ICEBERG',
 storage_uri = 'gs://blmt-snowflake-sharing/driver'
);


-- Step 7:
-- Load the table with some data
LOAD DATA INTO `blmt_dataset.driver`
FROM FILES (
 format = 'parquet',
 uris = ['gs://data-analytics-golden-demo/biglake/v1-source/managed-table-source/driver/*.parquet']);


-- View the data
SELECT * FROM `blmt_dataset.driver` LIMIT 1000;


-- Step 8:
-- View the storage account
-- Open: https://console.cloud.google.com/storage/browser and click on your storage account
-- You should see a folder called "driver"
-- You can  navigate to the "metadata" folder
-- You will probably see the file "v0.metadata.json"


-- To export the most recent metadata run this in BigQuery (a seperate window is preferred)
EXPORT TABLE METADATA FROM blmt_dataset.driver;


-- In your storage window
-- Press the Refresh button (top right)
-- You will not see many files in the metadata folder




-- Step 9:
-- Let's connect the data to Snowflake
-- Login to Snowflake
-- Click the Create button on the top left
-- Select SQL Worksheet
-- Run this command to switch to an account admin since we have to run some commands that requires this role
USE ROLE accountadmin;


-- Step 10:
-- Create a warehouse to hold the data
CREATE OR REPLACE WAREHOUSE BLMT_WAREHOUSE WITH WAREHOUSE_SIZE='XSMALL';


-- Step 11:
-- Create a database in snowflake
CREATE OR REPLACE DATABASE BLMT_DATABASE;


-- Step 12:
-- Select the database
USE DATABASE BLMT_DATABASE;


-- Step 13:
-- Create the schema to hold the table
CREATE SCHEMA IF NOT EXISTS BLMT_SCHEMA;


-- Step 14:
-- Select the schema
USE SCHEMA BLMT_SCHEMA;


-- Step 15:
-- Create our GCS volume integration.  This will create a link between Snowflake and GCS.
-- A service principal will be created and we will grant access to our GCS bucket.
-- https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration
-- Change the name of the storage account
CREATE STORAGE INTEGRATION gcs_storage_integration
 TYPE = EXTERNAL_STAGE
 STORAGE_PROVIDER = 'GCS'
 ENABLED = TRUE
 STORAGE_ALLOWED_LOCATIONS = ('gcs://blmt-snowflake-sharing/');


-- Step 16:
-- Get the service principal that we will grant Storage Object Admin in our GCS bucket
DESC STORAGE INTEGRATION gcs_storage_integration;

-- Copy the STORAGE_GCP_SERVICE_ACCOUNT
-- e.g. xxxxxxxxx@gcpuscentral1-1dfa.iam.gserviceaccount.com




-- Step 17:
-- https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-external-volume-gcs?_fsi=YFzl41ld&_fsi=YFzl41ld&_fsi=YFzl41ld
-- Create a custom IAM role
-- Create a custom role that has the permissions required to access the bucket and get objects.
-- Open: https://console.cloud.google.com/iam-admin/roles
-- Select Create Role.
 -- Enter a Title and optional Description for the custom role. [e.g. Snowflake Reader]
 -- Select Add Permissions.
 -- In Filter, select Service and then select storage.
   -- Filter the list of permissions, and add the following from the list:
   -- storage.buckets.get
   -- storage.objects.get
   -- storage.objects.list
   -- Select Add.
 -- Select Create.


-- Step 18:
-- Open your storage account you created
-- Open: https://console.cloud.google.com/storage/browser
-- Click on: blmt-snowflake-sharing (or whatever you named it)
-- Click on Permissions
-- Click Grant Access
-- Paste in the service account name (from Snowflake)
-- For the role select Custom | Snowflake Reader
-- Click Save


-- Step 19:
-- Create an external volume on GCS
-- https://docs.snowflake.com/en/sql-reference/sql/create-external-volume
CREATE OR REPLACE EXTERNAL VOLUME gcs_volume
  STORAGE_LOCATIONS =
     (
        (
           NAME = 'gcs_volume'
           STORAGE_PROVIDER = 'GCS'
           STORAGE_BASE_URL = 'gcs://blmt-snowflake-sharing/'
           )
     );


-- Step 20:
-- Create a catalog integration to manage Iceberg tables in the external volume
CREATE OR REPLACE CATALOG INTEGRATION catalog_integration
   CATALOG_SOURCE=OBJECT_STORE   -- Indicates that the catalog is backed by an object store
   TABLE_FORMAT=ICEBERG          -- Specifies the table format as Iceberg
   ENABLED=TRUE;                 -- Enables the catalog integration


-- Step 21:
-- Create the Iceberg table, pointing to the existing metadata file
-- To get the "latest" metadata file
-- Open your storage account and navigate to the driver/metadata folder
-- Open the version-hint.text, there will be a number inside
-- Replace the number below (in the value of v173076288, but leave the "v")
CREATE OR REPLACE ICEBERG TABLE driver
   CATALOG='catalog_integration'   -- The catalog where the table will reside
   EXTERNAL_VOLUME='gcs_volume'    -- The external volume for table data
   BASE_LOCATION=''                -- Optional: Subdirectory within the storage location
   METADATA_FILE_PATH='driver/metadata/v1730762887.metadata.json'; -- Path to the existing metadata file


-- Step 22:
-- This will show the table just created
SHOW TABLES


-- Step 23:
-- Query the Iceberg table
SELECT * FROM driver;


SELECT COUNT(*) FROM driver;


-- Now that you are linked, you can try the following
-- Insert a record into the BigQuery table:
INSERT INTO `blmt_dataset.driver`
(driver_id, driver_name, driver_mobile_number, driver_license_number, driver_email_address,
driver_dob, driver_ach_routing_number, driver_ach_account_number)
VALUES (0, 'New Driver', 'xxx-xxx-xxxx', 'driver_license_number', 'driver_email_address',
CURRENT_DATE(), 'driver_ach_routing_number','driver_ach_account_number');


-- Now Query the record in Snowflake
SELECT * FROM driver WHERE driver_id = 0;


– You will not see the new record
-- You first need to tell BigQuery to export the latest metadata (Step 8).
-- Update the metadata used by Snowflake (Step 21) pointing to the latest JSON file

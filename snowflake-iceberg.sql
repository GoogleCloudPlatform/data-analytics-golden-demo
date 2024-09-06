-- Warehouse
-- https://docs.snowflake.com/en/sql-reference/sql/create-warehouse
CREATE OR REPLACE WAREHOUSE ICEBERG_WAREHOUSE WITH WAREHOUSE_SIZE='XSMALL';

-- role
CREATE ROLE iceberg_lab;

-- Create a database
CREATE OR REPLACE DATABASE ICEBERG_DATABASE;

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

-- https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-external-volume-gcs?_fsi=YFzl41ld&_fsi=YFzl41ld&_fsi=YFzl41ld
-- Object admin does not work

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


-- Set it to use
USE ICEBERG_DATABASE;
  
-- Optional
--ALTER DATABASE ICEBERG_DATABASE SET EXTERNAL_VOLUME = 'snowflake_external_volume_001';

CREATE SCHEMA iceberg_schema;
USE SCHEMA iceberg_schema;

-- Create Iceberg table using Snowflake Catalog
-- https://docs.snowflake.com/en/sql-reference/sql/create-iceberg-table-snowflake
CREATE ICEBERG TABLE driver_iceberg (driver_id int, driver_name string)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'snowflake_external_volume'
  BASE_LOCATION = 'driver_iceberg';


SHOW TABLES

INSERT INTO driver_iceberg (driver_id, driver_name) VALUES (1, 'Adam');

SELECT JSON_EXTRACT_PATH_TEXT(
          SYSTEM$GET_ICEBERG_TABLE_INFORMATION('ICEBERG_DATABASE.iceberg_schema.driver_iceberg'),
          'metadataLocation')

          


CREATE OR REPLACE EXTERNAL TABLE `snowflake_managed_tables.driver_iceberg`
OPTIONS (
  format = "ICEBERG",
  uris = ["gs://data-analytics-preview-snowflake/snowflake-volume/driver_iceberg/metadata/00001-3b2dc4b1-b873-48e4-ac4d-c1748e77dd4b.metadata.json"]
);


SELECT * FROM `snowflake_managed_tables.driver_iceberg`;
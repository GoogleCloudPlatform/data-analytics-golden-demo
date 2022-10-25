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
Author: Adam Paternostro 

Use Cases:
    - Create tables located in a different cloud

Description: 
    - Create table for BQ OMNI with taxi data for different file formats and hive partitioning
    - There is a bucket named "sample-shared-data" in this project which you can view
      - The bucket shows the layout of the files on AWS and Azure (Azure has a blob container named "datalake")
      - So even though you do not have access to the data, the files are in this project so you can see the hive partitioning

Show:
    - Just like regular BQ external tables

References:
    - https://cloud.google.com/bigquery/docs/omni-aws-create-external-table

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_cls`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_rls`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_rls`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_cls`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_rls`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_cls`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_vendor`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_rate_code`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_payment_type`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_trip_type`;
*/

-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/*.parquet']
);

-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_cls`
WITH PARTITION COLUMNS 
/* Use auto detect for now
(
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
*/
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/*.parquet']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_rls`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/*.parquet']
);



CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv`
(
    Vendor_Id	            INTEGER,
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Passenger_Count	        INTEGER,
    Trip_Distance	        NUMERIC,
    Rate_Code_Id	        INTEGER,	
    Store_And_Forward	    STRING,
    PULocationID	        INTEGER,	
    DOLocationID	        INTEGER,
    Payment_Type_Id	        INTEGER,
    Fare_Amount	            NUMERIC,
    Surcharge	            NUMERIC,
    MTA_Tax	                NUMERIC,
    Tip_Amount	            NUMERIC,
    Tolls_Amount	        NUMERIC,
    Improvement_Surcharge	NUMERIC,
    Total_Amount	        NUMERIC,
    Congestion_Surcharge	NUMERIC
)
WITH PARTITION COLUMNS 
(
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/*.csv']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_rls`
(
    Vendor_Id	            INTEGER,
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Passenger_Count	        INTEGER,
    Trip_Distance	        NUMERIC,
    Rate_Code_Id	        INTEGER,	
    Store_And_Forward	    STRING,
    PULocationID	        INTEGER,	
    DOLocationID	        INTEGER,
    Payment_Type_Id	        INTEGER,
    Fare_Amount	            NUMERIC,
    Surcharge	            NUMERIC,
    MTA_Tax	                NUMERIC,
    Tip_Amount	            NUMERIC,
    Tolls_Amount	        NUMERIC,
    Improvement_Surcharge	NUMERIC,
    Total_Amount	        NUMERIC,
    Congestion_Surcharge	NUMERIC
)
WITH PARTITION COLUMNS 
(
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)

WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/*.csv']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_cls`
(
    Vendor_Id	            INTEGER,
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Passenger_Count	        INTEGER,
    Trip_Distance	        NUMERIC,
    Rate_Code_Id	        INTEGER,	
    Store_And_Forward	    STRING,
    PULocationID	        INTEGER,	
    DOLocationID	        INTEGER,
    Payment_Type_Id	        INTEGER,
    Fare_Amount	            NUMERIC,
    Surcharge	            NUMERIC,
    MTA_Tax	                NUMERIC,
    Tip_Amount	            NUMERIC,
    Tolls_Amount	        NUMERIC,
    Improvement_Surcharge	NUMERIC,
    Total_Amount	        NUMERIC,
    Congestion_Surcharge	NUMERIC
)
WITH PARTITION COLUMNS 
/*
(
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
*/
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/*.csv']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json`
(
    Vendor_Id	            INTEGER,
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Passenger_Count	        INTEGER,
    Trip_Distance	        NUMERIC,
    Rate_Code_Id	        INTEGER,	
    Store_And_Forward	    STRING,
    PULocationID	        INTEGER,	
    DOLocationID	        INTEGER,
    Payment_Type_Id	        INTEGER,
    Fare_Amount	            NUMERIC,
    Surcharge	            NUMERIC,
    MTA_Tax	                NUMERIC,
    Tip_Amount	            NUMERIC,
    Tolls_Amount	        NUMERIC,
    Improvement_Surcharge	NUMERIC,
    Total_Amount	        NUMERIC,
    Congestion_Surcharge	NUMERIC
)
WITH PARTITION COLUMNS (
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/*.json']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_rls`
(
    Vendor_Id	            INTEGER,
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Passenger_Count	        INTEGER,
    Trip_Distance	        NUMERIC,
    Rate_Code_Id	        INTEGER,	
    Store_And_Forward	    STRING,
    PULocationID	        INTEGER,	
    DOLocationID	        INTEGER,
    Payment_Type_Id	        INTEGER,
    Fare_Amount	            NUMERIC,
    Surcharge	            NUMERIC,
    MTA_Tax	                NUMERIC,
    Tip_Amount	            NUMERIC,
    Tolls_Amount	        NUMERIC,
    Improvement_Surcharge	NUMERIC,
    Total_Amount	        NUMERIC,
    Congestion_Surcharge	NUMERIC
)
WITH PARTITION COLUMNS (
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/*.json']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_cls`
(
    Vendor_Id	            INTEGER,
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Passenger_Count	        INTEGER,
    Trip_Distance	        NUMERIC,
    Rate_Code_Id	        INTEGER,	
    Store_And_Forward	    STRING,
    PULocationID	        INTEGER,	
    DOLocationID	        INTEGER,
    Payment_Type_Id	        INTEGER,
    Fare_Amount	            NUMERIC,
    Surcharge	            NUMERIC,
    MTA_Tax	                NUMERIC,
    Tip_Amount	            NUMERIC,
    Tolls_Amount	        NUMERIC,
    Improvement_Surcharge	NUMERIC,
    Total_Amount	        NUMERIC,
    Congestion_Surcharge	NUMERIC
)
WITH PARTITION COLUMNS 
/* Use auto detect for now
(
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
*/
WITH CONNECTION `${azure_omni_biglake_connection}`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/*.json']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_vendor`
WITH CONNECTION `${azure_omni_biglake_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/vendor_table/*.parquet']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_rate_code`
WITH CONNECTION `${azure_omni_biglake_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/rate_code_table/*.parquet']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_payment_type`
WITH CONNECTION `${azure_omni_biglake_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/payment_type_table/*.parquet']
);


-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_azure"
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_trip_type`
WITH CONNECTION `${azure_omni_biglake_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${azure_omni_biglake_adls_name}.blob.core.windows.net/datalake/taxi-data/trip_type_table/*.parquet']
);


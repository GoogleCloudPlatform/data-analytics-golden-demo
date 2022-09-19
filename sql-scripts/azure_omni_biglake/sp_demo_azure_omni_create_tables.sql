CREATE OR REPLACE PROCEDURE `azure_omni_biglake.sp_demo_azure_omni_create_tables`()
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
Author: Adam Paternostro 

Use Cases:
    - Create tables located in a different cloud

Description: 
    - Create table for BQ OMNI with taxi data for different file formats and hive partitioning

Show:
    - Just like regular BQ external tables

References:
    - https://cloud.google.com/bigquery/docs/omni-aws-create-external-table

Clean up / Reset script:
    - Please do not DROP
*/

CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_parquet`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/*.parquet']
);

CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_parquet_cls`
WITH PARTITION COLUMNS 
/* Use auto detect for now
(
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
*/
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_parquet_rls`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/parquet/*.parquet']
);



CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_csv`
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
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/*.csv']
);



CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_csv_rls`
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

WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/*.csv']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_csv_cls`
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
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/csv/*.csv']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_json`
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
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/*.json']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_json_rls`
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
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/*.json']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_yellow_trips_json_cls`
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
WITH CONNECTION `${omni_azure_connection}`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/yellow/trips_table/json/*.json']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_vendor`
WITH CONNECTION `${omni_azure_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/vendor_table/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_rate_code`
WITH CONNECTION `${omni_azure_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/rate_code_table/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_payment_type`
WITH CONNECTION `${omni_azure_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/payment_type_table/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `azure_omni_biglake.taxi_azure_trip_type`
WITH CONNECTION `${omni_azure_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-data/trip_type_table/*.parquet']
);



END;
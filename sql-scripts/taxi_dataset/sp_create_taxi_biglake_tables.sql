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
    - BigLake are great for querying data on cloud storage (files, Hive, etc.)
    - BigLake tables make loading data easy
    - BigLake tables make security easy on GCS, only the connection needs access to BigLake

Description: 
    - This will create external tables over "Hive" partitioned tables on storage.
    - Customers with Hadoop/Spark/Hive ecosystem can query their data in place using BigQuery.

Show:
    - BQ supports Avro, Csv (any delimiated, tab, pipes, etc.), Google Sheets, Json, Orc, Parquet
    - No need to setup special security with data sources and storage keys, etc.  Seemless security.

References:
    - https://cloud.google.com/bigquery/docs/hive-partitioned-queries-gcs

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_random_name`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips_parquet`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_csv`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_json`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_parquet`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_vendor`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_rate_code`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_payment_type`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_trip_type`;
*/

-- Create random name table for taxi driver's name and reviewer name
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_random_name`
(
    name STRING
)
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 0,
    uris = ['gs://${raw_bucket_name}/random_names/*.csv']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips_parquet`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/parquet/",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/parquet/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_csv`
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
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "CSV",
    field_delimiter = ',',
    skip_leading_rows = 1,
    hive_partition_uri_prefix = "gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/csv/",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/csv/*.csv']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_json`
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
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "JSON",
    hive_partition_uri_prefix = "gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/json/",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/json/*.json']
);



CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_parquet`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/parquet/",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/parquet/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_vendor`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
    format = "PARQUET",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/vendor_table/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_rate_code`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
    format = "PARQUET",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/rate_code_table/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_payment_type`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
    format = "PARQUET",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/payment_type_table/*.parquet']
);


CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_trip_type`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
    format = "PARQUET",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/trip_type_table/*.parquet']
);

CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_location`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
    format = "PARQUET",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/location/*.parquet']
);


-- Query External Tables
SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_csv` 
 WHERE year=2020
   AND month=1
 LIMIT 100;


SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_json` 
 WHERE year=2020
   AND month=1
 LIMIT 100;


 SELECT * 
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_yellow_trips_parquet` 
 WHERE year=2020
   AND month=1
 LIMIT 100;


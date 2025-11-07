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
      DROP EXTERNAL TABLE IF EXISTS `${project_id}.???.???`;

  */
  
-- Create a BigLake table over the PARQUET data  
  CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_parquet`
  WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
  OPTIONS (
      format = "PARQUET",
      uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/parquet/*.parquet']
  );
  
  
 -- Create a BigLake table over the AVRO data  
  CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_avro`
  WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
  OPTIONS (
      format = "AVRO",
      uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/avro/*.avro']
  );


-- Create a BigLake table over the JSON data
  CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_json`
  (
      rideshare_trip_id STRING,
      pickup_location_id INTEGER,
      pickup_datetime TIMESTAMP,
      dropoff_location_id INTEGER,
      dropoff_datetime TIMESTAMP,
      ride_distance 	BIGNUMERIC,
      is_airport BOOLEAN,
      payment_type_id INTEGER,
      fare_amount 	BIGNUMERIC,
      tip_amount 	BIGNUMERIC,
      taxes_amount 	BIGNUMERIC,
      total_amount 	BIGNUMERIC,
      partition_date DATE 
  )
  WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
  OPTIONS (
      format = "JSON",
      uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/json/*.json']
  );
  

-- Create a BigLake table over the Payment Type
  CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json`
  (
      payment_type_id INTEGER,
      payment_type_description STRING
  )
  WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
  OPTIONS (
      format = "JSON",
      uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_payment_type/*.json']
  );
  

-- Create a BigLake table over the Zone data
  CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`
  (
      location_id INTEGER,
      borough STRING,
      zone STRING,
      service_zone STRING
  )
  WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
  OPTIONS (
    format = "CSV",
    field_delimiter = '|',
    skip_leading_rows = 1,
    uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_zone/*.csv']
  );
  
  

  -- Query BigLake Tables
 SELECT * 
   FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_parquet`
  WHERE partition_date = '2022-01-01'
  LIMIT 100;
 
 /* This might change to a date in the future.
 SELECT * 
   FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_avro`
  WHERE partition_date = 18718
  LIMIT 100;
 */

 SELECT * 
   FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_json`
  WHERE partition_date = '2020-01-01'
  LIMIT 100;


 SELECT * 
   FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json`;
  

  SELECT * 
   FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;

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
YouTube:
    - https://youtu.be/bMS4p2XHMpE

Use Cases:
    - General overview of BigQuery recent features
    
Running this demo:
    - Start the Spanner Airflow DAG: sample-bigquery-start-spanner (takes about 10 minutes to deploy and shuts down after 4 hours)
    - Start the Datastream Airflow DAG: sample-datastream-private-ip-deploy (takes about 10 minutes to deploy)
        - Start the Change Data Capture (generate data) DAG: sample-datastream-private-ip-generate-data (starts immedately)
    - Start the Dataflow Airflow DAG: sample-dataflow-start-streaming-job (takes about 10 minutes to deploy and shuts down after 4 hours)
    - Upload the notebook from the code bucket to colab enterprise
    -   You should run the notebook: BigQuery-Create-TensorFlow-Model.ipynb 
    - Run the Iceberg table DAG: sample-iceberg-create-tables-update-data (takes about 15 minutes to deploy)
    - Start the Data Quality DAG: sample-rideshare-run-data-quality (takes about 10 minutes to complete)
    - Log into https://atomfashion.io/analytics/salesoverview and switch to Premium Account
    - Run the below "DO THIS IN ADVANCE"
    - Run a manual Data Profile of table: ${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip
      - https://console.cloud.google.com/dataplex/govern/profile?project=${project_id}
  
  


Clean up / Reset script:
    -- This table was put in the taxi dataset since we need to gran pub/sub permissions to access
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.taxi_trips_pub_sub`;
    DROP SCHEMA IF EXISTS `${project_id}.technical_demo`;

    DROP TABLE IF EXISTS `${project_id}.technical_demo.load_data_taxi_trips_csv`;
    DROP TABLE IF EXISTS `${project_id}.technical_demo.biglake_taxi_trips_parquet`;
    DROP TABLE IF EXISTS `${project_id}.technical_demo.biglake_green_trips_parquet`;
    DROP TABLE IF EXISTS `${project_id}.technical_demo.omni_aws_taxi_rate_code`;
    DROP TABLE IF EXISTS `${project_id}.technical_demo.bigquery_rideshare_zone`;
    DROP TABLE IF EXISTS `${project_id}.technical_demo.bigquery_time_travel`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`;

    DROP MODEL IF EXISTS `${project_id}.technical_demo.model_churn`;
    DROP MODEL IF EXISTS `${project_id}.technical_demo.model_tf_linear_regression_fare`;

    DROP EXTERNAL TABLE IF EXISTS `${project_id}.technical_demo.biglake_rideshare_zone_csv`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.technical_demo.biglake_rideshare_trip_iceberg`;
    DROP SEARCH INDEX IF EXISTS idx_all_bigsearch_log_5b_5t_json_hourly ON `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`;
*/


-- ***************************************************************************************************
-- BEGIN: DO THIS IN ADVANCE (some items need some time to fully initilize)
-- ***************************************************************************************************
--- Create temporary dataset 
CREATE SCHEMA `${project_id}.technical_demo`
    OPTIONS (
    location = "${bigquery_region}"
    );

-- Copy the data from the shared project
CREATE TABLE `${project_id}.technical_demo.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`
COPY `${shared_demo_project_id}.data_analytics_shared_data.bigsearch_log_5b_5t_json_hourly`;

CREATE TABLE `${project_id}.technical_demo.bigsearch_log_5b_5t_json_hourly_INDEXED`
COPY `${shared_demo_project_id}.data_analytics_shared_data.bigsearch_log_5b_5t_json_hourly`;

-- This can take some time to create the index
CREATE SEARCH INDEX idx_all_bigsearch_log_5b_5t_json_hourly 
    ON `${project_id}.technical_demo.bigsearch_log_5b_5t_json_hourly_INDEXED` (ALL COLUMNS)
    OPTIONS (analyzer = 'LOG_ANALYZER'); 

-- It can take data lineage a few minutes to be created
CREATE OR REPLACE VIEW `${project_id}.technical_demo.taxi_lineage` AS
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       zone_pickup.borough AS pickup_borough,
       CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       zone_dropoff.borough AS dropoff_borough,
       CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       payment.payment_type_description,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_json` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json` AS payment
               ON CAST(trip.payment_type_id AS INT64) = payment.payment_type_id
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_pickup
               ON CAST(trip.pickup_location_id AS INT64) = zone_pickup.location_id 
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_dropoff
               ON CAST(trip.dropoff_location_id AS INT64) = zone_dropoff.location_id 
UNION ALL
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       zone_pickup.borough AS pickup_borough,
       CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       zone_dropoff.borough AS dropoff_borough,
       CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       payment.payment_type_description,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_parquet` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json` AS payment
               ON CAST(trip.payment_type_id AS INT64) = payment.payment_type_id
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_pickup
               ON CAST(trip.pickup_location_id AS INT64) = zone_pickup.location_id 
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_dropoff
               ON CAST(trip.dropoff_location_id AS INT64) = zone_dropoff.location_id ;
-- ***************************************************************************************************
-- END: DO THIS IN ADVANCE
-- ***************************************************************************************************


--------------------------------------------------------------------------------------------------------
-- PART 1: See all the data - Any cloud, any speed
--------------------------------------------------------------------------------------------------------
/*
- Load data w/variety of file formats
- Create external tables over different file formats
  - Parquet
  - Parquet w/Hive partitioning
  - Iceberg
- Query and Transfer AWS data
- Dataflow Streaming Data
- BQ Subscriptions
- DataStream
- Spanner
*/

-- * Load data w/varity of file formats *
-- Load data into BigQuery (AVRO, ORC, CSV, JSON, Parquet, Iceberg) 
LOAD DATA OVERWRITE `${project_id}.technical_demo.load_data_taxi_trips_csv`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  field_delimiter=',',
  null_marker='',
  uris = ['gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/csv/year=2021/month=12/*.csv']);

SELECT * FROM `${project_id}.technical_demo.load_data_taxi_trips_csv`;


-- * Create external tables over different file formats *
-- Query External Parquet data
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.technical_demo.biglake_taxi_trips_parquet`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "PARQUET",
    uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/parquet/*.parquet']
);

SELECT * FROM `${project_id}.technical_demo.biglake_taxi_trips_parquet` LIMIT 1000;


-- Query External Parquet data w/Hive Partitioning
-- https://console.cloud.google.com/storage/browser/${processed_bucket_name};tab=objects?forceOnBucketsSortingFiltering=false&project=${project_id}&prefix=&forceOnObjectsSortingFiltering=false
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.technical_demo.biglake_green_trips_parquet`
WITH PARTITION COLUMNS (
    year  INTEGER, 
    month INTEGER
)
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    format = "PARQUET",
    hive_partition_uri_prefix = "gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/parquet/",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/parquet/*.parquet']
);

SELECT * FROM `${project_id}.technical_demo.biglake_green_trips_parquet` LIMIT 1000;


-- Query External Iceberg data
-- OPEN: https://console.cloud.google.com/storage/browser/rideshare-lakehouse-enriched-${random_extension}/rideshare_iceberg_catalog/rideshare_lakehouse_enriched.db/biglake_rideshare_payment_type_iceberg/metadata?pageState=(%22StorageObjectListTable%22:(%22f%22:%22%255B%255D%22))&project=${project_id}&prefix=&forceOnObjectsSortingFiltering=false
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.technical_demo.biglake_rideshare_trip_iceberg`
OPTIONS (
         format = 'ICEBERG',
         uris = ["gs://${gcs_rideshare_lakehouse_enriched_bucket}/rideshare_iceberg_catalog/rideshare_lakehouse_enriched.db/biglake_rideshare_payment_type_iceberg/metadata/REPLACE-ME.metadata.json"]
       );

SELECT * FROM `${project_id}.technical_demo.biglake_rideshare_trip_iceberg`;


-- * Query and Transfer AWS data *
-- https://cloud.google.com/bigquery/docs/load-data-using-cross-cloud-transfer

-- Create the AWS tables
CALL `${project_id}.${aws_omni_biglake_dataset_name}.sp_demo_aws_omni_create_tables`();

-- Load Data from AWS (or Azure) - Query data in a remote cloud and create a local BigQuery table
CREATE OR REPLACE TABLE `${project_id}.technical_demo.omni_aws_taxi_rate_code` AS
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.taxi_s3_rate_code`;

SELECT * FROM `${project_id}.technical_demo.omni_aws_taxi_rate_code`;


-- * Dataflow Streaming Data *
-- Ingest streaming data (Open Dataflow, we can use custom code and/or templates)
-- https://console.cloud.google.com/dataflow/jobs?project=${project_id}
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` LIMIT 1000;

SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 MINUTE);


-- * BQ Subscriptions *
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_pub_sub`
(
    data STRING
)
PARTITION BY TIMESTAMP_TRUNC(_PARTITIONTIME, HOUR);

-- Open: https://console.cloud.google.com/cloudpubsub/subscription/list?project=${project_id}
-- projects/pubsub-public-data/topics/taxirides-realtime
-- grant service account: service-31541164526@gcp-sa-pubsub.iam.gserviceaccount.com  
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_pub_sub` LIMIT 1000;
SELECT COUNT(*) AS Cnt FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_pub_sub`;

-- REMEMBER TO DELETE YOUR Pub/Sub TO BIGQUERY JOB


-- * Datastream *
-- https://console.cloud.google.com/datastream/streams?project=${project_id}
SELECT * FROM `${project_id}.datastream_private_ip_public.driver`;
SELECT * FROM `${project_id}.datastream_private_ip_public.review`;
SELECT * FROM `${project_id}.datastream_private_ip_public.payment`;


-- * Spanner Federated Query *
-- https://console.cloud.google.com/spanner/instances/spanner-ral9vzfqhi/databases/weather/details/tables?project=${project_id}
-- Spanner (data)
EXECUTE IMMEDIATE """
SELECT *
  FROM EXTERNAL_QUERY(
      'projects/${project_id}/locations/${spanner_region}/connections/bq_spanner_connection',
      "SELECT *  FROM weather WHERE station_id='USW00094728'");
""";



--------------------------------------------------------------------------------------------------------
-- PART 2: Trust it all - Data lineage, dataplex, data quality
--------------------------------------------------------------------------------------------------------
/*
- Lineage via/Console and Views
- Managing with Dataplex
- Securing with Dataplex
- Registration with Dataplex
- Data Profiling metrics
- Data Quality metrics
- Security (RLS/CLS/DM to both internal/BigLake tables)
*/


-- * Lineage via/Console and Views * 
-- Create a view and show the lineage
-- Show: ${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data
-- Shows Analytics Hub data
-- https://console.cloud.google.com/dataplex/search?project=${project_id}&q=${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data


-- Lineage from storage through tables and views
-- This was done in advance
/*
CREATE VIEW `${project_id}.technical_demo.taxi_lineage` AS
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       zone_pickup.borough AS pickup_borough,
       CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       zone_dropoff.borough AS dropoff_borough,
       CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       payment.payment_type_description,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_json` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json` AS payment
               ON CAST(trip.payment_type_id AS INT64) = payment.payment_type_id
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_pickup
               ON CAST(trip.pickup_location_id AS INT64) = zone_pickup.location_id 
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_dropoff
               ON CAST(trip.dropoff_location_id AS INT64) = zone_dropoff.location_id 
UNION ALL
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       zone_pickup.borough AS pickup_borough,
       CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       zone_dropoff.borough AS dropoff_borough,
       CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       payment.payment_type_description,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_parquet` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json` AS payment
               ON CAST(trip.payment_type_id AS INT64) = payment.payment_type_id
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_pickup
               ON CAST(trip.pickup_location_id AS INT64) = zone_pickup.location_id 
       INNER JOIN `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv` zone_dropoff
               ON CAST(trip.dropoff_location_id AS INT64) = zone_dropoff.location_id ;
*/

SELECT * FROM `${project_id}.technical_demo.taxi_lineage` LIMIT 100;


-- * Managing with Dataplex *
-- https://console.cloud.google.com/dataplex/lakes?project=${project_id}
-- Show Dataplex Lakes (Managed View)

-- * Security with Dataplex *
-- https://console.cloud.google.com/dataplex/secure?project=${project_id}
-- Show Dataplex Security (Securing Assests within BigQuery / Storage as one)


-- * Registration with Dataplex *
-- Show tables in storage
-- Show the tables within BigQuery
-- https://console.cloud.google.com/storage/browser/rideshare-lakehouse-raw-${random_extension};tab=objects?forceOnBucketsSortingFiltering=false&project=${project_id}&prefix=&forceOnObjectsSortingFiltering=false
SELECT * FROM `${project_id}.rideshare_raw_zone_${random_extension}.rideshare_payment_type` LIMIT 1000;
SELECT * FROM `${project_id}.rideshare_raw_zone_${random_extension}.rideshare_trip_json`    LIMIT 1000;
SELECT * FROM `${project_id}.rideshare_raw_zone_${random_extension}.rideshare_trip_parquet` LIMIT 1000;


-- * Data Profiling metrics *
-- Show data scan of table: bigquery_rideshare_trip
-- https://console.cloud.google.com/dataplex/govern/profile?project=${project_id}


-- * Data Quality metrics *
-- https://console.cloud.google.com/dataplex/govern/quality?project=${project_id}


-- See results in data catalog 
-- https://console.cloud.google.com/dataplex/search?project=${project_id}&q=${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip



-- * Security (RLS/CLS/DM to both internal/BigLake tables) *
-- Create a BigLake table over the Zone data
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.technical_demo.biglake_rideshare_zone_csv`
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

-- Show CSV table (all data)
SELECT * FROM `${project_id}.technical_demo.biglake_rideshare_zone_csv` LIMIT 1000;

-- Query: Create an access policy so the admin (you) can only see Manhattan data
CREATE OR REPLACE ROW ACCESS POLICY rls_biglake_rideshare_zone_csv
    ON `${project_id}.technical_demo.biglake_rideshare_zone_csv`
    GRANT TO ("user:${gcp_account_name}") 
FILTER USING (borough = 'Manhattan');

-- See just the data you are allowed to see
SELECT * FROM `${project_id}.technical_demo.biglake_rideshare_zone_csv`;

-- Edit the table and show Data Masking / Column level security on the service zone
SELECT * FROM `${project_id}.technical_demo.biglake_rideshare_zone_csv`;

DROP ALL ROW ACCESS POLICIES ON `${project_id}.technical_demo.biglake_rideshare_zone_csv`;


-- Create an Internal table and apply a policy (same exact code)
CREATE OR REPLACE TABLE `${project_id}.technical_demo.bigquery_rideshare_zone` AS 
SELECT * FROM `${project_id}.technical_demo.biglake_rideshare_zone_csv`;

CREATE OR REPLACE ROW ACCESS POLICY rls_biglake_rideshare_zone_csv
    ON `${project_id}.technical_demo.bigquery_rideshare_zone`
    GRANT TO ("user:${gcp_account_name}") 
FILTER USING (service_zone = 'Yellow Zone');

SELECT * FROM  `${project_id}.technical_demo.bigquery_rideshare_zone`;

DROP ALL ROW ACCESS POLICIES ON `${project_id}.technical_demo.bigquery_rideshare_zone`;


--------------------------------------------------------------------------------------------------------
-- PART 3: Activate it all - BQML, universal semantic layer, connect layer as dashboard, turn on bi engine (1 click), vertex (deploy 1 click and drift detection), etc
--------------------------------------------------------------------------------------------------------
/*
- BQML 
  - Create Model
  - Explainable AI
- Integration with Vertex AI
  - Model Registry
  - REST API to expose to consuming apps
- Build model in Vertex (ML Ops and ingest into BQ - Import) 
- Show time travel
- ML Ops pipeline (TO DO)
- JSON Analytics / data type
- BigSearch
- Query Acceleration
- Unstructured data analysis
- BigSpark
*/


-- * BQML - Create a Model * (takes 30 seconds)
-- Save the model in Vertex AI model registry
-- https://cloud.google.com/bigquery/docs/bqml-introduction#supported_models
-- https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-create#create_model_syntax
CREATE OR REPLACE MODEL `${project_id}.technical_demo.model_churn`
   OPTIONS(
   MODEL_TYPE="LOGISTIC_REG", -- or BOOSTED_TREE_CLASSIFIER, DNN_CLASSIFIER, AUTOML_CLASSIFIER
   INPUT_LABEL_COLS=["churned"],
   MODEL_REGISTRY = "vertex_ai"
) AS
SELECT * EXCEPT(user_first_engagement, user_pseudo_id)
  FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.training_data`;


-- * BQML - Explainable AI *
-- Use Explainable AI for the prediction
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.EXPLAIN_PREDICT(MODEL `${project_id}.technical_demo.model_churn`,
       (SELECT * FROM `${project_id}`.thelook_ecommerce.training_data LIMIT 10));
""";


-- * Integration with Vertex AI - Model Registry *
-- REST API to expose to consuming apps
-- https://console.cloud.google.com/vertex-ai/models?project=${project_id}


-- * Build model in Vertex (ML Ops and ingest into BQ - Import) *
-- Import a model (Tensorflow)
-- Show notebook / model
CREATE OR REPLACE MODEL `${project_id}.technical_demo..model_tf_linear_regression_fare`
       OPTIONS (MODEL_TYPE='TENSORFLOW',
       MODEL_PATH='gs://${processed_bucket_name}/tensorflow/taxi_fare_model/linear_regression/*');


-- Run a prediction (note you can run the same prediction in your notebook and get the same result)
EXECUTE IMMEDIATE """
SELECT *
  FROM ML.PREDICT(MODEL `${project_id}.technical_demo..model_tf_linear_regression_fare`,
     (
      SELECT [10.0,20.0] AS normalization_input
     ));
""";


-- * Show time travel w/this (delete then see time travel) - this is for easy recovery of data *
CREATE OR REPLACE TABLE `${project_id}.technical_demo.bigquery_time_travel` 
  (
      Vendor_Id	            INTEGER,	
      Pickup_DateTime	        TIMESTAMP,
      Dropoff_DateTime	    TIMESTAMP,
      PULocationID	        INTEGER,
      DOLocationID	        INTEGER,
      Trip_Distance	        FLOAT64,
      Total_Amount	        FLOAT64,
      PartitionDate           DATE	
  )
  PARTITION BY PartitionDate
  AS SELECT 
          Vendor_Id,
          Pickup_DateTime,
          Dropoff_DateTime,
          PULocationID,
          DOLocationID,
          Trip_Distance,
          Total_Amount,
          DATE(year, month, 1) as PartitionDate
     FROM `${project_id}.${bigquery_taxi_dataset}.ext_green_trips_parquet`
  WHERE DATE(year, month, 1) = '2021-01-01';
  
  -- Query: 76516
  SELECT COUNT(*) AS RecordCount FROM `${project_id}.technical_demo.bigquery_time_travel`;
  
  -- Make a delete mistake
  DELETE FROM `${project_id}.technical_demo.bigquery_time_travel` WHERE PULocationID <= 47;
  
  -- Query: 59114
  SELECT COUNT(*) AS RecordCount FROM `${project_id}.technical_demo.bigquery_time_travel`;
   
  -- Query: 76516 - See the prior data before the INSERT
  -- NOTE: You might need to change INTERVAL 30 SECOND to more time if you spend time talking
  SELECT COUNT(*) AS RecordCount
    FROM `${project_id}.technical_demo.bigquery_time_travel`
    FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 SECOND);



-- * JSON Analytics / data type *
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_json`
(
    taxi_json JSON
)
WITH PARTITION COLUMNS (
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
OPTIONS (
    format = "CSV",
    field_delimiter = '\u00fe',
    skip_leading_rows = 0,
    hive_partition_uri_prefix = "gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/json/",
    uris = ['gs://${processed_bucket_name}/processed/taxi-data/yellow/trips_table/json/*.json']
    );

-- JSON Analytics with JSON data 
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_json` LIMIT 100;

SELECT taxi_json.Vendor_Id, 
       taxi_json.Rate_Code_Id, 
       taxi_json.Fare_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_json` 
  LIMIT 100;

-- for each day find the highest passenger count and total amount per payment type
WITH TaxiData AS
  (
  SELECT CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) AS Pickup_DateTime,
         SAFE.INT64(taxi_trips.taxi_json.Payment_Type_Id)                    AS Payment_Type_Id,
         SAFE.INT64(taxi_trips.taxi_json.Passenger_Count)                    AS Passenger_Count,
         SAFE.FLOAT64(taxi_trips.taxi_json.Total_Amount)                     AS Total_Amount,
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_json` AS taxi_trips
   WHERE CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) BETWEEN '2020-01-01' AND '2020-06-01' 
     AND SAFE.INT64(taxi_trips.taxi_json.Payment_Type_Id)  IN (1,2)
  )
  , TaxiDataRanking AS
  (
  SELECT CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
         taxi_trips.Payment_Type_Id,
         taxi_trips.Passenger_Count,
         taxi_trips.Total_Amount,
         RANK() OVER (PARTITION BY CAST(Pickup_DateTime AS DATE),
                                   taxi_trips.Payment_Type_Id
                          ORDER BY taxi_trips.Passenger_Count DESC, 
                                   taxi_trips.Total_Amount DESC) AS Ranking
    FROM TaxiData AS taxi_trips
  )
  SELECT Pickup_Date,
         Payment_Type_Description,
         Passenger_Count,
         Total_Amount
    FROM TaxiDataRanking
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.payment_type` AS payment_type
                ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
  WHERE Ranking = 1
  ORDER BY Pickup_Date, Payment_Type_Description;
  

-- * BigSearch *
-- How many records are we searching
SELECT COUNT(*) AS Cnt FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip` ;

-- Find a credit card number this since this is generated data and change below REPLACE_CREDIT_CARD
SELECT credit_card_number
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip` 
 WHERE credit_Card_number IS NOT NULL
 LIMIT 1;

-- The table is not partitioned or clustered on this data
-- Click on Job Information and show "Index Usage Mode: FULLY_USED"
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip`
WHERE SEARCH(credit_card_number,'REPLACE_CREDIT_CARD', analyzer=>'NO_OP_ANALYZER'); 

-- Search even if we do not know the field name
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip` AS bigquery_rideshare_trip
WHERE SEARCH(bigquery_rideshare_trip,'REPLACE_CREDIT_CARD', analyzer=>'NO_OP_ANALYZER'); 


-- NOT_INDEXED
-- Bytes processed: 5.83 TB 
-- Index Usage Mode: UNUSED
SELECT *
  FROM `${project_id}.technical_demo.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`
  WHERE SEARCH(insertId, '40ms4zeh78tg6o6jx');

-- Make sure index is complete: coverage_percentage should be 100%
SELECT table_name, index_name, coverage_percentage
  FROM `${project_id}.technical_demo.INFORMATION_SCHEMA.SEARCH_INDEXES`
 WHERE index_status = 'ACTIVE';   

-- Search the field "insertId" for a value (just one column)
-- Bytes processed: 106.57 MB
-- Index Usage Mode: FULLY_USED
SELECT *
  FROM `${project_id}.technical_demo.bigsearch_log_5b_5t_json_hourly_INDEXED`
  WHERE SEARCH(insertId, '40ms4zeh78tg6o6jx');


-- 50 Billion Rows (requires access to the shared project)
SELECT COUNT(*) AS Cnt 
  FROM `${shared_demo_project_id}.bigquery_features.bigsearch_log_50b_60t_json_hourly` AS LogsIndexed
 WHERE SEARCH((internalClusterId, labels), 'service281')
   AND TIMESTAMP_TRUNC(timestamp, HOUR) BETWEEN TIMESTAMP("2021-02-01 00:00:00") 
                                            AND TIMESTAMP("2021-02-06 00:00:00") ;


-- * Query Acceleration *
/*
Data Size:
    - File Count = 5,068,912
    - Directory Count = 1,588,355
    - The taxi trip table was exported to cloud storage and partitioned by Year, Month, Day, Hour and Minute
    - About 75 GB of data was exported and created many small files 
*/
-- DO NOT RUN - TOO SLOW (the point of the demo)
-- NO ACCELERATION
-- Duration: >3 min 
SELECT *
  FROM `${shared_demo_project_id}.bigquery_preview_features.biglake_no_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1
   AND hour   = 0
   AND minute = 0;


-- WITH ACCELERATION
SELECT *
  FROM `${shared_demo_project_id}.bigquery_preview_features.biglake_query_acceleration`
 WHERE year   = 2021
   AND month  = 1
   AND day    = 1
   AND hour   = 0
   AND minute = 0;


-- * Unstructured Data Analytis *
-- https://console.cloud.google.com/storage/browser/${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images?pageState=(%22StorageObjectListTable%22:(%22f%22:%22%255B%255D%22))&project=${project_id}&prefix=&forceOnObjectsSortingFiltering=false
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.technical_demo.biglake_unstructured_data`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    object_metadata="DIRECTORY",
    uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images/*.jpg',
            'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images/*.jpeg'],
    max_staleness=INTERVAL 30 MINUTE, 
    metadata_cache_mode="MANUAL");

CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('${project_id}.technical_demo.biglake_unstructured_data');

-- See the data
SELECT * FROM `${project_id}.technical_demo.biglake_unstructured_data` ;

-- Process the images via our object table and show the results 
WITH UnstructuredData AS
(
  -- get the image from the oject table
  SELECT * 
    FROM `${project_id}.technical_demo.biglake_unstructured_data` 
    WHERE uri = (SELECT uri FROM `${project_id}.technical_demo.biglake_unstructured_data` LIMIT 1)
)
, ScoreAI AS 
(
  -- call a remote function
  SELECT `${project_id}.rideshare_lakehouse_enriched.ext_udf_ai_localize_objects`(UnstructuredData.uri) AS json_result
    FROM UnstructuredData
)
SELECT item.name,
       item.score,
       ScoreAI.json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.localized_object_annotations)) AS item;


-- Show all the images processed (object detection, labels, landmarks, logos)
SELECT * FROM `${project_id}.rideshare_lakehouse_enriched.bigquery_rideshare_images_ml_score` LIMIT 100;


-- * BigSpark *
-- BigLake Metastore Service
-- CALL `${project_id}.rideshare_lakehouse_enriched.sp_process_data`();


--------------------------------------------------------------------------------------------------------
-- PART 4: Intelligent infrastructure (autoscaling to the minute, best price/perf, etc, capacity, )
--------------------------------------------------------------------------------------------------------
/*
- Autoscaling / Workload management
- Monitoring - Show these views (slide 20): WIP - Landing Launches 27 Mar2023 - DA Field Council - go/da-fc (TO DO)
- See how much you are using 
- Quotas (even for on-demand) 
- Query Visualization (optimizer/queues) 
- Slot recommender / Info Schema (see pricing / slots) 
- Data Modeling (Looker: https://atomfashion.io/analytics/salesoverview | Select Map | Add Age)
- SQL Translate
- Sheets
- BI Engine
*/


-- * Autoscaling / Workload management - 10 second autoscaling *
-- https://console.cloud.google.com/bigquery/admin/reservations;region=${bigquery_region}/create?project=${project_id}&region=${bigquery_region}


-- * Monitoring *
-- https://console.cloud.google.com/bigquery/admin/monitoring/resource-utilization?project=${project_id}&region=${bigquery_region}



-- * See how much you are using (Informational Schema) *
-- Compute the cost per Job, Average slots per Job and Max slots per Job (at the job stage level)
-- This will show you the cost for the Query and the Maximum number of slots used and if any additional slots where requested (to help gauge for reservations)
SELECT project_id,
       job_id,
       reservation_id,
       EXTRACT(DATE FROM creation_time) AS creation_date,
       TIMESTAMP_DIFF(end_time, creation_time, SECOND) AS job_duration_seconds,
       job_type,
       user_email,
       total_bytes_billed,

       -- 6.25 / 1,099,511,627,776 = 0.00000000000568434188608080 ($6.25 per TB so cost per byte is 0.00000000000568434188608080)
       CASE WHEN reservation_id IS NULL
            THEN CAST(total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000568434188608080 AS BIGDECIMAL) 
            ELSE 0
       END      
       as est_cost,

       -- Average slot utilization per job is calculated by dividing
       -- total_slot_ms by the millisecond duration of the job
       SAFE_DIVIDE(job.total_slot_ms,(TIMESTAMP_DIFF(job.end_time, job.start_time, MILLISECOND))) AS job_avg_slots,
       query,

       -- Determine the max number of slots used at ANY stage in the query.  The average slots might be 55
       -- but a single stage might spike to 2000 slots.  This is important to know when estimating when purchasing slots.
       MAX(SAFE_DIVIDE(unnest_job_stages.slot_ms,unnest_job_stages.end_ms - unnest_job_stages.start_ms)) AS jobstage_max_slots,

       -- Is the job requesting more units of works (slots).  If so you need more slots.
       -- estimatedRunnableUnits = Units of work that can be scheduled immediately. 
       -- Providing additional slots for these units of work will accelerate the query, if no other query in the reservation needs additional slots.
       MAX(unnest_timeline.estimated_runnable_units) AS estimated_runnable_units
FROM `region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS AS job
      CROSS JOIN UNNEST(job_stages) as unnest_job_stages
      CROSS JOIN UNNEST(timeline) AS unnest_timeline
WHERE project_id = '${project_id}'
  AND DATE(creation_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE() 
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY creation_date DESC ;


-- * Quotas (even for on-demand) *
-- https://console.cloud.google.com/iam-admin/quotas?referrer=search&project=${project_id}&pageState=(%22allQuotasTable%22:(%22f%22:%22%255B%257B_22k_22_3A_22Metric_22_2C_22t_22_3A10_2C_22v_22_3A_22_5C_22bigquery.googleapis.com%252Fquota%252Fquery%252Fusage_5C_22_22_2C_22s_22_3Atrue_2C_22i_22_3A_22metricName_22%257D%255D%22))


-- * Query Visualization (optimizer/queues) *
SELECT FORMAT_DATE("%w", Pickup_DateTime) AS WeekdayNumber,
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       vendor.Vendor_Description,
       payment_type.Payment_Type_Description,
       SUM(taxi_trips.Total_Amount) AS high_value_trips
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS vendor 
               ON taxi_trips.Vendor_Id = vendor.Vendor_Id
              AND taxi_trips.Pickup_DateTime BETWEEN '2020-01-01' AND '2020-06-01' 
        LEFT JOIN `${project_id}.${bigquery_taxi_dataset}.payment_type` AS payment_type
               ON taxi_trips.Payment_Type_Id = payment_type.Payment_Type_Id
GROUP BY 1, 2, 3, 4
HAVING SUM(taxi_trips.Total_Amount) > 50
ORDER BY WeekdayNumber, 3, 4;


-- * Slot recommender *
-- https://console.cloud.google.com/bigquery/admin/reservations;region=${bigquery_region}/slot-estimator?project=${project_id}&region=${bigquery_region}


-- * Data Modeling (Looker: https://atomfashion.io/analytics/salesoverview | Select Map | Add Age) *


-- * SQL Translate *
/*
CREATE VOLATILE TABLE exampleTable (age INT, gender VARCHAR(10));
INS INTO exampleTable (10, 'F');
INS INTO exampleTable (20, 'M');

SEL *
FROM exampleTable
WHERE gender EQ 'F'
AND age LT 15;
*/

-- * Sheets *
-- Create sheet w/Taxi Data
-- Create pivot table (values of tip/total amt)


-- * BI Engine *
-- Open BI Engine tab and add BI Engine
-- https://console.cloud.google.com/bigquery/admin/bi-engine?project=${project_id}


-- REMEMBER TO DELETE YOUR Pub/Sub TO BIGQUERY JOB
SELECT 1;
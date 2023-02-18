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
      - Quickly load files from a data lake into BigQuery
      - Show creating tables from the BigQuery UI (load from GCS or direct upload, etc.)
      - Show loading tables via SQL commands
      - Show loading tables via the CLI
      - Show extracting data back to a data lake
      - Extract data from BigQuery for providing customer extracts and/or external applications
  
  Description: 
      - BigQuery has Free data loading!
      - Ingest data into BigQuery using the UI and Load command in formats: Parquet, ORC, Avro, CSV and JSON
      - Export data for consumption by data application.
  
  Reference:
      - SQL LOAD command: https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#load_data_statement
      - Command Line: https://cloud.google.com/bigquery/docs/bq-command-line-tool#loading_data
  
  Clean up / Reset script:
      DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.load_taxi_ui`;
      DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.load_taxi_sql`;
      DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.load_taxi_cli`;
      
  */
  
-- APPROACH 1 (Using the BigQuery User Interface)
-- Open BigQuery UI
-- Click on ${bigquery_taxi_dataset} (...) and select Create Table
-- Select
-- CREATE TABLE FROM:   GCS
-- GCS BUCKET PATTERN:  ${processed_bucket_name}/processed/taxi-data/green/trips_table/csv/year=2021/month=12/*.csv'
-- FILE FORMAT:         CSV (also show the others)
-- TABLE (name):        load_taxi_ui
-- SCEHMA:              Auto Dectect
-- Under Advanced
-- HEADER ROWS TO SKIP: 1
-- Click "Create Table"

-- APPROACH 2
-- Using SQL commands
-- https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#load_data_statement
LOAD DATA OVERWRITE ${bigquery_taxi_dataset}.load_taxi_sql
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  field_delimiter=',',
  null_marker='',
  uris = ['gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/csv/year=2021/month=12/*.csv']);

SELECT * FROM ${bigquery_taxi_dataset}.load_taxi_sql;


-- APPROACH 3
-- https://cloud.google.com/bigquery/docs/bq-command-line-tool#loading_data
-- Using CLI via command line
-- Open a Cloud Shell and paste each command below
/*
bq load \
--location=us \
--skip_leading_rows=1 \
--autodetect \
--replace \
--source_format='CSV' \
--field_delimiter=',' \
--null_marker='' \
"${project_id}:${bigquery_taxi_dataset}.load_taxi_cli" \
"gs://${processed_bucket_name}/processed/taxi-data/green/trips_table/csv/year=2021/month=12/*.csv"

bq query 'SELECT * FROM ${bigquery_taxi_dataset}.load_taxi_cli'

SELECT * FROM ${bigquery_taxi_dataset}.load_taxi_cli;
*/


-- EXPORTING DATA 3
EXPORT DATA
  OPTIONS (
    uri = 'gs://${raw_bucket_name}/taxi-data/green/trips_table/csv/*.csv',
    format = 'CSV',
    overwrite = true,
    header = true,
    field_delimiter = '|')
AS (
  SELECT *
  FROM ${bigquery_taxi_dataset}.load_taxi_sql
);

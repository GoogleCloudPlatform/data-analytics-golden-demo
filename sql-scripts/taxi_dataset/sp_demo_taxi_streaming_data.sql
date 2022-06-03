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
Prerequisites: 
    - In Composer / Airflow start the DAG: sample-dataflow-streaming-bigquery
    - It will take several minutes for the DAG to start
    - Please Cancel the DAG after your demo/testing

Use Cases:
    - Receive realtime data from streaming sources directly into BigQuery
    
Description: 
    - Shows streaming data from Pub/Sub -> Dataflow -> BigQuery
    - BigQuery has streaming ingestion where data is available as soon as it is ingested
    - Micro-batching is not used, the data is immediate

Reference:
    - https://cloud.google.com/bigquery/docs/write-api

Clean up / Reset script:
    n/a
*/


SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 2 HOUR) AND TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR)
 LIMIT 100;

-- Data older than last hour
SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR);

-- Last prior full hour of data
SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 2 HOUR) AND TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR);

-- Current data within past hour
SELECT COUNT(*) AS RecordCount  
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` 
  WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 HOUR);



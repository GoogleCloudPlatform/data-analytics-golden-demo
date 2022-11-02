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
    - Gets the Data Quality (Dataplex) results for each column in a table
    - This will be called by Airflow DAG: sample-dataplex-run-data-quality

Description: 
    - Shows gathering the data which will be ingeted into the Data Catalog Tag Template
    - You could make this procedure more generic and pass in the table as a parameter (this is just a demo)
    - You could also deploy this to the dataplex_data_quality dataset (instead of taxi)

Show:
    - 

References:
    - 

Clean up / Reset script:
*/

--SELECT * from `${project_id}.dataplex_data_quality.data_quality_results` ;

WITH LatestExecution AS
(
  SELECT MAX(execution_ts) AS latest_execution_ts
    FROM `${project_id}.dataplex_data_quality.data_quality_results` 
  WHERE table_id = '${project_id}.${bigquery_taxi_dataset}.taxi_trips'
)
, TableData AS
(
  SELECT invocation_id,
         execution_ts,
         column_id,
         rule_binding_id,
         rule_id,
         dimension,
         rows_validated,
         success_count,
         success_percentage,
         failed_count,
         failed_percentage,
         null_count,
         null_percentage

    FROM `${project_id}.dataplex_data_quality.data_quality_results` AS data_quality_results
         CROSS JOIN LatestExecution

   WHERE invocation_id = (SELECT DISTINCT invocation_id 
                            FROM `${project_id}.dataplex_data_quality.data_quality_results` 
                           WHERE execution_ts = (SELECT latest_execution_ts FROM LatestExecution))
    AND column_id IS NOT NULL
)

SELECT *
  FROM TableData;


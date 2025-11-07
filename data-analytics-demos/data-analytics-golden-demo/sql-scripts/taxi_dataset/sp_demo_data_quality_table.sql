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
    - Gets the Aggreated Data Quality (Dataplex) results for a table
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


WITH LatestExecution AS
(
  SELECT MAX(execution_ts) AS latest_execution_ts
    FROM `${project_id}.dataplex_data_quality.data_quality_results` 
  WHERE table_id = '${project_id}.${bigquery_taxi_dataset}.taxi_trips'
)
, TableRows AS
(
  SELECT COUNT(*) AS record_count
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
)
, ColumnsValidated AS
(
  SELECT COUNT(DISTINCT column_id) AS columns_validated
    FROM `${project_id}.dataplex_data_quality.data_quality_results` 
   WHERE invocation_id = (SELECT DISTINCT invocation_id 
                            FROM `${project_id}.dataplex_data_quality.data_quality_results` 
                           WHERE execution_ts = (SELECT latest_execution_ts FROM LatestExecution))
)
, ColumnsTotal AS
(
  SELECT COUNT(column_name) AS columns_count
    FROM `${project_id}.${bigquery_taxi_dataset}.INFORMATION_SCHEMA.COLUMNS`
   WHERE table_name = 'taxi_trips'  
)
, TableData AS
(
  SELECT TableRows.record_count,
         LatestExecution.latest_execution_ts,
         ColumnsValidated.columns_validated,
         ColumnsTotal.columns_count,
         data_quality_results.*
    FROM `${project_id}.dataplex_data_quality.data_quality_results` AS data_quality_results
         CROSS JOIN LatestExecution
         CROSS JOIN TableRows
         CROSS JOIN ColumnsValidated
         CROSS JOIN ColumnsTotal

   WHERE invocation_id = (SELECT DISTINCT invocation_id 
                            FROM `${project_id}.dataplex_data_quality.data_quality_results` 
                           WHERE execution_ts = (SELECT latest_execution_ts FROM LatestExecution))
)

SELECT record_count,
       latest_execution_ts,
       columns_validated,
       columns_count,
       invocation_id,
       CASE WHEN SUM(IFNULL(rows_validated,0)) = 0
            THEN CAST(1 AS NUMERIC)
            ELSE CAST(SUM(IFNULL(success_count,0)) / SUM(IFNULL(rows_validated,0)) AS NUMERIC)
       END AS success_percentage,
       -- There is a failed_count field but it does not sum to 100% with the success count.
       -- This is used in the demo so the UI does not show two numbers that do not add up to 100%
       CAST(1 AS NUMERIC) - CASE WHEN SUM(IFNULL(rows_validated,0)) = 0
            THEN CAST(1 AS NUMERIC)
            ELSE CAST(SUM(IFNULL(success_count,0)) / SUM(IFNULL(rows_validated,0)) AS NUMERIC)
       END AS failed_percentage  
  FROM TableData
GROUP BY 1,2,3,4,5;


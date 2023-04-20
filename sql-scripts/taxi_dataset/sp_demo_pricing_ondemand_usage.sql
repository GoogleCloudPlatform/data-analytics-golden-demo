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
-- NOTE: This is designed for a single BigQuery region
--       This gets the past 3 months of data (from first day of prior 3 months)

-- SEARCH and REPLACE the below values (if downloading this single file from GitHub)
-- Replace Region          -> Search for: region-${bigquery_region}
-- Replace Dataset         -> Search for: ${bigquery_taxi_dataset}
-- Replace GCS bucket Path -> Search for: gs://${raw_bucket_name}

Use Cases:
    - Shows the queries that are most used in your organization
    - Shows the estimatated on-demand cost of the queries (retail pricing)

Description: 
    - Loops through each project and get your query data from the informational schema tables

Reference:
    - https://cloud.google.com/bigquery/docs/information-schema-jobs


Clean up / Reset script:
    DROP TABLE IF EXISTS `${bigquery_taxi_dataset}.usage_export_project`;
    DROP TABLE IF EXISTS `${bigquery_taxi_dataset}.usage_export_data`;
    DROP TABLE IF EXISTS `${bigquery_taxi_dataset}.usage_import_data`;
*/


-- Track which projects we are able to get data 
CREATE OR REPLACE TABLE `${bigquery_taxi_dataset}.usage_export_project`
(
  project_id STRING,
  result STRING
) ;


-- Create a table to hold the results
CREATE OR REPLACE TABLE `${bigquery_taxi_dataset}.usage_export_data` 
(
  creation_time TIMESTAMP,
  project_id STRING,
  project_number INT64,
  user_email STRING,
  job_id STRING,
  job_type STRING,
  statement_type STRING,
  priority STRING,
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  query STRING,
  state STRING,
  reservation_id STRING,
  total_bytes_processed INT64,
  total_slot_ms INT64,
  error_result_reason STRING,
  error_result_location STRING,
  error_result_debug_info STRING,
  error_result_message STRING,
  cache_hit BOOLEAN,
  destination_table_project_id STRING,
  destination_table_dataset_id STRING,
  destination_table_table_id STRING,
  total_bytes_billed INT64,
  transaction_id STRING,
  parent_job_id STRING,
  session_info_session_id STRING,
  total_modified_partitions INT64,
  bi_engine_statistics_bi_engine_mode STRING,
  resource_warning STRING,
  normalized_literals STRING,
  transferred_bytes INT64,
  est_on_demand_cost FLOAT64,
  job_avg_slots FLOAT64,
  jobstage_max_slots FLOAT64,
  estimated_runnable_units INT64
);

SELECT DISTINCT project_id from `region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS_BY_ORGANIZATION;

-- Loop through each project id
-- This is done since only the JOBS view has the "query" field
FOR record IN (SELECT DISTINCT project_id 
                          FROM `region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS_BY_ORGANIZATION) 
                         -- You can inlcude the below WHERE statement to limit to just a few projects
                         --WHERE project_id IN ('data-analytics-demo-xxxxxxxxxx','data-analytics-demo-yyyyyyyyy'))
DO
  BEGIN
  EXECUTE IMMEDIATE FORMAT("""
  INSERT INTO ${bigquery_taxi_dataset}.usage_export_data 
    (
    creation_time,
    project_id,
    project_number,
    user_email,
    job_id,
    job_type,
    statement_type,
    priority,
    start_time,
    end_time,
    query,
    state,
    reservation_id,
    total_bytes_processed,
    total_slot_ms,
    error_result_reason,
    error_result_location,
    error_result_debug_info,
    error_result_message,
    cache_hit,
    destination_table_project_id,
    destination_table_dataset_id,
    destination_table_table_id,
    total_bytes_billed,
    transaction_id,
    parent_job_id,
    session_info_session_id,
    total_modified_partitions,
    bi_engine_statistics_bi_engine_mode,
    resource_warning,
    normalized_literals,
    transferred_bytes,
    est_on_demand_cost,
    job_avg_slots,
    jobstage_max_slots,
    estimated_runnable_units
  )
  SELECT job.creation_time,
        job.project_id,
        job.project_number,
        job.user_email,
        job.job_id,
        job.job_type,
        job.statement_type,
        job.priority,
        job.start_time,
        job.end_time,
        job.query,
        job.state,
        job.reservation_id,
        job.total_bytes_processed,
        job.total_slot_ms,
        job.error_result.reason     AS error_result_reason,
        job.error_result.location   AS error_result_location,
        job.error_result.debug_info AS error_result_debug_info,
        job.error_result.message    AS error_result_message,
        job.cache_hit,
        job.destination_table.project_id AS destination_table_project_id,
        job.destination_table.dataset_id AS destination_table_dataset_id,
        job.destination_table.table_id   AS destination_table_table_id,
        job.total_bytes_billed,
        job.transaction_id,
        job.parent_job_id,
        job.session_info.session_id AS session_info_session_id,
        job.total_modified_partitions,
        job.bi_engine_statistics.bi_engine_mode AS bi_engine_statistics_bi_engine_mode,
        job.query_info.resource_warning,
        job.query_info.query_hashes.normalized_literals,
        job.transferred_bytes,

        -- This is retail pricing (for estimating purposes)
        -- 5 / 1,099,511,627,776 = 0.00000000000454747350886464 ($5 per TB so cost per byte is 0.00000000000454747350886464)
        CASE WHEN job.reservation_id IS NULL 
             THEN CAST(CAST(job.total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000454747350886464 AS BIGDECIMAL) AS FLOAT64) 
             ELSE CAST (0 AS FLOAT64)
         END as est_on_demand_cost,

        -- Average slot utilization per job is calculated by dividing
        -- total_slot_ms by the millisecond duration of the job
        CAST(SAFE_DIVIDE(job.total_slot_ms,(TIMESTAMP_DIFF(job.end_time, job.start_time, MILLISECOND))) AS FLOAT64) AS job_avg_slots,

        MAX(SAFE_DIVIDE(unnest_job_stages.slot_ms,unnest_job_stages.end_ms - unnest_job_stages.start_ms)) AS jobstage_max_slots,
        MAX(unnest_timeline.estimated_runnable_units) AS estimated_runnable_units
    FROM `%s`.`region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS AS job
          CROSS JOIN UNNEST(job.job_stages) as unnest_job_stages
          CROSS JOIN UNNEST(job.timeline) AS unnest_timeline
    WHERE DATE(job.creation_time) BETWEEN DATE_SUB(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), INTERVAL (SELECT EXTRACT(DAY FROM CURRENT_DATE())-1) DAY) AND CURRENT_DATE()
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34;
  """,record.project_id);

  INSERT INTO `${bigquery_taxi_dataset}.usage_export_project` (project_id, result) VALUES (record.project_id,'SUCCESS');

  EXCEPTION WHEN ERROR THEN
    -- do nothing we do not have access to the project
    INSERT INTO `${bigquery_taxi_dataset}.usage_export_project` (project_id, result) VALUES (record.project_id,'FAILED');
  END;

END FOR;


-- Export the data (some people transfer this to have an analysis performed)
EXPORT DATA
OPTIONS (
   uri = 'gs://${raw_bucket_name}/query_usage/*.parquet',
   format = 'PARQUET',
   overwrite = true
   )
AS (
   SELECT *
     FROM `${bigquery_taxi_dataset}.usage_export_data`
);


-- Test loading the data
DROP TABLE IF EXISTS `${bigquery_taxi_dataset}.usage_import_data`;

LOAD DATA OVERWRITE `${bigquery_taxi_dataset}.usage_import_data`
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${raw_bucket_name}/query_usage/*.parquet']
);

-- See which projects worked/failed
SELECT * FROM ${bigquery_taxi_dataset}.usage_export_project ORDER BY result DESC;

-- See some results
SELECT project_id, query, SUM(est_on_demand_cost) AS est_sum_on_demand_cost, COUNT(1) AS Cnt
  FROM `${bigquery_taxi_dataset}.usage_import_data`
 GROUP BY 1, 2
 ORDER BY est_sum_on_demand_cost DESC
 LIMIT 100;
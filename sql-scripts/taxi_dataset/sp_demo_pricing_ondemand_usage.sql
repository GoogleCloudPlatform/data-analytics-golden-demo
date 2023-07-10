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

-- WARNING!!!
-- This will return every SQL statement run in BigQuery which could be A LOT!
-- Also, if you have PII data in your SQL (Passport, Date of Birth), it can be shown in some of the SQL statements
-- WARNING!!!

-- SEARCH and REPLACE the below values (if downloading this single file from GitHub)
-- Replace Region          -> Search for: region-${bigquery_region}
-- Replace GCS bucket Path -> Search for: gs://${raw_bucket_name}

Use Cases:
    - Shows the queries that are most used in your organization
    - Shows the estimatated on-demand cost of the queries (retail pricing)

Description: 
    - Loops through each project and get your query data from the informational schema tables

Reference:
    - https://cloud.google.com/bigquery/docs/information-schema-jobs


Clean up / Reset script:
    DROP SCHEMA IF EXISTS `${project_id}.ondemand_query_usage` CASCADE;  
    DROP SCHEMA IF EXISTS `${project_id}.ondemand_query_analysis` CASCADE;  
*/


-- This is designed to help you understand where you should focus your efforts or costs
-- It is NOT an exact costs savings calculator
CREATE SCHEMA `${project_id}.ondemand_query_usage`
    OPTIONS (
    location = "us"
    );


-- Track which projects we are able to get data 
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_usage.usage_export_project`
(
  project_id STRING,
  result STRING
) ;


-- Create a table to hold the results
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_usage.usage_export_data` 
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
  INSERT INTO `${project_id}.ondemand_query_usage.usage_export_data`
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
        -- 6.25 / 1,099,511,627,776 = 0.00000000000568434188608080 ($6.25 per TB so cost per byte is 0.00000000000568434188608080)
        CASE WHEN job.reservation_id IS NULL 
             THEN CAST(CAST(job.total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000568434188608080 AS BIGDECIMAL) AS FLOAT64) 
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

  INSERT INTO `${project_id}.ondemand_query_usage.usage_export_project` (project_id, result) VALUES (record.project_id,'SUCCESS');

  EXCEPTION WHEN ERROR THEN
    -- do nothing we do not have access to the project
    INSERT INTO `${project_id}.ondemand_query_usage.usage_export_project` (project_id, result) VALUES (record.project_id,'FAILED');
  END;

END FOR;


-- Export the data (some people transfer this to have an analysis performed)
-- You should delete the data from this path before exporting
-- You can also share the data via Analytics Hub (Preferred Method of Sharing)
EXPORT DATA
OPTIONS (
   uri = 'gs://${raw_bucket_name}/ondemand_query_usage/*.parquet',
   format = 'PARQUET',
   overwrite = true
   )
AS (
   SELECT *
     FROM `${project_id}.ondemand_query_usage.usage_export_data`
);


-- Test loading the data
DROP TABLE IF EXISTS `${project_id}.ondemand_query_usage.usage_import_data`;

LOAD DATA OVERWRITE `${project_id}.ondemand_query_usage.usage_import_data`
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${raw_bucket_name}/ondemand_query_usage/*.parquet']
);


-- See which projects worked/failed
SELECT * FROM `${project_id}.ondemand_query_usage.usage_export_project` ORDER BY result DESC;


-- See some results
SELECT project_id, query, SUM(est_on_demand_cost) AS est_sum_on_demand_cost, COUNT(1) AS Cnt
  FROM `${project_id}.ondemand_query_usage.usage_export_data`
 GROUP BY 1, 2
 ORDER BY 3 DESC
 LIMIT 100;


------------------------------------------------------------------------------------------------------------
-- Do Analysis
------------------------------------------------------------------------------------------------------------

-- This is designed to help you understand where you should focus your efforts or costs
-- It is NOT an exact costs savings calculator
CREATE SCHEMA `${project_id}.ondemand_query_analysis`
    OPTIONS (
    location = "us"
    );


-- In case we have duplicates (the tables were not dropped between runs)
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_analysis.usage_data` AS
SELECT DISTINCT *
  FROM `${project_id}.ondemand_query_usage.usage_import_data`
 WHERE error_result_reason IS NULL  
   AND reservation_id IS NULL;


-- Cost by month for top 1000 most expensive queries
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_analysis.usage_cost_by_query_top_1000` AS
SELECT project_id, 
       EXTRACT(YEAR  FROM start_time) AS Year,
       EXTRACT(MONTH FROM start_time) AS Month,
       query, 
       SUM(est_on_demand_cost) AS est_sum_on_demand_cost, 
       COUNT(1) AS Cnt,
       AVG(total_bytes_processed) / 1000000000 AS average_gb_processed,
       AVG(job_avg_slots) AS average_job_avg_slots,
       AVG(estimated_runnable_units) AS average_estimated_runnable_units,
  FROM `${project_id}.ondemand_query_analysis.usage_data`
 WHERE error_result_reason IS NULL
   AND reservation_id IS NULL
 GROUP BY 1, 2, 3, 4
 LIMIT 1000;

SELECT project_id,
       Year,
       Month,
       query,
       CAST(est_sum_on_demand_cost AS INT64) AS est_sum_on_demand_cost,
       Cnt,
       CAST(average_gb_processed AS INT64)   AS average_gb_processed,
       CAST(average_job_avg_slots AS INT64)  AS average_job_avg_slots,
       CAST(average_estimated_runnable_units AS INT64) AS average_estimated_runnable_units  
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_query_top_1000`
 ORDER BY est_sum_on_demand_cost DESC;


 -- Usage Costs by Project
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_analysis.usage_cost_by_project` AS
SELECT project_id, 
       EXTRACT(YEAR  FROM start_time) AS Year,
       EXTRACT(MONTH FROM start_time) AS Month,
       SUM(est_on_demand_cost) AS est_sum_on_demand_cost, 
       AVG(total_bytes_processed) / 1000000000 AS average_gb_processed,
       AVG(job_avg_slots) AS average_job_avg_slots,
       AVG(estimated_runnable_units) AS average_estimated_runnable_units,
  FROM `${project_id}.ondemand_query_analysis.usage_data`
 GROUP BY 1, 2, 3;

SELECT project_id,
       Year,
       Month,
       CAST(est_sum_on_demand_cost AS INT64) AS est_sum_on_demand_cost,
       CAST(average_gb_processed AS INT64)   AS average_gb_processed,
       CAST(average_job_avg_slots AS INT64)  AS average_job_avg_slots,
       CAST(average_estimated_runnable_units AS INT64) AS average_estimated_runnable_units  
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project`
 ORDER BY est_sum_on_demand_cost DESC;


-- Total costs for each month single month
-- This is based off of Retail Pricing (no discounts)
-- If you have a 10% discount then you can change the below to (1 minus .10 = .90) SUM(est_sum_on_demand_cost * .90)
SELECT Year,
       Month,
       CAST(SUM(est_sum_on_demand_cost) AS INT64)  AS total
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project`
GROUP BY 1,2
ORDER BY Year, Month;


-- For each minute, for each job, get the maximum number of slots
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_analysis.usage_slots_by_job` AS
SELECT project_id, 
       job_id,
       EXTRACT(YEAR FROM start_time)   AS Year,
       EXTRACT(MONTH FROM start_time)  AS Month,

       ((EXTRACT(DAY    FROM start_time) - 1) * (24*60)) +
       (EXTRACT(HOUR   FROM start_time) * 60) +
       (EXTRACT(MINUTE FROM start_time)) AS start_minute_of_job,

       ((EXTRACT(DAY    FROM end_time) - 1) * (24*60)) +
       (EXTRACT(HOUR   FROM end_time) * 60) +
       (EXTRACT(MINUTE FROM end_time)) AS end_minute_of_job,

       MAX(job_avg_slots) AS average_job_max_slots

  FROM `${project_id}.ondemand_query_analysis.usage_data`
 GROUP BY 1,2,3,4,5,6;


SELECT *
  FROM `${project_id}.ondemand_query_analysis.usage_slots_by_job`
 LIMIT 100;


-- For each minute in the month sum the max slots used by the jobs
-- For each minute determine the number of slots to buy (in increments of 100)
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_analysis.usage_slots_data_per_minute` AS
WITH minutes AS
(
  -- every minute in the month
  SELECT element as minute_number
    FROM UNNEST(GENERATE_ARRAY(1, 44640)) AS element
)
 SELECT project_id, 
        Year,
        Month,
        minute_number,
        CAST(SUM(average_job_max_slots) AS INT64) AS avg_slots,
        CAST(FLOOR((CAST(SUM(average_job_max_slots) AS INT64) + 99) / 100) * 100  AS INT64) AS avg_slots_rounded_up_100_slots
   FROM `${project_id}.ondemand_query_analysis.usage_slots_by_job` AS usage_slots_by_job
        INNER JOIN minutes
                ON minute_number BETWEEN start_minute_of_job AND end_minute_of_job
GROUP BY 1,2,3,4;


SELECT *
 FROM `${project_id}.ondemand_query_analysis.usage_slots_data_per_minute`
ORDER BY project_id, 
         Year,
         Month,
         minute_number
LIMIT 10000;


-- For each minute determine the number of slots to buy (in increments of 100)
-- 0.060 = US PAYG Slot price per 100 per minute at Retail price
CREATE OR REPLACE TABLE `${project_id}.ondemand_query_analysis.usage_slots_payg_slot_cost` AS
 SELECT project_id, 
        Year,
        Month,
        CAST(0.060 * FLOOR((SUM(avg_slots_rounded_up_100_slots) + 99) / 100) AS INT64) AS payg_slot_cost
   FROM `${project_id}.ondemand_query_analysis.usage_slots_data_per_minute` AS usage_slots_data_per_minute
GROUP BY 1,2,3;



-- Compare On-Demand versus Slots (HIGH LEVEL ESTIMATE FOR SEEING IF SLOTS SHOULD BE EVAULATED)
-- The above pricing is a ROUGH estimate so we say payg_slot_cost * 2 to account for any inefficiencies in auto-scaling
SELECT usage_cost_by_project.project_id,
       usage_cost_by_project.Year,
       usage_cost_by_project.Month,
       CAST(AVG(CAST(usage_cost_by_project.est_sum_on_demand_cost AS INT64)) AS INT64) AS est_sum_on_demand_cost,
       CAST(AVG(usage_slots_payg_slot_cost.payg_slot_cost) AS INT64)                   AS est_payg_slot_cost
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project` AS usage_cost_by_project
        INNER JOIN `${project_id}.ondemand_query_analysis.usage_slots_payg_slot_cost` AS usage_slots_payg_slot_cost
                ON usage_cost_by_project.project_id = usage_slots_payg_slot_cost.project_id
               AND usage_cost_by_project.Year       = usage_slots_payg_slot_cost.Year
               AND usage_cost_by_project.Month      = usage_slots_payg_slot_cost.Month
  WHERE est_sum_on_demand_cost > payg_slot_cost * 2
 GROUP BY 1,2,3
 ORDER BY 4 DESC;

-- $2000 is used as a high level estimate of 100 slots
 SELECT usage_cost_by_project.project_id,
        usage_cost_by_project.Year,
        usage_cost_by_project.Month,
        CAST(AVG(CAST(usage_cost_by_project.est_sum_on_demand_cost AS INT64)) AS INT64) -
        CAST(AVG(usage_slots_payg_slot_cost.payg_slot_cost) AS INT64)                   AS rough_savings,
        REPEAT('$', CAST((CAST(AVG(CAST(usage_cost_by_project.est_sum_on_demand_cost AS INT64)) AS INT64) -
        CAST(AVG(usage_slots_payg_slot_cost.payg_slot_cost) AS INT64))/2000 AS INT))
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project` AS usage_cost_by_project
        INNER JOIN `${project_id}.ondemand_query_analysis.usage_slots_payg_slot_cost` AS usage_slots_payg_slot_cost
                ON usage_cost_by_project.project_id = usage_slots_payg_slot_cost.project_id
               AND usage_cost_by_project.Year       = usage_slots_payg_slot_cost.Year
               AND usage_cost_by_project.Month      = usage_slots_payg_slot_cost.Month
  WHERE est_sum_on_demand_cost > payg_slot_cost * 2
 GROUP BY 1,2,3
ORDER BY 4 DESC;


-- Create Looker Views
CREATE OR REPLACE VIEW `${project_id}.ondemand_query_analysis.looker_cost_per_month` AS
SELECT Year,
       Month,
       CAST(CONCAT(CAST(Year AS STRING),'-',CAST(Month AS STRING),'-01') AS DATE) AS SortDate,
       CAST(SUM(est_sum_on_demand_cost) AS INT64)  AS Total
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project`
GROUP BY 1,2;


CREATE OR REPLACE VIEW `${project_id}.ondemand_query_analysis.looker_cost_per_month_per_project` AS
SELECT project_id,
       Year,
       Month,
       CAST(CONCAT(CAST(Year AS STRING),'-',CAST(Month AS STRING),'-01') AS DATE) AS SortDate,
       CAST(SUM(est_sum_on_demand_cost) AS INT64)  AS Total
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project`
GROUP BY 1,2,3;


CREATE OR REPLACE VIEW `${project_id}.ondemand_query_analysis.looker_most_expensive_queries` AS
SELECT project_id,
       Year,
       Month,
       SUBSTRING(query, 1, 1000) AS query,
       CAST(est_sum_on_demand_cost AS INT64) AS est_sum_on_demand_cost,
       Cnt AS execution_count,
       CAST(average_gb_processed AS INT64)   AS average_gb_processed,
       CAST(average_job_avg_slots AS INT64)  AS average_job_avg_slots,
       CAST(average_estimated_runnable_units AS INT64) AS average_estimated_runnable_units  
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_query_top_1000`;


-- $2000 is used as a high level estimate of 100 slots
CREATE OR REPLACE VIEW `${project_id}.ondemand_query_analysis.looker_ondemand_vs_slots` AS
WITH data AS
(
 SELECT usage_cost_by_project.project_id,
        usage_cost_by_project.Year,
        usage_cost_by_project.Month,
        CAST(SUM(usage_cost_by_project.est_sum_on_demand_cost) AS INT64) AS est_sum_on_demand_cost,
        CAST(AVG(CAST(usage_cost_by_project.est_sum_on_demand_cost AS INT64)) AS INT64) -
        CAST(AVG(usage_slots_payg_slot_cost.payg_slot_cost) AS INT64)                   AS rough_savings,
        REPEAT('$', CAST((CAST(AVG(CAST(usage_cost_by_project.est_sum_on_demand_cost AS INT64)) AS INT64) -
        CAST(AVG(usage_slots_payg_slot_cost.payg_slot_cost) AS INT64))/2000 AS INT)) AS stars
  FROM `${project_id}.ondemand_query_analysis.usage_cost_by_project` AS usage_cost_by_project
        INNER JOIN `${project_id}.ondemand_query_analysis.usage_slots_payg_slot_cost` AS usage_slots_payg_slot_cost
                ON usage_cost_by_project.project_id = usage_slots_payg_slot_cost.project_id
               AND usage_cost_by_project.Year       = usage_slots_payg_slot_cost.Year
               AND usage_cost_by_project.Month      = usage_slots_payg_slot_cost.Month
  WHERE est_sum_on_demand_cost > payg_slot_cost * 2
 GROUP BY 1,2,3
)
SELECT *
  FROM data;


-- Show the Looker report:
/*
Clone this report: https://lookerstudio.google.com/reporting/32c72a9a-1172-44d3-8f92-3eebdb042a02
Click the 3 dots in the top right and select "Make a copy"
Click "Copy Report"
Click "Resouce" menu then "Manage added data sources"
Click "Edit" under Actions title
Click "${project_id}" (or enter the Project Id) under Project title
Click "${bigquery_taxi_dataset}" under Dataset title
Click "looker_most_expensive_queries" under Table title
Click "Reconnect"
Click "Apply" - there should be no field changes
Click "Done" - in top right
Repeat the above for each data source (3 additional ones)
Click "Close" - in top right
You can now see the data
*/
SELECT * FROM `${project_id}.ondemand_query_analysis.looker_ondemand_vs_slots` ORDER BY rough_savings DESC;

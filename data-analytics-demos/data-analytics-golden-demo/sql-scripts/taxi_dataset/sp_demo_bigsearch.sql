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
    - Show BigSearch on 5.83 TB table with 5.2 billion rows
    - Show the table with and without a BigSearch index
    - NOTE: You will be consuming at lot of bytes scanned during this demo ($6.25 per 1 TB scanned)
    - NOTE: Drop the Large tables to save on Costs! (at end of script)

Description: 
    - Shows searching a large table on various columns with various partitioning filters

Show:
    - 

References:
    - https://cloud.google.com/bigquery/docs/search-intro

Clean up / Reset script:
    DROP SEARCH INDEX IF EXISTS idx_all_bigsearch_log_5b_5t_json_hourly ON `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`;
 
 More Data (BigSearch on more Data):
    - NOTE: To run some SQL on a 60TB, 50 billon row table head over to the shared project
    - Open a new tab and paste the URL below.  
    - https://console.cloud.google.com/bigquery?project=${shared_demo_project_id}
    - OPEN the stored procedure: ${shared_demo_project_id}.bigquery_features.sp_demo_bigsearch_50b_60t

*/

---------------------------------------------------------------------------------------------------------
-- NOTE: You might want to copy the tables and create the indexs BEFORE your demo.
--       It can take 15 minutes for everything to complete!
---------------------------------------------------------------------------------------------------------

CREATE TABLE `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`
COPY `${shared_demo_project_id}.data_analytics_shared_data.bigsearch_log_5b_5t_json_hourly`;

CREATE TABLE `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`
COPY `${shared_demo_project_id}.data_analytics_shared_data.bigsearch_log_5b_5t_json_hourly`;


---------------------------------------------------------------------------------------------------------
-- Create an index on the "Indexed" table
---------------------------------------------------------------------------------------------------------
-- LOG_ANALYZER analyzer works well for machine generated logs and has special rules around tokens commonly found in observability data, such as IP addresses or emails.
CREATE SEARCH INDEX idx_all_bigsearch_log_5b_5t_json_hourly 
    ON `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED` (ALL COLUMNS)
    OPTIONS (analyzer = 'LOG_ANALYZER');


-- Check our index (index_status = "Active", "total storage bytes" = 117 GB)
-- See the unindexed_row_count (rows not indexed)
-- Make sure your coverage_percent = 100 (so we know we are done indexing)
SELECT * -- table_name, index_name, ddl, coverage_percentage
  FROM `${project_id}.${bigquery_taxi_dataset}.INFORMATION_SCHEMA.SEARCH_INDEXES`
 WHERE index_status = 'ACTIVE';


-- See the columns that are in the index
SELECT * -- table_name, index_name, ddl, coverage_percentage
  FROM `${project_id}.${bigquery_taxi_dataset}.INFORMATION_SCHEMA.SEARCH_INDEX_COLUMNS`
 WHERE index_name = 'idx_all_bigsearch_log_5b_5t_json_hourly';


---------------------------------------------------------------------------------------------------------
-- Compare the INDEX versus the NOT INDEX tables for performance
---------------------------------------------------------------------------------------------------------
-- NOT_INDEXED
-- Search the Text Payload field of the log table (lots of text to sort through)
-- Result: Cnt = 351,124
-- Duration: 8 sec 
-- Bytes processed: 2.99 TB 
SELECT COUNT(*) AS Cnt
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`
 WHERE SEARCH(textPayload, 'service281');

-- Search the Text Payload field of the log table (lots of text to sort through)
-- Result: Cnt = 351,124
-- Duration: 6 sec 
-- Bytes processed: 2.99 TB 
-- Index Usage Mode: FULLY_USED 
SELECT COUNT(*) AS Cnt
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`
 WHERE SEARCH(textPayload, 'service281');

-- NOT_INDEXED
-- Search the field "insertId" for a value (just one column)
-- Duration: 5 sec
-- Bytes processed: 5.83 TB 
-- Index Usage Mode: UNUSED
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`
 WHERE SEARCH(insertId, '40ms4zeh78tg6o6jx');

-- Search the field "insertId" for a value (just one column)
-- Duration: 0 sec 
-- Bytes processed: 81.44 MB 
-- Index Usage Mode: FULLY_USED
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`
 WHERE SEARCH(insertId, '40ms4zeh78tg6o6jx');

---------------------------------------------------------------------------------------------------------
-- Compare RegEx search versus BigSearch SEARCH 
---------------------------------------------------------------------------------------------------------
-- Use RegEx
-- Duration: 5 sec 
-- Bytes processed:  739.99 GB 
-- Count: 26,504
SELECT COUNT(*) AS Cnt
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`
 WHERE REGEXP_CONTAINS(internalClusterId, r"(?i)(\b|_)gke-workload-test-gpu-pool-c358b5f5-2fll(\b|_)");

-- Use BQ Search 
-- Duration: 2 sec
-- Bytes processed: 123.58 GB 
-- Count: 26,504
SELECT COUNT(*) AS Cnt
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`
 WHERE SEARCH(internalClusterId, '`gke-workload-test-gpu-pool-c358b5f5-2fll`');


---------------------------------------------------------------------------------------------------------
-- Search ALL columns or on SEVERAL columns
---------------------------------------------------------------------------------------------------------
-- Search across all columns (has to search lots of data)
-- Duration: 36 sec 
-- Bytes processed: 5.79 TB 
-- Cnt: 2,207,223
SELECT COUNT(*) AS Cnt
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED` AS LogsIndexed
 WHERE SEARCH(LogsIndexed, 'service281');

-- Search 2 columns (searches less data since we know the columns to search)
-- Duration: 4 sec
-- Bytes processed: 1.11 TB 
-- Cnt: 1,856,005
SELECT COUNT(*) AS Cnt 
  FROM `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED` AS LogsIndexed
 WHERE SEARCH((internalClusterId, labels), 'service281');


---------------------------------------------------------------------------------------------------------
-- Clean up Large Data (to save on costs)
---------------------------------------------------------------------------------------------------------
DROP SEARCH INDEX IF EXISTS idx_all_bigsearch_log_5b_5t_json_hourly ON `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`;
DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_NOT_INDEXED`;
DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.bigsearch_log_5b_5t_json_hourly_INDEXED`;



---------------------------------------------------------------------------------------------------------
-- NOTE: To run some SQL on a 60TB, 50 billon row table head over to the shared project
-- Open a new tab and paste the URL below.  
-- https://console.cloud.google.com/bigquery?project=${shared_demo_project_id}
-- OPEN the stored procedure: ${shared_demo_project_id}.bigquery_features.sp_demo_bigsearch_50b_60t
---------------------------------------------------------------------------------------------------------
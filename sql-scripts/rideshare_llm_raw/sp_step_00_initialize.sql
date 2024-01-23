/*##################################################################################
# Copyright 2023 Google LLC
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
      - 

  Description: 
      - Loads the data for the AI Lakehouse Raw Zone

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


------------------------------------------------------------------------------------------------------------
-- Create link to the LLM
------------------------------------------------------------------------------------------------------------
/*
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_raw_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_LARGE_LANGUAGE_MODEL_V1');
*/

-- New Syntax for specifying a model version text-bison@001 or text-bison@002 for latest or text-bison-32k@latest
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_raw_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (endpoint = 'text-bison@002');

------------------------------------------------------------------------------------------------------------
-- Location Table
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.location`
CLUSTER BY location_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/raw_zone/location/*.parquet']
);


------------------------------------------------------------------------------------------------------------
-- Payment Type
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.payment_type`
CLUSTER BY payment_type_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/raw_zone/payment_type/*.parquet']
);


------------------------------------------------------------------------------------------------------------
-- Trip table
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.trip`
CLUSTER BY trip_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/raw_zone/trip/*.parquet']
);


------------------------------------------------------------------------------------------------------------
-- Customer
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.customer`
CLUSTER BY customer_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/raw_zone/customer/*.parquet']
);


------------------------------------------------------------------------------------------------------------
-- Driver
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.driver`
CLUSTER BY driver_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/raw_zone/driver/*.parquet']
);


------------------------------------------------------------------------------------------------------------
-- Customer Reviews
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.customer_review`
CLUSTER BY customer_id, trip_id, driver_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/raw_zone/customer_review/*.parquet']
);

------------------------------------------------------------------------------------------------------------
-- Audios (Object Table)
------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT  1
             FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}`.INFORMATION_SCHEMA.TABLES
            WHERE table_name = 'biglake_rideshare_audios' 
              AND table_type = 'EXTERNAL')
    THEN
    CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_llm_raw_dataset}.biglake_rideshare_audios`
    WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
        object_metadata="DIRECTORY",
        uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_audios/*.mp3'],
        max_staleness=INTERVAL 30 MINUTE, 
        --metadata_cache_mode="AUTOMATIC"
        -- set to Manual for demo
        metadata_cache_mode="MANUAL"
        ); 
END IF;

-- For the demo, refresh the table (so we do not need to wait)
-- Refresh can only be done for "manual" cache mode
CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('${project_id}.${bigquery_rideshare_llm_raw_dataset}.biglake_rideshare_audios');


-- Show our objects in GCS / Data Lake
-- Metadata values are recorded as to where the image was taken
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.biglake_rideshare_audios`;  


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
      - 

  Description: 
      - Initialize the "enriched" zone of the AI Lakehouse

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/



------------------------------------------------------------------------------------------------------------
-- Create link to the LLM
------------------------------------------------------------------------------------------------------------
/*
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_LARGE_LANGUAGE_MODEL_V1');
*/

-- New Syntax for specifying a model version text-bison@001 or text-bison@002 for latest or text-bison-32k@latest
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (endpoint = 'text-bison@002');

------------------------------------------------------------------------------------------------------------
-- Create link to the STT model
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_raw_dataset}.cloud_ai_stt_v2`
REMOTE WITH CONNECTION `${project_id}.us.biglake-connection`
OPTIONS (
  REMOTE_SERVICE_TYPE = 'CLOUD_AI_SPEECH_TO_TEXT_V2'
);

------------------------------------------------------------------------------------------------------------
-- Location Table
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.location`
CLUSTER BY location_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.location`;


------------------------------------------------------------------------------------------------------------
-- Payment Type
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.payment_type`
CLUSTER BY payment_type_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.payment_type`;


------------------------------------------------------------------------------------------------------------
-- Trip table
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.trip`
CLUSTER BY trip_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.trip`;


------------------------------------------------------------------------------------------------------------
-- Customer
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer`
CLUSTER BY customer_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.customer`;


------------------------------------------------------------------------------------------------------------
-- Driver
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver`
CLUSTER BY driver_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.driver`;


------------------------------------------------------------------------------------------------------------
-- Customer Reviews
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review`
CLUSTER BY customer_id, trip_id, driver_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_raw_dataset}.customer_review`;


------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------
-- Bring in Pre-Scored LLM data
-- This way the demo is pre-seeded with data and you do not need to process ALL the data yourself
------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------
-- Driver LLM fields (Add fields)
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver`
  ADD COLUMN IF NOT EXISTS driver_attribute_llm_summary_prompt STRING,
  ADD COLUMN IF NOT EXISTS llm_summary_driver_attribute_json JSON,
  ADD COLUMN IF NOT EXISTS llm_summary_driver_attribute STRING,

  ADD COLUMN IF NOT EXISTS driver_review_summary_llm_summary_prompt STRING,
  ADD COLUMN IF NOT EXISTS llm_summary_driver_review_summary_json JSON,
  ADD COLUMN IF NOT EXISTS llm_summary_driver_review_summary STRING,

  ADD COLUMN IF NOT EXISTS driver_quantitative_analysis_prompt STRING,
  ADD COLUMN IF NOT EXISTS llm_driver_quantitative_analysis_json JSON,
  ADD COLUMN IF NOT EXISTS llm_driver_quantitative_analysis STRING
;


-- Driver LLM fields (Load the data)
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sidecar_driver`
CLUSTER BY driver_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/enriched_zone/sidecar_driver/*.parquet']
);


-- Driver LLM fields (Update the table)
UPDATE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver` AS driver
   SET driver_attribute_llm_summary_prompt = sidecar_driver.driver_attribute_llm_summary_prompt,
       llm_summary_driver_attribute_json = TO_JSON(sidecar_driver.llm_summary_driver_attribute_json),
       llm_summary_driver_attribute = sidecar_driver.llm_summary_driver_attribute,

       driver_review_summary_llm_summary_prompt = sidecar_driver.driver_review_summary_llm_summary_prompt,
       llm_summary_driver_review_summary_json = TO_JSON(sidecar_driver.llm_summary_driver_review_summary_json),
       llm_summary_driver_review_summary = sidecar_driver.llm_summary_driver_review_summary,

       driver_quantitative_analysis_prompt = sidecar_driver.driver_quantitative_analysis_prompt,
       llm_driver_quantitative_analysis_json = TO_JSON(sidecar_driver.llm_driver_quantitative_analysis_json),
       llm_driver_quantitative_analysis = sidecar_driver.llm_driver_quantitative_analysis

  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sidecar_driver` AS sidecar_driver
 WHERE driver.driver_id = sidecar_driver.driver_id;


------------------------------------------------------------------------------------------------------------
-- Customer LLM fields (Add fields)
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer`
  ADD COLUMN IF NOT EXISTS customer_attribute_llm_summary_prompt STRING,
  ADD COLUMN IF NOT EXISTS llm_summary_customer_attribute_json JSON,
  ADD COLUMN IF NOT EXISTS llm_summary_customer_attribute STRING,

  ADD COLUMN IF NOT EXISTS customer_review_summary_llm_summary_prompt STRING,
  ADD COLUMN IF NOT EXISTS llm_summary_customer_review_summary_json JSON,
  ADD COLUMN IF NOT EXISTS llm_summary_customer_review_summary STRING,

  ADD COLUMN IF NOT EXISTS customer_quantitative_analysis_prompt STRING,
  ADD COLUMN IF NOT EXISTS llm_customer_quantitative_analysis_json JSON,
  ADD COLUMN IF NOT EXISTS llm_customer_quantitative_analysis STRING
;

-- Customer LLM fields (Load the data)
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sidecar_customer`
CLUSTER BY customer_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/enriched_zone/sidecar_customer/*.parquet']
);


-- Customer LLM fields (Update the table)
UPDATE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer` AS customer
   SET customer_attribute_llm_summary_prompt = sidecar_customer.customer_attribute_llm_summary_prompt,
       llm_summary_customer_attribute_json = TO_JSON(sidecar_customer.llm_summary_customer_attribute_json),
       llm_summary_customer_attribute = sidecar_customer.llm_summary_customer_attribute,

       customer_review_summary_llm_summary_prompt = sidecar_customer.customer_review_summary_llm_summary_prompt,
       llm_summary_customer_review_summary_json = TO_JSON(sidecar_customer.llm_summary_customer_review_summary_json),
       llm_summary_customer_review_summary = sidecar_customer.llm_summary_customer_review_summary,

       customer_quantitative_analysis_prompt = sidecar_customer.customer_quantitative_analysis_prompt,
       llm_customer_quantitative_analysis_json = TO_JSON(sidecar_customer.llm_customer_quantitative_analysis_json),
       llm_customer_quantitative_analysis = sidecar_customer.llm_customer_quantitative_analysis

  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sidecar_customer` AS sidecar_customer
 WHERE customer.customer_id = sidecar_customer.customer_id;



------------------------------------------------------------------------------------------------------------
-- Customer Review LLM fields (Add fields)
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review`
  ADD COLUMN IF NOT EXISTS llm_sentiment_prompt STRING,
  ADD COLUMN IF NOT EXISTS raw_sentiment_json JSON,
  ADD COLUMN IF NOT EXISTS review_sentiment STRING,

  ADD COLUMN IF NOT EXISTS extracted_driver_theme_json JSON,
  ADD COLUMN IF NOT EXISTS extracted_driver_theme STRING,

  ADD COLUMN IF NOT EXISTS extracted_customer_theme_json JSON,
  ADD COLUMN IF NOT EXISTS extracted_customer_theme STRING
;

-- Customer Review LLM fields (Load the data)
LOAD DATA OVERWRITE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sidecar_customer_review`
CLUSTER BY customer_id, trip_id, driver_id
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_llm_export/enriched_zone/sidecar_customer_review/*.parquet']
);


-- Customer Review LLM fields (Update the table)
UPDATE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review` AS customer_review
   SET llm_sentiment_prompt = sidecar_customer_review.llm_sentiment_prompt,
       raw_sentiment_json = TO_JSON(sidecar_customer_review.raw_sentiment_json),
       review_sentiment = sidecar_customer_review.review_sentiment,

       extracted_driver_theme_json = TO_JSON(sidecar_customer_review.extracted_driver_theme_json),
       extracted_driver_theme = sidecar_customer_review.extracted_driver_theme,

       extracted_customer_theme_json = TO_JSON(sidecar_customer_review.extracted_customer_theme_json),
       extracted_customer_theme = sidecar_customer_review.extracted_customer_theme

  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sidecar_customer_review` AS sidecar_customer_review
 WHERE customer_review.customer_id = sidecar_customer_review.customer_id
   AND customer_review.trip_id = sidecar_customer_review.trip_id
   AND customer_review.driver_id = sidecar_customer_review.driver_id;


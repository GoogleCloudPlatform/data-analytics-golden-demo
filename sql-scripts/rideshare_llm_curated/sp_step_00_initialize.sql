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
      - Initialize the Curated zone of the AI Lakehouse

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


------------------------------------------------------------------------------------------------------------
-- Create link to the LLM
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_curated_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_LARGE_LANGUAGE_MODEL_V1');


------------------------------------------------------------------------------------------------------------
-- Location Table
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.location`
CLUSTER BY location_id
AS 
SELECT *     
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.location`;


------------------------------------------------------------------------------------------------------------
-- Payment Type
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.payment_type`
CLUSTER BY payment_type_id
AS 
SELECT *     
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.payment_type`;


------------------------------------------------------------------------------------------------------------
-- Trip table
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`
CLUSTER BY trip_id, driver_id, customer_id
AS 
SELECT *     
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.trip`;


------------------------------------------------------------------------------------------------------------
-- Customer
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` 
CLUSTER BY customer_id
AS 
SELECT customer.customer_id,
       customer.customer_name,
       customer.customer_since_date,
       customer.include_in_llm_processing,
       customer.llm_summary_customer_attribute AS customer_attribute_summary,
       customer.llm_summary_customer_review_summary AS customer_review_summary,
       customer.llm_customer_quantitative_analysis AS customer_quantitative_analysis,
       COUNT(*)             AS total_trip_count,
       AVG(passenger_count) AS avg_passenger_count,
       AVG(trip_distance)   AS avg_trip_distance,
       AVG(fare_amount)     AS avg_fare_amount,
       AVG(tip_amount)      AS avg_tip_amount,
       AVG(total_amount)    AS avg_total_amount,
       SUM(total_amount)    AS sum_total_amount
 FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer` AS customer
      INNER JOIN  `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS trip
             ON customer.customer_id = trip.customer_id
GROUP BY 1,2,3,4,5,6,7
;


------------------------------------------------------------------------------------------------------------
-- Customer Reviews
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review` 
CLUSTER BY customer_id
AS
SELECT customer.customer_id,
       customer.customer_name,
       customer.include_in_llm_processing AS customer_include_in_llm_processing,
       customer_review.trip_id,
       customer_review.review_date,
       driver.driver_id,
       driver.driver_name,
       driver.include_in_llm_processing AS driver_include_in_llm_processing,
       customer_review.customer_review_text,
       customer_review.review_sentiment,
       customer_review.extracted_driver_theme,
       customer_review.extracted_customer_theme       
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review` AS customer_review
              ON customer.customer_id = customer_review.customer_id   
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver` AS driver
              ON customer_review.driver_id = driver.driver_id
;


------------------------------------------------------------------------------------------------------------
-- Customer Reviews (Summary)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE MATERIALIZED VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review_summary`
CLUSTER BY customer_id
OPTIONS (enable_refresh = true, refresh_interval_minutes = 30)
AS
SELECT customer.customer_id,
       customer.customer_name, 
       customer.include_in_llm_processing,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%neutral%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%') AS total_review_count_postive,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%neutral%')  AS total_review_count_neutral,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count_negative,
       
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review` AS customer_review
              ON customer.customer_id = customer_review.customer_id   
GROUP BY 1, 2, 3
;


------------------------------------------------------------------------------------------------------------
-- Customer Table (Preferences)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_preference` 
CLUSTER BY customer_id
AS 
SELECT DISTINCT 
       customer.customer_id,
       customer.customer_name,
       customer.include_in_llm_processing,
       CASE WHEN TRIM(LOWER(extracted_customer_attribute)) = 'speaks spanish'                      THEN 'Bilingual'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'prefers english'                     THEN 'Speaks English'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes a clean car'                   THEN 'Likes a clean car'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'prefers the radio on'                THEN 'Likes the radio on'  
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'prefers the radio off'               THEN 'Likes the radio off'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'travels with large luggage'          THEN 'Likes a large amount of trunck space'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'travels with small luggage'          THEN 'Typically travels without luggage'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes a warm vehicle inside'         THEN 'Likes the car to be warm inside'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes a cooler vehicle inside'       THEN 'Likes the car to be cool inside'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes their driver to drive fast'    THEN 'Likes a driver that drives quickly'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes their driver to drive slow'    THEN 'Likes a driver that drives slowly'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes to have a conversation'        THEN 'Likes a driver who likes conversation'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'perfers a driver that does not talk' THEN 'Likes a quiet driver'
            ELSE 'Other'
       END AS preference

   FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_attribute` AS customer_attribute
        INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
                ON customer_attribute.customer_id = customer.customer_id
               AND customer_attribute.rank_order = 1
;


------------------------------------------------------------------------------------------------------------
-- Looker "Customer" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer`
AS
SELECT customer.customer_id,
       customer.customer_name,
       customer.customer_since_date,
       customer.include_in_llm_processing,
       customer.customer_attribute_summary,
       customer.customer_review_summary,
       customer.customer_quantitative_analysis,
       customer.total_trip_count,
       customer.avg_passenger_count,
       customer.avg_trip_distance,
       customer.avg_fare_amount,
       customer.avg_tip_amount,
       customer.avg_total_amount,
       customer.sum_total_amount,

       customer_review_summary.total_review_count,
       customer_review_summary.total_review_count_postive,
       customer_review_summary.total_review_count_neutral,
       customer_review_summary.total_review_count_negative,

  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
        LEFT JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review_summary` AS customer_review_summary
              ON customer.customer_id = customer_review_summary.customer_id
;


------------------------------------------------------------------------------------------------------------
-- Looker "Customer Preferences" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer_preference`
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_preference`
;


------------------------------------------------------------------------------------------------------------
-- Looker "Customer Reviews" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer_review`
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review`
;


------------------------------------------------------------------------------------------------------------
-- Driver Table w/Averages
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` 
CLUSTER BY driver_id
AS 
SELECT driver.driver_id,
       driver.driver_name,
       driver.driver_since_date,
       driver.include_in_llm_processing,
       driver.llm_summary_driver_attribute AS driver_attribute_summary,
       driver.llm_summary_driver_review_summary AS driver_review_summary,
       driver.llm_driver_quantitative_analysis AS driver_quantitative_analysis,       
       COUNT(*)             AS total_trip_count,
       AVG(passenger_count) AS avg_passenger_count,
       AVG(trip_distance)   AS avg_trip_distance,
       AVG(fare_amount)     AS avg_fare_amount,
       AVG(tip_amount)      AS avg_tip_amount,
       AVG(total_amount)    AS avg_total_amount,    
       SUM(total_amount)    AS sum_total_amount   
 FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver` AS driver
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS trip
              ON driver.driver_id = trip.driver_id
GROUP BY 1,2,3,4,5,6,7
;


------------------------------------------------------------------------------------------------------------
-- Driver Reviews (some data cleaning from LLM)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE MATERIALIZED VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_review_summary`
CLUSTER BY driver_id
OPTIONS (enable_refresh = true, refresh_interval_minutes = 30)
AS 
SELECT driver.driver_id,
       driver.driver_name,
       driver.include_in_llm_processing,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%neutral%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%') AS total_review_count_postive,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%neutral%')  AS total_review_count_neutral,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count_negative,
       
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review` AS customer_review
             ON driver.driver_id = customer_review.driver_id
GROUP BY 1, 2, 3
;


------------------------------------------------------------------------------------------------------------
-- Driver Table (Preferences)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_preference` 
CLUSTER BY driver_id
AS 
SELECT DISTINCT 
       driver.driver_id,
       driver.driver_name,
       driver.include_in_llm_processing,
       CASE WHEN TRIM(LOWER(extracted_driver_attribute)) = 'safe driver'                   THEN 'Safe Driver'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes music'            THEN 'Radio On'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes no music'         THEN 'Radio Off'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'trunk space large'             THEN 'Large amount of truck space'  
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'trunk space small'             THEN 'Limited amount of truck space'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes conversation'     THEN 'Likes conversation with customer(s)'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes no conversation'  THEN 'Likes prefers not talking with customer(s)'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driving too fast'              THEN 'Drives fast'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driving too slow'              THEN 'Drives slow'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'clean car'                     THEN 'Keeps a clean car'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'dirty car'                     THEN 'Keeps a ditry car'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'car too hot'                   THEN 'Keeps car temperature warm'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'car too cold'                  THEN 'Keeps car temperature cool'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver speaks spanish'         THEN 'Bilingual'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver does not speak spanish' THEN 'Speaks English'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'distracted driver'             THEN 'Unsafe Distracted Driver'
            ELSE 'Other'
       END AS preference

   FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver_attribute` AS driver_attribute
        INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
                ON driver_attribute.driver_id = driver.driver_id
               AND driver_attribute.rank_order = 1
;


------------------------------------------------------------------------------------------------------------
-- Looker "Driver" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_driver`
AS
SELECT driver.driver_id,
       driver.driver_name,
       driver.driver_since_date,
       driver.include_in_llm_processing,
       driver.driver_attribute_summary,
       driver.driver_review_summary,
       driver.driver_quantitative_analysis,
       driver.total_trip_count,
       driver.avg_passenger_count,
       driver.avg_trip_distance,
       driver.avg_fare_amount,
       driver.avg_tip_amount,
       driver.avg_total_amount,
       driver.sum_total_amount,

       driver_review_summary.total_review_count,
       driver_review_summary.total_review_count_postive,
       driver_review_summary.total_review_count_neutral,
       driver_review_summary.total_review_count_negative,

  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
       LEFT JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_review_summary` AS driver_review_summary
              ON driver.driver_id = driver_review_summary.driver_id
;


------------------------------------------------------------------------------------------------------------
-- Looker "Driver Preferences" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_driver_preference`
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_preference`
;

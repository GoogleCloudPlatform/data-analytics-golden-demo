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
      - Extract the attributes for our customers

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


---------------------------------------------------------------------------------------------------------------------
-- Customer: 
---------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_attribute`
CLUSTER BY customer_id
AS
WITH customer_attribute_data AS
(
SELECT customer_review.customer_id,
       customer_review.extracted_customer_theme,

       CASE WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer has small luggage%'          THEN 'travels with small luggage'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer has large luggage%'          THEN 'travels with large luggage'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes to drive fast%'        THEN 'likes their driver to drive fast'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes to drive slow%'        THEN 'likes their driver to drive slow'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer speaks spanish%'             THEN 'speaks spanish'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer does not speak spanish%'     THEN 'prefers english'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes a clean car%'          THEN 'likes a clean car'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes the temperature warm%' THEN 'likes a warm vehicle inside'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes the temperature cold%' THEN 'likes a cooler vehicle inside'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes conversation%'         THEN 'likes to have a conversation'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes no conversation%'      THEN 'perfers a driver that does not talk'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes music%'                THEN 'prefers the radio on'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes quiet%'                THEN 'prefers the radio off'
            ELSE 'unknown'
        END AS extracted_customer_attribute,

       CASE WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer has small luggage%'          THEN 'trunk-space'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer has large luggage%'          THEN 'trunk-space'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes to drive fast%'        THEN 'customer-speed'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes to drive slow%'        THEN 'customer-speed'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer speaks spanish%'             THEN 'spanish-language'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer does not speak spanish%'     THEN 'spanish-language'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes a clean car%'          THEN 'car-cleanliness'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes the temperature warm%' THEN 'car-temperature'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes the temperature cold%' THEN 'car-temperature'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes conversation%'         THEN 'conversation'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes no conversation%'      THEN 'conversation'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes music%'                THEN 'music'
            WHEN LOWER(customer_review.extracted_customer_theme) LIKE '%customer likes quiet%'                THEN 'music'
            ELSE 'unknown'
        END AS customer_attribute_grouping,

       COUNT(*) AS cnt
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review` AS  customer_review
GROUP BY customer_review.customer_id,
         customer_review.extracted_customer_theme,
         customer_attribute_grouping
)
, ranking AS
(
  SELECT customer_id,
         extracted_customer_attribute,
         customer_attribute_grouping,
         cnt,
         ROW_NUMBER() OVER (PARTITION BY customer_id, customer_attribute_grouping ORDER BY cnt DESC) AS rank_order
    FROM customer_attribute_data
   WHERE extracted_customer_attribute != 'unknown'
     AND customer_attribute_grouping != 'unknown'
)
SELECT *
  FROM ranking
 WHERE ranking.rank_order = 1
   --AND cnt > 10 -- make sure we just do not have just a few indicators of a theme
;

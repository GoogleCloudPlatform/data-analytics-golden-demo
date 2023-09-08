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
      - Extract the attributes for our drivers

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


---------------------------------------------------------------------------------------------------------------------
-- Driver: 
---------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver_attribute`
CLUSTER BY driver_id
AS
WITH driver_attribute_data AS
(
SELECT trip.driver_id,
       customer_review.extracted_driver_theme AS extracted_driver_attribute,
       CASE WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%trunk space small%'             THEN 'trunk-space'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%trunk space large%'             THEN 'trunk-space'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driving too fast%'              THEN 'driver-speed'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driving too slow%'              THEN 'driver-speed'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driver speaks spanish%'         THEN 'spanish-language'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driver does not speak spanish%' THEN 'spanish-language'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%clean car%'                     THEN 'car-cleanliness'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%dirty car%'                     THEN 'car-cleanliness'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%car too hot%'                   THEN 'car-temperature'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%car too cold%'                  THEN 'car-temperature'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driver likes conversation%'     THEN 'conversation'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driver likes no conversation%'  THEN 'conversation'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driver likes music%'            THEN 'music'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%driver likes no music%'         THEN 'music'
            WHEN LOWER(customer_review.extracted_driver_theme) LIKE '%distracted driver%'             THEN 'distracted-driver'
            ELSE 'unknown'
        END AS driver_attribute_grouping,
       COUNT(*) AS cnt
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review` AS  customer_review
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.trip` AS trip
               ON customer_review.trip_id = trip.trip_id
GROUP BY trip.driver_id,
         customer_review.extracted_driver_theme,
         driver_attribute_grouping
)
, ranking AS
(
  SELECT driver_id,
         extracted_driver_attribute,
         driver_attribute_grouping,
         cnt,
         ROW_NUMBER() OVER (PARTITION BY driver_id, driver_attribute_grouping ORDER BY cnt DESC) AS rank_order
    FROM driver_attribute_data
  WHERE driver_attribute_grouping != 'unknown'
)
SELECT *
  FROM ranking
 WHERE ranking.rank_order = 1
   AND cnt > 10 -- make sure we just do not have just a few indicators of a theme
;

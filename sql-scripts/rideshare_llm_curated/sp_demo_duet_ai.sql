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
      - Use GenAI for:
        - Code Completion
        - Code Generation
        - Code Explaination

  Description: 
      - See how we can use Duet AI and Prompts to code SQL for us

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


-- In project:${project_id}, dataset:${bigquery_rideshare_llm_curated_dataset}, table:trip find the longest trip_distance
SELECT max(TRIP_DISTANCE) 
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`;


/* Since we have descriptions for each column lets write the prompt using business terms */
-- In project:${project_id}, dataset:${bigquery_rideshare_llm_curated_dataset}, table:trip find the first inception date.
SELECT min(DRIVER_SINCE_DATE)
FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver`;


/* We can even use LLMs to generate field names for our database tables.  In this case we want the field to have the business term */
/* This will return " Customer Since Date - The inception date of the customer relationship" */

/* Uncomment this out.  The model cloud_ai_llm_v1 does not exist at deployment time
SELECT JSON_VALUE(ml_generate_text_result, '$.predictions[0].content') AS result, 
     ml_generate_text_result
FROM ML.GENERATE_TEXT(MODEL`${project_id}.${bigquery_rideshare_llm_curated_dataset}.cloud_ai_llm_v1`,
     (SELECT
"""
For the following field name:
1. Replace underscores with spaces
2. Apply proper capitalization to the output
3. After the field also include a hyphen and a suitiable description
4. Include in the description the word "inception date" since this is the busines term 

Field: customer_since_date
""" AS prompt),
STRUCT(
     .2    AS temperature,
     1024 AS max_output_tokens,
     0    AS top_p,
     1   AS top_k
));
*/

-- In project:${project_id}, dataset:${bigquery_rideshare_llm_curated_dataset}, table:trip find the most highly used pickup_location
SELECT PICKUP_LOCATION_ID, CAST(count(*) as BIGNUMERIC) 
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`
 GROUP BY 1 
 ORDER BY CAST(count(*) as BIGNUMERIC) DESC NULLS FIRST;


-- In project:${project_id}, dataset:${bigquery_rideshare_llm_curated_dataset}, join the trip and payment_type tables and show the highest total_amount by payment type description in the payment_type table for driver_id = 1
SELECT T2.PAYMENT_TYPE_DESCRIPTION, max(T1.TOTAL_AMOUNT)
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS T1 
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.payment_type` AS T2 
       ON T1.PAYMENT_TYPE_ID = T2.PAYMENT_TYPE_ID
 WHERE T1.DRIVER_ID = 1
 GROUP BY 1;


-- In project:${project_id}, dataset:${bigquery_rideshare_llm_curated_dataset}, table:trip randomly select 10% of the data
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` 
 WHERE RAND() < 0.1;


-- Code completion (copy the below for Duet AI to complete the JOIN condition)
/*
SELECT *
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.location`
*/



-- Highlight the below Query and Click the "Explain this query" on the left (Star with Pencil Icon)
WITH data AS 
(
SELECT driver_id,

       COUNT(DISTINCT pickup_location_id)  AS pickup_location_count,       
       COUNT(DISTINCT dropoff_location_id) AS dropoff_location_count,

       STRING_AGG(DISTINCT location_pickup.zone,", ")  AS distinct_pickup_location_zones,
       STRING_AGG(DISTINCT location_dropoff.zone,", ") AS distinct_dropoff_location_zones,
       
       COUNTIF(location_pickup.service_zone = 'EWR' 
               OR location_dropoff.service_zone = 'EWR') AS crosses_state_line_count,

       COUNTIF(location_pickup.service_zone = 'EWR' 
               OR location_dropoff.service_zone = 'EWR'
               OR location_pickup.service_zone = 'Airports'
               OR location_dropoff.service_zone = 'Airports') AS airport_count,

       COUNT(*) AS total_number_of_trips,

       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 1) AS dayofweek_1, -- Sunday
       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 2) AS dayofweek_2,
       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 3) AS dayofweek_3,
       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 4) AS dayofweek_4,
       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 5) AS dayofweek_5,
       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 6) AS dayofweek_6, -- We could check for Friday nights
       COUNTIF(EXTRACT(DAYOFWEEK FROM trip.pickup_time) = 7) AS dayofweek_7,   

       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 0) AS hourofday_0, -- Midnight
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 1) AS hourofday_1,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 2) AS hourofday_2,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 3) AS hourofday_3,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 4) AS hourofday_4,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 5) AS hourofday_5,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 6) AS hourofday_6,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 7) AS hourofday_7,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 8) AS hourofday_8,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 9) AS hourofday_9,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 10) AS hourofday_10,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 11) AS hourofday_11,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 12) AS hourofday_12,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 13) AS hourofday_13,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 14) AS hourofday_14,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 15) AS hourofday_15,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 16) AS hourofday_16,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 17) AS hourofday_17,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 18) AS hourofday_18,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 19) AS hourofday_19,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 20) AS hourofday_20,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 21) AS hourofday_21,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 22) AS hourofday_22,
       COUNTIF(EXTRACT(HOUR FROM trip.pickup_time) = 23) AS hourofday_23, 
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.trip` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.location` AS location_pickup
               ON trip.pickup_location_id = location_pickup.location_id
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.location` AS location_dropoff
               ON trip.dropoff_location_id = location_dropoff.location_id
               
  GROUP BY driver_id
) 
, assign_attribute AS 
(
SELECT driver_id,

       distinct_pickup_location_zones,
       distinct_dropoff_location_zones,

       pickup_location_count, 
       dropoff_location_count,

       CASE WHEN pickup_location_count BETWEEN 1 AND 3 THEN 'few-1-3-pickup-locations'
            WHEN pickup_location_count BETWEEN 4 AND 6 THEN 'average-4-6-pickup-locations'
            WHEN pickup_location_count BETWEEN 7 AND 9 THEN 'many-7-9-pickup-locations'
            ELSE 'any-pickup-locations'
       END AS pickup_location_habit,

       CASE WHEN pickup_location_count BETWEEN 1 AND 9 THEN distinct_pickup_location_zones
            ELSE 'too-many-to-list'
       END AS pickup_location_zone_habit,
       
       CASE WHEN dropoff_location_count BETWEEN 1 AND 3 THEN 'few-1-3-dropoff-locations'
            WHEN dropoff_location_count BETWEEN 4 AND 6 THEN 'average-4-6-dropoff-locations'
            WHEN dropoff_location_count BETWEEN 7 AND 9 THEN 'many-7-9-dropoff-locations'
            ELSE 'any-pickup-locations'
       END AS dropoff_location_habit,

       CASE WHEN dropoff_location_count BETWEEN 1 AND 9 THEN distinct_dropoff_location_zones
            ELSE 'too-many-to-list'
       END AS dropoff_location_zone_habit,
       
       CASE WHEN crosses_state_line_count > CAST(total_number_of_trips * .2  AS INT64) THEN 'crosses-state-line'
            WHEN crosses_state_line_count < CAST(total_number_of_trips * .05 AS INT64) THEN 'does-not-cross-state-line'
            ELSE 'any-state-line'
        END AS cross_state_habit,

       CASE WHEN airport_count > CAST(total_number_of_trips * .75 AS INT64) THEN 'airport-driver'
            WHEN airport_count < CAST(total_number_of_trips * .1 AS INT64) THEN 'non-airport-driver'
            ELSE 'airport-agnostic'
        END AS airport_habit,        

       CASE WHEN (dayofweek_1 + dayofweek_7) > 
                 CAST(total_number_of_trips * .8 AS INT64)
            THEN 'weekend-driver'
            WHEN (dayofweek_2 + dayofweek_3 + dayofweek_4 + dayofweek_5 + dayofweek_6) > 
                 CAST(total_number_of_trips * .8 AS INT64)
            THEN 'weekday-driver'
            ELSE 'any-day-driver'
        END AS day_of_week,

        CASE WHEN (hourofday_0 + hourofday_1 + hourofday_2 + hourofday_3 + hourofday_4 + hourofday_22 + hourofday_23) > 
                  CAST(total_number_of_trips * .8 AS INT64)
             THEN 'night-hour-driver'
             WHEN (hourofday_7 + hourofday_8 + hourofday_9 + hourofday_16 + hourofday_17 + hourofday_18 + hourofday_19) > 
                  CAST(total_number_of_trips * .8 AS INT64)
             THEN 'rush-hour-driver'
             ELSE 'any-hour-driver'
        END AS hour_of_day

  FROM data 
)
, driver_daily_amount AS 
(
    SELECT driver_id, 
           CAST(pickup_time AS DATE) AS dt,
           SUM(trip.total_amount) as daily_total_amount
      FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.trip` AS trip
   --WHERE driver_id = 620
   GROUP BY 1,2
)
, arr_ag AS
(
    SELECT driver_id,
           AVG(daily_total_amount) AS average_daily_pay,
           ARRAY_AGG(daily_total_amount) as array_daily_total_amount
      FROM driver_daily_amount
  GROUP BY 1
)
, stddev_tbl AS
(
    SELECT driver_id, 
           average_daily_pay,
           STDDEV_SAMP(daily_total_amount) AS stddev_amt
      FROM arr_ag
          CROSS JOIN UNNEST(arr_ag.array_daily_total_amount) AS daily_total_amount
   GROUP BY 1, 2
)
, stddev_results AS 
(
    SELECT stddev_tbl.*, 
      FROM stddev_tbl
     WHERE stddev_amt < 20 
       AND stddev_amt is not null
)    
SELECT assign_attribute.*,
       stddev_results.average_daily_pay,
       stddev_results.stddev_amt
  FROM assign_attribute
       LEFT JOIN stddev_results
            ON assign_attribute.driver_id = stddev_results.driver_id;
   

-- With Duet AI chat open:
/*

RESET YOUR CHAT (Press the Trash Can Icon) and then press RESET CHAT. If to do not do this you will be in "Explain mode".

--------------------------------------------------------
PROMPT 1: 
--------------------------------------------------------
Find the max trip_distence in project:${project_id}, dataset:${bigquery_rideshare_llm_curated_dataset}, table:trip. Explain your answer using SQL.

* RETURNS:
SELECT max(trip_distance)
FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`;


--------------------------------------------------------
PROMPT 2: 
--------------------------------------------------------
Write the SQL to find the driver's name who has the highest total_amount based using the following points:
1. Project ${project_id}
2. Dataset ${bigquery_rideshare_llm_curated_dataset},
3. Tables trip and driver
4. Use the following pattern for tables in the FROM claues: `project.dataset.table`
5. Do not prefix the FROM clause with "project:"

* RETURNS: (you have to fix "GROUP BY driver.driver_id" -> "GROUP BY 1")
SELECT driver.driver_name
  FROM ${bigquery_rideshare_llm_curated_dataset}.trip AS trip
       INNER JOIN ${bigquery_rideshare_llm_curated_dataset}.driver AS driver
       ON trip.driver_id = driver.driver_id
 GROUP BY driver.driver_id  -- ### ERROR: Grouped by a field not in the SELECT, so change to 1 ###
 ORDER BY SUM(trip.total_amount) DESC
 LIMIT 1;

* CORRECTED
SELECT driver.driver_name
  FROM ${bigquery_rideshare_llm_curated_dataset}.trip AS trip
       INNER JOIN ${bigquery_rideshare_llm_curated_dataset}.driver AS driver
       ON trip.driver_id = driver.driver_id
 GROUP BY 1
 ORDER BY SUM(trip.total_amount) DESC
 LIMIT 1;

--------------------------------------------------------
PROMPT 3:
--------------------------------------------------------
Write the SQL to find the payment_type_description that is most fequency used for driver name "Suzanne Roussel" based on the following inputs:
1. Project ${project_id}
2. Dataset ${bigquery_rideshare_llm_curated_dataset},
3. Tables trip, driver, payment_type
4. Do not prefix the FROM clause with "project:"

* RETURNS (change "payment_method_id" to "payment_type_id"):
SELECT payment_type.payment_type_description
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
       ON trip.driver_id = driver.driver_id
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.payment_type` AS payment_type
       ON trip.payment_method_id = payment_type.payment_method_id -- ### ERROR: Incorrect field name ###
 WHERE driver.driver_name = "Suzanne Roussel"
 GROUP BY payment_type.payment_type_description
 ORDER BY COUNT(*) DESC
 LIMIT 1;

* CORRECTED:
SELECT payment_type.payment_type_description
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS trip
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
       ON trip.driver_id = driver.driver_id
       INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.payment_type` AS payment_type
       ON trip.payment_type_id = payment_type.payment_type_id
 WHERE driver.driver_name = "Suzanne Roussel"
 GROUP BY payment_type.payment_type_description
 ORDER BY COUNT(*) DESC
 LIMIT 1;

*/

-- Data Processing (JSON output of an unstructured address)
/* Uncomment this out.  The model cloud_ai_llm_v1 does not exist at deployment time
SELECT JSON_VALUE(ml_generate_text_result, '$.predictions[0].content') AS result, 
       ml_generate_text_result
  FROM ML.GENERATE_TEXT(MODEL`${project_id}.${bigquery_rideshare_llm_curated_dataset}.cloud_ai_llm_v1`,
       (SELECT
"""
For the following address extract the fields "address line", "city", "state" and "zip code" and return the below JSON format. Avoid using newlines in the output.
JSON format: { "address_line": "value","city": "value","state": "value", "zip_code": "value" }
Example: 123 Anywhere St Philadelphia, PA 00000
Answer: { "address_line": "123 Anywhere St","city": "Philadelphia","state": "PA", "zip_code": "00000" }

Address: 1600 Pennsylvania Avenue, N.W. Washington, DC 20500
""" AS prompt),
STRUCT(
  .0    AS temperature,
  1024 AS max_output_tokens,
  0    AS top_p,
  1   AS top_k
  ));


  -- Data Processing (JSON Array of many address with a "line 2")
  SELECT JSON_VALUE(ml_generate_text_result, '$.predictions[0].content') AS result, 
         ml_generate_text_result
    FROM ML.GENERATE_TEXT(MODEL`${project_id}.${bigquery_rideshare_llm_curated_dataset}.cloud_ai_llm_v1`,
         (SELECT
  """
  For the following addresses extract the fields "address line1", "address line2", "city", "state" and "zip code" and return the below JSON array. 
  Avoid using newlines in the output.
  For address line2 use this field for suite, apartment number or attention to data.
  JSON format: [{ "address_line1": "value","address_line2": "value","city": "value","state": "value", "zip_code": "value" }]
  
  Address: 1600 Pennsylvania Avenue, N.W. Washington, DC 20500
  Address: 4501 Elm St Orlando FL 32804
  Address: 1000 5th Ave Suite 514 New York, NY 10028
  Address: 1000 5th Ave Apartment 10A New York, NY 10028
  """ AS prompt),
  STRUCT(
    .0    AS temperature,
    1024 AS max_output_tokens,
    0    AS top_p,
    1   AS top_k
    ));

*/  

SELECT 1;
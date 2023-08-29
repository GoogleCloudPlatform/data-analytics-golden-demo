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
      - Perform the quantitative analysis on our data

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


---------------------------------------------------------------------------------------------------------------------
-- Customer: what days of the week and hours of the day do they use our service
---------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_quantitative_analysis`
CLUSTER BY customer_id
AS
WITH data AS 
(
SELECT customer_id,

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
  GROUP BY customer_id
)  
SELECT customer_id,

       CASE WHEN (dayofweek_1 + dayofweek_7) > 
                 CAST(total_number_of_trips * .8 AS INT64)
            THEN 'weekend-customer'
            WHEN (dayofweek_2 + dayofweek_3 + dayofweek_4 + dayofweek_5 + dayofweek_6) > 
                 CAST(total_number_of_trips * .8 AS INT64)
            THEN 'weekday-customer'
            ELSE 'any-day-customer'
        END AS day_of_week,

        CASE WHEN (hourofday_0 + hourofday_1 + hourofday_2 + hourofday_3 + hourofday_4 + hourofday_22 + hourofday_23) > 
                  CAST(total_number_of_trips * .8 AS INT64)
             THEN 'night-hour-customer'
             WHEN (hourofday_7 + hourofday_8 + hourofday_9 + hourofday_16 + hourofday_17 + hourofday_18 + hourofday_19) > 
                  CAST(total_number_of_trips * .8 AS INT64)
             THEN 'rush-hour-customer'
             ELSE 'any-hour-customer'
        END AS hour_of_day
  FROM data ;
  

---------------------------------------------------------------------------------------------------------------------
-- Driver: What days/hours do they work and what are their common/preferred pickup locations
---------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver_quantitative_analysis`
CLUSTER BY driver_id
AS
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

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
    - Clean Rooms allow organizations to share data and obtain insights
    - Show how a rideshare company shares trip data for insights (such as #trips during time window)

Description: 
    - Shows searching a BigQuery Data Clean Room on two different views of rideshare trip data.  
       One with a privacy policy and one without to show BQCR's can protect sensitive data.
Show:
    - Subscripe to a data clean room and run queries with and without a privacy policy to show 
       insights can be gained without leaking sensitive data with a pricacy policy.

References:
    - https://cloud.google.com/bigquery/docs/data-clean-rooms

Clean up / Reset script:
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_taxi_dataset}.sp_demo_cleanroom_queries`; 
*/

------------------------------------------------------------------------------------
-- Query 1
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
--   The trip view has an aggregation threshold privacy policy which enforces the minimum number 
--   of distinct entitie (2 in this case) on a particiular column (customer_id in this case).
-- This query will run on the unprotected table and allow you to view sensitive data
--
-- NOTE: You first need to add the Cleanroom shared data
--       1 - Click on Analytic Hub on the left side of the console after (after opening BigQuery)
--       2 - Click on Search Listings
--       3 - Click "Cleanroom" under Filters
--       4 - Click "NYC Rideshare Data" in the search results
--       5 - Click "ADD DATASET TO PROJECT"
--       6 - Click "SAVE"
--       7 - Head back over to BigQuery SQL Workspace
--       8 - Run the query below on the unprotected view and you should see 9 results of 
--           famous people living in NYC (for identifying celebrities they all have income
--           of 500000)
---------------------------------------------------------------------------------------------
select
  distinct(customer_id),
  customer_name,
  age,
  income,
  gender
from
  `${project_id}.${bigquery_cleanroom_dataset}.trip_no_pp`
where
  income = 500000;

------------------------------------------------------------------------------------
-- Query 2
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
--   The trip view has an aggregation threshold privacy policy which enforces the minimum number 
--   of distinct entitie (2 in this case) on a particiular column (customer_id in this case).
-- This query will run on the protected table and WILL NOT allow you to view sensitive data
--
-- NOTE: You first need to add the Cleanroom shared data
--       1 - Head back over to BigQuery SQL Workspace
--       2 - Run the query below on the unprotected view and you get an error: 
--           "You must use SELECT WITH AGGREGATION_THRESHOLD for this query because a 
--           privacy policy has been set by a data owner.""
---------------------------------------------------------------------------------------------
select
  distinct(customer_id),
  customer_name,
  age,
  income,
  gender
from
  `${project_id}.${bigquery_cleanroom_dataset}.trip`
where
  income = 500000;

------------------------------------------------------------------------------------
-- Query 3a
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
-- We will create a stored procedure to create time bucket to nearest N seconds
--
-- NOTE: You first need to add the Cleanroom shared data
--       1 - Head back over to BigQuery SQL Workspace
--       2 - Run the statement below to create the stored procedure
---------------------------------------------------------------------------------------------
CREATE
OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.tumble_interval` (val DATETIME, tumble_seconds INT64) AS (
    DATETIME(timestamp_seconds(div(UNIX_SECONDS(TIMESTAMP(val)), 
    tumble_seconds) * tumble_seconds),
        "America/New_York"
    )
);

------------------------------------------------------------------------------------
-- Query 3b
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
-- A consulting company is working with a restaurateur who is investigating two NYC locations and 
--   wants to measure traffic in the vicinity during luncheon hours.   The company will use Rideshare 
--   Trip Data available in BigQuery Data Cleanrooms for the number of customers dropped off in 3 
--   minute windows during prime lunchtime hours.
--
-- NOTE: You first need to add the Cleanroom shared data (and create the funciton above)
--       1 - Head back over to BigQuery SQL Workspace
--       2 - Run the query below on the protected view and you get about 116 results 
--           You will notice each result has a minumum of 2 distinct customer id's as
--           enforeced by the privacy policy on the view.
---------------------------------------------------------------------------------------------

select
    with aggregation_threshold 
    `${project_id}.${bigquery_taxi_dataset}.tumble_interval`(DATETIME(dropoff_time), 180) AS three_min,
    dropoff_location_id,
    count(distinct(customer_id)) as num_customers,
    CAST(ROUND(avg(income)) AS STRING FORMAT '$999,999') as avg_income,
    ROUND(avg(age)) as avg_age
from
  `${project_id}.${bigquery_cleanroom_dataset}.trip`
where
    DATETIME(timestamp(dropoff_time), "America/New_York") >= '2022-09-05T00:00:00'
    AND DATETIME(timestamp(dropoff_time), "America/New_York") <= '2022-09-06T00:00:00' ---132: JFK ; 138: LaGuardia
    and dropoff_location_id in (132, 138)
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) >= 12
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) <= 14
group by
    three_min,
    dropoff_location_id
order by
    num_customers asc,
    three_min asc;

------------------------------------------------------------------------------------
-- Query 4
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
-- A consulting company is working with a restaurateur who is investigating two NYC locations and 
--   wants to measure traffic in the vicinity during luncheon hours.   The company will use Rideshare 
--   Trip Data available in BigQuery Data Cleanrooms for the number of customers dropped off in 3 
--   minute windows during prime lunchtime hours.
--
-- NOTE: You first need to add the Cleanroom shared data
--       1 - Head back over to BigQuery SQL Workspace
--       2 - Run the query below on the unprotected view and you get about 120 results 
--           You will notice in this case there are results that have 1 distinct customer id's
--           which means it's possible to reveal sensitive data.
---------------------------------------------------------------------------------------------

select
    `${project_id}.${bigquery_taxi_dataset}.tumble_interval` (DATETIME(dropoff_time), 180) AS three_min,
    dropoff_location_id,
    count(distinct(customer_id)) as num_customers,
    CAST(ROUND(avg(income)) AS STRING FORMAT '$999,999') as avg_income,
    ROUND(avg(age)) as avg_age
from
  `${project_id}.${bigquery_cleanroom_dataset}.trip_no_pp`
where
    DATETIME(timestamp(dropoff_time), "America/New_York") >= '2022-09-05T00:00:00'
    AND DATETIME(timestamp(dropoff_time), "America/New_York") <= '2022-09-06T00:00:00' ---132: JFK ; 138: LaGuardia
    and dropoff_location_id in (132, 138)
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) >= 12
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) <= 14
group by
    three_min,
    dropoff_location_id
order by
    num_customers asc,
    three_min asc;


------------------------------------------------------------------------------------
-- Query 5
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
-- A consulting company is working with a restaurateur who is investigating two NYC locations and 
--   wants to measure traffic in the vicinity during luncheon hours.   The company will use Rideshare 
--   Trip Data available in BigQuery Data Cleanrooms for the number of customers dropped off in 3 
--   minute windows during prime lunchtime hours.
--
-- NOTE: You first need to add the Cleanroom shared data
--       1 - Head back over to BigQuery SQL Workspace
--       2 - Run the query below on the unprotected view and add customer_name to the result
--           You will notice in this case there are results that have 1 distinct customer id's
--           and you can see specific customer names which is a leak of sensitive data.
---------------------------------------------------------------------------------------------

select
    `${project_id}.${bigquery_taxi_dataset}.tumble_interval` (DATETIME(dropoff_time), 180) AS three_min,
    dropoff_location_id,
    count(distinct(customer_id)) as num_customers,
    CAST(ROUND(avg(income)) AS STRING FORMAT '$999,999') as avg_income,
    ROUND(avg(age)) as avg_age,
    customer_name
from
  `${project_id}.${bigquery_cleanroom_dataset}.trip_no_pp`
where
    DATETIME(timestamp(dropoff_time), "America/New_York") >= '2022-09-05T00:00:00'
    AND DATETIME(timestamp(dropoff_time), "America/New_York") <= '2022-09-06T00:00:00' ---132: JFK ; 138: LaGuardia
    and dropoff_location_id in (132, 138)
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) >= 12
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) <= 14
group by
    three_min,
    dropoff_location_id,
    customer_name
order by
    num_customers asc,
    three_min asc;

------------------------------------------------------------------------------------
-- Query 6
-- We have two views, one with a privacy policy (trip) and one without (trip_no_pp)
-- A consulting company is working with a restaurateur who is investigating two NYC locations and 
--   wants to measure traffic in the vicinity during luncheon hours.   The company will use Rideshare 
--   Trip Data available in BigQuery Data Cleanrooms for the number of customers dropped off in 3 
--   minute windows during prime lunchtime hours.
--
-- NOTE: You first need to add the Cleanroom shared data
--       1 - Head back over to BigQuery SQL Workspace
--       2 - Run the query below on the protected view and add customer_name to the result
--           You will get 0 results because all results are filtered out because the aggreage
--           threshold is not met.
---------------------------------------------------------------------------------------------

select
    with aggregation_threshold 
    `${project_id}.${bigquery_taxi_dataset}.tumble_interval` (DATETIME(dropoff_time), 180) AS three_min,
    dropoff_location_id,
    count(distinct(customer_id)) as num_customers,
    CAST(ROUND(avg(income)) AS STRING FORMAT '$999,999') as avg_income,
    ROUND(avg(age)) as avg_age,
    customer_name
from
  `${project_id}.${bigquery_cleanroom_dataset}.trip`
where
    DATETIME(timestamp(dropoff_time), "America/New_York") >= '2022-09-05T00:00:00'
    AND DATETIME(timestamp(dropoff_time), "America/New_York") <= '2022-09-06T00:00:00' ---132: JFK ; 138: LaGuardia
    and dropoff_location_id in (132, 138)
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) >= 12
    AND EXTRACT(
        HOUR
        FROM
            DATETIME(timestamp(dropoff_time), "America/New_York")
    ) <= 14
group by
    three_min,
    dropoff_location_id,
    customer_name
order by
    num_customers asc,
    three_min asc;

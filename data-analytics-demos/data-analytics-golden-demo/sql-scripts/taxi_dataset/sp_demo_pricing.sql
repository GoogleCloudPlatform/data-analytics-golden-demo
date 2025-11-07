CREATE OR REPLACE PROCEDURE `${project_id}.${bigquery_taxi_dataset}.sp_demo_pricing`()
BEGIN
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
IMPORTANT: If you create a reservation, you MUST DROP it or else you will get BILLED.  See the end of the script!

YouTube:
    - https://youtu.be/PPF8wBjJOxU
    
Use Cases:
    - Pricing for companies that want a warehouse do not want a commit can use ad-hoc pricing
    - Pricing for companies that want a fixed cost model can use reservations pricing model
      - Autoscaling can introduce flexible costs even when using reservations.
      - You can set your baseline and max slots to the same number to prevent autoscaling.

Description: 
    - 
    
    - Discuss slots can be purchased in 100 level increments.  Others warehouse double your pricing when scaling and incremental
      growth is not possible leading to high costs.

Reference:
    - https://cloud.google.com/bigquery/docs/information-schema-jobs
    - To set quotas: https://console.cloud.google.com/apis/api/bigquery.googleapis.com/quotas
    - Editions Features: https://cloud.google.com/bigquery/docs/editions-intro
    - Autoscaling: https://cloud.google.com/blog/products/data-analytics/introducing-new-bigquery-pricing-editions
    - Reservations: https://cloud.google.com/bigquery/docs/reservations-intro
    - Storage Pricing: https://cloud.google.com/bigquery/pricing#storage
    - To setup quotas for user/project: 
      https://cloud.google.com/bigquery/docs/custom-quotas#example
      https://cloud.google.com/bigquery/docs/custom-quotas#how_to_set_or_modify_custom_quotas
    - https://cloud.google.com/blog/topics/developers-practitioners/monitoring-bigquery-reservations-and-slot-utilization-information_schema
    - https://cloud.google.com/bigquery/docs/information-schema-jobs      

Clean up / Reset script:
    DROP ASSIGNMENT  `${project_id}.region-${bigquery_region}.pricing-reservation-autoscale-100.pricing-assignment-autoscale-100`;
    DROP RESERVATION `${project_id}.region-${bigquery_region}.pricing-reservation-autoscale-100`;

*/
  

-- TURN OFF CACHED RESULTS
-- Go to More | Query Settings | Cache preference | Use cached results

-- Run a query that scans a decent amount of data
WITH TaxiDataRanking AS
(
SELECT CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
       taxi_trips.Payment_Type_Id,
       taxi_trips.Passenger_Count,
       taxi_trips.Total_Amount,
       RANK() OVER (PARTITION BY CAST(Pickup_DateTime AS DATE),
                                 taxi_trips.Payment_Type_Id
                        ORDER BY taxi_trips.Passenger_Count DESC, 
                                 taxi_trips.Total_Amount DESC) AS Ranking
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
)
SELECT Pickup_Date,
       Payment_Type_Description,
       Passenger_Count,
       Total_Amount
  FROM TaxiDataRanking
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.payment_type` AS payment_type
               ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE Ranking = 1
ORDER BY Pickup_Date, Payment_Type_Description;


-- Compute the price for above query
-- The reservation_id will be NULL since you do not have any reservations
-- See the physical SQL statement that was run 
SELECT project_id,
       job_id,
       reservation_id,
       creation_time,
       TIMESTAMP_DIFF(end_time, creation_time, SECOND) AS job_duration_seconds,
       job_type,
       user_email,
       total_bytes_billed,

       -- 6.25 / 1,099,511,627,776 = 0.00000000000568434188608080 ($6.25 per TB so cost per byte is 0.00000000000568434188608080)
       CASE WHEN job.reservation_id IS NULL
           THEN CAST(total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000568434188608080 AS BIGDECIMAL)
           ELSE 0
       END AS est_on_demand_cost,

       -- Average slot utilization per job is calculated by dividing
       -- total_slot_ms by the millisecond duration of the job
       SAFE_DIVIDE(job.total_slot_ms,(TIMESTAMP_DIFF(job.end_time, job.start_time, MILLISECOND))) AS job_avg_slots,
       query,

       -- Determine the max number of slots used at ANY stage in the query.  The average slots might be 55
       -- but a single stage might spike to 2000 slots.  This is important to know when estimating when purchasing slots.
       MAX(SAFE_DIVIDE(unnest_job_stages.slot_ms,unnest_job_stages.end_ms - unnest_job_stages.start_ms)) AS jobstage_max_slots,

       -- Is the job requesting more units of works (slots).  If so you need more slots.
       -- estimatedRunnableUnits = Units of work that can be scheduled immediately. 
       -- Providing additional slots for these units of work will accelerate the query, if no other query in the reservation needs additional slots.
       MAX(unnest_timeline.estimated_runnable_units) AS estimated_runnable_units
FROM `region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS AS job
      CROSS JOIN UNNEST(job_stages) as unnest_job_stages
      CROSS JOIN UNNEST(timeline) AS unnest_timeline
WHERE project_id = '${project_id}'
  AND creation_time BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE) AND CURRENT_TIMESTAMP() 
  AND query LIKE '%WITH TaxiDataRanking AS%'
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY creation_time DESC
LIMIT 10;


-- See slot estimator (how many slots do I need)
-- https://console.cloud.google.com/bigquery/admin/reservations;region=${bigquery_region}/slot-estimator?project=${project_id}&region=${bigquery_region}


-- Create an Autoscaling Resevation
-- NOTE: After you run this query you will start getting BILLED!  
-- You must DROP this to avoid getting charged for the baseline slots (which is zero)
-- You must wait 60 seconds in order to DROP this capacity
CREATE RESERVATION `${project_id}.region-${bigquery_region}.pricing-reservation-autoscale-100`
OPTIONS (
  edition = "enterprise",
  slot_capacity = 0, -- change to 100 for a baseline of 100 (faster query start time)
  autoscale_max_slots = 200);
  
-- Open Capacity management to see the reservation
-- https://console.cloud.google.com/bigquery/admin/reservations?project=${project_id}
  

-- Assign the reservation to a project
-- Assignments can be done at the project, folder or organization level.  This lets you create
-- workload managements assigments for various divsions or workloads in your company 
CREATE ASSIGNMENT `${project_id}.region-${bigquery_region}.pricing-reservation-autoscale-100.pricing-assignment-autoscale-100`
OPTIONS(
   assignee = "projects/${project_id}",
   job_type = "QUERY"
);

-- Open Capacity management to see the reservation assignment
-- https://console.cloud.google.com/bigquery/admin/reservations?project=${project_id}
-- Expand the arrow on the left to see the assignment


-- View the assigment.  You will want to wait for this query to return results.
-- When you create a reservation assignment, wait at least several minutes before running a query. 
SELECT *
  FROM `region-${bigquery_region}.INFORMATION_SCHEMA.ASSIGNMENTS_BY_PROJECT`
  WHERE project_id = '${project_id}';

-- Review the UI for creating reservations while the assignment takes effect
-- https://console.cloud.google.com/bigquery/admin/reservations;region=${bigquery_region}/create?project=${project_id}&region=${bigquery_region}
-- Show: Edition, 
--       Max reservation size
--       Baseline slots
--       Ignore idle slots

-- Show creating a commitment
-- https://console.cloud.google.com/bigquery/admin/reservations;region=${bigquery_region}/capacity-commitments/create;noExistingSlots=false?project=${project_id}&region=${bigquery_region}


/* If you have commitments you would like to see, you can run this
SELECT *
  FROM `region-${bigquery_region}.INFORMATION_SCHEMA.CAPACITY_COMMITMENTS_BY_PROJECT`
  WHERE project_id = '${project_id}';
*/


-- Re-run the first query (cached results need to be off)
WITH TaxiDataRanking AS
(
SELECT CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
       taxi_trips.Payment_Type_Id,
       taxi_trips.Passenger_Count,
       taxi_trips.Total_Amount,
       RANK() OVER (PARTITION BY CAST(Pickup_DateTime AS DATE),
                                 taxi_trips.Payment_Type_Id
                        ORDER BY taxi_trips.Passenger_Count DESC, 
                                 taxi_trips.Total_Amount DESC) AS Ranking
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
)
SELECT Pickup_Date,
       Payment_Type_Description,
       Passenger_Count,
       Total_Amount
  FROM TaxiDataRanking
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.payment_type` AS payment_type
               ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE Ranking = 1
ORDER BY Pickup_Date, Payment_Type_Description;


-- We should now see the reservation id populated since we used our reservation
-- est_on_demand_cost should be Zero
SELECT project_id,
       job_id,
       reservation_id,
       creation_time,
       TIMESTAMP_DIFF(end_time, creation_time, SECOND) AS job_duration_seconds,
       job_type,
       user_email,
       total_bytes_billed,

       -- 6.25 / 1,099,511,627,776 = 0.00000000000568434188608080 ($6.25 per TB so cost per byte is 0.00000000000568434188608080)
       CASE WHEN job.reservation_id IS NULL
           THEN CAST(total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000568434188608080 AS BIGDECIMAL)
           ELSE 0
       END AS est_on_demand_cost,

       -- Average slot utilization per job is calculated by dividing
       -- total_slot_ms by the millisecond duration of the job
       SAFE_DIVIDE(job.total_slot_ms,(TIMESTAMP_DIFF(job.end_time, job.start_time, MILLISECOND))) AS job_avg_slots,
       query,

       -- Determine the max number of slots used at ANY stage in the query.  The average slots might be 55
       -- but a single stage might spike to 2000 slots.  This is important to know when estimating when purchasing slots.
       MAX(SAFE_DIVIDE(unnest_job_stages.slot_ms,unnest_job_stages.end_ms - unnest_job_stages.start_ms)) AS jobstage_max_slots,

       -- Is the job requesting more units of works (slots).  If so you need more slots.
       -- estimatedRunnableUnits = Units of work that can be scheduled immediately. 
       -- Providing additional slots for these units of work will accelerate the query, if no other query in the reservation needs additional slots.
       MAX(unnest_timeline.estimated_runnable_units) AS estimated_runnable_units
FROM `region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS AS job
      CROSS JOIN UNNEST(job_stages) as unnest_job_stages
      CROSS JOIN UNNEST(timeline) AS unnest_timeline
WHERE project_id = '${project_id}'
  AND creation_time BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE) AND CURRENT_TIMESTAMP() 
  AND query LIKE '%WITH TaxiDataRanking AS%'
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY creation_time DESC
LIMIT 10;


-- See slot estimator (we have a reservation)
-- https://console.cloud.google.com/bigquery/admin/reservations;region=${bigquery_region}/slot-estimator?project=${project_id}&region=${bigquery_region}
  

-- ******************************************************************************************
-- IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  
-- ******************************************************************************************
-- !!!!!!!!!!! DROP YOUR RESERVATION !!!!!!!!!!! (clean up or you WILL GET BILLED!)
-- ******************************************************************************************
-- IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  
-- ******************************************************************************************
DROP ASSIGNMENT  `${project_id}.region-${bigquery_region}.pricing-reservation-autoscale-100.pricing-assignment-autoscale-100`;
DROP RESERVATION `${project_id}.region-${bigquery_region}.pricing-reservation-autoscale-100`;

-- Open Capacity management to see the reservation has been removed
-- https://console.cloud.google.com/bigquery/admin/reservations?project=${project_id}
  
  
END;
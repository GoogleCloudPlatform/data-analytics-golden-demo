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
IMPORTANT: If you create Capacity, you MUST DROP it or else you will get BILLED.  See the end of the script!

Use Cases:
    - Pricing for companies that want a warehouse do not want a commit can use ad-hoc pricing
    - Pricing for companies that want a fixed cost model can use reservations pricing model

Description: 
    - Discuss ad-hoc vs slot base billing
    - Show the ad-hoc pricing query
    - Show the steps to create a resevation and assign it
    - Discuss how un-used slots are used accross the entire organization.  Other warehouses are constrained to sharing
      capacity within a cluster.  BigQuery has no such contraint and un-used slots are shared for your entire company.  If
      a query is submitted and fails under a reservation in which another job is utilizing the idle resources BigQuery scales
      back the running query to begin execution of the new query. 
    - Discuss slots can be purchased in 100 level increments.  Others warehouse double your pricing when scaling and incremental
      growth is not possible leading to high costs.

Reference:
    - https://cloud.google.com/bigquery/docs/information-schema-jobs
    - To set quotas: https://console.cloud.google.com/apis/api/bigquery.googleapis.com/quotas
    - Buy Flex Slots: https://cloud.google.com/bigquery/docs/reservations-get-started
    - To setup quotas for user/project: 
      https://cloud.google.com/bigquery/docs/custom-quotas#example
      https://cloud.google.com/bigquery/docs/custom-quotas#how_to_set_or_modify_custom_quotas

Clean up / Reset script:
    DROP ASSIGNMENT  `${project_id}.region-${bigquery_region}.demo-reservation-flex-100.demo-assignment-flex-100`;
    DROP RESERVATION `${project_id}.region-${bigquery_region}.demo-reservation-flex-100`;
    DROP CAPACITY    `${project_id}.region-${bigquery_region}.demo-commitment-flex-100`;
*/

-- Query 1: Compute the price for the past 5 days per user using retail costs $5 per TB scanned
-- The reservation_id will be NULL since you do not have any reservations
-- See the physical SQL statement that was run 

-- References:
-- https://cloud.google.com/blog/topics/developers-practitioners/monitoring-bigquery-reservations-and-slot-utilization-information_schema
-- https://cloud.google.com/bigquery/docs/information-schema-jobs

-- Compute the cost per Job, Average slots per Job and Max slots per Job (at the job stage level)
-- This will show you the cost for the Query and the Maximum number of slots used and if any additional slots where requested (to help gauge for reservations)
SELECT project_id,
       job_id,
       reservation_id,
       EXTRACT(DATE FROM creation_time) AS creation_date,
       TIMESTAMP_DIFF(end_time, creation_time, SECOND) AS job_duration_seconds,
       job_type,
       user_email,
       total_bytes_billed,

       -- 5 / 1,099,511,627,776 = 0.00000000000454747350886464 ($5 per TB so cost per byte is 0.00000000000454747350886464)
       CASE WHEN job.reservation_id IS NULL
            THEN CAST(total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000454747350886464 AS BIGDECIMAL)
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
  AND DATE(creation_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE() 
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY job_id ;



-- Query 2: Allocate Capacity which will later be assigned
-- NOTE: After you run this query you will start getting BILLED!  
-- You must DROP this to avoid getting charged for the slots! ($2,920 for a month)
-- 100 slots for 1 hour is $4.00/hour.  This is fine for a demo.  You will only use for 5 minutes so not a large expense.
-- You must wait 60 seconds in order to DROP this capacity
CREATE CAPACITY `${project_id}.region-${bigquery_region}.demo-commitment-flex-100`
    AS JSON """{
        "slot_count": 100,
        "plan": "FLEX"
        }""" ;

-- Query 3: Create a Reservervation from the overall Capacity.  You can have many reservations for your capacity.
CREATE RESERVATION `${project_id}.region-${bigquery_region}.demo-reservation-flex-100`
    AS JSON """{
        "slot_capacity": 100
        }""";


-- Query 4: Assign the reservation to a project
-- Assignments can be done at the project, folder or organization level.  This lets you create
-- workload managements assigments for various divsions or workloads in your company 
CREATE ASSIGNMENT `${project_id}.region-${bigquery_region}.demo-reservation-flex-100.demo-assignment-flex-100`
    AS JSON """{
        "assignee": "projects/${project_id}",
        "job_type": "QUERY"
        }""";


-- Query 5: View the data.  You need to WAIT for this to show, it can take several minutes..
-- When you create a reservation assignment, wait at least several minutes before running a query. 
-- Both queries must return results in order to continue
SELECT *
  FROM `region-${bigquery_region}.INFORMATION_SCHEMA.CAPACITY_COMMITMENTS_BY_PROJECT`
 WHERE project_id = '${project_id}';

SELECT *
  FROM `region-${bigquery_region}.INFORMATION_SCHEMA.ASSIGNMENTS_BY_PROJECT`
 WHERE project_id = '${project_id}';


-- Query 6: Run any query just so we can then check the billing tables
SELECT taxi_trips.TaxiCompany,
       vendor.Vendor_Description, 
       CAST(taxi_trips.Pickup_DateTime AS DATE)   AS Pickup_Date,
        SUM(taxi_trips.Total_Amount)               AS Total_Total_Amount 
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS vendor
               ON taxi_trips.Vendor_Id = vendor.Vendor_Id
              AND CAST(taxi_trips.Pickup_DateTime AS DATE) BETWEEN '2019-05-01' AND '2020-06-20'
 GROUP BY taxi_trips.TaxiCompany, vendor.Vendor_Description, CAST(taxi_trips.Pickup_DateTime AS DATE);


-- Query 7: Same as Query 1.  The reservation_id should now be populated with the flex slot we just created.
SELECT project_id,
       user_email,
       job_type,
       reservation_id,
       EXTRACT(DATE FROM  creation_time) AS execution_date, 
       SUM(total_slot_ms) / (1000*60*60*24*7) AS avg_slots,
       SUM(total_bytes_billed) AS total_bytes_billed,
       
       -- 5 / 1,099,511,627,776 = 0.00000000000454747350886464 ($5 per TB so cost per byte is 0.00000000000454747350886464)
       CASE WHEN reservation_id IS NULL
            THEN CAST(SUM(total_bytes_billed) AS BIGDECIMAL) * CAST(0.00000000000454747350886464 AS BIGDECIMAL)
            ELSE 0
        END AS est_on_deman_cost       
  FROM `region-${bigquery_region}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
 WHERE creation_time BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 DAY) AND CURRENT_TIMESTAMP()
   AND end_time      BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) AND CURRENT_TIMESTAMP()
 GROUP BY project_id, user_email, job_type, reservation_id, EXTRACT(DATE FROM  creation_time);


-- See the physical SQL statement that was run 

-- References:
-- https://cloud.google.com/blog/topics/developers-practitioners/monitoring-bigquery-reservations-and-slot-utilization-information_schema
-- https://cloud.google.com/bigquery/docs/information-schema-jobs

-- Compute the cost per Job, Average slots per Job and Max slots per Job (at the job stage level)
-- This will show you the cost for the Query and the Maximum number of slots used and if any additional slots where requested (to help gauge for reservations)
SELECT project_id,
       job_id,
       reservation_id,
       EXTRACT(DATE FROM creation_time) AS creation_date,
       TIMESTAMP_DIFF(end_time, creation_time, SECOND) AS job_duration_seconds,
       job_type,
       user_email,
       total_bytes_billed,

       -- 5 / 1,099,511,627,776 = 0.00000000000454747350886464 ($5 per TB so cost per byte is 0.00000000000454747350886464)
       CASE WHEN job.reservation_id IS NULL
            THEN CAST(total_bytes_billed AS BIGDECIMAL) * CAST(0.00000000000454747350886464 AS BIGDECIMAL)
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
  AND DATE(creation_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE() 
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY job_id ;


-- ******************************************************************************************
-- IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  
-- ******************************************************************************************
-- Query 8: Drop the flex slots (clean up or you WILL GET BILLED!)
-- ******************************************************************************************
-- IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  IMPORTANT!  
-- ******************************************************************************************
DROP ASSIGNMENT  `${project_id}.region-${bigquery_region}.demo-reservation-flex-100.demo-assignment-flex-100`;
DROP RESERVATION `${project_id}.region-${bigquery_region}.demo-reservation-flex-100`;
DROP CAPACITY    `${project_id}.region-${bigquery_region}.demo-commitment-flex-100`;


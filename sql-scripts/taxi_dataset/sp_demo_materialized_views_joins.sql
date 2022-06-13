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
    - Materialized views can increase your performance on aggreation queries or simply re-cluster your data based upon how your
      users are using your tables.  Materialized views can be implemented without having to go back and update all your SQL
      statements to point to the materialized view.  
    - Materialized views can be used to re-clusters data 

Description: 
    - Show how to use a materialize view to increase performance
    - Show how your existing queries can be automatically rewritten to utilize a materialize view

Reference:
    - https://cloud.google.com/bigquery/docs/materialized-views

Clean up / Reset script:
    DROP MATERIALIZED VIEW IF EXISTS `${project_id}.${bigquery_taxi_dataset}.mv_taxi_tips_totals`;
    DROP MATERIALIZED VIEW IF EXISTS `${project_id}.${bigquery_taxi_dataset}.mv_taxi_trips_by_location`;
*/

-- Query 1: Sum the yellow taxi data
-- Notes the time taken and bytes read (e.g. Query complete (5.9 sec elapsed, 9.2 GB processed))
SELECT vendor.Vendor_Description, 
       CAST(taxi_trips.Pickup_DateTime AS DATE)   AS Pickup_Date,
       SUM(taxi_trips.Fare_Amount)                AS Total_Fare_Amount,
       SUM(taxi_trips.Surcharge)                  AS Total_Surcharge,
       SUM(taxi_trips.MTA_Tax)                    AS Total_MTA_Tax,
       SUM(taxi_trips.Tip_Amount)                 AS Total_Tip_Amount,
       SUM(taxi_trips.Tolls_Amount)               AS Total_Tolls_Amount,
       SUM(taxi_trips.Improvement_Surcharge)      AS Total_Improvement_Surcharge,
       SUM(taxi_trips.Congestion_Surcharge)       AS Total_Congestion_Surcharge,
       SUM(taxi_trips.Total_Amount)               AS Total_Total_Amount 
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS vendor
               ON taxi_trips.Vendor_Id = vendor.Vendor_Id
 WHERE CAST(taxi_trips.Pickup_DateTime AS DATE) BETWEEN '2019-05-01' AND '2020-06-18'
 GROUP BY vendor.Vendor_Description, CAST(taxi_trips.Pickup_DateTime AS DATE);



-- Query 2:  Create a materialize view that does a JOIN
-- Same set of data as Query 1
DROP MATERIALIZED VIEW IF EXISTS `${project_id}.${bigquery_taxi_dataset}.mv_taxi_tips_totals`;

CREATE MATERIALIZED VIEW `${project_id}.${bigquery_taxi_dataset}.mv_taxi_tips_totals` AS
SELECT vendor.Vendor_Description, 
       CAST(taxi_trips.Pickup_DateTime AS DATE)   AS Pickup_Date,
       SUM(taxi_trips.Fare_Amount)                AS Fare_Amount,
       SUM(taxi_trips.Surcharge)                  AS Surcharge,
       SUM(taxi_trips.MTA_Tax)                    AS MTA_Tax,
       SUM(taxi_trips.Tip_Amount)                 AS Tip_Amount,
       SUM(taxi_trips.Tolls_Amount)               AS Tolls_Amount,
       SUM(taxi_trips.Improvement_Surcharge)      AS Improvement_Surcharge,
       SUM(taxi_trips.Congestion_Surcharge)       AS Congestion_Surcharge,
       SUM(taxi_trips.Total_Amount)               AS Total_Amount 
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS vendor
               ON taxi_trips.Vendor_Id = vendor.Vendor_Id
GROUP BY 1, 2;


-- Query 3: Manual Refresh of the Materalized View
-- Force a refresh (for demo); otherwise, the base tables will be queried until the refresh is complete
CALL BQ.REFRESH_MATERIALIZED_VIEW("taxi_dataset.mv_taxi_tips_totals");


-- Query 4: Same as Query 1, but the FROM clause references the materialize view directly
-- Run a statement directly against the materialized view
-- Note the faster speed and less bytes read (e.g. Query complete (0.7 sec elapsed, 170 KB processed))
SELECT Vendor_Description, 
       Pickup_Date,
       SUM(Fare_Amount)                AS Total_Fare_Amount,
       SUM(Surcharge)                  AS Total_Surcharge,
       SUM(MTA_Tax)                    AS Total_MTA_Tax,
       SUM(Tip_Amount)                 AS Total_Tip_Amount,
       SUM(Tolls_Amount)               AS Total_Tolls_Amount,
       SUM(Improvement_Surcharge)      AS Total_Improvement_Surcharge,
       SUM(Congestion_Surcharge)       AS Total_Congestion_Surcharge,
       SUM(Total_Amount)               AS Total_Total_Amount 
  FROM `${project_id}.${bigquery_taxi_dataset}.mv_taxi_tips_totals`
 WHERE Pickup_Date BETWEEN '2019-06-01' AND '2020-06-27'
 GROUP BY 1,2;


-- Query 5: Same as Query 1 (with different dates to avoid caching)
-- This statement will be re-written automatically by BigQuery to use the materialized view under the covers.
-- Note the query time (e.g. Query complete (0.5 sec elapsed, 170 KB processed))
-- If you click on Execution details and looks at S03 Join+, you should see the READ is from "FROM ${project_id}.${bigquery_taxi_dataset}.mv_taxi_tips_totals"
-- This means you can create materialized views and your users can benefit without having to find, alter and deploy their SQL statement to directly point at the materialized view.
SELECT vendor.Vendor_Description, 
       CAST(taxi_trips.Pickup_DateTime AS DATE)   AS Pickup_Date,
       SUM(taxi_trips.Fare_Amount)                AS Total_Fare_Amount,
       SUM(taxi_trips.Surcharge)                  AS Total_Surcharge,
       SUM(taxi_trips.MTA_Tax)                    AS Total_MTA_Tax,
       SUM(taxi_trips.Tip_Amount)                 AS Total_Tip_Amount,
       SUM(taxi_trips.Tolls_Amount)               AS Total_Tolls_Amount,
       SUM(taxi_trips.Improvement_Surcharge)      AS Total_Improvement_Surcharge,
       SUM(taxi_trips.Congestion_Surcharge)       AS Total_Congestion_Surcharge,
       SUM(taxi_trips.Total_Amount)               AS Total_Total_Amount 
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS vendor
               ON taxi_trips.Vendor_Id = vendor.Vendor_Id
 WHERE CAST(taxi_trips.Pickup_DateTime AS DATE) BETWEEN '2019-05-02' AND '2020-06-24'
 GROUP BY vendor.Vendor_Description, CAST(taxi_trips.Pickup_DateTime AS DATE);


------------------------------------------------------------------------------
-- Recluster a table using a materialize view
-- Use Case: Your main table is cluster by a set of columns for most queries,
-- but you have other queries that access the table with a different set of criteria
------------------------------------------------------------------------------

-- Query: 
DROP MATERIALIZED VIEW IF EXISTS `${project_id}.${bigquery_taxi_dataset}.mv_taxi_trips_by_location`;

-- Test (without materialized view)
-- Look at Job Information and Bytes processed
SELECT PULocationID, DOLocationID, Fare_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` 
 WHERE PULocationID = 74
   AND DOLocationID = 233;

CREATE MATERIALIZED VIEW `${project_id}.${bigquery_taxi_dataset}.mv_taxi_trips_by_location`
CLUSTER BY PULocationID, DOLocationID
AS SELECT *
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` ;
    
CALL BQ.REFRESH_MATERIALIZED_VIEW("taxi_dataset.mv_taxi_trips_by_location");

-- Test (with materialized view)
-- Look at Job Information and Bytes processed (should be smaller)
SELECT PULocationID, DOLocationID, Fare_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` 
 WHERE PULocationID = 74
   AND DOLocationID = 233;


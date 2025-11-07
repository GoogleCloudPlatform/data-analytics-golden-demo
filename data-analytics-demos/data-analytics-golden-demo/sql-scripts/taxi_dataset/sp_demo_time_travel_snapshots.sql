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
    - Time travel and/or Snapshot can be used for reporting.  
      - This can make reports consistent even if data is being loaded or changed.
      - This also lets you see data at a particular point in time
    - Time travel is used for restoring data that has been mistakely altered or deleted.  
    
Description: 
    - Show time travel.  
      - Data can be accessed for 7 days for any BQ table.
      - If you need to freeze your data (e.g. weekly) you can create Snapshots to preseve your data for a particular time.
    - Show snapshots
    - Show delete data, drop table and then restore a table

Reference:
    - https://cloud.google.com/bigquery/docs/time-travel
    - https://cloud.google.com/bigquery/docs/table-snapshots-create

Clean up / Reset script:
    DROP SNAPSHOT TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel_snapshot` ;
*/


-- Query: Create a new table for Green Trips and load data for Jan 2021
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
(
    Vendor_Id	            INTEGER,	
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    PULocationID	        INTEGER,
    DOLocationID	        INTEGER,
    Trip_Distance	        FLOAT64,
    Total_Amount	        FLOAT64,
    PartitionDate           DATE	
)
PARTITION BY PartitionDate
AS SELECT 
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        PULocationID,
        DOLocationID,
        Trip_Distance,
        Total_Amount,
        DATE(year, month, 1) as PartitionDate
   FROM `${project_id}.${bigquery_taxi_dataset}.ext_green_trips_parquet`
WHERE DATE(year, month, 1) = '2021-01-01';


-- Query: 76516
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` ;


-- Query: See the table in the past
-- Wait 15 seconds from CREATE TABLE: 76516 (if you get an error "table does not havea a schema, you need to wait 15 seconds")
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
  FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 SECOND);


-- Query: Insert more data
INSERT INTO `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
       (Vendor_Id, Pickup_DateTime, Dropoff_DateTime, PULocationID, DOLocationID,Trip_Distance,Total_Amount,PartitionDate)
SELECT Vendor_Id,
       Pickup_DateTime,
       Dropoff_DateTime,
       PULocationID,
       DOLocationID,
       Trip_Distance,
       Total_Amount,
       DATE(year, month, 1) as PartitionDate
  FROM `${project_id}.${bigquery_taxi_dataset}.ext_green_trips_parquet`
 WHERE DATE(year, month, 1) = '2021-02-01';


-- Query: 141086
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` ;


-- Query: 76516 - See the prior data before the INSERT
-- Wait at least 30 seconds.
-- NOTE: You might need to change INTERVAL 30 SECOND to more time if you spend time talking
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
  FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 SECOND);


-- Query: Create a Snapshot and keep for 1 year
-- Typically you would snapshot once a week to keep longer than 7 days the "INTERVAL 1 SECOND" is just for demo.
-- You can schedule this BigQuery "Scheduled Queries" https://cloud.google.com/bigquery/docs/table-snapshots-scheduled
-- Snapshots are only charged for the "delta" pricing of data from the base table
-- NOTE: You can create the snapshot in a different project and then grant Viewer access to the snapshot.  This allows you
--       to snapshot "prod" data into a "dev" project.
CREATE SNAPSHOT TABLE `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel_snapshot` 
 CLONE `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
   FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 SECOND)
OPTIONS(expiration_timestamp = CAST(DATE_ADD(CURRENT_DATE('America/New_York'), INTERVAL 1 YEAR) AS TIMESTAMP));


-- See all the snapshots you have created
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}..INFORMATION_SCHEMA.TABLE_SNAPSHOTS`;


-- Query: Whoops: Now less mess up the data.  Who granted them delete access anyway?
DELETE
  FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel`
 WHERE Pickup_DateTime BETWEEN '2021-01-25'AND '2021-02-10';


-- Query: 105253
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` ;

-- Query: All records still exist: 141086
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
  FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE);


-- Query: This user really messed up, time to call an admin...
DROP TABLE `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel`;


-- ERROR: Not found: Table ${project_id}:${bigquery_taxi_dataset}.green_trips_time_travel was not found in location
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` ;


-- STILL ERROR: Not found: Table ${project_id}:${bigquery_taxi_dataset}.green_trips_time_travel@1643126823820 was not found in location
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` 
  FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE);


-- ##############################################################
-- You need to run this command line in the Cloud Console Shell
-- ##############################################################
-- Restore the table from 1 minute ago (after drop)
-- 1 minute:  60000
-- 2 minutes: 120000 (you might have to replace 60000 with this if you wait)
-- 5 minutes: 300000 (you might have to replace 60000 with this if you wait)

-- SHELL COMMAND (Run This!)
-- bq cp "${bigquery_taxi_dataset}.green_trips_time_travel@-60000" "${bigquery_taxi_dataset}.green_trips_time_travel"


-- Sample Shell Output:
-- admin_@cloudshell:~ (${project_id})$ bq cp "${bigquery_taxi_dataset}.green_trips_timetravel@-120000" "${bigquery_taxi_dataset}.green_trips_timetravel"
-- Waiting on bqjob_r4b7df7dfd4abd254_0000017e91fefcc6_1 ... (0s) Current status: DONE   
-- Table '${project_id}:${bigquery_taxi_dataset}.green_trips_timetravel@-120000' successfully copied to '${project_id}:${bigquery_taxi_dataset}.green_trips_timetravel'


-- Query: Records are back
SELECT COUNT(*) AS RecordCount
FROM `${project_id}.${bigquery_taxi_dataset}.green_trips_time_travel` ;

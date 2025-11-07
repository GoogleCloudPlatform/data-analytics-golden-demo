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
    - To run the datafrom demo, first run this sp to create the necessary objects

Description: 
    - Create new dataset
    - Create table for pub_sub raw data
    - Create BigLake table

Clean up / Reset script:
    DROP SCHEMA IF EXISTS `${project_id}.dataform_demo` CASCADE;    
*/


-- Drop everythingi
DROP SCHEMA IF EXISTS `${project_id}.dataform_demo` CASCADE;


--- Create dataform_demo dataset 
CREATE SCHEMA `${project_id}.dataform_demo`
    OPTIONS (
    location = "${bigquery_region}"
    );


-- Let Dataform access
GRANT `roles/bigquery.dataEditor`
   ON SCHEMA `${project_id}.dataform_demo`
   TO "serviceAccount:service-${project_number}@gcp-sa-dataform.iam.gserviceaccount.com";


--- Create table for pub_sub raw data 
CREATE OR REPLACE TABLE `${project_id}.dataform_demo.taxi_trips_pub_sub`
(
    data STRING
)
PARTITION BY TIMESTAMP_TRUNC(_PARTITIONTIME, HOUR);


-- For Dataform to call to create the BigLake table (yes, we are creating a stored procedure from within a stored procedure)
     CREATE OR REPLACE PROCEDURE `${project_id}.dataform_demo.create_biglake_table`(name STRING, uris STRING)
     BEGIN
       EXECUTE IMMEDIATE FORMAT("""
           CREATE OR REPLACE EXTERNAL TABLE `${project_id}.dataform_demo.%s`
              WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
              OPTIONS(
                  uris=[%s], 
                  format="PARQUET"
              )
          """,name,uris);
     END;

-- Call the stored procedure just created
CALL `${project_id}.dataform_demo.create_biglake_table` ('biglake_payment_type',"'gs://${bucket_name}/processed/taxi-data/payment_type_table/*.parquet'");


-- This replaces the Pub/Sub topic since we already have loaded the same data into a table
-- The DAG "sample-dataflow-start-streaming-job" runs for 4 hours when the Terraform is deployed, 
-- so the taxi_trips_streaming table will have data.
--
-- If you want more data (to show the incremental features of Dataform), run Dataform, then
-- run the DAG "sample-dataflow-start-streaming-job" (wait a few minutes for it to start) and
-- then re-run below SQL a second time.  This will add the new rows streamed into the taxi_trips_streaming
-- to the dataform_demo.taxi_trips_pub_sub table.
-- NOTE: The Dataform job does a Timestamp Subtract of 1 hour for data to load. The Dataflow job must be running for 1+ hours to 
--       have data processed by dataform.
/*
{
    "ride_id": "1a80b0e2-2adb-431b-8455-aa7ee51839f3",
    "point_idx": 69,
    "latitude": 40.758160000000004,
    "longitude": -73.97748,
    "timestamp": "2022-11-28 19:15:31.062430+00",
    "meter_reading": 4.233383,
    "meter_increment": 0.06135338,
    "ride_status": "enroute",
    "passenger_count": 1
}
*/
INSERT INTO `${project_id}.dataform_demo.taxi_trips_pub_sub` (_PARTITIONTIME,data)
SELECT TIMESTAMP_TRUNC(timestamp, HOUR),
    CONCAT(
    "{ ",
    '"ride_id"',":",'"',ride_id,'", ',
    '"point_idx"',":",point_idx,", ",
    '"latitude"',":",latitude,", ",
    '"longitude"',":",longitude,", ",
    '"timestamp"',":",'"',timestamp,'", ',
    '"meter_reading"',":",meter_reading,", ",
    '"meter_increment"',":",meter_increment,", ",
    '"ride_status"',":",'"',ride_status,'", ',
    '"passenger_count"',":",passenger_count,
    " }") AS Data
 FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming` AS parent
WHERE NOT EXISTS (SELECT 1
                    FROM `${project_id}.dataform_demo.taxi_trips_pub_sub` AS child
                   WHERE parent.ride_id = JSON_EXTRACT_SCALAR(child.data,'$.ride_id'));


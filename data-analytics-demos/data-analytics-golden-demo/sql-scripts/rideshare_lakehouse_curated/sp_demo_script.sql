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
  YouTube:
      - https://youtu.be/Yru78Pk1jMM

  Use Cases:
      - Analytical Lakehouse

  Description: 
      - This is the Main Demo script for the entire demo

  Show:
      - The entire demo and architecture slide

  References:
      - 

  Clean up / Reset script:
    DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.rideshare_plus_rides`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_plus_rides`;

*/

--************************************************************************************************************
-- RAW Zone
--************************************************************************************************************

--------------------------------------------------------------------------------------------------------------
-- BigLake Row Level Security and Data Masking
--------------------------------------------------------------------------------------------------------------

-- Select parquet data
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_parquet` LIMIT 1000;

-- Show CSV table (all data)
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;

-- Query: Create an access policy so the admin (you) can only see Manhattan data
CREATE OR REPLACE ROW ACCESS POLICY rls_biglake_rideshare_zone_csv
    ON `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`
    GRANT TO ("user:${gcp_account_name}") 
FILTER USING (borough = 'Manhattan');

-- See just the data you are allowed to see
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;

-- Edit the table and show Data Masking on the service zone
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;

-- Drop the policy (do not break things in future demo steps)
DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;


--------------------------------------------------------------------------------------------------------------
-- OMNI (Bring in data from other clouds)
--------------------------------------------------------------------------------------------------------------
-- Create a table on data in AWS (S3)
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_plus_rides`
WITH PARTITION COLUMNS (
    year  INTEGER, -- column order must match the external path
    month INTEGER
)
WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`
OPTIONS (
  format = "PARQUET",
  hive_partition_uri_prefix = "s3://${aws_omni_biglake_s3_bucket}/taxi-data/yellow/trips_table/parquet/",
  uris = ['s3://${aws_omni_biglake_s3_bucket}/taxi-data/yellow/trips_table/parquet/*.parquet']
);

-- Retrieve some aggregate data from AWS
-- Use CTAS to query and directy load into a local BigQuery table
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.rideshare_plus_rides` AS
SELECT CAST(Pickup_DateTime AS DATE)  AS PickupDate,
       CAST(Dropoff_DateTime AS DATE) AS DropoffDate,
       PULocationID                   AS PickupLocationId,
       DOLocationID                   AS DropoffLocationId,
       AVG(Passenger_Count)           AS AvgPassengerCnt,
       AVG(Tip_Amount)                AS AvgTipAmt,
       AVG(Total_Amount)              AS AvgTotalAmt
  FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_plus_rides`
 WHERE year=2022
   AND month=1
 GROUP BY 1, 2, 3, 4;

-- We now have data in Google BigQuery to used for our analysis
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.rideshare_plus_rides`;


--------------------------------------------------------------------------------------------------------------
-- Unstructured Data (Object table)
--------------------------------------------------------------------------------------------------------------
-- Create a table over GCS (we can now see our data lake in a table)
-- Only the connection need access to the lake, not individual users which becomes unmanageable with billions/trillions of files
/*
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
    object_metadata="DIRECTORY",
    uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images/*.jpg',
            'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images/*.jpeg'],
    max_staleness=INTERVAL 30 MINUTE, 
    metadata_cache_mode="AUTOMATIC"
    );
*/

-- Show our objects in GCS / Data Lake
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images`;

-- Metadata values are recorded as to where the image was taken
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images` 
  WHERE ARRAY_LENGTH(metadata) > 0;


--------------------------------------------------------------------------------------------------------------
-- DataFlow (streaming ingestion)
--------------------------------------------------------------------------------------------------------------
-- Query raw data
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.bigquery_streaming_rideshare_trips` LIMIT 100;

-- Show streaming base table: taxi_dataset.taxi_trips_streaming
 

--************************************************************************************************************
-- Enriched Zone
--************************************************************************************************************

--------------------------------------------------------------------------------------------------------------
-- Unstructured Data Analysis
--------------------------------------------------------------------------------------------------------------

-- Process the images via our object table and show the results 
WITH UnstructuredData AS
(
  -- get the image from the oject table
  SELECT * 
    FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images` 
    WHERE uri = (SELECT uri FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images` LIMIT 1)
)
, ScoreAI AS 
(
  -- call a remote function
  SELECT `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_localize_objects`(UnstructuredData.uri) AS json_result
    FROM UnstructuredData
)
SELECT item.name,
       item.score,
       ScoreAI.json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.localized_object_annotations)) AS item;


-- Show all the images processed (object detection, labels, landmarks, logos)
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score` LIMIT 100;


--------------------------------------------------------------------------------------------------------------
-- Iceberg
--------------------------------------------------------------------------------------------------------------

-- Payment Data:
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg` LIMIT 1000;

-- Trip Data:
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg` LIMIT 1000;


--************************************************************************************************************
-- Curated Zone
--************************************************************************************************************

--------------------------------------------------------------------------------------------------------------
-- Unstructured Data Analysis (structured for consumption)
--------------------------------------------------------------------------------------------------------------

-- BigSearch
-- How many records are we searching
SELECT COUNT(*) AS Cnt
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip`;

-- Find the credit card 6701-1287-5578-5710 (NOTE: You might need to change this since this is generated data)
-- The table is not partitioned or clustered on this data
-- Click on Job Information and show "Index Usage Mode: FULLY_USED"
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip`
WHERE SEARCH(credit_card_number,'6701-1287-5578-5710', analyzer=>'NO_OP_ANALYZER'); 

-- Search even if we do not know the field name
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip` AS bigquery_rideshare_trip
WHERE SEARCH(bigquery_rideshare_trip,'6701-1287-5578-5710', analyzer=>'NO_OP_ANALYZER'); 

-- See curated image data
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_images_ml_detection` LIMIT 1000;


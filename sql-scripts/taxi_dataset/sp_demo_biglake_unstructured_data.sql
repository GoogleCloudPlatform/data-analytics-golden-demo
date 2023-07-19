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
    - Secure your files on GCS with data goverance (row, column level security)
      Users do not need access to storage (they only need access to BigQuery)
    - Provide SQL access to your files
    - Allow BigQuery to cache your GCS metadata (file listing)

Description: 
    - First View and Explore the Cloud Storage Account in this Project
      - The first folder "${raw_bucket_name}\biglake-unstructured-data" contains the images we will place a BigQuery Object table over
      - The second folder "${code_bucket_name}\tf-models" contains TensorFlow models download from TensorFlow Hub: https://tfhub.dev/

Models (downloaded for you)
      - https://tfhub.dev/tensorflow/resnet_50/classification/1?tf-hub-format=compressed
      - https://tfhub.dev/google/imagenet/mobilenet_v3_small_075_224/feature_vector/5?tf-hub-format=compressed

Show:
    - BQ support for GCS
    - BQ importing models
    - BQ scoring image data using a model

References:
    - https://cloud.google.com/bigquery/docs/object-table-introduction
    - https://cloud.google.com/blog/products/data-analytics/how-to-manage-and-process-unstructured-data-in-bigquery

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`;
    DROP MODEL IF EXISTS `${project_id}.${bigquery_taxi_dataset}.resnet_50_classification_1`;
    DROP MODEL IF EXISTS `${project_id}.${bigquery_taxi_dataset}.imagenet_mobilenet_v3_small_075_224_feature_vector_5`;
    DROP ASSIGNMENT  `${project_id}.region-${bigquery_region}.demo-reservation-autoscale-100.demo-assignment-autoscale-100`;
    DROP RESERVATION `${project_id}.region-${bigquery_region}.demo-reservation-autoscale-100`;
*/

-- To run ML Predictions on Object tables you need a reservation
-- If you create this MAKE SURE YOU DROP IT (especially if you use baseline slots)!
CREATE RESERVATION `${project_id}.region-${bigquery_region}.demo-reservation-autoscale-100`
OPTIONS (
  edition = "enterprise",
  slot_capacity = 0, -- change to 200 for a baseline of 200 (faster query start time)
  autoscale_max_slots = 200);


CREATE ASSIGNMENT `${project_id}.region-${bigquery_region}.demo-reservation-autoscale-100.demo-assignment-autoscale-100`
OPTIONS(
   assignee = "projects/${project_id}",
   job_type = "QUERY"
   );


-- YOU MIGHT NEED TO WAIT A FEW MINUTES FOR THE RESERVATION TO TAKE AFFECT
-- You might see this error: BigQuery ML for Object tables requires reservation, but no reservation was assigned for job type `QUERY`, to project `data-analytics-demo-ikiu2litcw` or its parent, in location `US`.
-- If you see the error, wait a 15 seconds and try again



-- Create a BigLake table for the biglake-unstructured-data directory for all JPG image files
-- Review the OPTIONS block
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
WITH connection`${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
  object_metadata="DIRECTORY",
  uris = ['gs://${raw_bucket_name}/biglake-unstructured-data/*.jpg'],
  max_staleness=INTERVAL 30 MINUTE, 
  --metadata_cache_mode="AUTOMATIC"
  -- set to Manual for demo
  metadata_cache_mode="MANUAL"
  );

-- For the demo, refresh the table (so we do not need to wait)
-- Refresh can only be done for "manual" cache mode
CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data');


-- View the data
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`;


-- Import the model (https://tfhub.dev/tensorflow/resnet_50/classification/1)
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.resnet_50_classification_1` 
OPTIONS(
  model_type="TENSORFLOW", 
  --color_space="RGB", 
  model_path="gs://${code_bucket_name}/tf-models/resnet_50_classification_1/*"
  );
  

-- Score the image data
EXECUTE IMMEDIATE """
SELECT * 
  FROM ML.PREDICT(MODEL `${project_id}.${bigquery_taxi_dataset}.resnet_50_classification_1`, 
                  (SELECT ML.DECODE_IMAGE(data) AS input_1
                     FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
                    WHERE content_type = 'image/jpeg'
                    LIMIT 10)
                  );
""";


-- Load the resnet_imagenet_labels into a table
LOAD DATA OVERWRITE `${project_id}.${bigquery_taxi_dataset}.resnet_imagenet_labels`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  field_delimiter=',',
  null_marker='',
  uris = ['gs://${raw_bucket_name}/resnet_imagenet_labels/resnet_imagenet_labels.csv']);

SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.resnet_imagenet_labels`;


-- Decription: Score the images in the BigLake object table against the Resnet ML model we've uploaded. 
--             This will provide a prediction against each of the 1000 class labels that are part of the original Imagenet data that the Resnet model was trained on. 
--             To identify the label name, we join the predictions with an Imagenet lookup table on the index. 
--             The query finally returns the top 3 predictions and its corresponding label for each image in our BigLake object table.
EXECUTE IMMEDIATE """
WITH predictions AS (
  SELECT *
    FROM ML.PREDICT(MODEL `${project_id}.${bigquery_taxi_dataset}.resnet_50_classification_1`,
         (SELECT ML.DECODE_IMAGE(data) AS input_1, uri
            FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
           WHERE content_type = 'image/jpeg'
           LIMIT 100)) -- you can change to a higher value if you'd like
 )
 , predictions_with_labels AS (
  SELECT label,
         label_score,
         uri,
         ROW_NUMBER() OVER (PARTITION BY uri ORDER BY label_score DESC) AS row_number
    FROM predictions,
         UNNEST(activation_49) AS label_score
         WITH OFFSET AS label_index
         LEFT JOIN `${project_id}.${bigquery_taxi_dataset}.resnet_imagenet_labels`
                ON label_index = index
)
SELECT *
  FROM predictions_with_labels
 WHERE row_number <= 3
 ORDER BY uri, label_score DESC;
""";


-- Import the model (https://tfhub.dev/google/imagenet/mobilenet_v3_small_075_224/feature_vector/5)
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.imagenet_mobilenet_v3_small_075_224_feature_vector_5` 
OPTIONS(
  model_type="TENSORFLOW", 
  --color_space="RGB", 
  model_path="gs://${code_bucket_name}/tf-models/imagenet_mobilenet_v3_small_075_224_feature_vector_5/*"
  );


-- Score the image data
EXECUTE IMMEDIATE """
SELECT * 
  FROM ML.PREDICT(MODEL `${project_id}.${bigquery_taxi_dataset}.imagenet_mobilenet_v3_small_075_224_feature_vector_5`, 
                  (SELECT ML.DECODE_IMAGE(data) AS inputs
                     FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
                    WHERE content_type = 'image/jpeg'
                    LIMIT 10)
                  );
""";


------------------------------------------------------------------------------------------
-- External Cloud Functions that use the Vision API
-- Create a connection to a cloud function that will use the Vertex AI to detect objects in images
------------------------------------------------------------------------------------------

-- Create the Function Link between BQ and the Cloud Function
CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_localize_objects` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","localize_objects_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_labels` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_labels_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_landmarks` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_landmarks_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_logos` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_logos_uri")]
    );

------------------------------------------------------------------------------------------
-- Use our BigLake table to do some image detection
------------------------------------------------------------------------------------------
-- Call the object_localization method of Vision API
-- The Vision API can detect and extract multiple objects in an image with Object Localization.
-- Object localization identifies multiple objects in an image and provides a LocalizedObjectAnnotation for each object in the image.
-- https://cloud.google.com/vision/docs/object-localizer
-- For more images: gcloud storage ls gs://cloud-samples-data/vision/object_localization/
WITH Data AS
(
  SELECT uri
    FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://${raw_bucket_name}/biglake-unstructured-data/vision/object_localization/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_localize_objects`(Data.uri) AS json_result
    FROM Data
)
SELECT uri,
       item.name,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.localized_object_annotations)) AS item;



-- Call the label_detection method of Vision API
-- The Vision API can detect and extract information about entities in an image, across a broad group of categories.
-- Labels can identify general objects, locations, activities, animal species, products, and more.
-- https://cloud.google.com/vision/docs/labels
-- For more images: gcloud storage ls gs://cloud-samples-data/vision/label
WITH Data AS
(
  SELECT uri
    FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://${raw_bucket_name}/biglake-unstructured-data/vision/label/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_labels`(Data.uri) AS json_result
    FROM Data
)
SELECT uri,
       item.description,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.label_annotations)) AS item;


-- Call the landmark_detection method of Vision API
-- For more images: gcloud storage ls gs://cloud-samples-data/vision/landmark
-- Landmark Detection detects popular natural and human-made structures within an image
-- https://cloud.google.com/vision/docs/detecting-landmarks
-- For more images: gcloud storage ls gs://cloud-samples-data/vision/landmark
WITH Data AS
(
  SELECT uri
    FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://${raw_bucket_name}/biglake-unstructured-data/vision/landmark/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_landmarks`(Data.uri) AS json_result
    FROM Data
)
SELECT uri,
       item.description,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.landmark_annotations)) AS item;


-- Call the logo_detection method of Vision API
-- Logo Detection detects popular product logos within an image.
-- https://cloud.google.com/vision/docs/detecting-logos
-- For more images: gcloud storage ls gs://cloud-samples-data/vision/logo
WITH Data AS
(
  SELECT uri
    FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://${raw_bucket_name}/biglake-unstructured-data/vision/logo/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_logos`(Data.uri) AS json_result
    FROM Data
)
SELECT uri,
       item.description,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.logo_annotations)) AS item;


-- You can also save the results in a BigQuery Table and now join the two 
-- You could also have a cloud function that updates the metadata tags of the files in cloud storage


-- How do we secure this data and share it?
-- We can add metatags on the data 
-- We can apply row level security on the data
-- We can share the table with Analytics Hub
-- We can generate Signed URLs so users can access the images
-- NOTE: Signed URLs can be opened by anyone so becareful with who you share them with


-- Create a new table (since we will be applying security and do not want to mess up the current one)
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data_rls`
WITH connection`${project_id}.${bigquery_region}.biglake-connection`
OPTIONS (
  object_metadata="DIRECTORY",
  uris = ['gs://${raw_bucket_name}/biglake-unstructured-data/*.jpg'],
  max_staleness=INTERVAL 30 MINUTE, 
  metadata_cache_mode="MANUAL"
  );

-- Call refresh (manually) for demo
CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data_rls');

-- Some of the images contain sensitive information that we 
-- View the files in https://console.cloud.google.com/storage/browser/${raw_bucket_name}/biglake-unstructured-data/confidential?project=${project_id}
-- These files have "Custom Metadata" Key=pii Value=true
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data` -- THE NON-SECURE TABLE (so we can see the data)
 WHERE ARRAY_LENGTH(metadata) = 1 AND metadata[OFFSET(0)].name = 'pii' AND metadata[OFFSET(0)].value = 'true';


-- Prevent anyone from see the data when we share
-- Secure the data based upon the pii metadata
CREATE OR REPLACE ROW ACCESS POLICY biglake_unstructured_data_rls_pii
    ON `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data_rls`
    GRANT TO ('user:${gcp_account_name}')
FILTER USING (ARRAY_LENGTH(metadata) = 0 -- no meta data
              OR
              ARRAY_LENGTH(metadata) = 1 AND metadata[OFFSET(0)].name = 'pii' AND metadata[OFFSET(0)].value != 'true' -- contains pii tag, but not "true"
              );


-- Can we see it?  (should return nothing)
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data_rls` -- THE SECURE TABLE 
 WHERE ARRAY_LENGTH(metadata) = 1 AND metadata[OFFSET(0)].name = 'pii' AND metadata[OFFSET(0)].value != 'true' ;

-- We can see the rest of the data
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data_rls`;


-- Users do not have access to the storage account (only BigLake), so how do they see / access the images
-- Use the function EXTERNAL_OBJECT_TRANSFORM to generate a signed url
-- Copy a signed_url and open anonymous browser and paste the url
SELECT uri, 
       content_type,
       signed_url
  FROM EXTERNAL_OBJECT_TRANSFORM (TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data_rls`,['SIGNED_URL']) LIMIT 10;


-- This only works if you have a shared project
-- A BigLake Object table has been shared within the shared project
-- Open Analytics Hub and click "Search Listings" (click off Private and select data_analytics_shared_data)
SELECT uri, 
        content_type,
        signed_url
  FROM EXTERNAL_OBJECT_TRANSFORM (TABLE `data_analytics_shared_data.biglake_caspian_rls`,['SIGNED_URL']) LIMIT 10;
  

-- Create a table to hold all the ML scoring results
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai`
(
  uri                        STRING,
  vision_ai_localize_objects JSON,
  vision_ai_detect_labels    JSON,
  vision_ai_detect_landmarks JSON,
  vision_ai_detect_logos     JSON
)
CLUSTER BY uri;

-- Score all the data in batches so we do not overwelm the function
-- Typically you would score the data as it arrives or in small batches
-- This takes a while, so you project do not want to run (plus you might affect other users)
LOOP
  INSERT INTO `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai`
  (uri, vision_ai_localize_objects, vision_ai_detect_labels, vision_ai_detect_landmarks, vision_ai_detect_logos)
  WITH Data AS
  (
    SELECT biglake_unstructured_data.uri, 
           ROW_NUMBER() OVER (ORDER BY biglake_unstructured_data.updated) AS RowNumber
      FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data` AS biglake_unstructured_data
    WHERE biglake_unstructured_data.content_type = 'image/jpeg'
      -- A better way then NOT EXISTS would be to check the md5_hash/updated date per item and do a MERGE command for existing items
      AND NOT EXISTS (SELECT 1
                        FROM `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai` AS biglake_vision_ai
                       WHERE biglake_unstructured_data.uri = biglake_vision_ai.uri)
  )
  SELECT uri, 
         `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_localize_objects`(uri),
         `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_labels`(uri),
         `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_landmarks`(uri),
         `${project_id}.${bigquery_taxi_dataset}.ext_udf_ai_detect_logos`(uri),
    FROM Data
   WHERE RowNumber BETWEEN 1 AND 50; -- do 50 at a time

  IF 0 = (SELECT COUNT(*) AS Cnt
                      FROM `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data` AS biglake_unstructured_data
                     WHERE biglake_unstructured_data.content_type = 'image/jpeg'
                       AND NOT EXISTS (SELECT 1
                                         FROM `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai` AS biglake_vision_ai
                                        WHERE biglake_unstructured_data.uri = biglake_vision_ai.uri)) THEN
     LEAVE;
  END IF;
END LOOP;


-- Create a search index on all columns
-- The table is too small to benefit from a BigSearch index (this would be good for a larger dataset)
-- CREATE SEARCH INDEX idx_biglake_vision_ai
-- ON `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai` (ALL COLUMNS);

-- Check our index (index_status = "Active", "total storage bytes" = 1.1 TB)
-- See the unindexed_row_count (rows not indexed)
-- coverage_percentage must be 100% to we know the data has been indexed
-- SELECT * -- table_name, index_name, ddl, coverage_percentage
--   FROM `${project_id}.${bigquery_taxi_dataset}.INFORMATION_SCHEMA.SEARCH_INDEXES`
--  WHERE index_status = 'ACTIVE';


 -- Find all Cats, Dogs, etc...
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai` AS Data
 WHERE SEARCH(Data, 'Whiskers');


-- Find all Dogs
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai` AS Data
 WHERE SEARCH(Data, 'Dog');


-- Get a signed url for the search results
SELECT Signed_Table.signed_url,
       AI_Results.*
  FROM EXTERNAL_OBJECT_TRANSFORM 
          (TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_unstructured_data`,['SIGNED_URL']) AS Signed_Table
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.biglake_vision_ai` AS AI_Results
               ON Signed_Table.uri = AI_Results.uri
              AND SEARCH(AI_Results, 'Dog');

--!!!!!!!!!!! DROP YOUR RESERVATION !!!!!!!!!!!
--!!!!!!!!!!! DROP YOUR RESERVATION !!!!!!!!!!!
--!!!!!!!!!!! DROP YOUR RESERVATION !!!!!!!!!!!
DROP ASSIGNMENT  `${project_id}.region-${bigquery_region}.demo-reservation-autoscale-100.demo-assignment-autoscale-100`;
DROP RESERVATION `${project_id}.region-${bigquery_region}.demo-reservation-autoscale-100`;
CREATE OR REPLACE PROCEDURE `bigquery_preview_features.sp_demo_caspian`()
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
Use Cases:
    - Secure your files on GCS with data goverance (row, column level security)
      Users do not need access to storage (they only need access to BigQuery)
    - Provide SQL access to your files
    - Allow BigQuery to cache your GCS metadata (file listing)

Description: 
    - First View and Explore the Cloud Storage Account in this Project
      - The bucket is named "sample-shared-data"
      - The first folder "bigquery-caspian-tf-models" contains TensorFlow models download from TensorFlow Hub: https://tfhub.dev/
      - The second folder "bigquery-caspian" contains the images we will place a BigQuery table over

Show:
    - BQ support for GCS
    - BQ importing models
    - BQ scoring image data using a model

References:
    - go/caspian-user-guide

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `bigquery_preview_features.biglake_caspian`;
    DROP MODEL IF EXISTS `bigquery_preview_features.resnet_50_classification_1`;
    DROP MODEL IF EXISTS `bigquery_preview_features.imagenet_mobilenet_v3_small_075_224_feature_vector_5`;
*/


/*
You need to make the connection to Cloud Storage
Since this is preview you need to use Cloud Shell (BQ UI does not have these yet)

This Connection has been created

bq mk --connection \
  --location="US" \
  --project_id="REPLACE-ME" \
  --connection_type=CLOUD_RESOURCE \
  "caspian-connection"

bq show \
  --location="US" \
  --connection "caspian-connection"

*/

DECLARE loopCounter INT64 DEFAULT 0;

-- Create a BigLake table for the bigquery-caspian directory for all JPG image files
-- Review the OPTIONS block
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE EXTERNAL TABLE `bigquery_preview_features.biglake_caspian`
WITH CONNECTION `us.caspian-connection `
OPTIONS (
  object_metadata="DIRECTORY",
  uris = ['gs://sample-shared-data/bigquery-caspian/*.jpg'],
  max_staleness=INTERVAL 30 MINUTE, 
  metadata_cache_mode="AUTOMATIC"
  );


-- View the data
SELECT * FROM `bigquery_preview_features.biglake_caspian`;


-- Download model from: https://tfhub.dev/tensorflow/resnet_50/classification/1
-- Save in storage
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE MODEL `bigquery_preview_features.resnet_50_classification_1` 
OPTIONS(
  model_type="TENSORFLOW", 
  color_space="RGB", 
  model_path="gs://sample-shared-data/bigquery-caspian-tf-models/resnet_50_classification_1/*"
  );


-- Score the image data
SELECT * 
  FROM ML.PREDICT(MODEL `bigquery_preview_features.resnet_50_classification_1`, 
                  (SELECT * 
                     FROM `bigquery_preview_features.biglake_caspian`
                    WHERE content_type = 'image/jpeg'
                    LIMIT 10)
                  );


-- Download model from: https://tfhub.dev/google/imagenet/mobilenet_v3_small_075_224/feature_vector/5
-- Save in storage
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE MODEL `bigquery_preview_features.imagenet_mobilenet_v3_small_075_224_feature_vector_5` 
OPTIONS(
  model_type="TENSORFLOW", 
  color_space="RGB", 
  model_path="gs://sample-shared-data/bigquery-caspian-tf-models/imagenet_mobilenet_v3_small_075_224_feature_vector_5/*"
  );


-- Score the image data
SELECT * 
  FROM ML.PREDICT(MODEL `bigquery_preview_features.imagenet_mobilenet_v3_small_075_224_feature_vector_5`, 
                  (SELECT * 
                     FROM `bigquery_preview_features.biglake_caspian`
                    WHERE content_type = 'image/jpeg'
                    LIMIT 10)
                  );

------------------------------------------------------------------------------------------
-- External Cloud Functions that use the Vision API
-- Create a connection to a cloud function that will use the Vertex AI to detect objects in images

-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION `bigquery_preview_features.ext_udf_ai_localize_objects` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","localize_objects_uri")]
    );


CREATE OR REPLACE FUNCTION `bigquery_preview_features.ext_udf_ai_detect_labels` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_labels_uri")]
    );


CREATE OR REPLACE FUNCTION `bigquery_preview_features.ext_udf_ai_detect_landmarks` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_landmarks_uri")]
    );


CREATE OR REPLACE FUNCTION `bigquery_preview_features.ext_udf_ai_detect_logos` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_logos_uri")]
    );


------------------------------------------------------------------------------------------
-- Use our BigLake table to do some image detection
------------------------------------------------------------------------------------------
-- Call the object_localization method of Vision API
-- The Vision API can detect and extract multiple objects in an image with Object Localization.
-- Object localization identifies multiple objects in an image and provides a LocalizedObjectAnnotation for each object in the image.
-- https://cloud.google.com/vision/docs/object-localizer
-- For more images: gsutil ls gs://cloud-samples-data/vision/object_localization/
WITH Data AS
(
  SELECT uri
    FROM `bigquery_preview_features.biglake_caspian`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://sample-shared-data/bigquery-caspian/vision/object_localization/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_localize_objects`(Data.uri)) AS json_result
    FROM Data
)
SELECT uri,
       item.name,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.localizedObjectAnnotations)) AS item;



-- Call the label_detection method of Vision API
-- The Vision API can detect and extract information about entities in an image, across a broad group of categories.
-- Labels can identify general objects, locations, activities, animal species, products, and more.
-- https://cloud.google.com/vision/docs/labels
-- For more images: gsutil ls gs://cloud-samples-data/vision/label
WITH Data AS
(
  SELECT uri
    FROM `bigquery_preview_features.biglake_caspian`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://sample-shared-data/bigquery-caspian/vision/label/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_detect_labels`(Data.uri)) AS json_result
    FROM Data
)
SELECT uri,
       item.description,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.labelAnnotations)) AS item;


-- Call the landmark_detection method of Vision API
-- For more images: gsutil ls gs://cloud-samples-data/vision/landmark
-- Landmark Detection detects popular natural and human-made structures within an image
-- https://cloud.google.com/vision/docs/detecting-landmarks
-- For more images: gsutil ls gs://cloud-samples-data/vision/landmark
WITH Data AS
(
  SELECT uri
    FROM `bigquery_preview_features.biglake_caspian`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://sample-shared-data/bigquery-caspian/vision/landmark/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_detect_landmarks`(Data.uri)) AS json_result
    FROM Data
)
SELECT uri,
       item.description,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.landmarkAnnotations)) AS item;


-- Call the logo_detection method of Vision API
-- Logo Detection detects popular product logos within an image.
-- https://cloud.google.com/vision/docs/detecting-logos
-- For more images: gsutil ls gs://cloud-samples-data/vision/logo
WITH Data AS
(
  SELECT uri
    FROM `bigquery_preview_features.biglake_caspian`
   WHERE content_type = 'image/jpeg'
     AND STARTS_WITH(uri,'gs://sample-shared-data/bigquery-caspian/vision/logo/')
  LIMIT 10
)
, ScoreAI AS 
(
  SELECT uri, SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_detect_logos`(Data.uri)) AS json_result
    FROM Data
)
SELECT uri,
       item.description,
       item.score,
       json_result 
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.json_result.logoAnnotations)) AS item;


-- You can also save the results in a BigQuery Table and now join the two 
-- You could also have a cloud function that updates the metadata tags of the files in cloud storage


-- How do we secure this data and share it?
-- We can add metatags on the data 
-- We can apply row level security on the data
-- We can share the table with Analytics Hub
-- We can generate Signed URLs so users can access the images
-- NOTE: Signed URLs can be opened by anyone so becareful with who you share them with


-- Create a new table (since we will be applying security and do not want to mess up the current one)
CREATE OR REPLACE EXTERNAL TABLE `bigquery_preview_features.biglake_caspian_rls`
WITH CONNECTION `us.caspian-connection `
OPTIONS (
  object_metadata="DIRECTORY",
  uris = ['gs://sample-shared-data/bigquery-caspian/*.jpg'],
  max_staleness=INTERVAL 30 MINUTE, 
  metadata_cache_mode="AUTOMATIC"
  );

-- Some of the images contain sensitive information that we 
-- View the files in https://console.cloud.google.com/storage/browser/sample-shared-data/bigquery-caspian/confidential?project=REPLACE-ME
-- These files have "Custom Metadata" Key=pii Value=true
SELECT *
  FROM `bigquery_preview_features.biglake_caspian` -- THE NON-SECURE TABLE (so we can see the data)
 WHERE ARRAY_LENGTH(metadata) = 1 AND metadata[OFFSET(0)].name = 'pii' AND metadata[OFFSET(0)].value = 'true';


-- Prevent anyone from see the data when we share
-- Secure the data based upon the pii metadata
CREATE OR REPLACE ROW ACCESS POLICY biglake_caspian_rls_pii
    ON `bigquery_preview_features.biglake_caspian_rls`
    GRANT TO ('allAuthenticatedUsers')
FILTER USING (ARRAY_LENGTH(metadata) = 0 -- no meta data
              OR
              ARRAY_LENGTH(metadata) = 1 AND metadata[OFFSET(0)].name = 'pii' AND metadata[OFFSET(0)].value != 'true' -- contains pii tag, but not "true"
              );


-- Can we see it?  (should return nothing)
SELECT *
  FROM `bigquery_preview_features.biglake_caspian_rls` -- THE SECURE TABLE 
 WHERE ARRAY_LENGTH(metadata) = 1 AND metadata[OFFSET(0)].name = 'pii' AND metadata[OFFSET(0)].value != 'true' ;

-- We can see the rest of the data
SELECT *
  FROM `bigquery_preview_features.biglake_caspian_rls`;


-- Users do not have access to the storage account (only BigLake), so how do they see / access the images
-- Use the function EXTERNAL_OBJECT_TRANSFORM to generate a signed url
-- Copy a signed_url and open anonymous browser and paste the url
SELECT uri, 
       content_type,
       signed_url
  FROM EXTERNAL_OBJECT_TRANSFORM (TABLE `bigquery_preview_features.biglake_caspian_rls`,['SIGNED_URL']);


-- This table is also in the dataset named "data_analytics_shared_data"
-- The table has been shared with Analytics Hub
-- Open your Argolis, open Analytics Hub and click "Search Listings" (click off Private and select data_analytics_shared_data)
-- You would run this SQL in your Argolis (you need to be allowlisted for the function EXTERNAL_OBJECT_TRANSFORM)
/*
SELECT uri, 
       content_type,
       signed_url
  FROM EXTERNAL_OBJECT_TRANSFORM (TABLE `data_analytics_shared_data.biglake_caspian_rls`,['SIGNED_URL'] LIMIT 10);
*/


-- Create a table to hold all the ML scoring results
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
CREATE OR REPLACE TABLE `bigquery_preview_features.biglake_vision_ai`
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
-- DECLARE loopCounter INT64 DEFAULT 0;
LOOP
  INSERT INTO `bigquery_preview_features.biglake_vision_ai`
  (uri, vision_ai_localize_objects, vision_ai_detect_labels, vision_ai_detect_landmarks, vision_ai_detect_logos)
  WITH Data AS
  (
    SELECT uri, 
          ROW_NUMBER() OVER (ORDER BY updated) AS RowNumber
      FROM `bigquery_preview_features.biglake_caspian`
    WHERE content_type = 'image/jpeg'
  )
  SELECT uri, 
        SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_localize_objects`(uri)),
        SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_detect_labels`(uri)),
        SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_detect_landmarks`(uri)),
        SAFE.PARSE_JSON(`bigquery_preview_features.ext_udf_ai_detect_logos`(uri)),
    FROM Data
    WHERE RowNumber BETWEEN (loopCounter + 1) AND (loopCounter + 100);

  SET loopCounter = loopCounter + 100;
  IF loopCounter >= 8200 THEN
     LEAVE;
  END IF;
END LOOP;


-- Create a search index on all columns
-- The table is too small to benefit from a BigSearch index (this would be good for a larger dataset)
-- NOTE: You do not have access to run this command (the table is already created)
--       If you want to run this use the dataset "ce_playground_google"
-- CREATE SEARCH INDEX idx_biglake_vision_ai
-- ON `bigquery_preview_features.biglake_vision_ai` (ALL COLUMNS);

-- Check our index (index_status = "Active", "total storage bytes" = 1.1 TB)
-- See the unindexed_row_count (rows not indexed)
-- coverage_percentage must be 100% to we know the data has been indexed
-- SELECT * -- table_name, index_name, ddl, coverage_percentage
--   FROM `bigquery_preview_features.INFORMATION_SCHEMA.SEARCH_INDEXES`
--  WHERE index_status = 'ACTIVE';


 -- Find all Cats, Dogs, etc...
SELECT *
  FROM `bigquery_preview_features.biglake_vision_ai` AS Data
 WHERE SEARCH(Data, 'Whiskers');


-- Find all Companion dogs
SELECT *
  FROM `bigquery_preview_features.biglake_vision_ai` AS Data
 WHERE SEARCH(Data, 'Companion dog');


-- Get a signed url for the search results
SELECT Signed_Table.signed_url,
       AI_Results.*
  FROM EXTERNAL_OBJECT_TRANSFORM 
          (TABLE `bigquery_preview_features.biglake_caspian`,['SIGNED_URL']) AS Signed_Table
       INNER JOIN `bigquery_preview_features.biglake_vision_ai` AS AI_Results
               ON Signed_Table.uri = AI_Results.uri
              AND SEARCH(AI_Results, 'Companion dog');


END;
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
      - Perform AI/ML on unstructed data stored in a data lake
      - Be able to query your data lake files with SQL
      - Filter files by last updated and/or metadata
      - Apply row level secuirty to the files that users can view
  
  Description: 
      - Customers have images, PDF and other types of data in their lakes.  
      - Customers want to gain insights to this data which is typically operated on at a file level
      - Users want an easy way to navigate and find items on data lakes
  
  Show:
      - The scoring of each item identified in each image.
  
  References:
      - https://cloud.google.com/bigquery/docs/object-table-introduction
      - https://cloud.google.com/vision/docs/drag-and-drop
  
  Clean up / Reset script:
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_localize_objects`;
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_labels`;
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_landmarks`;
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_logos`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score`;
  */

DECLARE loopCounter INT64 DEFAULT 0;
DECLARE rowCount INT64 DEFAULT 0;


-- Show our objects in GCS / Data Lake
-- Metadata values are recorded as to where the image was taken
SELECT * FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images`;


-- Create the Function Link between BQ and the Cloud Function
CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_localize_objects` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","localize_objects_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_labels` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_labels_uri")],
    max_batching_rows = 1
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_landmarks` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_landmarks_uri")],
    max_batching_rows = 1
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_logos` (uri STRING) RETURNS JSON 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_logos_uri")],
    max_batching_rows = 1
    );


-- Table to hold our ML scoring
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score`
(
  uri                        STRING,
  location_id                INT,
  image_date                 DATE,
  vision_ai_localize_objects JSON,
  vision_ai_detect_labels    JSON,
  vision_ai_detect_landmarks JSON,
  vision_ai_detect_logos     JSON,
  updated                    TIMESTAMP
)
CLUSTER BY uri;


/* Testing with sample images
SELECT `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_localize_objects`('gs://cloud-samples-data/vision/object_localization/duck_and_truck.jpg')
SELECT `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_labels`('gs://cloud-samples-data/vision/object_localization/duck_and_truck.jpg')
SELECT `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_landmarks`('gs://cloud-samples-data/vision/object_localization/duck_and_truck.jpg')
SELECT `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_logos`('gs://cloud-samples-data/vision/object_localization/duck_and_truck.jpg')
 */        


--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- ALERT: You need to make sure there is data in the table
--        Object tables can take a few minutes to sync
--        During the deployment the Airflow job waits for data in this table, before calling this procedure
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

-- Score all the new items (that have not been scored) in batches of 10
-- DECLARE loopCounter INT64 DEFAULT 0; DECLARE rowCount INT64 DEFAULT 0;
SET rowCount = (SELECT COUNT(1) 
                  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images` 
                 WHERE content_type = 'image/jpeg');
LOOP
INSERT INTO `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score`
(uri, location_id, image_date, vision_ai_localize_objects, vision_ai_detect_labels, vision_ai_detect_landmarks, vision_ai_detect_logos, updated)
  WITH Data AS
  (
    SELECT uri,
           metadata,
           updated,
           ROW_NUMBER() OVER (ORDER BY updated) AS RowNumber
      FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images` AS ObjectTable
    WHERE content_type = 'image/jpeg'
      AND NOT EXISTS (SELECT 1
                        FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score` AS MLScoreTable
                       WHERE ObjectTable.uri = MLScoreTable.uri
                         AND ObjectTable.updated = MLScoreTable.updated)
  )
  SELECT uri, 
         CASE WHEN ARRAY_LENGTH(metadata) = 0 -- no meta data
              THEN NULL
              WHEN ARRAY_LENGTH(metadata) >= 1 AND metadata[OFFSET(0)].name = 'location_id'
              THEN CAST(metadata[OFFSET(0)].value AS INT)
              WHEN ARRAY_LENGTH(metadata) = 2 AND metadata[OFFSET(1)].name = 'location_id'
              THEN CAST(metadata[OFFSET(1)].value AS INT)
              ELSE NULL
         END AS location_id,
         CASE WHEN ARRAY_LENGTH(metadata) = 0 -- no meta data
              THEN NULL
              WHEN ARRAY_LENGTH(metadata) >= 1 AND metadata[OFFSET(0)].name = 'image_date'
              THEN CAST(metadata[OFFSET(0)].value AS DATE)
              WHEN ARRAY_LENGTH(metadata) = 2 AND metadata[OFFSET(1)].name = 'image_date'
              THEN CAST(metadata[OFFSET(1)].value AS DATE)
              ELSE null
         END AS image_date,         
         `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_localize_objects`(uri),
         `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_labels`(uri),
         `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_landmarks`(uri),
         `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.ext_udf_ai_detect_logos`(uri),
         updated
    FROM Data
   WHERE RowNumber BETWEEN 1 AND 10; 

  SET loopCounter = loopCounter + 10;
  IF (SELECT COUNT(1)
        FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images` AS ObjectTable
       WHERE content_type = 'image/jpeg'
         AND NOT EXISTS (SELECT 1
                           FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score` AS MLScoreTable
                          WHERE ObjectTable.uri = MLScoreTable.uri
                            AND ObjectTable.updated = MLScoreTable.updated) ) = 0 OR loopCounter > rowCount THEN
     LEAVE;
  END IF;
END LOOP;

-- See results
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score`;

  
WITH ScoreAI AS
(
    SELECT uri,
           location_id,
           image_date,
           vision_ai_localize_objects,
           vision_ai_detect_labels,
           vision_ai_detect_landmarks,
           vision_ai_detect_logos
      FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score`
)
SELECT uri,
       'Object' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.name),'"','') AS name,
       item.score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_localize_objects.localized_object_annotations)) AS item
UNION ALL
SELECT uri,
       'Label' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.description),'"','') AS name,
       item.score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_detect_labels.label_annotations)) AS item
UNION ALL
SELECT uri,
       'Landmark' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.description),'"','') AS name,
       item.score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_detect_landmarks.landmark_annotations)) AS item
UNION ALL
SELECT uri,
       'Logo' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.description),'"','') AS name,
       item.score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_detect_logos.logo_annotations)) AS item
ORDER BY 1;

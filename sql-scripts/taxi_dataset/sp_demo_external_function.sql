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
    - Call custom code from BigQuery that is not achiveable with BQ JavaScript functions or SQL functions

Prerequisite:
    - Run the DAG ??? to deploy the Cloud Function

Description: 
    - The below creates the external function "link" in BigQuery
    - The below calls a single cloud function that has several methods
    - The "user_defined_context" passes the mode (which method to call in the function)
    - The Vision API is used as an example of processing data via a Cloud Function
    - There is a Taxi Pickup/DropOff that shows looking up data (that might now be available in the database) 

Show:
    - Connection 
    - Security - the connection has a service principal.  
    - The service principal has been granted Cloud Function Invoker role
    - The Cloud Function has been granted access to call to the processed storaged account (if we have images there)
    - The Cloud Funcation requires an authenicated call

References:
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/remote-functions

Clean up / Reset script:
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_taxi_dataset}.localize_objects_uri` 
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_taxi_dataset}.detect_labels_uri`
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_taxi_dataset}.detect_landmarks_uri`
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_taxi_dataset}.detect_logos_uri`
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_taxi_dataset}.taxi_zone_lookup`
*/

/*
# Example bq command to create a connection:
bq mk --connection \
    --display_name="cloud-function" \
    --connection_type=CLOUD_RESOURCE \
    --project_id="${project_id}" \
    --location=US \
    "cloud-function"

# Example Cloud Function deployment - Source code is on GitHub
gcloud functions deploy bigquery_external_function \
    --project="${project_id}" \
    --region="us-central1" \
    --runtime="python310" \
    --ingress-settings="all" \
    --no-allow-unauthenticated \
    --trigger-http

*/


-- Create the Function Link between BQ and the Cloud Function
CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.localize_objects_uri` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `${project_id}.us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://us-central1-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","localize_objects_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.detect_labels_uri` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `${project_id}.us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://us-central1-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_labels_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.detect_landmarks_uri` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `${project_id}.us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://us-central1-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_landmarks_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.detect_logos_uri` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `${project_id}.us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://us-central1-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","detect_logos_uri")]
    );


CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_taxi_dataset}.taxi_zone_lookup` (LocationID INT64) RETURNS STRING 
    REMOTE WITH CONNECTION `${project_id}.us.cloud-function` 
    OPTIONS 
    (endpoint = 'https://us-central1-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","taxi_zone_lookup")]
    );


-- Images from: "gsutil ls  gs://cloud-samples-data/vision"

-- Call the object_localization method of Vision API
-- The Vision API can detect and extract multiple objects in an image with Object Localization.
-- Object localization identifies multiple objects in an image and provides a LocalizedObjectAnnotation for each object in the image.
-- https://cloud.google.com/vision/docs/object-localizer
-- For more images: gsutil ls gs://cloud-samples-data/vision/object_localization/
WITH Data AS
(
    SELECT SAFE.PARSE_JSON(${bigquery_taxi_dataset}.localize_objects_uri('gs://cloud-samples-data/vision/object_localization/duck_and_truck.jpg')) AS json_result
)
SELECT item.name,
       item.score,
       json_result 
 FROM  Data, UNNEST(JSON_QUERY_ARRAY(Data.json_result.localizedObjectAnnotations)) AS item;



-- Call the label_detection method of Vision API
-- The Vision API can detect and extract information about entities in an image, across a broad group of categories.
-- Labels can identify general objects, locations, activities, animal species, products, and more.
-- https://cloud.google.com/vision/docs/labels
-- For more images: gsutil ls gs://cloud-samples-data/vision/label
WITH Data AS
(
    SELECT SAFE.PARSE_JSON(${bigquery_taxi_dataset}.detect_labels_uri('gs://cloud-samples-data/vision/label/setagaya.jpeg')) AS json_result
)
SELECT item.description,
       item.score,
       json_result 
 FROM  Data, UNNEST(JSON_QUERY_ARRAY(Data.json_result.labelAnnotations)) AS item;


-- Call the landmark_detection method of Vision API
-- For more images: gsutil ls gs://cloud-samples-data/vision/landmark
-- Landmark Detection detects popular natural and human-made structures within an image
-- https://cloud.google.com/vision/docs/detecting-landmarks
-- For more images: gsutil ls gs://cloud-samples-data/vision/landmark
WITH Data AS
(
    SELECT SAFE.PARSE_JSON(${bigquery_taxi_dataset}.detect_landmarks_uri('gs://cloud-samples-data/vision/landmark/eiffel_tower.jpg')) AS json_result
)
SELECT item.description,
       item.score,
       json_result 
 FROM  Data, UNNEST(JSON_QUERY_ARRAY(Data.json_result.landmarkAnnotations)) AS item;



-- Call the logo_detection method of Vision API
-- Logo Detection detects popular product logos within an image.
-- https://cloud.google.com/vision/docs/detecting-logos
-- For more images: gsutil ls gs://cloud-samples-data/vision/logo
WITH Data AS
(
    SELECT SAFE.PARSE_JSON(${bigquery_taxi_dataset}.detect_logos_uri('gs://cloud-samples-data/vision/logo/google_logo.jpg')) AS json_result
)
SELECT item.description,
       item.score,
       json_result 
 FROM  Data, UNNEST(JSON_QUERY_ARRAY(Data.json_result.labelAnnotations)) AS item;


-- Function that looksup the pickup/dropoff location codes
-- Filter the data first (do not call the function and then filter, that would be bad)
WITH Data AS
(
    SELECT Pickup_DateTime,
           Dropoff_DateTime,
           PULocationID,
           DOLocationID,
           Total_Amount
      FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` 
     WHERE PULocationID IS NOT NULL
       AND DOLocationID IS NOT NULL
       AND Total_Amount IS NOT NULL
       AND PartitionDate = '2022-01-01'
     LIMIT 10
)
SELECT Pickup_DateTime,
       Dropoff_DateTime,
       SAFE.PARSE_JSON(${bigquery_taxi_dataset}.taxi_zone_lookup(PULocationID)) As PickupDetails,
       SAFE.PARSE_JSON(${bigquery_taxi_dataset}.taxi_zone_lookup(DOLocationID)) AS DropOffDetails,
       Total_Amount
  FROM Data;

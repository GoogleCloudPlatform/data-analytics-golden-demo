CREATE OR REPLACE PROCEDURE `{{ params.project_id }}.{{ params.dataset_id }}.sp_demo_biglake`()
OPTIONS(strict_mode=FALSE)
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
PREVIEW FEATURE:
    - You need to run the below "CLI Commands" from your Cloud Shell

Use Cases:
    - Secure your data on your datalake with row level security
    - Replace Apache Ranger with a simipler easy to use solution

Description: 
    - Create an external table
    - Create a row level access policy on the table.  Security can be preformed on: Parquet, ORC, Avro, CSV and JSON

Reference:
    - n/a

Clean up / Reset script:
    DROP ALL ROW ACCESS POLICIES ON `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`;
    DROP EXTERNAL TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`


# CLI Commands
# NOTE: If you cloud shell is out of date then run this (only of out of data)
# sudo apt-get update && sudo apt-get --only-upgrade install google-cloud-sdk-config-connector google-cloud-sdk-anthos-auth google-cloud-sdk-cloud-build-local google-cloud-sdk-app-engine-go kubectl google-cloud-sdk-datastore-emulator google-cloud-sdk-terraform-validator google-cloud-sdk-gke-gcloud-auth-plugin google-cloud-sdk-app-engine-python google-cloud-sdk-skaffold google-cloud-sdk-pubsub-emulator google-cloud-sdk-minikube google-cloud-sdk-spanner-emulator google-cloud-sdk-cbt google-cloud-sdk-app-engine-grpc google-cloud-sdk-kpt google-cloud-sdk google-cloud-sdk-local-extract google-cloud-sdk-firestore-emulator google-cloud-sdk-bigtable-emulator google-cloud-sdk-datalab google-cloud-sdk-app-engine-python-extras google-cloud-sdk-kubectl-oidc google-cloud-sdk-app-engine-java

# Step 1: Create the connection
bq mk --connection \
--location="{{ params.region }}" \
--project_id="{{ params.project_id }}" \
--connection_type=CLOUD_RESOURCE \
biglake-connection

# Step 2: A service account has been created, we need to get its name
bq show --connection \
--location="{{ params.region }}" \
--project_id="{{ params.project_id }}" \
--format=json \
biglake-connection > bq-connection.json

bqOutputJsonFile="./bq-connection.json"
bqOutputJson=$(cat $bqOutputJsonFile)
biglake_service_account=$(echo "${bqOutputJson}" | jq .cloudResource.serviceAccountId --raw-output)

echo "biglake_service_account: ${biglake_service_account}"

# Step 3: Add Storage Object Viewer permissions to this Service Account
# Storage will be access via this service account (users do not need individual access) 
gcloud projects add-iam-policy-binding "{{ params.project_id }}" \
--member="serviceAccount:${biglake_service_account}" \
--role='roles/storage.objectViewer'

*/

-- Query: Create an external table (this is some of the Green Taxi Trips data in Parquet format)
-- Preview features, plus the connection might not have been created.
EXECUTE IMMEDIATE """
CREATE OR REPLACE EXTERNAL TABLE `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`
WITH CONNECTION `{{ params.project_id }}.{{ params.region }}.biglake-connection`
OPTIONS(uris=['gs://{{ params.bucket_name }}/processed/taxi-data/green/trips_table/parquet/year=2019/month=1/*.parquet'], format="PARQUET")
""";

-- See ALL the data
SELECT *
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`;


-- Query: Create an access policy so the admin (you) can only see pick up locations of 244
CREATE OR REPLACE ROW ACCESS POLICY rap_green_trips_pu_244
    ON `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`
    GRANT TO ("user:{{ params.gcp_account_name }}") -- This also works for groups: "group:my-group@altostrat.com"
FILTER USING (PULocationID = 244);


-- See just the data you are allowed to see
SELECT *
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`;


-- Drop the policy
DROP ALL ROW ACCESS POLICIES ON `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`;


-- See all the data
SELECT *
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.biglake_green_trips`;


END
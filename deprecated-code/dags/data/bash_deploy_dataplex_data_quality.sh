#!/bin/bash

####################################################################################
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
####################################################################################

# Deploys DataPlex using gCloud commands
# Currently Terraform is under development: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dataplex_lake
# https://cloud.google.com/dataplex/docs/discover-data
# https://cloud.google.com/static/dataplex/docs/reference/rest/v1/projects.locations.lakes.zones#DiscoverySpec
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dataplex_lake
# glob patterns: https://cloud.google.com/dataplex/docs/discover-data#discovery-configuration

# https://github.com/GoogleCloudPlatform/cloud-data-quality
# https://github.com/GoogleCloudPlatform/cloud-data-quality/blob/main/scripts/dataproc-workflow-composer/clouddq_composer_dataplex_task_job.py
# https://cloud.google.com/dataplex/docs/check-data-quality#sample-1

PROJECT_ID="{{ params.project_id }}"
TAXI_DATASET="{{ params.taxi_dataset }}"
THELOOK_DATASET="{{ params.thelook_dataset }}"
YAML_PATH="{{ params.yaml_path }}"
BIGQUERY_REGION="{{ params.bigquery_region }}"
TAXI_DATAPLEX_LAKE_NAME="{{ params.taxi_dataplex_lake_name }}"
VPC_SUBNET_NAME="{{ params.vpc_subnet_name }}"
DATAPLEX_REGION="{{ params.dataplex_region }}"
SERVICE_ACCOUNT_TO_RUN_DATAPLEX="{{ params.service_account_to_run_dataplex }}"
RANDOM_EXTENSION="{{ params.random_extension }}"

#PROJECT_ID="data-analytics-demo-4g4pkx9s5l"
#TAXI_DATASET="taxi_dataset"
#THELOOK_DATASET="thelook_ecommerce"
#YAML_PATH="gs://processed-data-analytics-demo-4g4pkx9s5l/dataplex/dataplex_data_quality_taxi.yaml"
## Region is case-sensitive
#BIGQUERY_REGION="US"
#TAXI_DATAPLEX_LAKE_NAME="taxi-data-lake"
#VPC_SUBNET_NAME="dataproc-serverless-subnet"
#DATAPLEX_REGION="REPLACE-REGION"
#SERVICE_ACCOUNT_TO_RUN_DATAPLEX="dataproc-service-account@data-analytics-demo-4g4pkx9s5l.iam.gserviceaccount.com"

# Create the YAML Data Quality Template
# NOTE: The template uses the Dataplex deployed region (e.g. REPLACE-REGION)
echo "YAML Replacing: /home/airflow/gcs/data/dataplex_data_quality_taxi.yaml"
sed "s/DATAPLEX_REGION/${DATAPLEX_REGION}/g" "/home/airflow/gcs/data/dataplex_data_quality_taxi.yaml" > "/home/airflow/gcs/data/dataplex_data_quality_taxi.tmp1"
sed "s/PROJECT_ID/${PROJECT_ID}/g" "/home/airflow/gcs/data/dataplex_data_quality_taxi.tmp1" > "/home/airflow/gcs/data/dataplex_data_quality_taxi.tmp2"
sed "s/RANDOM_EXTENSION/${RANDOM_EXTENSION}/g" "/home/airflow/gcs/data/dataplex_data_quality_taxi.tmp2" > "/home/airflow/gcs/data/dataplex_data_quality_taxi.tmp3"
gsutil cp /home/airflow/gcs/data/dataplex_data_quality_taxi.tmp3 ${YAML_PATH}
rm /home/airflow/gcs/data/dataplex_data_quality_taxi.tmp1
rm /home/airflow/gcs/data/dataplex_data_quality_taxi.tmp2
rm /home/airflow/gcs/data/dataplex_data_quality_taxi.tmp3

# Since the current version of gCloud does not have DataPlex, install it.
# This is NOT a best practice
sudo apt-get update && sudo apt-get --only-upgrade install google-cloud-sdk 
# sudo apt-get update && sudo apt-get --only-upgrade install google-cloud-sdk-cbt google-cloud-sdk-bigtable-emulator google-cloud-sdk-kpt google-cloud-sdk-gke-gcloud-auth-plugin google-cloud-sdk-app-engine-python google-cloud-sdk-datalab google-cloud-sdk-datastore-emulator google-cloud-sdk-anthos-auth google-cloud-sdk-terraform-validator google-cloud-sdk google-cloud-sdk-spanner-emulator google-cloud-sdk-pubsub-emulator google-cloud-sdk-app-engine-python-extras google-cloud-sdk-app-engine-java google-cloud-sdk-kubectl-oidc google-cloud-sdk-app-engine-grpc google-cloud-sdk-firestore-emulator google-cloud-sdk-skaffold google-cloud-sdk-local-extract google-cloud-sdk-minikube google-cloud-sdk-cloud-build-local google-cloud-sdk-config-connector kubectl google-cloud-sdk-app-engine-go


# Path to our YAML Script for Data Quality (You Author This)
USER_CLOUDDQ_YAML_CONFIGS_GCS_PATH="${YAML_PATH}"

# Google Cloud Project where the Dataplex task will be created.
GOOGLE_CLOUD_PROJECT="${PROJECT_ID}"

# Google Cloud region for the Dataplex Lake.
DATAPLEX_REGION_ID="${DATAPLEX_REGION}"

# Public Cloud Storage bucket containing the prebuilt data quality executable artifact. There is one bucket per GCP region.
DATAPLEX_PUBLIC_GCS_BUCKET_NAME="dataplex-clouddq-artifacts-${DATAPLEX_REGION_ID}"

# The Dataplex Lake where your task will be created.
DATAPLEX_LAKE_NAME="${TAXI_DATAPLEX_LAKE_NAME}"

# The service account used for executing the task. Ensure this service account has sufficient IAM permissions on your project including BigQuery Data Editor, BigQuery Job User, Dataplex Editor, Dataproc Worker, Service Usage Consumer.
DATAPLEX_TASK_SERVICE_ACCOUNT="${SERVICE_ACCOUNT_TO_RUN_DATAPLEX}"

# The BigQuery dataset used for storing the intermediate data quality summary results and the BigQuery views associated with each rule binding.
TARGET_BQ_DATASET="dataplex_data_quality"

# If you want to use a different dataset for storing the intermediate data quality summary results and the BigQuery views associated with each rule binding, use the following:
CLOUDDQ_BIGQUERY_DATASET=$TARGET_BQ_DATASET

# The BigQuery dataset where the final results of the data quality checks are stored. This could be the same as CLOUDDQ_BIGQUERY_DATASET.
TARGET_BQ_DATASET="dataplex_data_quality"

# The BigQuery table where the final results of the data quality checks are stored.
TARGET_BQ_TABLE="data_quality_summary"

# https://cloud.google.com/dataplex/docs/check-data-quality#gcloud
# To run in BigQuery US multi-region we need to tell Dataplex to execute in the US region, even though Dataplex is in REPLACE-REGION
# gcp-project-id	Project ID that is used to execute (and is billed for) the BigQuery queries.
# gcp-region-id	Region for running the BigQuery jobs for data quality validation. This region should be the same as the region for gcp-bq-dataset-id and target_bigquery_summary_table.
# gcp-bq-dataset-id	BigQuery dataset that is used to store the rule_binding views and intermediate data quality summary results.

# The unique identifier for the task (you cannot have duplicates)
random_number=$(echo $RANDOM)
TASK_ID="data-quality-taxi-task-${random_number}"

gcloud dataplex tasks create \
    --location="${DATAPLEX_REGION_ID}" \
    --project="${PROJECT_ID}" \
    --vpc-sub-network-name="${VPC_SUBNET_NAME}" \
    --lake="${DATAPLEX_LAKE_NAME}" \
    --trigger-type=ON_DEMAND \
    --execution-service-account="${DATAPLEX_TASK_SERVICE_ACCOUNT}" \
    --spark-python-script-file="gs://${DATAPLEX_PUBLIC_GCS_BUCKET_NAME}/clouddq_pyspark_driver.py" \
    --spark-file-uris="gs://${DATAPLEX_PUBLIC_GCS_BUCKET_NAME}/clouddq-executable.zip","gs://${DATAPLEX_PUBLIC_GCS_BUCKET_NAME}/clouddq-executable.zip.hashsum","${USER_CLOUDDQ_YAML_CONFIGS_GCS_PATH}" \
    --execution-args=^::^TASK_ARGS="clouddq-executable.zip, ALL, ${USER_CLOUDDQ_YAML_CONFIGS_GCS_PATH}, --gcp_project_id='${GOOGLE_CLOUD_PROJECT}', --gcp_region_id='${BIGQUERY_REGION}', --gcp_bq_dataset_id='${TARGET_BQ_DATASET}', --target_bigquery_summary_table='${GOOGLE_CLOUD_PROJECT}.${TARGET_BQ_DATASET}.${TARGET_BQ_TABLE}'," \
    "${TASK_ID}"

echo "TASK_ID: ${TASK_ID}"

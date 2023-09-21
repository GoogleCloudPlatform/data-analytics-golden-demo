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

# Runs a dataplex, data profile scan on many tables

DATAPLEX_REGION="{{ params.dataplex_region }}"
PROJECT_ID="{{ params.project_id }}"

TAXI_DATASET="{{ params.taxi_dataset }}"
THELOOK_DATASET="{{ params.thelook_dataset }}"

RIDESHARE_LAKEHOUSE_RAW_DATASET="{{ params.rideshare_lakehouse_raw_dataset }}"
RIDESHARE_LAKEHOUSE_ENRICHED_DATASET="{{ params.rideshare_lakehouse_enriched_dataset }}"
RIDESHARE_LAKEHOUSE_CURATED_DATASET="{{ params.rideshare_lakehouse_curated_dataset }}"

RIDESHARE_LLM_RAW_DATASET="{{ params.rideshare_llm_raw_dataset }}"
RIDESHARE_LLM_ENRICHED_DATASET="{{ params.rideshare_llm_enriched_dataset }}"
RIDESHARE_LLM_CURATED_DATASET="{{ params.rideshare_llm_curated_dataset }}"


#DATAPLEX_REGION="us-central1"
#PROJECT_ID="data-analytics-demo-jahkfjsl89"
#RIDESHARE_LLM_CURATED_DATASET="rideshare_llm_curated"

# Install the latest version of gCloud (This is NOT a best practice)
wget https://packages.cloud.google.com/apt/doc/apt-key.gpg && sudo apt-key add apt-key.gpg
sudo apt-get update && sudo apt-get --only-upgrade install google-cloud-sdk 


#############################################
SCAN_NAME="rideshare-llm-curated-customer"
TABLE_NAME="customer"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################

#############################################
SCAN_NAME="rideshare-llm-curated-customer-preference"
TABLE_NAME="customer_preference"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-customer-review"
TABLE_NAME="customer_review"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-customer-review-summary"
TABLE_NAME="customer_review_summary"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-driver"
TABLE_NAME="driver"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-driver-preference"
TABLE_NAME="driver_preference"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# materialized view
SCAN_NAME="rideshare-llm-curated-driver-review-summary"
TABLE_NAME="driver_review_summary"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-location"
TABLE_NAME="location"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-customer"
TABLE_NAME="looker_customer"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-customer-preference"
TABLE_NAME="looker_customer_preference"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-customer-review"
TABLE_NAME="looker_customer_review"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-driver"
TABLE_NAME="looker_driver"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-driver-preference"
TABLE_NAME="looker_driver_preference"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-payment-type"
TABLE_NAME="payment_type"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-trip"
TABLE_NAME="trip"

gcloud dataplex datascans create data-profile "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${RIDESHARE_LLM_CURATED_DATASET}/tables/${TABLE_NAME}"

gcloud dataplex datascans run "${SCAN_NAME}" \
    --project=${PROJECT_ID} \
    --location=${DATAPLEX_REGION}
#############################################


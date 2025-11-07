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
# https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans/create

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
#RIDESHARE_LLM_RAW_DATASET="rideshare_llm_raw"
#RIDESHARE_LLM_ENRICHED_DATASET="rideshare_llm_enriched"
#RIDESHARE_LLM_CURATED_DATASET="rideshare_llm_curated"


# Install JQ for parsing REST API return status
echo "BEGIN: jq Install"
STR=$(which jq)
SUB='jq'
echo "STR=$STR"
if [[ "$STR" == *"$SUB"* ]]; then
  echo "jq is installed, skipping..."
else
  sudo apt update -y
  sudo apt install jq -y
fi
echo "END: jq Install"

# Get a token to pass to the REST API
token=$(gcloud auth print-access-token)

dataplex_create_data_profile () {
    local_project_id=$1
    local_dataplex_region=$2
    local_scan_name=$3
    local_dataset_name=$4
    local_table_name=$5

    curl --request POST \
        "https://dataplex.googleapis.com/v1/projects/${local_project_id}/locations/${local_dataplex_region}/dataScans?dataScanId=${local_scan_name}" \
        --header "Authorization: Bearer $token" \
        --header "Accept: application/json" \
        --header "Content-Type: application/json" \
        --data "{\"dataProfileSpec\":{\"samplingPercent\":10},\"data\":{\"resource\":\"//bigquery.googleapis.com/projects/${local_project_id}/datasets/${local_dataset_name}/tables/${local_table_name}\"},\"description\":\"${local_scan_name}\",\"displayName\":\"${local_scan_name}\"}" \
        --compressed

    state="STATE_UNSPECIFIED"
    while [[ "${state}" == "STATE_UNSPECIFIED" || "${state}" == "CREATING" ]]
        do
        sleep 2
        json=$(curl "https://dataplex.googleapis.com/v1/projects/${local_project_id}/locations/${local_dataplex_region}/dataScans/${local_scan_name}?view=BASIC" \
            --header "Authorization: Bearer $(gcloud auth print-access-token)" \
            --header "Accept: application/json" \
            --compressed)

        state=$(echo $json | jq .state --raw-output)
        echo "items: $state"
        done

    # Update BQ fields so we can get the data scan results published in the BQ UI
    curl --request PATCH \
        "https://bigquery.googleapis.com/bigquery/v2/projects/${local_project_id}/datasets/${local_dataset_name}/tables/${local_table_name}" \
        --header "Authorization: Bearer $token" \
        --header "Accept: application/json" \
        --header "Content-Type: application/json" \
        --data "{\"labels\":{\"dataplex-dp-published-location\":\"${local_dataplex_region}\",\"dataplex-dp-published-project\":\"${local_project_id}\",\"dataplex-dp-published-scan\":\"${local_scan_name}\"}}" \
        --compressed

    curl --request POST "https://dataplex.googleapis.com/v1/projects/${local_project_id}/locations/${local_dataplex_region}/dataScans/${local_scan_name}:run" \
        --header "Authorization: Bearer $token" \
        --header "Accept: application/json" \
        --header "Content-Type: application/json" \
        --data '{}' \
        --compressed
}


#############################################
SCAN_NAME="rideshare-llm-curated-customer"
TABLE_NAME="customer"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-customer-preference"
TABLE_NAME="customer_preference"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-customer-review"
TABLE_NAME="customer_review"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-customer-review-summary"
TABLE_NAME="customer_review_summary"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-driver"
TABLE_NAME="driver"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-driver-preference"
TABLE_NAME="driver_preference"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


############################################# materialized view
SCAN_NAME="rideshare-llm-curated-driver-review-summary"
TABLE_NAME="driver_review_summary"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-location"
TABLE_NAME="location"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"

#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-customer"
TABLE_NAME="looker_customer"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-customer-preference"
TABLE_NAME="looker_customer_preference"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-customer-review"
TABLE_NAME="looker_customer_review"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-driver"
TABLE_NAME="looker_driver"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


############################################# View
SCAN_NAME="rideshare-llm-curated-looker-driver-preference"
TABLE_NAME="looker_driver_preference"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-payment-type"
TABLE_NAME="payment_type"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#############################################
SCAN_NAME="rideshare-llm-curated-trip"
TABLE_NAME="trip"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_CURATED_DATASET}" "${TABLE_NAME}"
#############################################


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-customer"
TABLE_NAME="customer"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-customer-attribute"
TABLE_NAME="customer_attribute"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-customer-quantitative-analysis"
TABLE_NAME="customer_quantitative_analysis"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-customer-review"
TABLE_NAME="customer_review"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-driver"
TABLE_NAME="driver"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-driver-attribute"
TABLE_NAME="driver_attribute"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-driver-quantitative-analysis"
TABLE_NAME="driver_quantitative_analysis"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-location"
TABLE_NAME="location"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-payment-type"
TABLE_NAME="payment_type"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-sidecar-customer"
TABLE_NAME="sidecar_customer"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-sidecar-customer-review"
TABLE_NAME="sidecar_customer_review"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-sidecar-driver"
TABLE_NAME="sidecar_driver"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#--------------------------------------------
SCAN_NAME="rideshare-llm-enriched-trip"
TABLE_NAME="trip"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_ENRICHED_DATASET}" "${TABLE_NAME}"
#--------------------------------------------


#============================================
SCAN_NAME="rideshare-llm-raw-biglake-rideshare-audios"
TABLE_NAME="biglake_rideshare_audios"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================


#============================================
SCAN_NAME="rideshare-llm-raw-customer"
TABLE_NAME="customer"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================


#============================================
SCAN_NAME="rideshare-llm-raw-customer-review"
TABLE_NAME="customer_review"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================


#============================================
SCAN_NAME="rideshare-llm-raw-driver"
TABLE_NAME="driver"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================


#============================================
SCAN_NAME="rideshare-llm-raw-location"
TABLE_NAME="location"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================


#============================================
SCAN_NAME="rideshare-llm-raw-payment-type"
TABLE_NAME="payment_type"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================


#============================================
SCAN_NAME="rideshare-llm-raw-trip"
TABLE_NAME="trip"
dataplex_create_data_profile "${PROJECT_ID}" "${DATAPLEX_REGION}" "${SCAN_NAME}" "${RIDESHARE_LLM_RAW_DATASET}" "${TABLE_NAME}"
#============================================

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

LOCATION="{{ params.dataplex_region }}"
PROJECT_ID="{{ params.project_id }}"
RAW_BUCKET="{{ params.raw_bucket }}"
PROCESSED_BUCKET="{{ params.processed_bucket }}"
TAXI_DATASET="{{ params.taxi_dataset }}"
THELOOK_DATASET="{{ params.thelook_dataset }}"
RANDOM_EXTENSION="{{ params.random_extension }}"
RIDESHARE_RAW_BUCKET="{{ params.rideshare_raw_bucket }}"
RIDESHARE_ENRICHED_BUCKET="{{ params.rideshare_enriched_bucket }}"
RIDESHARE_CURATED_BUCKET="{{ params.rideshare_curated_bucket }}"

# Activate the services (TODO: Move the full TF script - DONE)
# gcloud services enable metastore.googleapis.com --project="${PROJECT_ID}"
# gcloud services enable dataplex.googleapis.com --project="${PROJECT_ID}"

# Install the latest version of gCloud (This is NOT a best practice)
# wget https://packages.cloud.google.com/apt/doc/apt-key.gpg && sudo apt-key add apt-key.gpg
# sudo apt-get update && sudo apt-get --only-upgrade install google-cloud-sdk 


##########################################################################################
# Taxi Data
##########################################################################################

# Create the Data Lake
gcloud dataplex lakes create "taxi-data-lake-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Data Lake" \
    --display-name="Taxi Data Lake"


# Create the Zones 
gcloud dataplex zones create "taxi-raw-zone-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --type=RAW \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Raw Zone" \
    --display-name="Taxi Raw Zone" \
    --csv-delimiter="," \
    --csv-header-rows=1

gcloud dataplex zones create "taxi-curated-zone-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Curated Zone" \
    --display-name="Taxi Curated Zone" \
    --csv-delimiter="," \
    --csv-header-rows=1

# Add the Assests (2 buckets and 1 dataset)
# Showing how to exclude at the bucket let (you would probably do this instead of the zone level unless you have a common zone path to exclude)
gcloud dataplex assets create "taxi-raw-bucket-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --zone="taxi-raw-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Raw Bucket" \
    --display-name="Taxi Raw Bucket" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RAW_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="," \
    --csv-header-rows=1
# This will NOT generate action warnings.  For the demo is it good to show Bad data/issue.
#    --discovery-exclude-patterns=[**/bigspark/*,**/dataflow/*,**/pyspark-code/*]

gcloud dataplex assets create "taxi-processed-bucket-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --zone="taxi-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Processed Bucket" \
    --display-name="Taxi Processed Bucket" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${PROCESSED_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="," \
    --csv-header-rows=1 
# This will NOT generate action warnings.  For the demo is it good to show Bad data/issue.
#    --discovery-exclude-patterns=[**/delta_io/*,**/notebooks/*]

gcloud dataplex assets create "taxi-processed-datasets-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --zone="taxi-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi BigQuery Dataset" \
    --display-name="Taxi BigQuery Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/${TAXI_DATASET}" \
    --discovery-enabled


##########################################################################################
# The Look eCommerce
##########################################################################################
gcloud dataplex lakes create "ecommerce-data-lake-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="The Look eCommerce Data Lake" \
    --display-name="The Look eCommerce Data Lake"

gcloud dataplex zones create "ecommerce-curated-zone-${RANDOM_EXTENSION}" \
    --lake="ecommerce-data-lake-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="The Look eCommerce Curated Zone" \
    --display-name="The Look eCommerce Zone"

gcloud dataplex assets create "ecommerce-dataset-${RANDOM_EXTENSION}" \
    --lake="ecommerce-data-lake-${RANDOM_EXTENSION}" \
    --zone="ecommerce-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="TheLook eCommerce BigQuery Dataset" \
    --display-name="eCommerce BigQuery Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/${THELOOK_DATASET}" \
    --discovery-enabled


##########################################################################################
# Rideshare Lakehouse
##########################################################################################
gcloud dataplex lakes create "rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Rideshare Lakehouse" \
    --display-name="Rideshare Lakehouse"

# RAW
gcloud dataplex zones create "rideshare-raw-zone-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --type=RAW \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Raw Zone" \
    --display-name="Raw Zone"

gcloud dataplex assets create "rideshare-raw-unstructured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-raw-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Raw Zone - Unstructured" \
    --display-name="Raw Zone - Unstructured" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RIDESHARE_RAW_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="|" \
    --csv-header-rows=1 

gcloud dataplex assets create "rideshare-raw-structured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-raw-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Raw Zone - Structured" \
    --display-name="Raw Zone - Structured" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/rideshare_lakehouse_raw" \
    --discovery-enabled


# Enriched
gcloud dataplex zones create "rideshare-enriched-zone-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Enriched Zone" \
    --display-name="Enriched Zone"

gcloud dataplex assets create "rideshare-enriched-unstructured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-enriched-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Enriched Zone - Unstructured" \
    --display-name="Enriched Zone - Unstructured" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RIDESHARE_ENRICHED_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="|" \
    --csv-header-rows=1 

gcloud dataplex assets create "rideshare-enriched-structured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-enriched-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Enriched Zone - Structured" \
    --display-name="Enriched Zone - Structured" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/rideshare_lakehouse_enriched" \
    --discovery-enabled


# Curated
gcloud dataplex zones create "rideshare-curated-zone-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Curated Zone" \
    --display-name="Curated Zone"

gcloud dataplex assets create "rideshare-curated-unstructured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Curated Zone - Unstructured" \
    --display-name="Curated Zone - Unstructured" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RIDESHARE_CURATED_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="|" \
    --csv-header-rows=1 

gcloud dataplex assets create "rideshare-curated-structured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Curated Zone - Structured" \
    --display-name="Curated Zone - Structured" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/rideshare_lakehouse_curated" \
    --discovery-enabled

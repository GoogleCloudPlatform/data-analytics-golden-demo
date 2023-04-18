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
# https://cloud.google.com/sql/docs/postgres/db-versions


# Parameters
PROJECT_ID="{{ params.project_id }}"
PROJECT_NUMBER="{{ params.project_number }}"
ROOT_PASSWORD="{{ params.root_password }}"
INSTANCE="postgres-private-ip"
DATABASE_VERSION="POSTGRES_14"
CPU="2"
MEMORY="8GB"
CLOUD_SQL_REGION="{{ params.cloud_sql_region }}"
YOUR_IP_ADDRESS=$(curl ifconfig.me)
DATABASE_NAME="guestbook"
DATASTREAM_REGION="{{ params.datastream_region }}"


# Create networking connections
gcloud compute addresses create google-managed-services-vpc-main \
    --global \
    --purpose=VPC_PEERING \
    --addresses=10.6.0.0 \
    --prefix-length=16 \
    --network="vpc-main" \
    --project="${PROJECT_ID}"  


gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-vpc-main \
    --network="vpc-main" \
    --project="${PROJECT_ID}" 


gcloud compute networks peerings create vpc-main-peer \
    --network=vpc-main \
    --peer-project=PEER_PROJECT_ID \
    --peer-network=PEER_NETWORK_NAME \


gcloud services vpc-peerings operations describe \
    --name=OPERATION_ID    


gcloud projects add-iam-policy-binding "${PROJECT_ID}"  \
    --member=serviceAccount:service-${PROJECT_NUMBER}@service-networking.iam.gserviceaccount.com \
    --role=roles/servicenetworking.serviceAgent


# https://cloud.google.com/sdk/gcloud/reference/sql/instances/create
gcloud sql instances create "${INSTANCE}" \
    --database-version=${DATABASE_VERSION} \
    --cpu=${CPU} \
    --memory=${MEMORY} \
    --project="${PROJECT_ID}" \
    --region=${CLOUD_SQL_REGION} \
    --root-password="${ROOT_PASSWORD}" \
    --no-assign-ip \
    --storage-size="10GB" \
    --storage-type="SSD" \
    --storage-auto-increase \
    --network="vpc-main" \
    --enable-google-private-path \
    --maintenance-window-day=SAT \
    --maintenance-window-hour=1 \
    --database-flags=cloudsql.logical_decoding=on


# Get ip address (of this node)
cloudsql_ip_address=$(gcloud sql instances list --filter="NAME=${INSTANCE}" --project="${PROJECT_ID}" --format="value(PRIMARY_ADDRESS)")


# Write out so we can read in via Python
echo ${cloudsql_ip_address} > /home/airflow/gcs/data/postgres_private_ip_address.txt


# Create the database
gcloud sql databases create ${DATABASE_NAME} --instance="${INSTANCE}" --project="${PROJECT_ID}"

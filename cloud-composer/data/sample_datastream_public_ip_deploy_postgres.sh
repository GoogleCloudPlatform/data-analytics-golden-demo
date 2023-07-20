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

# MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! 
# You need to run this as an Org Admin (Manually)
# org_id=$(gcloud organizations list --format="value(name)")
# project_id=$(gcloud config get project)
# gcloud organizations add-iam-policy-binding "${org_id}" --member="serviceAccount:composer-service-account@${project_id}.iam.gserviceaccount.com" --role="roles/orgpolicy.policyAdmin"
# MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! MANUAL! 


# Parameters
PROJECT_ID="{{ params.project_id }}"
ROOT_PASSWORD="{{ params.root_password }}"
INSTANCE="postgres-public-ip"
DATABASE_VERSION="POSTGRES_14"
CPU="2"
MEMORY="8GB"
CLOUD_SQL_REGION="{{ params.cloud_sql_region }}"
YOUR_IP_ADDRESS=$(curl ifconfig.me)
DATABASE_NAME="demodb"
DATASTREAM_REGION="{{ params.datastream_region }}"

DATASTREAM_IPS="ERROR-NOT-SET"

# https://cloud.google.com/datastream/docs/ip-allowlists-and-regions

# us-central1
if [[ "$DATASTREAM_REGION" = "us-central1" ]]; 
then
    DATASTREAM_IPS="34.71.242.81,34.72.28.29,34.67.6.157,34.67.234.134,34.72.239.218"
fi

# us-east1
if [[ "$DATASTREAM_REGION" = "us-east1" ]]; 
then
    DATASTREAM_IPS="34.74.216.163,34.75.166.194,104.196.6.24,34.73.50.6,35.237.45.20"
fi

# us-east4
if [[ "$DATASTREAM_REGION" = "us-east4" ]]; 
then
    DATASTREAM_IPS="35.245.110.238,34.85.182.28,34.150.213.121,34.150.171.115,34.145.160.237"
fi

# us-west1
if [[ "$DATASTREAM_REGION" = "us-west1" ]]; 
then
    DATASTREAM_IPS="35.247.10.221,35.233.208.195,34.82.253.59,35.247.95.52,34.82.254.46"
fi

# us-west2
if [[ "$DATASTREAM_REGION" = "us-west2" ]]; 
then
    DATASTREAM_IPS="35.235.83.92,34.94.230.251,34.94.60.44,34.102.102.81,34.94.40.175"
fi

# us-west3
if [[ "$DATASTREAM_REGION" = "us-west3" ]]; 
then
    DATASTREAM_IPS="34.106.215.166,34.106.204.197,34.106.119.245,34.106.60.77,34.106.53.183"
fi

# us-west4
if [[ "$DATASTREAM_REGION" = "us-west4" ]]; 
then
    DATASTREAM_IPS="34.125.243.211,34.125.107.65,34.125.139.78,34.125.158.25,34.125.152.20"
fi


# europe-west1
if [[ "$DATASTREAM_REGION" = "europe-west1" ]]; 
then
    DATASTREAM_IPS="35.187.27.174,104.199.6.64,35.205.33.30,34.78.213.130,35.205.125.111"
fi

echo "DATASTREAM_IPS: ${DATASTREAM_IPS}"

# YOU MUST DO THIS BY HAND
# Disable this constraint (Your composer service account needs to be an Org Admin)
# gcloud resource-manager org-policies disable-enforce sql.restrictAuthorizedNetworks --project="${PROJECT_ID}"

# wait
# sleep 180


# https://cloud.google.com/sdk/gcloud/reference/sql/instances/create
# The IP Address are for Iowa (us-central1)
# https://cloud.google.com/datastream/docs/ip-allowlists-and-regions
gcloud sql instances create "${INSTANCE}" \
    --database-version=${DATABASE_VERSION} \
    --cpu=${CPU} \
    --memory=${MEMORY} \
    --project="${PROJECT_ID}" \
    --region=${CLOUD_SQL_REGION} \
    --root-password="${ROOT_PASSWORD}" \
    --storage-size="10GB" \
    --storage-type="SSD" \
    --storage-auto-increase \
    --maintenance-window-day=SAT \
    --maintenance-window-hour=1 \
    --database-flags=cloudsql.logical_decoding=on \
    --authorized-networks="${YOUR_IP_ADDRESS},${DATASTREAM_IPS}"


# Re-enable this constraint (Your composer service account needs to be an Org Admin)
# This will keep it as Custom: gcloud resource-manager org-policies enable-enforce sql.restrictAuthorizedNetworks --project="${PROJECT_ID}"
# Deleting it will set it back to "Inherit from parent"
# YOU MUST DO THIS BY HAND
# gcloud resource-manager org-policies delete sql.restrictAuthorizedNetworks --project="${PROJECT_ID}"

# Get ip address (of this node)
cloudsql_ip_address=$(gcloud sql instances list --filter="NAME=${INSTANCE}" --project="${PROJECT_ID}" --format="value(PRIMARY_ADDRESS)")


# Write out so we can read in via Python
echo ${cloudsql_ip_address} > /home/airflow/gcs/data/postgres_public_ip_address.txt


# Create the database
gcloud sql databases create ${DATABASE_NAME} --instance="${INSTANCE}" --project="${PROJECT_ID}"


# gcloud sql instances patch "${INSTANCE}" \
#   --project="${PROJECT_ID}" \
#   --authorized-networks="${YOUR_IP_ADDRESS},34.71.242.81,34.72.28.29,34.67.6.157,34.67.234.134,34.72.239.218"


# https://www.postgresqltutorial.com/postgresql-python/
# To run through cloud shell
# gcloud services enable sqladmin.googleapis.com
# gcloud sql connect ${INSTANCE} --user=postgres

# Run this in pgAdmin
# https://cloud.google.com/sql/docs/postgres/connect-instance-cloud-shell
# CREATE TABLE xxx

# Datastream required configuration (replicating All tables by default)
# CREATE PUBLICATION datastream_publication FOR ALL TABLES;
# ALTER USER postgres with replication;
# SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('datastream_replication_slot', 'pgoutput');
# CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD 'password123';
# GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;
# GRANT USAGE ON SCHEMA public TO datastream_user ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;

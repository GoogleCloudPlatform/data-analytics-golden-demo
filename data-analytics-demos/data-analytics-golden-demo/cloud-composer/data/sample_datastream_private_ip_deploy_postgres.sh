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


# ==============================================================================
# 1. Variables from Airflow
# ==============================================================================
PROJECT_ID="{{ params.project_id }}"
PROJECT_NUMBER="{{ params.project_number }}"
ROOT_PASSWORD="{{ params.root_password }}"
INSTANCE="postgres-private-ip"
DATABASE_VERSION="POSTGRES_14"
CPU="2"
MEMORY="8GB"
CLOUD_SQL_REGION="{{ params.cloud_sql_region }}"
YOUR_IP_ADDRESS=$(curl ifconfig.me)
DATABASE_NAME="demodb"
DATASTREAM_REGION="{{ params.datastream_region }}"
CODE_BUCKET_NAME="{{ params.code_bucket_name }}"
CLOUD_SQL_ZONE="{{ params.cloud_sql_zone }}"


# ==============================================================================
# 2. Create the Cloud SQL Instance
# ==============================================================================
# This will take about 5-10 minutes to complete
# - --network: Turns on Peering (for BigQuery)
# - --enable-private-service-connect: Turns on PSC (for postgres-client machine & Datastream)
# - --allowed-psc-projects: Authorization (so you can connect immediately)

echo "Creating Cloud SQL Instance: ${INSTANCE}..."
gcloud sql instances create "${INSTANCE}" \
    --project="${PROJECT_ID}" \
    --database-version=${DATABASE_VERSION} \
    --cpu=${CPU} \
    --memory=${MEMORY} \
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
    --database-flags=cloudsql.logical_decoding=on \
    --enable-private-service-connect \
    --allowed-psc-projects="${PROJECT_ID}"


# ==============================================================================
# 3. Create the specific 'demodb' database inside the instance
# ==============================================================================
echo "Creating database ${DATABASE_NAME}..."
gcloud sql databases create "${DATABASE_NAME}" \
    --instance="${INSTANCE}" \
    --project="${PROJECT_ID}"


# ==============================================================================
# 4. Create the Postgres Client VM
# ==============================================================================
# Note: I moved the complex installation logic INTO the startup script.
# You will not need to run manual install commands when you SSH in.

echo "Creating Postgres Client VM..."
gcloud compute instances create postgres-client \
    --project="${PROJECT_ID}" \
    --zone=${CLOUD_SQL_ZONE} \
    --machine-type=e2-small \
    --network-interface=subnet=compute-subnet,no-address \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --create-disk=auto-delete=yes,boot=yes,device-name=postgres-client,image=projects/debian-cloud/global/images/debian-11-bullseye-v20230411,mode=rw,size=10,type=projects/${PROJECT_ID}/zones/${CLOUD_SQL_ZONE}/diskTypes/pd-balanced \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --tags=ssh-firewall-tag \
    --reservation-affinity=any \
    --metadata=startup-script='#! /bin/bash
# Install Postgres Client automatically on startup using official Repo
sudo apt-get install wget ca-certificates -y
wget -O- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/EXAMPLE.gpg > /dev/null
sudo sh -c "echo deb http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main >> /etc/apt/sources.list.d/pgdg.list"
sudo apt-get update -y
sudo apt-get install postgresql-client -y
echo "Postgres client installed."
'


# ==============================================================================
# 5. Get the Service Attachment URL (The address of the "Producer")
# ==============================================================================
# We need this to tell the Endpoint where to point.
export SERVICE_ATTACHMENT_LINK=$(gcloud sql instances describe "${INSTANCE}" \
    --project="${PROJECT_ID}" \
    --format="value(pscServiceAttachmentLink)")

echo "Service Attachment: ${SERVICE_ATTACHMENT_LINK}"


# ==============================================================================
# 6. Reserve a specific IP in the compute-subnet (e.g., 10.1.0.50)
# ==============================================================================
export DB_LOCAL_IP="10.1.0.50"

echo "Reserving IP ${DB_LOCAL_IP}..."
gcloud compute addresses create "postgres-local-ip" \
    --region="${CLOUD_SQL_REGION}" \
    --subnet="compute-subnet" \
    --addresses="${DB_LOCAL_IP}" \
    --project="${PROJECT_ID}"


# ==============================================================================
# 7. Create the Forwarding Rule (The Endpoint)
# ==============================================================================
# This maps 10.1.0.50 -> The Cloud SQL Instance

echo "Creating PSC Endpoint..."
gcloud compute forwarding-rules create "postgres-endpoint" \
    --region="${CLOUD_SQL_REGION}" \
    --network="vpc-main" \
    --address="postgres-local-ip" \
    --target-service-attachment="${SERVICE_ATTACHMENT_LINK}" \
    --project="${PROJECT_ID}"


# ==============================================================================
# PART C: Output Instructions
# ==============================================================================

echo ""
echo "################################################################"
echo "           INFRASTRUCTURE SETUP COMPLETE"
echo "################################################################"
echo ""
echo "1. CONNECTION DETAILS:"
echo "   - Endpoint IP: ${DB_LOCAL_IP}"
echo "   - Database: ${DATABASE_NAME}"
echo "   - Password: ${ROOT_PASSWORD}"
echo ""
echo "2. HOW TO CONNECT:"
echo "   Go to Compute Engine -> VM Instances -> postgres-client -> SSH"
echo ""
echo "   (Wait 60 seconds for the startup script to finish installing psql)"
echo ""
echo "   Run:"
echo "   psql --host=${DB_LOCAL_IP} --user=postgres --password -d ${DATABASE_NAME}"
echo ""
echo "################################################################"

# ==============================================================================
# Manual Delete Instructions
# ==============================================================================
# gcloud compute forwarding-rules delete postgres-endpoint --region="${CLOUD_SQL_REGION}" --project="${PROJECT_ID}" --quiet
# gcloud compute addresses delete "postgres-local-ip" --region="${CLOUD_SQL_REGION}" --project="${PROJECT_ID}" --quiet
# gcloud compute instances delete postgres-client --zone="${CLOUD_SQL_ZONE}" --project="${PROJECT_ID}" --quiet 
# gcloud sql instances delete "${INSTANCE}" --project="${PROJECT_ID}" --quiet
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
DATABASE_NAME="demodb"
DATASTREAM_REGION="{{ params.datastream_region }}"
CODE_BUCKET_NAME="{{ params.code_bucket_name }}"
CLOUD_SQL_ZONE="{{ params.cloud_sql_zone }}"

# REMOVED: Unnecessary gcloud installation (Composer has this pre-installed)

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
cloudsql_ip_address=$(gcloud sql instances list --filter="NAME=${INSTANCE}" --project="${PROJECT_ID}" --format="value(PRIVATE_ADDRESS)")


# Write out so we can read in via Python
echo ${cloudsql_ip_address} > /home/airflow/gcs/data/postgres_private_ip_address.txt


# Create the database
gcloud sql databases create ${DATABASE_NAME} --instance="${INSTANCE}" --project="${PROJECT_ID}"


# We need a script that will be run on the SQL reverse proxy VM
sed "s/REPLACE_DB_ADDR/${cloudsql_ip_address}/g" /home/airflow/gcs/data/cloud_sql_reverse_proxy_template.sh > /home/airflow/gcs/data/cloud_sql_reverse_proxy.sh
gsutil cp /home/airflow/gcs/data/cloud_sql_reverse_proxy.sh gs://${CODE_BUCKET_NAME}/vm-startup-scripts/cloud_sql_reverse_proxy.sh

# Create the reverse proxy machine
gcloud compute instances create sql-reverse-proxy \
    --project="${PROJECT_ID}" \
    --zone=${CLOUD_SQL_ZONE} \
    --machine-type=e2-small \
    --network-interface=subnet=compute-subnet,no-address \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=sql-reverse-proxy,image=projects/debian-cloud/global/images/debian-11-bullseye-v20230411,mode=rw,size=10,type=projects/${PROJECT_ID}/zones/${CLOUD_SQL_ZONE}/diskTypes/pd-balanced \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --tags=ssh-firewall-tag \
    --reservation-affinity=any \
    --metadata=enable-oslogin=true,startup-script-url=gs://${CODE_BUCKET_NAME}/vm-startup-scripts/cloud_sql_reverse_proxy.sh

reverse_proxy_vm_ip_address=$(gcloud compute instances list --filter="NAME=sql-reverse-proxy" --project="${PROJECT_ID}" --format="value(INTERNAL_IP)")

# We can read this file to create the connection for Datastream
# Datastream needs to point to the reverse proxy
echo "reverse_proxy_vm_ip_address: ${reverse_proxy_vm_ip_address}"
echo ${reverse_proxy_vm_ip_address} > /home/airflow/gcs/data/reverse_proxy_vm_ip_address.txt


# Install postgresql client (you must do this, this is not done since it can take a while and the automation might break)
echo '############## How to connect to the Cloud SQL "##############'
echo 'In the Cloud Console go to Compute Engine -> VM Instances'
echo 'For this sql-reverse-proxy VM click SSH -> Open in Browser Window'
echo 'Run the bolow command (only needed to do once)'
echo "sudo apt-get install wget ca-certificates -y"
echo "wget -O- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/EXAMPLE.gpg > /dev/null"
echo "sudo sh -c 'echo deb http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main >> /etc/apt/sources.list.d/pgdg.list'"
echo "sudo apt-get update -y"
echo "sudo apt-get install postgresql-client -y"

echo "To connect and run SQL commands use this:"
echo "psql --host=${cloudsql_ip_address} --user=postgres --password" -d demodb
echo "<<ENTER PASSWORD>>"
echo "SELECT * FROM entries;"
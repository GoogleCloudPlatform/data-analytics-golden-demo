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


PROJECT_ID="{{ params.project_id }}"
ROOT_PASSWORD="{{ params.root_password }}"
DATASTREAM_REGION="{{ params.datastream_region }}"
DATABASE_NAME="demodb"
INSTANCE="postgres-private-ip"
BIGQUERY_REGION="{{ params.bigquery_region }}"

echo "PROJECT_ID: ${PROJECT_ID}"
echo "DATASTREAM_REGION: ${DATASTREAM_REGION}"


# Install the latest version of gCloud (This is NOT a best practice)
wget https://packages.cloud.google.com/apt/doc/apt-key.gpg && sudo apt-key add apt-key.gpg
sudo apt-get update && sudo apt-get --only-upgrade install google-cloud-sdk 


# *** NOTE: THIS HAS BEEN MOVED TO TERRAFORM ***
# You need to be an Org Admin to disable this policy
# Constraint  violated for the specified VPC network. Peering with Datastream's network is not allowed.
# cat > restrictVpcPeering.yaml << ENDOFFILE
# name: projects/$PROJECT_ID/policies/compute.restrictVpcPeering
# spec:
#   rules:
#   - allowAll: true
# ENDOFFILE
# gcloud org-policies set-policy restrictVpcPeering.yaml --project=${PROJECT_ID}


# *** NOTE: THIS HAS BEEN MOVED TO TERRAFORM ***
# This takes a few minutes
# gcloud datastream private-connections create cloud-sql-private-connect \
#   --location=${DATASTREAM_REGION} \
#   --display-name=cloud-sql-private-connect \
#   --subnet="10.7.0.0/29" \
#   --vpc="vpc-main" \
#   --project="${PROJECT_ID}"


# Loop while it creates
# stateDataStream="CREATING"
# while [ "$stateDataStream" = "CREATING" ]
#     do
#     sleep 5
#     stateDataStream=$(gcloud datastream private-connections list --location=${DATASTREAM_REGION} --project="${PROJECT_ID}" --filter="DISPLAY_NAME=cloud-sql-private-connect" --format="value(STATE)")
#     echo "stateDataStream: $stateDataStream"
#     done


# *** NOTE: THIS HAS BEEN MOVED TO TERRAFORM ***
# Re-enable this constraint (Your composer service account needs to be an Org Admin)
# Deleting it will set it back to "Inherit from parent"
# gcloud resource-manager org-policies delete constraints/compute.restrictVpcPeering --project="${PROJECT_ID}"


# Get ip address (of this node)
reverse_proxy_vm_ip_address=$(gcloud compute instances list --filter="NAME=sql-reverse-proxy" --project="${PROJECT_ID}" --format="value(INTERNAL_IP)")
echo "reverse_proxy_vm_ip_address: ${reverse_proxy_vm_ip_address}"


# Create the Datastream source
# https://cloud.google.com/sdk/gcloud/reference/datastream/connection-profiles/create
gcloud datastream connection-profiles create postgres-private-ip-connection \
    --location=${DATASTREAM_REGION} \
    --type=postgresql \
    --postgresql-password=${ROOT_PASSWORD} \
    --postgresql-username=postgres \
    --display-name=postgres-private-ip-connection \
    --postgresql-hostname=${reverse_proxy_vm_ip_address} \
    --postgresql-port=5432 \
    --postgresql-database=${DATABASE_NAME} \
    --private-connection=cloud-sql-private-connect  \
    --project="${PROJECT_ID}"


# Create the Datastream destination
gcloud datastream connection-profiles create bigquery-private-ip-connection \
    --location=${DATASTREAM_REGION} \
    --type=bigquery \
    --display-name=bigquery-private-ip-connection \
    --project="${PROJECT_ID}"


# Do we need a wait statement here while the connections get created
# Should call apis to test for sure
echo "Sleep 90"
sleep 90


# Postgres source JSON/YAML
# https://cloud.google.com/datastream/docs/reference/rest/v1/projects.locations.streams#PostgresqlTable
source_config_json=$(cat <<EOF
  {
    "excludeObjects": {},
    "includeObjects": {
      "postgresqlSchemas": [
        {
          "schema": "public"
        }
      ]
    },
    "replicationSlot": "datastream_replication_slot",
    "publication": "datastream_publication"
  }
EOF
)

# Write to file
echo ${source_config_json} > /home/airflow/gcs/data/source_private_ip_config.json
echo "source_config_json: ${source_config_json}"


# BigQuery destination JSON/YAML
destination_config_json=$(cat <<EOF
{
  "sourceHierarchyDatasets": {
    "datasetTemplate": {
      "location": "${BIGQUERY_REGION}",
      "datasetIdPrefix": "datastream_private_ip_",
    }
  },
  "dataFreshness": "0s"
}
EOF
)

# Write to file
echo ${destination_config_json} > /home/airflow/gcs/data/destination_private_ip_config.json
echo "destination_config_json: ${destination_config_json}"


# Create DataStream "Stream"
# https://cloud.google.com/sdk/gcloud/reference/datastream/streams/create
gcloud datastream streams create datastream-demo-private-ip-stream \
    --location="${DATASTREAM_REGION}" \
    --display-name=datastream-demo-private-ip-stream \
    --source=postgres-private-ip-connection \
    --postgresql-source-config=/home/airflow/gcs/data/source_private_ip_config.json \
    --destination=bigquery-private-ip-connection \
    --bigquery-destination-config=/home/airflow/gcs/data/destination_private_ip_config.json \
    --backfill-all \
    --project="${PROJECT_ID}"


echo "Sleep 60"
sleep 60

# Show the stream attributes
gcloud datastream streams describe datastream-demo-private-ip-stream --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}"


echo "Sleep 60"
sleep 60

# Start the stream
gcloud datastream streams update datastream-demo-private-ip-stream --location="${DATASTREAM_REGION}" --state=RUNNING --update-mask=state --project="${PROJECT_ID}"

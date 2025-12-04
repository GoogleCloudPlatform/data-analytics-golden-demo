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

export ATTACHMENT_NAME="datastream-attachment"
export CONNECTION_NAME="cloud-sql-private-connect"
export DB_LOCAL_IP="10.1.0.50" 
export NEW_SUBNET_NAME="datastream-subnet"


# ==============================================================================
# 1. Create a subnet and firewall rule for Datastream
# ==============================================================================
echo "Creating Datastream Subnet..."
gcloud compute networks subnets create "${NEW_SUBNET_NAME}" \
    --network="vpc-main" \
    --region="${DATASTREAM_REGION}" \
    --range="10.20.0.0/29" \
    --project="${PROJECT_ID}"

echo "Creating Firewall Rule..."
gcloud compute firewall-rules create allow-datastream-ingress \
    --network="vpc-main" \
    --allow=tcp:5432 \
    --source-ranges="10.20.0.0/29" \
    --direction=INGRESS \
    --description="Allow Datastream Subnet to talk to Postgres" \
    --project="${PROJECT_ID}"


# ==============================================================================
# 2. Create Network Attachment
# ==============================================================================
echo "Creating Network Attachment: ${ATTACHMENT_NAME}..."
gcloud compute network-attachments create "${ATTACHMENT_NAME}" \
    --region="${DATASTREAM_REGION}" \
    --subnets="${NEW_SUBNET_NAME}" \
    --subnets-region="${DATASTREAM_REGION}" \
    --connection-preference="ACCEPT_MANUAL" \
    --producer-accept-list="${PROJECT_ID}" \
    --project="${PROJECT_ID}" 


# ==============================================================================
# 3. Set the producer id
# ==============================================================================
#ERROR_OUTPUT=$(gcloud datastream private-connections create ${CONNECTION_NAME} \
#    --location="${DATASTREAM_REGION}" \
#    --display-name="${CONNECTION_NAME}" \
#    --network-attachment="projects/${PROJECT_ID}/regions/${DATASTREAM_REGION}/networkAttachments/${ATTACHMENT_NAME}" \
#    --project="${PROJECT_ID}" \
#    --validate-only 2>&1)
#    
#export PRODUCER_PROJECT_ID=$(echo "$ERROR_OUTPUT" | grep "tenant_project_id:" | awk '{print $2}')
#
#echo "PRODUCER_PROJECT_ID: ${PRODUCER_PROJECT_ID}"


echo "Attempting to Validate Connection to find Producer ID..."

# 1. Run the command and capture ALL output (stdout and stderr)
OUTPUT=$(gcloud datastream private-connections create ${CONNECTION_NAME} \
    --location="${DATASTREAM_REGION}" \
    --display-name="${CONNECTION_NAME}" \
    --network-attachment="projects/${PROJECT_ID}/regions/${DATASTREAM_REGION}/networkAttachments/${ATTACHMENT_NAME}" \
    --project="${PROJECT_ID}" \
    --validate-only 2>&1)

# 2. Check if we got the ID immediately (Synchronous case)
PRODUCER_PROJECT_ID=$(echo "$OUTPUT" | grep "tenant_project_id" | awk '{print $2}' | tr -d '"')

# 3. If empty, check if we got an Operation ID (Asynchronous case - like Airflow)
if [[ -z "$PRODUCER_PROJECT_ID" ]]; then
    # Extract Operation Name (looks like projects/.../operations/operation-123...)
    OPERATION_NAME=$(echo "$OUTPUT" | grep -o "projects/.*/operations/operation-[a-zA-Z0-9-]*")

    if [[ -n "$OPERATION_NAME" ]]; then
        echo "Validation started asynchronously. Waiting for Operation: $OPERATION_NAME..."
        
        # Wait for the operation to complete and capture THAT output
        WAIT_OUTPUT=$(gcloud datastream operations wait "$OPERATION_NAME" \
            --location="${DATASTREAM_REGION}" \
            --project="${PROJECT_ID}" 2>&1)
            
        # Now extract the ID from the finished operation output
        PRODUCER_PROJECT_ID=$(echo "$WAIT_OUTPUT" | grep "tenant_project_id" | awk '{print $2}' | tr -d '"')
    else
        echo "CRITICAL ERROR: Could not find Tenant ID or Operation Name."
        echo "Raw Output:"
        echo "$OUTPUT"
        exit 1
    fi
fi

# 4. Final Validation
if [[ -z "$PRODUCER_PROJECT_ID" ]]; then
    echo "CRITICAL ERROR: Producer Project ID is still empty after waiting."
    exit 1
fi

echo "SUCCESS! Found Producer Project ID: ${PRODUCER_PROJECT_ID}"



echo "Authorizing Datastream ID..."
gcloud compute network-attachments update "${ATTACHMENT_NAME}" \
    --region="${DATASTREAM_REGION}" \
    --producer-accept-list="${PRODUCER_PROJECT_ID}" \
    --project="${PROJECT_ID}"


# ==============================================================================
# 4. Create the Connection 
# ==============================================================================
echo "Creating Datastream Private Connection (This takes a few minutes)..."
gcloud datastream private-connections create ${CONNECTION_NAME} \
    --location="${DATASTREAM_REGION}" \
    --display-name="${CONNECTION_NAME}" \
    --network-attachment="projects/${PROJECT_ID}/regions/${DATASTREAM_REGION}/networkAttachments/${ATTACHMENT_NAME}" \
    --project="${PROJECT_ID}"


# ==============================================================================
# 4. Wait Loop (Same logic as your original script)
# ==============================================================================
echo "Checking status of connection: ${CONNECTION_NAME}..."

stateDataStream="CREATING"
while [ "$stateDataStream" = "CREATING" ]
    do
    sleep 5
    stateDataStream=$(gcloud datastream private-connections list --location=${DATASTREAM_REGION} --project="${PROJECT_ID}" --filter="DISPLAY_NAME=cloud-sql-private-connect" --format="value(STATE)")
    echo "stateDataStream: $stateDataStream"
    done


# ==============================================================================
# 5. Create Source Profile (Postgres)
# ==============================================================================
# Note: We use the Private Connection we just created.
# Note: Hostname is 10.1.0.50 (The Local Endpoint)

gcloud datastream connection-profiles create postgres-private-ip-connection \
    --location=${DATASTREAM_REGION} \
    --type=postgresql \
    --postgresql-password=${ROOT_PASSWORD} \
    --postgresql-username=postgres \
    --display-name=postgres-private-ip-connection \
    --postgresql-hostname=${DB_LOCAL_IP} \
    --postgresql-port=5432 \
    --postgresql-database=${DATABASE_NAME} \
    --private-connection="${CONNECTION_NAME}" \
    --project="${PROJECT_ID}"


# ==============================================================================
# 6. Create Destination Profile (BigQuery)
# ==============================================================================
echo "Creating BigQuery Destination Profile..."
gcloud datastream connection-profiles create bigquery-private-ip-connection \
    --location=${DATASTREAM_REGION} \
    --type=bigquery \
    --display-name=bigquery-private-ip-connection \
    --project="${PROJECT_ID}"


# ==============================================================================
# 7. Wait for the connections to get created
# ==============================================================================
# Should call apis to test for sure
echo "Sleep 90"
sleep 90


# ==============================================================================
# 8. Create the stream
# ==============================================================================
export FILE_PATH="/home/airflow/gcs/data"
# Test locally
#export FILE_PATH="/Users/paternostro/data-analytics-golden-demo" 

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
echo ${source_config_json} > $FILE_PATH/source_private_ip_config.json
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
echo ${destination_config_json} > $FILE_PATH/destination_private_ip_config.json
echo "destination_config_json: ${destination_config_json}"


# Create DataStream "Stream"
# https://cloud.google.com/sdk/gcloud/reference/datastream/streams/create
gcloud datastream streams create datastream-demo-private-ip-stream \
    --location="${DATASTREAM_REGION}" \
    --display-name=datastream-demo-private-ip-stream \
    --source=postgres-private-ip-connection \
    --postgresql-source-config=$FILE_PATH/source_private_ip_config.json \
    --destination=bigquery-private-ip-connection \
    --bigquery-destination-config=$FILE_PATH/destination_private_ip_config.json \
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


# Manually Delete
# gcloud datastream streams delete datastream-demo-private-ip-stream --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet
# gcloud datastream connection-profiles delete bigquery-private-ip-connection --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet
# gcloud datastream connection-profiles delete postgres-private-ip-connection --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet
# gcloud datastream private-connections delete "${CONNECTION_NAME}" --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --force --quiet
# You need to wait for the connection to be deleted before deleting the network attachment
# gcloud compute network-attachments delete "${ATTACHMENT_NAME}" --region="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet
# gcloud compute firewall-rules delete allow-datastream-ingress --project="${PROJECT_ID}" --quiet
# gcloud compute networks subnets delete "${NEW_SUBNET_NAME}" --region="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet

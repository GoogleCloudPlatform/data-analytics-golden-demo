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
INSTANCE="postgres-public-ip"

echo "PROJECT_ID: ${PROJECT_ID}"
echo "DATASTREAM_REGION: ${DATASTREAM_REGION}"

# Delete the stream
gcloud datastream streams delete datastream-demo-public-ip-stream \
    --location="${DATASTREAM_REGION}" \
    --project="${PROJECT_ID}" \
    --quiet

echo "Sleep 180 - incase datastream needs a minute to stop the stream"
sleep 180


# Delete the connection
gcloud datastream connection-profiles delete postgres-public-ip-connection \
    --location=${DATASTREAM_REGION} \
    --project="${PROJECT_ID}" \
    --quiet


# Delete the connection
gcloud datastream connection-profiles delete bigquery-public-ip-connection \
    --location=${DATASTREAM_REGION} \
    --project="${PROJECT_ID}" \
    --quiet


# Delete the postgres database
gcloud sql instances delete "${INSTANCE}" \
    --project="${PROJECT_ID}" \
    --quiet


# Delete the BigQuery Dataset
bq rm -r -f --dataset ${PROJECT_ID}:datastream_public_ip_public

# Reset the CDC file:
rm /home/airflow/gcs/data/datastream-public-ip-generate-data.json
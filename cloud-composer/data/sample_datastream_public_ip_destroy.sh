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
DATABASE_NAME="guestbook"
INSTANCE="postgres-cloud-sql"

echo "PROJECT_ID: ${PROJECT_ID}"
echo "DATASTREAM_REGION: ${DATASTREAM_REGION}"

# Delete the stream
gcloud datastream streams delete datastream-demo-stream \
    --location="${DATASTREAM_REGION}" \
    --project="${PROJECT_ID}"

echo "Sleep 180 - incase datastream needs a minute to stop the stream"
sleep 180

# Delete the connection
gcloud datastream connection-profiles delete postgres-cloud-sql-connection \
    --location=${DATASTREAM_REGION} \
    --project="${PROJECT_ID}"


# Delete the connection
gcloud datastream connection-profiles create bigquery-connection \
    --location=${DATASTREAM_REGION} \
    --project="${PROJECT_ID}"


# Delete the postgres database
gcloud sql instances delete "${INSTANCE}" \
    --project="${PROJECT_ID}"
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
CLOUD_SQL_REGION="{{ params.cloud_sql_region }}"
CLOUD_SQL_ZONE="{{ params.cloud_sql_zone }}"

export ATTACHMENT_NAME="datastream-attachment"
export CONNECTION_NAME="cloud-sql-private-connect"
export NEW_SUBNET_NAME="datastream-subnet"


gcloud datastream streams delete datastream-demo-private-ip-stream --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet
echo "Sleep 180"
sleep 180

# You need to wait for the stream to be deleted before deleting the connection profiles
gcloud datastream connection-profiles delete bigquery-private-ip-connection --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet

gcloud datastream connection-profiles delete postgres-private-ip-connection --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet

gcloud datastream private-connections delete "${CONNECTION_NAME}" --location="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --force --quiet
echo "Sleep 600"
sleep 600

# You need to wait for the connection to be deleted before deleting the network attachment
gcloud compute network-attachments delete "${ATTACHMENT_NAME}" --region="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet

gcloud compute firewall-rules delete allow-datastream-ingress --project="${PROJECT_ID}" --quiet

gcloud compute networks subnets delete "${NEW_SUBNET_NAME}" --region="${DATASTREAM_REGION}" --project="${PROJECT_ID}" --quiet

gcloud compute forwarding-rules delete postgres-endpoint --region="${CLOUD_SQL_REGION}" --project="${PROJECT_ID}" --quiet

gcloud compute addresses delete "postgres-local-ip" --region="${CLOUD_SQL_REGION}" --project="${PROJECT_ID}" --quiet

gcloud compute instances delete postgres-client --zone="${CLOUD_SQL_ZONE}" --project="${PROJECT_ID}" --quiet 

gcloud sql instances delete "${INSTANCE}" --project="${PROJECT_ID}" --quiet

# Delete the BigQuery Dataset
bq rm -r -f --dataset ${PROJECT_ID}:datastream_private_ip_public

# Reset the CDC file:
rm /home/airflow/gcs/data/datastream-private-ip-generate-data.json

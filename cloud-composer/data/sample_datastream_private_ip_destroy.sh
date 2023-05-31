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


echo "PROJECT_ID: ${PROJECT_ID}"
echo "DATASTREAM_REGION: ${DATASTREAM_REGION}"

# Delete the stream
gcloud datastream streams delete datastream-demo-private-ip-stream \
    --location="${DATASTREAM_REGION}" \
    --project="${PROJECT_ID}" \
    --quiet

echo "Sleep 180 - incase datastream needs a minute to stop the stream"
sleep 180


# Delete the connection
gcloud datastream connection-profiles delete postgres-private-ip-connection \
    --location=${DATASTREAM_REGION} \
    --project="${PROJECT_ID}" \
    --quiet


# Delete the connection
gcloud datastream connection-profiles delete bigquery-private-ip-connection \
    --location=${DATASTREAM_REGION} \
    --project="${PROJECT_ID}" \
    --quiet


# Delete the postgres database
gcloud sql instances delete "${INSTANCE}" \
    --project="${PROJECT_ID}" \
    --quiet


# Delete the BigQuery Dataset
bq rm -r -f --dataset ${PROJECT_ID}:datastream_private_ip_public


# *** NOTE: THIS HAS BEEN MOVED TO TERRAFORM *** -> The rules are left in place and are not deleted
# Delete the firewall rule for the SQL Proxy
# gcloud compute firewall-rules delete cloud-sql-ssh-firewall-rule \
#     --project="${PROJECT_ID}" \
#     --quiet


# Delete the SQL Reverse Proxy VM
gcloud compute instances delete sql-reverse-proxy \
    --project="${PROJECT_ID}" \
    --zone="${CLOUD_SQL_ZONE}" \
    --quiet


# *** NOTE: THIS HAS BEEN MOVED TO TERRAFORM *** -> The rules are left in place and are not deleted
# Delete the firewall rules
# gcloud compute firewall-rules delete datastream-ingress-rule \
#     --project="${PROJECT_ID}" \
#     --quiet


# *** NOTE: THIS HAS BEEN MOVED TO TERRAFORM *** -> The rules are left in place and are not deleted
# Delete the firewall rules
# gcloud compute firewall-rules delete datastream-egress-rule \
#    --project="${PROJECT_ID}" \
#    --quiet

# Reset the CDC file:
rm /home/airflow/gcs/data/datastream-private-ip-generate-data.json

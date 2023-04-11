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

PROJECT_ID="{{ params.project_id }}"
INSTANCE="postgres-cloud-sql"
DATASET_NAME="postgres_cloud_sql"
DATABASE_VERSION="POSTGRES_14"
CPU="2"
MEMORY="8GB"
REGION="us-central1"
ROOT_PASSWORD="password123"
YOUR_IP_ADDRESS=$(curl ifconfig.me)
DATABASE_NAME="guestbook"


# Disable this constraint (Your composer service account needs to be an Org Admin)
gcloud resource-manager org-policies disable-enforce sql.restrictAuthorizedNetworks --project="${PROJECT_ID}"


# https://cloud.google.com/sdk/gcloud/reference/sql/instances/create
# The IP Address are for Iowa (us-central1)
# https://cloud.google.com/datastream/docs/ip-allowlists-and-regions
gcloud sql instances create "${INSTANCE}" \
    --database-version=${DATABASE_VERSION} \
    --cpu=${CPU} \
    --memory=${MEMORY} \
    --project="${PROJECT_ID}" \
    --region=${REGION} \
    --root-password="${ROOT_PASSWORD}" \
    --storage-size="10GB" \
    --storage-type="SSD" \
    --storage-auto-increase \
    --maintenance-window-day=SAT \
    --maintenance-window-hour=1 \
    --database-flags=cloudsql.logical_decoding=on \
    --authorized-networks="${YOUR_IP_ADDRESS},34.71.242.81,34.72.28.29,34.67.6.157,34.67.234.134,34.72.239.218"


# Re-enable this constraint (Your composer service account needs to be an Org Admin)
gcloud resource-manager org-policies enable-enforce sql.restrictAuthorizedNetworks --project="${PROJECT_ID}"


# Get ip address (of this node)
cloudsql_ip_address=$(gcloud sql instances list --filter="NAME=${INSTANCE}" --project="${PROJECT_ID}" --format="value(PRIMARY_ADDRESS)")


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
# CREATE TABLE entries (guestName VARCHAR(255), content VARCHAR(255), entryID SERIAL PRIMARY KEY);
# INSERT INTO entries (guestName, content) values ('first guest', 'I got here!');
# INSERT INTO entries (guestName, content) values ('second guest', 'Me too!');

# Datastream required configuration (replicating All tables by default)
# CREATE PUBLICATION datastream_publication FOR ALL TABLES;
# ALTER USER postgres with replication;
# SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('datastream_replication_slot', 'pgoutput');
# CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD 'password123';
# GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;
# GRANT USAGE ON SCHEMA public TO datastream_user ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;


# Create the Datastream source
# https://cloud.google.com/sdk/gcloud/reference/datastream/connection-profiles/create
gcloud datastream connection-profiles create postgres-cloud-sql-connection \
    --location=${REGION} \
    --type=postgresql \
    --postgresql-password=${ROOT_PASSWORD} \
    --postgresql-username=postgres \
    --display-name=postgres-cloud-sql-connection \
    --postgresql-hostname=${cloudsql_ip_address} \
    --postgresql-port=5432 \
    --postgresql-database=${DATABASE_NAME} \
    --static-ip-connectivity \
    --project="${PROJECT_ID}"


# Create the Datastream destination
gcloud datastream connection-profiles create bigquery-connection \
    --location=us-central1 \
    --type=bigquery \
    --display-name=bigquery-connection \
    --project="${PROJECT_ID}"


# Do we need a wait statement here while the connections get created
# Should call apis to test for sure
sleep 60


# Postgres source JSON/YAML
# https://cloud.google.com/datastream/docs/reference/rest/v1/projects.locations.streams#PostgresqlTable
source_config_json=$(cat <<EOF
  {
    "excludeObjects": {},
    "includeObjects": {
      "postgresqlSchemas": [
        {
          "schema": "public",
          "postgresqlTables": [
            {
              "table": "entries",
            }
          ]
        }
      ]
    },
    "replicationSlot": "datastream_replication_slot",
    "publication": "datastream_publication"
  }
EOF
)

# Write to file
echo ${source_config_json} > source_config.json


# BigQuery destination JSON/YAML
destination_config_json=$(cat <<EOF
{
  "sourceHierarchyDatasets": {
    "datasetTemplate": {
      "location": "us",
      "datasetIdPrefix": "datastream_cdc_",
    }
  },
  "dataFreshness": "0s"
}
EOF
)

# Write to file
echo ${destination_config_json} > destination_config.json


# Create DataStream "Stream"
# https://cloud.google.com/sdk/gcloud/reference/datastream/streams/create
gcloud datastream streams create datastream-demo-stream \
    --location=us-central1 \
    --display-name=datastream-demo-stream \
    --source=postgres-cloud-sql-connection \
    --postgresql-source-config=source_config.json \
    --destination=bigquery-connection \
    --bigquery-destination-config=destination_config.json \
    --backfill-all \
    --project="${PROJECT_ID}" \
    --validate-only


# Show the stream attributes
gcloud datastream streams describe datastream-demo-stream --location=us-central1 --project="${PROJECT_ID}"


# Start the stream
gcloud datastream streams update datastream-demo-stream --location=us-central1 --state=RUNNING --update-mask=state --project="${PROJECT_ID}"

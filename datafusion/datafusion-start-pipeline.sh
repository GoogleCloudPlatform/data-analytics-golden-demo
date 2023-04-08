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


# NOTES:
# 1. This does not remove items from the hard drive that have been deleted from DataFusion.  
#    You would need to clear each directory before downloading each set of asessts.
# 2. 



# Login to GCP by running BOTH below gcloud auth commands (you only need to do this once which is why they are commented out)
#      These command are not needed when running from a Cloud Shell
# gcloud auth login
# gcloud auth application-default login
gcp_account_name=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# Variables
project="data-analytics-demo-z4x77nbcc3"
datafusion_name="data-fusion-dev-01"
datafusion_location="REPLACE-REGION"
datafusion_api_version="v1"
#datafusion_api_version="v1beta1"


echo "gcp_account_name:        ${gcp_account_name}"
echo "project:                 ${project}"
echo "datafusion_name:         ${datafusion_name}"
echo "datafusion_location:     ${datafusion_location}"
echo "datafusion_api_version:  ${datafusion_api_version}"



####################################################################################
# Using a Service Account
####################################################################################
# See deploy-use-docker.sh (this shows how to enable a service account and login)
# This demo is currently using the interactive credentials


####################################################################################
# Login to Data Fusion
####################################################################################
# Get the access token for the current user (or service account)
access_token=$(gcloud auth application-default print-access-token)

datafusion_get=$(curl --silent "https://content-datafusion.googleapis.com/${datafusion_api_version}/projects/${project}/locations/${datafusion_location}/instances/${datafusion_name}" \
    -H "Authorization: Bearer ${access_token}")

datafusion_version=$(echo "${datafusion_get}" | jq .version --raw-output)
datafusion_api_endpoint=$(echo "${datafusion_get}" | jq .apiEndpoint --raw-output)

#echo "datafusion_get:          ${datafusion_get}"
echo "datafusion_version:      ${datafusion_version}"
echo "datafusion_api_endpoint: ${datafusion_api_endpoint}"


echo ""
echo "*********************************************************"
echo "Start pipeline"
echo "*********************************************************"
echo ""

echo "Starting Pipeline: (default) GCS-Parquet-To-AVRO"
curl --silent -X POST "${datafusion_api_endpoint}/v3/namespaces/default/apps/GCS-Parquet-To-AVRO/workflows/DataPipelineWorkflow/start" \
    -H "Authorization: Bearer ${access_token}"

echo ""
echo "*********************************************************"
echo "Done"
echo "*********************************************************"
echo ""

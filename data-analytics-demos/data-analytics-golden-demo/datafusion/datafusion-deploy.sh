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
# 1. You will need to do JSON string substition for items (e.g. the project name, bucket names, etc.)
#    e.g. newJson=$(echo "$pipelineJSON" | jq  "def walkJson(f): . as \$in | if type == \"object\" then reduce keys[] as \$key ( {}; . + { (\$key):  (\$in[\$key] | walkJson(f)) } ) | f elif type == \"array\" then map( walkJson(f) ) | f else f end; walkJson(if type == \"object\" and .name == \"$pipelineArtifact\" then .version=\"$datafusion_version\" else . end)")  
# 2. This assumes you are creating a new Data Fusion for each deployment.  This script adds items to DataFusion, it does not
#    do incremental updates (a GET and then a PATCH).  You would need to enhance the script to do that.
#    Also, the script does not do deletes.


# Login to GCP by running BOTH below gcloud auth commands (you only need to do this once which is why they are commented out)
#      These command are not needed when running from a Cloud Shell
# gcloud auth login
# gcloud auth application-default login
gcp_account_name=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# Variables
project="data-analytics-demo-z4x77nbcc3"
datafusion_name="data-fusion-prod-02"
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
echo "Load and Create namespaces"
echo "*********************************************************"
echo ""

# Load from disk
allNamepaces=$(cat ./system/allNamepaces.json)

for namespaceName in $(echo "${namespaceNames}"); do
    if [ "$namespaceName" = "default" ]; then
        echo "Not creating Default namespace (skipping)"
    else
        file="./system/namespace/${namespaceName}.json"

        curl --silent -X PUT "${datafusion_api_endpoint}/v3/namespaces/${namespaceName}" \
            -H "Authorization: Bearer ${access_token}" \
            -d @${file}        
    fi
done


echo ""
echo "*********************************************************"
echo "Upload DRAFT pipelines to DataFusion (for each namespace)"
echo "*********************************************************"
echo ""

for namespaceName in $(echo "${namespaceNames}"); do
    # For each file in the pipelines directory upload the pipeline to datafusion
    find ./system/namespace/${namespaceName}/pipelines/draft -type f -name "*.json" -print0 | while IFS= read -r -d '' file; do
        echo "Uploading File: ${file}"
        searchString="./system/namespace/${namespaceName}/pipelines/draft/"
        replaceString=""
        removePath=$(echo "${file//$searchString/$replaceString}")
        searchString=".json"
        replaceString=""
        pipelineName=$(echo "${removePath//$searchString/$replaceString}")    
        echo "pipelineName:   ${pipelineName}"

        curl  -X PUT "${datafusion_api_endpoint}/v3/namespaces/system/apps/pipeline/services/studio/methods/${datafusion_api_version}/contexts/${namespaceName}/drafts/${pipelineName}" \
            -H "Authorization: Bearer ${access_token}" \
            -d @${file}
    done
done



echo ""
echo "*********************************************************"
echo "Upload PUBISHED pipelines to DataFusion (for each namespace)"
echo "*********************************************************"
echo ""

for namespaceName in $(echo "${namespaceNames}"); do
    # For each file in the pipelines directory upload the pipeline to datafusion
    find ./system/namespace/${namespaceName}/pipelines/published -type f -name "*.json" -print0 | while IFS= read -r -d '' file; do
        echo "Uploading File: ${file}"
        searchString="./system/namespace/${namespaceName}/pipelines/published/"
        replaceString=""
        removePath=$(echo "${file//$searchString/$replaceString}")
        searchString=".json"
        replaceString=""
        pipelineName=$(echo "${removePath//$searchString/$replaceString}")    
        echo "pipelineName:   ${pipelineName}"

        curl  -X PUT "${datafusion_api_endpoint}/v3/namespaces/${namespaceName}/apps/${pipelineName}" \
            -H "Authorization: Bearer ${access_token}" \
            -d @${file}
    done
done


echo ""
echo "*********************************************************"
echo "Upload Compute Profiles"
echo "*********************************************************"
echo ""


# For each file in the pipelines directory upload the pipeline to datafusion
find ./system/compute-profile -type f -name "*.json" -print0 | while IFS= read -r -d '' file; do
    echo "Uploading Compute Profile: ${file}"
    searchString="./system/compute-profile/"
    replaceString=""
    removePath=$(echo "${file//$searchString/$replaceString}")
    searchString=".json"
    replaceString=""
    computeProfile=$(echo "${removePath//$searchString/$replaceString}")    
    echo "computeProfile:   ${computeProfile}"

    curl --silent -X PUT "${datafusion_api_endpoint}/v3/profiles/${computeProfile}" \
        -H "Authorization: Bearer ${access_token}"  \
        -H "Content-Type: application/json" \
        -d @${file}
done


echo ""
echo "*********************************************************"
echo "Done"
echo "*********************************************************"
echo ""

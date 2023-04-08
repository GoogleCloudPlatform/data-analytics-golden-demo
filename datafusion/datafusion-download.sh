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


# How to use
# 1. Create Data Fusion (by hand or DAG) - Call this df-DEV
# 2. Author pipelines
# 3. Use this script to download the namespaces, pipelines and compute profiles
# 4. Create a new Data fusion (by hand or alter DAG) - Call this df-QA
# 5. Run the datafusion-deploy.sh to push out the artifacts

# NOTES:
# 1. This does not remove items from the hard drive that have been deleted from DataFusion.  
#    You would need to clear each directory before downloading each set of asessts.
# 2. This assumes you have created some pipelines in Data Fusion and you now want to download them.



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
echo "Get namespaces"
echo "*********************************************************"
echo ""
allNamepaces=$(curl --silent -X GET "${datafusion_api_endpoint}/v3/namespaces" \
    -H "Authorization: Bearer ${access_token}")

# echo "allNamepaces: ${allNamepaces}"
namespaceNames=$(echo "${allNamepaces}" | jq .[].name --raw-output)

mkdir -p ./system/namespace

# Save so when we upload we have a list of namespaces to iterate through
echo ${allNamepaces} > ./system/allNamepaces.json

# Download each pipelines
for namespaceName in $(echo "${namespaceNames}"); do
    echo "Namespace: ${namespaceName}"
    curl --silent -X GET "${datafusion_api_endpoint}/v3/namespaces/${namespaceName}" \
        -H "Authorization: Bearer ${access_token}" > ./system/namespace/${namespaceName}.json
   
    mkdir -p ./system/namespace/${namespaceName}/pipelines/published
    mkdir -p ./system/namespace/${namespaceName}/pipelines/draft
    mkdir -p ./system/compute-profile
done


echo ""
echo "*********************************************************"
echo "Download DRAFT pipelines from DataFusion (for each namespace)"
echo "*********************************************************"
echo ""


for namespaceName in $(echo "${namespaceNames}"); do
    # Get a list of all the pipelines 
    # https://cloud.google.com/data-fusion/docs/reference/cdap-reference#retrieve_all_pipelines
    allDrafts=$(curl --silent -X GET "${datafusion_api_endpoint}/v3/namespaces/system/apps/pipeline/services/studio/methods/${datafusion_api_version}/contexts/${namespaceName}/drafts" \
        -H "Authorization: Bearer ${access_token}")

    # echo ${allDrafts}
    draftNames=$(echo "${allDrafts}" | jq .[].name --raw-output)

    # Download each pipelines
    for draftName in $(echo "${draftNames}"); do
        echo "Downloading Draft: ${draftName}" 

        # Get the id since it does not download by name
        draftId=$(echo "${allDrafts} "| jq ".[] | select(.name ==\"${draftName}\")" | jq .id --raw-output)
        echo "Downloading Draft: ${draftName} Draft Id: ${draftId}" 

        # https://cdap.atlassian.net/wiki/spaces/DOCS/pages/975929350/Pipeline+Microservices#Details-of-a-Draft-Pipeline
        curl --silent -X GET "${datafusion_api_endpoint}/v3/namespaces/system/apps/pipeline/services/studio/methods/${datafusion_api_version}/contexts/${namespaceName}/drafts/${draftId}" \
            -H "Authorization: Bearer ${access_token}" > ./system/namespace/${namespaceName}/pipelines/draft/${draftName}.json
    done
done


echo ""
echo "*********************************************************"
echo "Download PUBISHED pipelines from DataFusion (for each namespace)"
echo "*********************************************************"
echo ""

for namespaceName in $(echo "${namespaceNames}"); do
    # Get a list of all the pipelines 
    # https://cloud.google.com/data-fusion/docs/reference/cdap-reference#retrieve_all_pipelines
    allPipelines=$(curl --silent -X GET "${datafusion_api_endpoint}/v3/namespaces/${namespaceName}/apps" \
        -H "Authorization: Bearer ${access_token}")

    pipelineNames=$(echo "${allPipelines}" | jq .[].name --raw-output)

    # Download each pipelines
    for pipelineName in $(echo "${pipelineNames}"); do
        echo "Downloading Pipeline: ${pipelineName}"
        curl --silent -X GET "${datafusion_api_endpoint}/v3/namespaces/${namespaceName}/apps/${pipelineName}" \
            -H "Authorization: Bearer ${access_token}" > ./system/namespace/${namespaceName}/pipelines/published/${pipelineName}.json
    done
done


echo ""
echo "*********************************************************"
echo "Compute Profiles"
echo "*********************************************************"
echo ""

allComputeProfiles=$(curl --silent -X GET "${datafusion_api_endpoint}/v3/profiles" \
    -H "Authorization: Bearer ${access_token}")

computeProfiles=$(echo "${allComputeProfiles}" | jq .[].name --raw-output)

# Download each compute profile
for computeProfile in $(echo "${computeProfiles}"); do
    echo "computeProfile: ${computeProfile}"
    curl --silent -X GET "${datafusion_api_endpoint}/v3/profiles/${computeProfile}" \
        -H "Authorization: Bearer ${access_token}" > ./system/compute-profile/${computeProfile}.json
done

# Remove the default internal profiles
rm -f ./system/compute-profile/autoscaling-dataproc.json
rm -f ./system/compute-profile/dataproc.json
rm -f ./system/compute-profile/native.json


echo ""
echo "*********************************************************"
echo "Done"
echo "*********************************************************"
echo ""

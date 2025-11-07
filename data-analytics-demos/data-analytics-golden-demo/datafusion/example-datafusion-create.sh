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


echo "---------------------------------------------------------------------------------------------------------" 
echo "Setting names and locations (These could be placed in the config)"
echo "---------------------------------------------------------------------------------------------------------" 
# You can set these, but you need to ensure the location exists for each service
region="REPLACE-REGION"
zone="REPLACE-REGION-a"
datafusion_name="sa-datafusion-$environment"
datafusion_location="REPLACE-REGION"

echo "region:$region"
echo "zone:$zone"
echo "datafusion_name:$datafusion_name"
echo "datafusion_location:$datafusion_location"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Login using service account"
echo "---------------------------------------------------------------------------------------------------------" 
# The username of the service account (e.g.  "smart-analytics-dev-ops@smart-analytics-demo-01.iam.gserviceaccount.com" )
accountName=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email --raw-output)

gcloud auth activate-service-account $accountName --key-file=$GOOGLE_APPLICATION_CREDENTIALS --project=$project


echo "---------------------------------------------------------------------------------------------------------" 
echo "Enabling Google Cloud APIs"
echo "---------------------------------------------------------------------------------------------------------" 
# gcloud services list
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable datafusion.googleapis.com


echo "---------------------------------------------------------------------------------------------------------" 
echo "Getting access token"
echo "---------------------------------------------------------------------------------------------------------" 
# We need a token for making REST API calls
# Uses: GOOGLE_APPLICATION_CREDENTIALS https://cloud.google.com/docs/authentication/getting-started#setting_the_environment_variable
access_token=$(gcloud auth application-default print-access-token)

# Get the project Number
projects=$(curl --silent "https://cloudresourcemanager.googleapis.com/v1/projects" \
            -H "Authorization: Bearer $access_token")

projectNumber=$(echo "$projects "| jq ".projects[] | select(.projectId == \"$project\") | .projectNumber" --raw-output)

echo "projectNumber:$projectNumber"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Data Fusion"
echo "---------------------------------------------------------------------------------------------------------" 
access_token=$(gcloud auth application-default print-access-token)
voidResult=$(curl --silent -X POST "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances?instanceId=$datafusion_name" \
    -H "Authorization: Bearer $access_token")
 


echo "---------------------------------------------------------------------------------------------------------" 
echo "Waiting for Cloud Composer and Data Fusion to be created"
echo "---------------------------------------------------------------------------------------------------------"
access_token=$(gcloud auth application-default print-access-token)

stateDataFusion=$(curl --silent "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
    -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

echo "stateDataFusion: $stateDataFusion"


while [ "$stateDataFusion" == "CREATING" ] ]
    do
    sleep 5
    stateDataFusion=$(curl --silent "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
        -H "Authorization: Bearer $access_token" | jq .state --raw-output) 
    echo "stateDataFusion: $stateDataFusion"

    done

echo "---------------------------------------------------------------------------------------------------------" 
echo "Permissions"
echo "---------------------------------------------------------------------------------------------------------" 
serviceAccount="$project@appspot.gserviceaccount.com"
echo "serviceAccount: $serviceAccount"

gcloud projects add-iam-policy-binding \
    $project \
    --member "serviceAccount:$serviceAccount" \
    --role "roles/iam.serviceAccountTokenCreator"


serviceAccountDataFusion=$(curl --silent "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
    -H "Authorization: Bearer $access_token" | jq .serviceAccount --raw-output) 
echo "serviceAccountDataFusion: $serviceAccountDataFusion"

# cloud-datafusion-management-sa@ae7a3d33eca365aa8p-tp.iam.gserviceaccount.com
# Requires: Cloud Data Fusion API Service Agent
gcloud projects add-iam-policy-binding \
    $project \
    --member "serviceAccount:$serviceAccountDataFusion" \
    --role "roles/dataproc.serviceAgent"


serviceAccountCloudComposer=$(curl --silent "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments/$composer_name" \
    -H "Authorization: Bearer $access_token" | jq .config.nodeConfig.serviceAccount --raw-output) 
echo "serviceAccountCloudComposer: $serviceAccountCloudComposer"

# 971334511334-compute@developer.gserviceaccount.com
# Reqiures: Cloud Data Fusion Runner to run Data Fusion Jobs
gcloud projects add-iam-policy-binding \
    $project \
    --member "serviceAccount:$serviceAccountCloudComposer" \
    --role "roles/datafusion.runner"

# This allows data fusion (via airflow) to create dataproc clusters
# The account is added to the compute default account (used by Airflow) and then that account
# can impersonate this account
accountForDataFusion="service-$projectNumber@gcp-sa-datafusion.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding \
    $serviceAccountCloudComposer \
    --member="serviceAccount:$accountForDataFusion" \
    --role="roles/iam.serviceAccountUser"
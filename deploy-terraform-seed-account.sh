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

####################################################################################
# README: This will create a GCP Project named "Terraform" and a service account named "sa-terraform".
#         The service account will be passed to the Docker Container as its credentials
#         KEEP the export JSON safe (or delete immediately)
#
#         NOTE: If you are an internal Google user you need to go to your environment management  
#               panel and click the down arrow and select "Request Billing Roles".  Paste in the 
#               name of your service account created below and select all the roles.
# 
# You need to run this script before using the below scripts:
# - deploy-use-docker.sh
# - deploy-use-existing-project-docker
# - deploy-use-existing-project.sh
#
# https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform
#####################################################################################################################

# As the admin user create the project
# Login to GCP by running BOTH below gcloud auth commands (you only need to do this once which is why they are commented out)
#      These command are not needed when running from a Cloud Shell
# gcloud auth login
# gcloud auth application-default login

# Set variables needed
random_number=$(echo $RANDOM)
project_id="terraform-${random_number}"
project_name="terraform"
gcp_account_name=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# Get the Org Id (needed for org policies and creating the GCP project)
org_id=$(gcloud organizations list --format="value(name)")
if [ -z "${org_id}" ]
then
  echo "Org Id could not be automatically read."
  echo "Open this link: https://console.cloud.google.com/cloud-resource-manager/ and copy your org id."
  echo "Your org id will be in the format of xxxxxxxxxxxx"
  read -p "Please enter your org id:" org_id
else
  org_id_length=$(echo -n "${org_id}" | wc -m)
  org_id_length_int=$(expr ${org_id_length} + 0)
  if [ ${org_id_length_int} != 12 ]
  then
    echo "You have more than one org id, please manually enter the correct one."
    echo "Your org id will be in the format of xxxxxxxxxxxx"
    read -p "Please enter your org id:" billing_account
  else
    echo "Org Id was automatically retreived."
  fi
fi

# Get the Billing Account (needed for creating the GCP project)
billing_account=$(gcloud beta billing accounts list --format="value(ACCOUNT_ID)")
if [ -z "${billing_account}" ]
then
  echo "Billing Account could not be automatically read."
  echo "Open this link: https://console.cloud.google.com/billing/ and copy your billing account."
  echo "Your billing account will be in the format of xxxxxx-xxxxxx-xxxxxx"
  read -p "Please enter your billing account:" billing_account
else
  billing_account_length=$(echo -n "${billing_account}" | wc -m)
  billing_account_length_int=$(expr ${billing_account_length} + 0)
  if [ ${billing_account_length_int} != 20 ]
  then
    echo "You have more than one billing account, please manually enter the correct one."
    echo "Your billing account will be in the format of xxxxxx-xxxxxx-xxxxxx"
    read -p "Please enter your billing account:" billing_account
  else
    echo "Billing Account was automatically retreived."
  fi
fi


echo "project_id:       ${project_id}"
echo "gcp_account_name: ${gcp_account_name}"
echo "org_id:           ${org_id}"
echo "billing_account:  ${billing_account}"

# Create a new GCP project 
gcloud projects create ${project_id} --name="Terraform" --organization=${org_id}
gcloud beta billing projects link "${project_id}" --billing-account="${billing_account}"

project_number=$(gcloud projects describe ${project_id} --format=json | jq .projectNumber --raw-output)
echo "project_number:   ${project_number}"

# New service account that will be doing the deployment
service_account="sa-${project_name}"
service_account_email="${service_account}@${project_id}.iam.gserviceaccount.com"
gcloud iam service-accounts create ${service_account} --project="${project_id}" --description="Terraform DevOps Automation" --display-name="Terraform Service Account"
echo "service_account:  ${service_account_email}"

# Needs Owner, Org Policy Admin and Org Admin permissions
gcloud projects      add-iam-policy-binding ${project_id}  --member="serviceAccount:${service_account_email}" --role="roles/owner"
gcloud organizations add-iam-policy-binding ${org_id}      --member="serviceAccount:${service_account_email}" --role="roles/orgpolicy.policyAdmin"
gcloud organizations add-iam-policy-binding ${org_id}      --member="serviceAccount:${service_account_email}" --role="roles/resourcemanager.organizationAdmin"
gcloud organizations add-iam-policy-binding ${org_id}      --member="serviceAccount:${service_account_email}" --role="roles/billing.admin"
gcloud organizations add-iam-policy-binding ${org_id}      --member="serviceAccount:${service_account_email}" --role="roles/resourcemanager.projectCreator"

# NOTE: If you are using Google Internal Environment you need to submit the form to add this use to your billing account

# Turn off the Org Policy that prevent exporting of service account key files (JSON)
gcloud resource-manager org-policies disable-enforce "iam.disableServiceAccountKeyCreation" --project=${project_id}
echo "Sleeping for 120 seconds.  Waiting for Org Policies to replicate on the cloud."
sleep 120   # wait for the policy to take effect

# Export the keyfile
rootPath=$(echo "$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")")
keyFile="${rootPath}key-file-${project_name}.json"
gcloud iam service-accounts keys create "${keyFile}" --iam-account="${service_account_email}"

# Enable various cloud services
gcloud services enable cloudbilling.googleapis.com --project=${project_id}
gcloud services enable cloudresourcemanager.googleapis.com --project=${project_id}
gcloud services enable cloudbilling.googleapis.com --project=${project_id}
gcloud services enable iam.googleapis.com --project=${project_id}
gcloud services enable compute.googleapis.com --project=${project_id}
gcloud services enable serviceusage.googleapis.com --project=${project_id}

# These are needed since their APIs are called (even though we call to a different project)
# This using Curl and cannot impersonate
gcloud services enable bigquerydatatransfer.googleapis.com --project=${project_id}
# This could use impersonation if the gcloud command logged in and impersonated
# The gcloud login above the line "gcloud composer environments run" in tf-main.tf
gcloud services disable container.googleapis.com --project=Terraform
# gcloud services enable spanner.googleapis.com --project=${project_id} 

# Read the key-file contents so we can disable
deployment_service_account_name=$(cat $keyFile | jq .client_email --raw-output)
echo "deployment_service_account_name: ${deployment_service_account_name}"

service_account_key_id=$(cat $keyFile | jq .private_key_id --raw-output)
echo "service_account_key_id: ${service_account_key_id}"

service_account_project_id=$(cat $keyFile | jq .project_id --raw-output)
echo "service_account_project_id: ${service_account_project_id}"

# Disable the key
echo "Disabling your service account key (until you need to use it)..."
gcloud iam service-accounts keys disable ${service_account_key_id} --project="${service_account_project_id}" --iam-account=${deployment_service_account_name}
echo "You can always disable your key by running this command. If a script fails it might not reach the code to disable your key"
echo "gcloud iam service-accounts keys disable ${service_account_key_id} --project=\"${service_account_project_id}\" --iam-account=${deployment_service_account_name}"

echo ""
echo "Your account key file is: key-file-${project_name}.json"
echo ""
echo "NOTE! Keep this file safe or delete it when not in use (it has been disabled until you use it).  It has been added to the .gitignore so it does not get checked into Git."
echo ""
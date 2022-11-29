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
# README: This script will use the standard docker container for deployment.
#         This will run the "terraform" folder entrypoint (uses the seed Terraform service account)
#         This will emulates deploying into an existing project (it creates the project for you or you can hardcode)
# NOTE:   You need to have run "source deploy-terraform-seed-account.sh" to generate the Terraform Service Account
# TO RUN: "source deploy-use-existing-project-docker.sh"
####################################################################################


# As the admin user create the project
# Login to GCP by running BOTH below gcloud auth commands (you only need to do this once which is why they are commented out)
#      These command are not needed when running from a Cloud Shell
# gcloud auth login
# gcloud auth application-default login

# Set variables needed
random_number=$(echo $RANDOM)
project_id="data-analytics-demo-${random_number}"

# Get the account name who logged in above 
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


echo "*********************************************************"
read -p "Press [Enter] key if all the above items are set (gcp_account_name, org_id, billing_account). If not press Ctrl+C ..."
echo "*********************************************************"

# Create a new GCP project 
gcloud projects create ${project_id} --organization=${org_id}
gcloud beta billing projects link "${project_id}" --billing-account="${billing_account}"

project_number=$(gcloud projects describe ${project_id} --format=json | jq .projectNumber --raw-output)
echo "project_number:   ${project_number}"


####################################################################################
# Use the Terraform service account
####################################################################################
rootPath=$(echo "$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")")
keyFile="${rootPath}key-file-terraform.json"
echo "keyFile: ${keyFile}"

# Pass in the service account since we need to know we are not running this as the current user
# The TF scripts will run as this account, but we still need to grant the current user access
deployment_service_account_name=$(cat $keyFile | jq .client_email --raw-output)
echo "deployment_service_account_name: ${deployment_service_account_name}"

service_account_key_id=$(cat $keyFile | jq .private_key_id --raw-output)
echo "service_account_key_id: ${service_account_key_id}"

service_account_project_id=$(cat $keyFile | jq .project_id --raw-output)
echo "service_account_project_id: ${service_account_project_id}"

# enable the key
echo "Enabling your service account key for use..."
gcloud iam service-accounts keys enable ${service_account_key_id} --project="${service_account_project_id}" --iam-account=${deployment_service_account_name}

# Make the TF account an owner of the new project (not done in TF script since it assumes an Admin does this)
gcloud projects  add-iam-policy-binding ${project_id}  --member="serviceAccount:${deployment_service_account_name}" --role="roles/owner"

echo "*********************************************************"
read -p "Press [Enter] key if the service account is correct. If not press Ctrl+C ..."
echo "*********************************************************"


####################################################################################
# Deploy Terraform
####################################################################################

# Initialize Terraform
docker run -it --entrypoint terraform -v $PWD:$PWD -w $PWD/terraform terraform-deploy-image init

# Validate
docker run -it --entrypoint terraform -v $PWD:$PWD -w $PWD/terraform terraform-deploy-image validate 

echo "docker run -it --entrypoint terraform --volume $PWD:$PWD --workdir $PWD/terraform --env GOOGLE_APPLICATION_CREDENTIALS=\"${keyFile}\" terraform-deploy-image apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"project_id=${project_id}\" -var=\"project_number=${project_number}\" -var=\"org_id=${org_id}\" -var=\"deployment_service_account_name=${deployment_service_account_name}\""

# Run the Terraform Apply
docker run -it \
  --entrypoint terraform \
  --volume $PWD:$PWD \
  --workdir $PWD/terraform \
  --env GOOGLE_APPLICATION_CREDENTIALS="${keyFile}" \
  terraform-deploy-image apply \
  -var="gcp_account_name=${gcp_account_name}" \
  -var="project_id=${project_id}" \
  -var="project_number=${project_number}" \
  -var="org_id=${org_id}" \
  -var="deployment_service_account_name=${deployment_service_account_name}"

echo "docker run -it --entrypoint terraform --volume $PWD:$PWD --workdir $PWD/terraform --env GOOGLE_APPLICATION_CREDENTIALS=\"${keyFile}\" terraform-deploy-image apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"project_id=${project_id}\" -var=\"project_number=${project_number}\" -var=\"org_id=${org_id}\" -var=\"deployment_service_account_name=${deployment_service_account_name}\""


# Disable the key
echo "Disabling your service account key (until you need to use it)..."
gcloud iam service-accounts keys disable ${service_account_key_id} --project="${service_account_project_id}" --iam-account=${deployment_service_account_name}


echo "*********************************************************"
echo "Done"
echo "*********************************************************"

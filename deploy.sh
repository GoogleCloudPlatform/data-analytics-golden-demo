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
# README: This script will use "bash" to deploy the code
#         This will run the "terraform-local" folder entrypoint (uses service account impersonation)
#         This will create a new GCP project in Terraform
# TO RUN: "source deploy.sh"
####################################################################################
# 
#
# This script will then run the terraform-local script
# This script will deploy DAGs, dag data, pyspark and trigger the run-all-dag
# This script needs an admin login so that the project and a service account can be created in the terraform script
#
# NOTE: If you do not want to install this software, then run build and run the Dockerfile in this directory
# You would run "source deploy-use-docker.sh" "(after you have built the docker image, see the Dockerfile for instructions)

# Required software (cloud shell has this installed):
#   - gcloud
#   - gcloud beta (sudo gcloud components install beta)
#   - terraform
#   - .jq (command line JSON parser)
#   - kubectrl (sudo gcloud components install kubectl) to Trigger the Airflow 2 DAG (This is not installed on Cloud Shell by default)
#   - curl
#
# Author: Adam Paternostro
# Terraform for Google: https://registry.terraform.io/providers/hashicorp/google/latest/docs
####################################################################################

# Login to GCP by running BOTH below gcloud auth commands (you only need to do this once which is why they are commented out)
#      These command are not needed when running from a Cloud Shell
# gcloud auth login
# gcloud auth application-default login

# Get the account name who logged in above 
gcp_account_name=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")


# Get the Org Id (needed for org policies and creating the GCP project)
org_id=$(gcloud organizations list --format="value(name)")


# Get the Billing Account (needed for creating the GCP project)
billing_account=$(gcloud beta billing accounts list --format="value(ACCOUNT_ID)")
if [ -z "${billing_account}" ]
then
  echo "Billing Account could not be automatically read."
  echo "Open this link: https://console.cloud.google.com/billing/ and copy your billing account."
  echo "Your billing account will be in the format of xxxxxx-xxxxxx-xxxxxx"
  read -p "Please enter your billing account:" billing_account
else
  echo "Billing Account was automatically retreived."
fi  


echo "gcp_account_name: ${gcp_account_name}"
echo "billing_account:  ${billing_account}"
echo "org_id:           ${org_id}"


echo "*********************************************************"
read -p "Press [Enter] key if all the above items are set (gcp_account_name, org_id, billing_account). If not press Ctrl+C ..."
echo "*********************************************************"


####################################################################################
# Deploy Terraform
####################################################################################
cd "./terraform-local"

# Initialize Terraform
terraform init

# Validate
terraform validate

echo "terraform apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"org_id=${org_id}\" -var=\"billing_account=${billing_account}\" -var=\"project_id=bigquery-demo\""

# Run the Terraform Apply
terraform apply \
  -var="gcp_account_name=${gcp_account_name}" \
  -var="org_id=${org_id}" \
  -var="billing_account=${billing_account}" \
  -var="project_id=bigquery-demo"
 
# Write out the output variables (currently not used)
terraform output -json > tf-output.json

cd ..

echo "terraform apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"org_id=${org_id}\" -var=\"billing_account=${billing_account}\" -var=\"project_id=bigquery-demo\""

echo "*********************************************************"
echo "Done"
echo "*********************************************************"
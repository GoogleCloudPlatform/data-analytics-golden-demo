#!/bin/bash

####################################################################################
# Copyright 2024 Google LLC
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
#         This will run the "terraform" folder entrypoint (uses service account impersonation)
#         This will create a new GCP project in Terraform
# TO RUN: "source deploy.sh"
####################################################################################
#
# Required software (cloud shell has this installed):
#   - gcloud
#   - gcloud beta (sudo gcloud components install beta)
#   - terraform
#   - .jq (command line JSON parser)
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
if [ -z "${org_id}" ]
then
  echo "Org Id could not be automatically read."
  echo "Open this link: https://console.cloud.google.com/cloud-resource-manager/ and copy your org id."
  echo "Your org id will be in the format of xxxxxxxxxxxx"
  read -p "Please enter your org id:" org_id
else
  org_id_length=$(echo -n "${org_id}" | wc -m)
  org_id_length_int=$(expr ${org_id_length} + 0)
  if [ ${org_id_length_int} -gt 13 ]
  then
    echo "You have more than one org id, please manually enter the correct one."
    echo "Your org id will be in the format of xxxxxxxxxxxx"
    read -p "Please enter your org id:" org_id
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

echo "gcp_account_name: ${gcp_account_name}"
echo "billing_account:  ${billing_account}"
echo "org_id:           ${org_id}"

echo "*********************************************************"
read -p "Press [Enter] key if all the above items are set (gcp_account_name, org_id, billing_account). If not press Ctrl+C ..."
echo "*********************************************************"


####################################################################################
# Deploy Terraform
####################################################################################
currentDir=$(pwd -P)
export TF_LOG=INFO
export TF_LOG_PATH="${currentDir}/tf.log"

cd "./terraform"

# Initialize Terraform
terraform init

# Validate
terraform validate

start=$(date)

echo "terraform apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"org_id=${org_id}\" -var=\"billing_account=${billing_account}\" -var=\"project_id=governed-data\""

# Run the Terraform Apply
terraform apply -auto-approve \
  -var="gcp_account_name=${gcp_account_name}" \
  -var="org_id=${org_id}" \
  -var="billing_account=${billing_account}" \
  -var="project_id=governed-data"

terraform_exit_code=$?
echo "Terraform exit code: ${terraform_exit_code}"

echo "Terraform Times"
stop=$(date)
echo "Start time: ${start}"
echo "Stop  time: ${stop}"
echo ""

if [ $terraform_exit_code -eq 0 ]
then
  
  # Write out the output variables 
  terraform output -json > tf-output.json

  # Get the name of the bucket the user specified to upload the output file
  terraform_output_bucket=$(terraform output -raw terraform-output-bucket)
  echo "terraform_output_bucket: ${terraform_output_bucket}"

  # Copy TF Output - Check to see if the user did not specify an output bucket
  if [[ $terraform_output_bucket == *"Error"* ]]; 
  then
    echo "No terraform_output_bucket specified.  Not copying tf-output.json"
  else
    echo "Copying tf-output.json: gsutil cp tf-output.json gs://${terraform_output_bucket}/terraform/output/"
    gsutil cp tf-output.json "gs://${terraform_output_bucket}/terraform/output/"
  fi

  # Copy TF State file - Check to see if the user did not specify an output bucket
  if [[ $terraform_output_bucket == *"Error"* ]]; 
  then
    echo "No terraform_output_bucket specified.  Not copying Terraform State file"
  else
    echo "Copying terraform.tfstate: gsutil cp terraform.tfstate gs://${terraform_output_bucket}/terraform/state/"
    gsutil cp terraform.tfstate "gs://${terraform_output_bucket}/terraform/state/"
  fi

  # # Copy the EMPTY org policies over the existing one
  # # Run Terraform apply again to then revert the org policies back to "inherit from parent"
  # if [ -f "../terraform-modules/org-policies/tf-org-policies-original.txt" ]; then
  #   echo "The Org Policies file has already been replaced"
  # else
  #   echo "Replacing the Org Policies file and revoking the policy exceptions used during the deployment"
  #   mv ../terraform-modules/org-policies/tf-org-policies.tf ../terraform-modules/org-policies/tf-org-policies-original.txt
  #   cp ../terraform-modules/org-policies-destroy/tf-org-policies.tf ../terraform-modules/org-policies/tf-org-policies.tf

  #   echo "Start Terraform (Org Policies Revoke)"
  #   echo $(date)
  #   echo ""

  #   start=$(date)

  #   # Run the Terraform Apply (to destroy the org policies)
  #   terraform apply -auto-approve \
  #     -var="gcp_account_name=${gcp_account_name}" \
  #     -var="org_id=${org_id}" \
  #     -var="billing_account=${billing_account}" \
  #     -var="project_id=governed-data"

  #   # Move the files back so Git does not check in the wrong file
  #   # Also, if we do another deployment we want to disable the policies so we do not interfere with the deployment
  #   # and then re-enable them.
  #   rm ../terraform-modules/org-policies/tf-org-policies.tf
  #   mv ../terraform-modules/org-policies/tf-org-policies-original.txt ../terraform-modules/org-policies/tf-org-policies.tf

  #   echo "Terraform Times"
  #   stop=$(date)
  #   echo "Start time: ${start}"
  #   echo "Stop  time: ${stop}"
  #   echo ""

  # fi  
fi

cd ..

echo "terraform apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"org_id=${org_id}\" -var=\"billing_account=${billing_account}\" -var=\"project_id=governed-data\""

echo "*********************************************************"
echo "Done"
echo "*********************************************************"
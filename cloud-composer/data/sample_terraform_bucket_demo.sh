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


# Author:  Adam Paternostro
# Summary: This will deploy dataplex via Terraform. 
#          The parameters are piped in via Airflow.
#          This script will also be used for destroying resources.
#          To copy this, you just need to change the Terraform Apply code (and the echo)
# YouTube: https://youtu.be/2Qu29_hR2Z0


####################################################################################
# Skip script if not required to run via the DAG
####################################################################################
echo "ENV_RUN_BASH: $ENV_RUN_BASH"
if [[ "$ENV_RUN_BASH" == "true" ]]; 
then
  echo "Executing Terraform Bash Script"
else
  echo "Skipping Terraform Bash Script"
  exit 0
fi

####################################################################################
# Install Terraform (do not change)
####################################################################################
# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
echo "BEGIN: Terraform Install"

STR=$(which terraform)
SUB='terraform'
echo "STR=${STR}"
if [[ "$STR" == *"$SUB"* ]]; then
  echo "Terraform is installed, skipping..."
else
  sudo apt-get update -y && sudo apt-get install -y gnupg software-properties-common

  wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

  gpg --no-default-keyring \
  --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
  --fingerprint

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

  sudo apt update -y

  sudo apt-get install terraform -y
fi

echo "END: Terraform Install"


####################################################################################
# Deploy Terraform (change to the folder with the TF script and run it)
####################################################################################
cd {{ params.airflow_data_path_to_tf_script }}
export TF_LOG=INFO
export TF_LOG_PATH="{{ params.airflow_data_path_to_tf_script }}/tf.log"

# Initialize Terraform
echo "terraform init"
terraform init

# Validate
terraform validate
echo "terraform validate"

# Display for debugging (copy the below terraform apply comamnd here so you can see the output)
echo '
terraform apply {{ params.terraform_destroy }}  -auto-approve \
  -var="project_id={{ params.project_id }}" \
  -var="impersonate_service_account={{ params.impersonate_service_account }}" \
  -var="bucket_name={{ params.bucket_name }}" \
  -var="bucket_region={{ params.bucket_region }}"
'  

# Run the Terraform Apply
terraform apply {{ params.terraform_destroy }}  -auto-approve \
  -var="project_id={{ params.project_id }}" \
  -var="impersonate_service_account={{ params.impersonate_service_account }}" \
  -var="bucket_name={{ params.bucket_name }}" \
  -var="bucket_region={{ params.bucket_region }}"

# Print exit code
terraform_exit_code=$?
echo "Terraform exit code: ${terraform_exit_code}"

echo "*********************************************************"
echo "Done"
echo "*********************************************************"

exit ${terraform_exit_code}
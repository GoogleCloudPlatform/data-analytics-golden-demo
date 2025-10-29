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
# Summary: This will deploy dataplex (with an Dataproc Hive Metastore Service) via Terraform. 
#          The parameters are piped in via Airflow.
#          This script will also be used for destroying resources.
#          To copy this, you just need to change the Terraform Apply code (and the echo)


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
# Install Terraform (Robust Method for Automated Environments)
####################################################################################
echo "BEGIN: Terraform Install"

# Check if terraform is already in the PATH
if command -v terraform &> /dev/null; then
    echo "Terraform is already installed at $(which terraform)"
else
    echo "Terraform not found, proceeding with installation."
    
    # Install dependencies needed for this installation method
    sudo apt-get update -y && sudo apt-get install -y wget unzip

    # Define the Terraform version and architecture
    TERRAFORM_VERSION="1.13.4" # You can update this version as needed
    CPU_ARCH=$(dpkg --print-architecture)

    # Download the specified Terraform binary
    echo "Downloading Terraform v${TERRAFORM_VERSION} for ${CPU_ARCH}..."
    wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${CPU_ARCH}.zip"

    # Unzip and install the binary
    unzip "terraform_${TERRAFORM_VERSION}_linux_${CPU_ARCH}.zip"
    sudo mv terraform /usr/local/bin/

    # Clean up the downloaded zip file
    rm "terraform_${TERRAFORM_VERSION}_linux_${CPU_ARCH}.zip"

    # Verify the installation
    if command -v terraform &> /dev/null; then
        echo "Terraform installed successfully!"
        terraform --version
    else
        echo "Terraform installation failed!"
        exit 1
    fi
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
  -var="dataplex_region={{ params.dataplex_region }}" \
  -var="raw_bucket_name={{ params.raw_bucket_name }}" \
  -var="processed_bucket_name={{ params.processed_bucket_name }}" \
  -var="taxi_dataset_id={{ params.taxi_dataset_id }}" \
  -var="thelook_dataset_id={{ params.thelook_dataset_id }}" \
  -var="random_extension={{ params.random_extension }}" \
  -var="rideshare_raw_bucket={{ params.rideshare_raw_bucket }}" \
  -var="rideshare_enriched_bucket={{ params.rideshare_enriched_bucket }}" \
  -var="rideshare_curated_bucket={{ params.rideshare_curated_bucket }}" \
  -var="rideshare_raw_dataset={{ params.rideshare_raw_dataset }}" \
  -var="rideshare_enriched_dataset={{ params.rideshare_enriched_dataset }}" \
  -var="rideshare_curated_dataset={{ params.rideshare_curated_dataset }}" \
  -var="rideshare_llm_raw_dataset={{ params.rideshare_llm_raw_dataset }}" \
  -var="rideshare_llm_enriched_dataset={{ params.rideshare_llm_enriched_dataset }}" \
  -var="rideshare_llm_curated_dataset={{ params.rideshare_llm_curated_dataset }}"
'  

# Run the Terraform Apply
terraform apply {{ params.terraform_destroy }}  -auto-approve \
  -var="project_id={{ params.project_id }}" \
  -var="impersonate_service_account={{ params.impersonate_service_account }}" \
  -var="dataplex_region={{ params.dataplex_region }}" \
  -var="raw_bucket_name={{ params.raw_bucket_name }}" \
  -var="processed_bucket_name={{ params.processed_bucket_name }}" \
  -var="taxi_dataset_id={{ params.taxi_dataset_id }}" \
  -var="thelook_dataset_id={{ params.thelook_dataset_id }}" \
  -var="random_extension={{ params.random_extension }}" \
  -var="rideshare_raw_bucket={{ params.rideshare_raw_bucket }}" \
  -var="rideshare_enriched_bucket={{ params.rideshare_enriched_bucket }}" \
  -var="rideshare_curated_bucket={{ params.rideshare_curated_bucket }}" \
  -var="rideshare_raw_dataset={{ params.rideshare_raw_dataset }}" \
  -var="rideshare_enriched_dataset={{ params.rideshare_enriched_dataset }}" \
  -var="rideshare_curated_dataset={{ params.rideshare_curated_dataset }}" \
  -var="rideshare_llm_raw_dataset={{ params.rideshare_llm_raw_dataset }}" \
  -var="rideshare_llm_enriched_dataset={{ params.rideshare_llm_enriched_dataset }}" \
  -var="rideshare_llm_curated_dataset={{ params.rideshare_llm_curated_dataset }}"



# Print exit code
terraform_exit_code=$?
echo "Terraform exit code: ${terraform_exit_code}"

echo "*********************************************************"
echo "Done"
echo "*********************************************************"

exit ${terraform_exit_code}
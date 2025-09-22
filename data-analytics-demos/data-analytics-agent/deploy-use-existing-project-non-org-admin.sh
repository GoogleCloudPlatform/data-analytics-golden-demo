#!/bin/bash

####################################################################################
# Copyright 2025 Google LLC
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
# TO RUN: "source deploy-use-existing-project-non-org-admin"
####################################################################################

# Steps:
# 0 - Login (not necessary if using cloud shell)
# gcloud auth login
# gcloud auth application-default login

# 1 - Create a new project

# 2 - Grant your user Owner IAM access to the new project

# 3 - Run the below script and replace the following variables
gcp_account_name="your-name@your-domain.com"
project_id="my-project"
project_number="000000000000"


####################################################################################
# Deploy Terraform
####################################################################################
cd terraform 

# Initialize Terraform
terraform init

# Validate
terraform validate

# NOTE: The "Org Id = 0" is a signal to the terraform script that you are not an Org Admin
terraform apply \
  -var="gcp_account_name=${gcp_account_name}" \
  -var="project_id=${project_id}" \
  -var="project_number=${project_number}" \
  -var="org_id=0"


terraform_exit_code=$?
echo "Terraform exit code: ${terraform_exit_code}"

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

fi

cd ..

echo "*********************************************************"
echo "Done"
echo "*********************************************************"

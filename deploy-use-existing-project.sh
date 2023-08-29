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
#         This will run the "terraform" folder entrypoint (uses the seed Terraform service account)
#         This will emulates deploying into an existing project (it creates the project for you or you can hardcode)
# NOTE:   You need to have run "source deploy-terraform-seed-account.sh" to generate the Terraform Service Account
# TO RUN: "source deploy-use-existing-project.sh"
####################################################################################


# As the admin user create the project
# Login to GCP by running BOTH below gcloud auth commands (you only need to do this once which is why they are commented out)
#      These command are not needed when running from a Cloud Shell
# gcloud auth login
# gcloud auth application-default login

project_id=$(gcloud config get project)

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

# Activate the TF service account as the current user
gcloud auth activate-service-account "${deployment_service_account_name}" --key-file="${keyFile}" --project="${project_id}"
gcloud config set account "${deployment_service_account_name}"

echo "*********************************************************"
read -p "Press [Enter] key if the service account is correct. If not press Ctrl+C ..."
echo "*********************************************************"


####################################################################################
# Deploy Terraform
####################################################################################
cd terraform 

# Initialize Terraform
terraform init

# Validate
terraform validate

echo "terraform apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"project_id=${project_id}\" -var=\"project_number=${project_number}\"  -var=\"deployment_service_account_name=${service_account_email}\" -var=\"org_id=${org_id}\""

terraform apply \
  -var="gcp_account_name=${gcp_account_name}" \
  -var="project_id=${project_id}" \
  -var="project_number=${project_number}" \
  -var="deployment_service_account_name=${service_account_email}" \
  -var="org_id=${org_id}"

# For EU deployment: see deploy-europe-region.sh
#      -var="composer_region=europe-west1" \
#      -var="dataform_region=europe-west1" \
#      -var="dataplex_region=europe-west1" \
#      -var="dataproc_region=europe-west1" \
#      -var="dataflow_region=europe-west1" \
#      -var="bigquery_region=eu" \
#      -var="bigquery_non_multi_region=europe-west1" \
#      -var="spanner_region=europe-west1" \
#      -var="spanner_config=eur3"\
#      -var="datafusion_region=europe-west1" \
#      -var="vertex_ai_region=europe-west1" \
#      -var="cloud_function_region=europe-west1" \
#      -var="data_catalog_region=europe-west1" \
#      -var="appengine_region=europe-west" \
#      -var="dataproc_serverless_region=europe-west1" \
#      -var="cloud_sql_region=europe-west1" \
#      -var="cloud_sql_zone=europe-west1-b" \
#      -var="datastream_region=europe-west1" \
#      -var="colab_enterprise_region=us-central1" \
#      -var="default_region=europe-west1" \
#      -var="default_zone=europe-west1-b"

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

  # Copy the EMPTY org policies over the existing one
  # Run Terraform apply again to then revert the org policies back to "inherit from parent"
  if [ -f "../terraform-modules/org-policies/tf-org-policies-original.txt" ]; then
    echo "The Org Policies file has already been replaced"
  else
    echo "Replacing the Org Policies file and revoking the policy exceptions used during the deployment"
    mv ../terraform-modules/org-policies/tf-org-policies.tf ../terraform-modules/org-policies/tf-org-policies-original.txt
    cp ../terraform-modules/org-policies-destroy/tf-org-policies.tf ../terraform-modules/org-policies/tf-org-policies.tf

    # Run the Terraform Apply (to destroy the org policies)
    terraform apply \
      -var="gcp_account_name=${gcp_account_name}" \
      -var="project_id=${project_id}" \
      -var="project_number=${project_number}" \
      -var="deployment_service_account_name=${service_account_email}" \
      -var="org_id=${org_id}"

    # For EU deployment: see deploy-europe-region.sh
    #      -var="composer_region=europe-west1" \
    #      -var="dataform_region=europe-west1" \
    #      -var="dataplex_region=europe-west1" \
    #      -var="dataproc_region=europe-west1" \
    #      -var="dataflow_region=europe-west1" \
    #      -var="bigquery_region=eu" \
    #      -var="bigquery_non_multi_region=europe-west1" \
    #      -var="spanner_region=europe-west1" \
    #      -var="spanner_config=eur3"\
    #      -var="datafusion_region=europe-west1" \
    #      -var="vertex_ai_region=europe-west1" \
    #      -var="cloud_function_region=europe-west1" \
    #      -var="data_catalog_region=europe-west1" \
    #      -var="appengine_region=europe-west" \
    #      -var="dataproc_serverless_region=europe-west1" \
    #      -var="cloud_sql_region=europe-west1" \
    #      -var="cloud_sql_zone=europe-west1-b" \
    #      -var="datastream_region=europe-west1" \
    #      -var="colab_enterprise_region=us-central1" \
    #      -var="default_region=europe-west1" \
    #      -var="default_zone=europe-west1-b"

    # NOTE: To deploy for BQ OMNI you need to also include there arguments to the terraform apply
    #  -var="shared_demo_project_id=mySharedProject" \
    #  -var="aws_omni_biglake_s3_bucket=myS3Bucket" \
    #  -var="azure_omni_biglake_adls_name=myAzureADLSGen2StorageAccount"  

    # Move the files back so Git does not check in the wrong file
    # Also, if we do another deployment we want to disable the policies so we do not interfere with the deployment
    # and then re-enable them.
    rm ../terraform-modules/org-policies/tf-org-policies.tf
    mv ../terraform-modules/org-policies/tf-org-policies-original.txt ../terraform-modules/org-policies/tf-org-policies.tf
  fi  
fi

cd ..

# Set the current user as the GCP logged in user (not the service account)
gcloud config set account "${gcp_account_name}"

echo "terraform apply -var=\"gcp_account_name=${gcp_account_name}\" -var=\"project_id=${project_id}\" -var=\"project_number=${project_number}\"  -var=\"deployment_service_account_name=${service_account_email}\" -var=\"org_id=${org_id}\""

# Disable the key
echo "Disabling your service account key (until you need to use it)..."
gcloud iam service-accounts keys disable ${service_account_key_id} --project="${service_account_project_id}" --iam-account=${deployment_service_account_name}


echo "*********************************************************"
echo "Done"
echo "*********************************************************"

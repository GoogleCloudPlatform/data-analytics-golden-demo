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
# Enables the APIs used by the resources
# Using the Batch Enable (up to 20 at time is the Most Efficient way to do this)
# See: https://cloud.google.com/service-usage/docs/reference/rest/v1/services/batchEnable
# This also helps avoid the "API not activated issue"
#
# Author: Adam Paternostro
####################################################################################

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.15.0"
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "project_number" {}
variable "deployment_service_account_name" {}


####################################################################################
# API Services
####################################################################################
# Do first 20 services (20 is the limit)
resource "null_resource" "batch_enable_service_apis_01" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command     = <<EOF
if [ -z "$${GOOGLE_APPLICATION_CREDENTIALS}" ]
then
    echo "We are not running in a local docker container.  No need to login."
else
    echo "We are running in local docker container. Logging in."
    gcloud auth activate-service-account "${var.deployment_service_account_name}" --key-file="$${GOOGLE_APPLICATION_CREDENTIALS}" --project="${var.project_id}"
    gcloud config set account "${var.deployment_service_account_name}"
fi 
json='{ "serviceIds": [ "serviceusage.googleapis.com","cloudresourcemanager.googleapis.com","servicemanagement.googleapis.com","orgpolicy.googleapis.com","compute.googleapis.com","bigquerystorage.googleapis.com","bigquerydatatransfer.googleapis.com","bigqueryreservation.googleapis.com","bigqueryconnection.googleapis.com","composer.googleapis.com","dataproc.googleapis.com","datacatalog.googleapis.com","aiplatform.googleapis.com","notebooks.googleapis.com","spanner.googleapis.com","dataflow.googleapis.com","analyticshub.googleapis.com","cloudkms.googleapis.com","metastore.googleapis.com","dataplex.googleapis.com" ] }'

response=$(curl -X POST "https://serviceusage.googleapis.com/v1/projects/${var.project_number}/services:batchEnable" \
    --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
    --header "Content-Type: application/json" \
    --data "$${json}" \
    --compressed)
echo "Response: $${response}"

# EXAMPLE: successTest: operations/acat.p2-494222074122-7ec9a3dd-b9fc-4748-8d43-99366bf9bfaf
successTest=$(echo $${response} | jq .name --raw-output)
echo "successTest: $${successTest}"

if [[ $${successTest} == operations* ]] 
then
    echo "Successfully activated services"
    exit 0
else
    echo "FAILED to activated services"
    exit 1
fi      
EOF
  }  
}

# Do second 20 services
resource "null_resource" "batch_enable_service_apis_02" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command     = <<EOF
if [ -z "$${GOOGLE_APPLICATION_CREDENTIALS}" ]
then
    echo "We are not running in a local docker container.  No need to login."
else
    echo "We are running in local docker container. Logging in."
    gcloud auth activate-service-account "${var.deployment_service_account_name}" --key-file="$${GOOGLE_APPLICATION_CREDENTIALS}" --project="${var.project_id}"
    gcloud config set account "${var.deployment_service_account_name}"
fi 
json='{ "serviceIds": [ "bigquerydatapolicy.googleapis.com" ] }'

response=$(curl -X POST "https://serviceusage.googleapis.com/v1/projects/${var.project_number}/services:batchEnable" \
    --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
    --header "Content-Type: application/json" \
    --data "$${json}" \
    --compressed)
echo "Response: $${response}"

# EXAMPLE: successTest: operations/acat.p2-494222074122-7ec9a3dd-b9fc-4748-8d43-99366bf9bfaf
successTest=$(echo $${response} | jq .name --raw-output)
echo "successTest: $${successTest}"

if [[ $${successTest} == operations* ]] 
then
    echo "Successfully activated services"
    exit 0
else
    echo "FAILED to activated services"
    exit 1
fi        
EOF
  }

  depends_on = [null_resource.batch_enable_service_apis_01]  
}

# This time delay was placed in the Main TF script
#resource "time_sleep" "batch_enable_service_apis_time_delay" {
#  depends_on      = [null_resource.batch_enable_service_apis_01,
#                     null_resource.batch_enable_service_apis_02]
#  create_duration = "60s"
#}

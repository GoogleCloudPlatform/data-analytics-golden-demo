####################################################################################
# Copyright 2023 Google LLC
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
      version = ">= 4.52, < 6"
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "project_number" {}


####################################################################################
# API Services - Using Curl to manaully enable APIs in 20 sizes batches
####################################################################################

# NOTE: This is fast, takes about 1-2 seconds per curl call.  But this is not Terraform native; therefore, see the next section (takes ~1 minute).

/*******************************************************************************************
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
*******************************************************************************************/


####################################################################################
# API Services (let Google provide do batching for you)
####################################################################################

# NOTE: These services will be enabled via Batches since batching is turned on by default for the Google provider
#       Batching will also help the cache hit/eviction which means you will less likely get an error that a specific
#       service has not been activated (when used later on by terraform).
# 
# You can review the terraform log file and search for: Creating new batch "Enable Project Service"
#
# You will see the following:
# [DEBUG] Creating new batch "Enable Project Service \"cloudkms.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" from request "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"orgpolicy.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"orgpolicy.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"bigquerystorage.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"bigquerystorage.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"notebooks.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"notebooks.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"dataflow.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"dataflow.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com dataflow.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"bigqueryconnection.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"bigqueryconnection.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com dataflow.googleapis.com bigqueryconnection.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"dataplex.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"dataplex.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com dataflow.googleapis.com bigqueryconnection.googleapis.com dataplex.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"bigquerydatatransfer.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"bigquerydatatransfer.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com dataflow.googleapis.com bigqueryconnection.googleapis.com dataplex.googleapis.com bigquerydatatransfer.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"dataproc.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"dataproc.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com dataflow.googleapis.com bigqueryconnection.googleapis.com dataplex.googleapis.com bigquerydatatransfer.googleapis.com dataproc.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Adding batch request "Enable Project Service \"analyticshub.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to existing batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable": timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Added batch request "Enable Project Service \"analyticshub.googleapis.com\" for project \"data-analytics-demo-7rlf2vua2t\"" to batch. New batch body: [cloudkms.googleapis.com orgpolicy.googleapis.com bigquerystorage.googleapis.com notebooks.googleapis.com dataflow.googleapis.com bigqueryconnection.googleapis.com dataplex.googleapis.com bigquerydatatransfer.googleapis.com dataproc.googleapis.com analyticshub.googleapis.com]: timestamp=2022-09-07T15:09:29.901-0400
# [DEBUG] Sending batch "project/data-analytics-demo-7rlf2vua2t/services:batchEnable" combining 10 requests): timestamp=2022-09-07T15:09:32.901-0400


resource "google_project_service" "service-serviceusage" {
  project = var.project_id
  service = "serviceusage.googleapis.com"
}

resource "google_project_service" "service-cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "service-servicemanagement" {
  project = var.project_id
  service = "servicemanagement.googleapis.com"
}

resource "google_project_service" "service-orgpolicy" {
  project = var.project_id
  service = "orgpolicy.googleapis.com"
}

resource "google_project_service" "service-compute" {
  project = var.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "service-bigquerystorage" {
  project = var.project_id
  service = "bigquerystorage.googleapis.com"
}

resource "google_project_service" "service-bigquerydatatransfer" {
  project = var.project_id
  service = "bigquerydatatransfer.googleapis.com"
}

resource "google_project_service" "service-bigqueryreservation" {
  project = var.project_id
  service = "bigqueryreservation.googleapis.com"
}

resource "google_project_service" "service-bigqueryconnection" {
  project = var.project_id
  service = "bigqueryconnection.googleapis.com"
}

resource "google_project_service" "service-composer" {
  project = var.project_id
  service = "composer.googleapis.com"
}

resource "google_project_service" "service-dataproc" {
  project = var.project_id
  service = "dataproc.googleapis.com"
}

resource "google_project_service" "service-datacatalog" {
  project = var.project_id
  service = "datacatalog.googleapis.com"
}

resource "google_project_service" "service-aiplatform" {
  project = var.project_id
  service = "aiplatform.googleapis.com"
}

resource "google_project_service" "service-notebooks" {
  project = var.project_id
  service = "notebooks.googleapis.com"
}

resource "google_project_service" "service-spanner" {
  project = var.project_id
  service = "spanner.googleapis.com"
}

resource "google_project_service" "service-dataflow" {
  project = var.project_id
  service = "dataflow.googleapis.com"
}

resource "google_project_service" "service-analyticshub" {
  project = var.project_id
  service = "analyticshub.googleapis.com"
}

resource "google_project_service" "service-cloudkms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "service-metastore" {
  project = var.project_id
  service = "metastore.googleapis.com"
}

resource "google_project_service" "service-dataplex" {
  project = var.project_id
  service = "dataplex.googleapis.com"
}

resource "google_project_service" "service-bigquerydatapolicy" {
  project = var.project_id
  service = "bigquerydatapolicy.googleapis.com"
}

resource "google_project_service" "service-cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "service-vision" {
  project = var.project_id
  service = "vision.googleapis.com"
}

resource "google_project_service" "service-datafusion" {
  project = var.project_id
  service = "datafusion.googleapis.com"
}

resource "google_project_service" "service-dataform" {
  project = var.project_id
  service = "dataform.googleapis.com"
}

resource "google_project_service" "service-secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "service-appengine" {
  project = var.project_id
  service = "appengine.googleapis.com"
}

resource "google_project_service" "service-cloudrun" {
  project = var.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "service-biglake" {
  project = var.project_id
  service = "biglake.googleapis.com"
}

resource "google_project_service" "service-datalineage" {
  project = var.project_id
  service = "datalineage.googleapis.com"
}

resource "google_project_service" "service-datastream" {
  project = var.project_id
  service = "datastream.googleapis.com"
}

resource "google_project_service" "service-pubsub" {
  project = var.project_id
  service = "pubsub.googleapis.com"
}

resource "google_project_service" "service-servicenetworking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
}

# For Cloud Run Deploy
resource "google_project_service" "service-cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "service-clouddeploy" {
  project = var.project_id
  service = "clouddeploy.googleapis.com"
}

resource "google_project_service" "service-artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "service-speech" {
  project = var.project_id
  service = "speech.googleapis.com"
}

resource "google_project_service" "service-workflows" {
  project = var.project_id
  service = "workflows.googleapis.com"
}

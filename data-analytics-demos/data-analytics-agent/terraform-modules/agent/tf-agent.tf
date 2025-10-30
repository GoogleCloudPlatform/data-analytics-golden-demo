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
# Deploys an agent by buiding a docker image and deploying it
#
# Author: Adam Paternostro
####################################################################################

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "6.40.0"
    }    
  }
}

####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "cloud_run_region" {}
variable "data_analytics_agent_code_bucket" {}
variable "gcp_account_name" {}

variable "bigquery_non_multi_region" {}
variable "dataplex_region" {}
variable "vertex_ai_region" {}
variable "dataform_region" {}
variable "project_number" {}
variable "dataform_service_account" {}

data "google_client_config" "current" {}


####################################################################################
# Repo for Docker Image: The repo for our Agent Development Kit compiled Docker Image
####################################################################################
resource "google_artifact_registry_repository" "artifact_registry_cloud_run_deploy" {
  project       = var.project_id
  location      = var.cloud_run_region
  repository_id = "cloud-run-source-deploy"
  description   = "cloud-run-source-deploy"
  format        = "DOCKER"
}


####################################################################################
# Create an API key for Google Search: The Agent uses Google Search and needs a key
####################################################################################
resource "google_apikeys_key" "google_search_api_key" {
  project       = var.project_id
  name          = "google-search-api-key"
  display_name  = "google-search-api-key"

  restrictions {
    api_targets {
      service = "customsearch.googleapis.com"
    }
  }
}


####################################################################################
# Copy the Agent code, do variable substition, zip up the files to GCS
####################################################################################
locals {
  source_template_dir    = "${path.module}/../../agent-code/data_analytics_agent"
  destination_output_dir = "${path.module}/../../agent-code-zip/agents/data_analytics_agent"
  all_source_files = fileset(local.source_template_dir, "**")

  ignored_patterns = [
    "/.env/",        # Matches files inside a .env directory (e.g., ".env/config.txt")
    ".env",          # Matches the .env file (the user should have which is .geitignored)
    ".env-template", # Matches the .env-template file
    ".png",          # Matches images
    ".DS_Store",     # Mac files
    "__pycache__/",  # Matches files inside a __pycache__ directory (e.e., "my_app/__pycache__/foo.pyc")
  ]

  # This local will contain a set of `file_path` strings that match any of the `ignored_patterns`.
  ignored_output_files_set = toset([
    for file_path in local.all_source_files :
    file_path
    if length([ # This checks if *any* of the ignored_patterns match the current file_path
      for ignored_pattern in local.ignored_patterns :
      true
      # Use regexall to check for substring presence.
      # regexall returns a list of matches. If the list is empty, no match was found.
      # length(regexall(...)) > 0 means a match was found.
      if length(regexall(ignored_pattern, file_path)) > 0
    ]) > 0
  ])

  template_files = [
    for file_path in local.all_source_files :
    file_path
    if !contains(local.ignored_output_files_set, file_path) # This 'contains' *is* correct, as it checks if file_path is in the set
  ]

  rendered_files = {
    for file_path in local.template_files :
    file_path => file("${local.source_template_dir}/${file_path}")
  }
}

# Create the files (Agent Python files)
resource "local_file" "templated_output" {
  for_each = local.rendered_files
  filename = "${local.destination_output_dir}/${each.key}"
  content  = each.value
}


# Create the Dockerfile
resource "local_file" "local_file_docker_file" {
  filename = "${path.module}/../../agent-code-zip/Dockerfile"
  content = templatefile("${path.module}/../../agent-code/Dockerfile",
   {
      project_id = var.project_id,
      cloud_run_region = var.cloud_run_region
    }
  )
}

# Create the .env
resource "local_file" "local_file_dot_env" {
  filename = "${path.module}/../../agent-code-zip/agents/data_analytics_agent/.env"
  content = templatefile("${path.module}/../../agent-code/data_analytics_agent/.env-template",
   {
      project_id = var.project_id,
      cloud_run_region = var.cloud_run_region
      google_search_api_key_value = google_apikeys_key.google_search_api_key.key_string
      cloud_run_region = var.cloud_run_region
      bigquery_non_multi_region = var.bigquery_non_multi_region
      dataplex_region =  var.dataplex_region
      vertex_ai_region = var.vertex_ai_region
      dataform_region = var.dataform_region
      gcp_account_name = var.gcp_account_name
      dataform_service_account = var.dataform_service_account
  }
  )
}

# This will be .getignored and will let the user run the agent locally.
resource "local_file" "local_file_dot_env_agent_code_directory" {
  filename = "${path.module}/../../agent-code/data_analytics_agent/.env"
  content = templatefile("${path.module}/../../agent-code/data_analytics_agent/.env-template",
   {
      project_id = var.project_id,
      cloud_run_region = var.cloud_run_region
      google_search_api_key_value = google_apikeys_key.google_search_api_key.key_string
      cloud_run_region = var.cloud_run_region
      bigquery_non_multi_region = var.bigquery_non_multi_region
      dataplex_region =  var.dataplex_region
      vertex_ai_region = var.vertex_ai_region
      dataform_region = var.dataform_region
      gcp_account_name = var.gcp_account_name
      dataform_service_account = var.dataform_service_account
  }
  )
}

# Create the requirements.txt
resource "local_file" "local_file_requirements_txt" {
  filename = "${path.module}/../../agent-code-zip/requirements.txt"
  content = templatefile("${path.module}/../../agent-code/requirements.txt",
   {
   }
  )
}


# Zip the source code
data "archive_file" "archive_data_analytics_agent_source_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../agent-code-zip"
  output_path = "${path.module}/../../data-analytics-agent.zip"

  depends_on = [
    local_file.templated_output,
    local_file.local_file_docker_file,
    local_file.local_file_requirements_txt,
    local_file.local_file_dot_env
  ]
}


# Upload code
resource "google_storage_bucket_object" "upload_data_analytics_agent_source_code" {
  name   = "data-analytics-agent/data-analytics-agent.zip"
  bucket = var.data_analytics_agent_code_bucket
  source = data.archive_file.archive_data_analytics_agent_source_code.output_path

  depends_on = [
    data.archive_file.archive_data_analytics_agent_source_code
  ]
}


####################################################################################
# Cloud Build - Builds the Agent Development Kit code
####################################################################################
resource "null_resource" "cloudbuild_data_analytics_agent_docker_image" {
  # Removed 'when = create' to allow triggers to work for updates.
  # The default behavior for provisioner "local-exec" is to run on create and update.
  provisioner "local-exec" {
    command = <<EOF
json=$(curl --request POST \
  "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/builds" \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"source":{"storageSource":{"bucket":"${var.data_analytics_agent_code_bucket}","object":"data-analytics-agent/data-analytics-agent.zip"}},"steps":[{"name":"gcr.io/cloud-builders/docker","args":["build","-t","${var.cloud_run_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/data-analytics-agent","."]},{"name":"gcr.io/cloud-builders/docker","args":["push","${var.cloud_run_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/data-analytics-agent"]}]}' \
  --compressed)

build_id=$(echo $${json} | jq .metadata.build.id --raw-output)
echo "build_id: $${build_id}"

# Loop while it creates
build_status_id="PENDING"
while [[ "$${build_status_id}" == "PENDING" || "$${build_status_id}" == "QUEUED" || "$${build_status_id}" == "WORKING" ]]
    do
    sleep 5
    build_status_json=$(curl \
    "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/builds/$${build_id}" \
    --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
    --header "Accept: application/json" \
    --compressed)

    build_status_id=$(echo $${build_status_json} | jq .status --raw-output)
    echo "build_status_id: $${build_status_id}"
    done

if [[ "$${build_status_id}" != "SUCCESS" ]];
then
    echo "Could not build the Data Analytics Agent Docker image with Cloud Build"
    exit 1;
else
    echo "Cloud Build Successful"
    # For new projects you need to wait up to 240 seconds after your cloud build.
    # The Cloud Run Terraform task is placed after the deployment of Composer which takes 15+ minutes to deploy.
    # sleep 240
fi
EOF
  }
  triggers = {
    always_run = timestamp() # Forces this null_resource to run on every apply
  }
  depends_on = [
    google_artifact_registry_repository.artifact_registry_cloud_run_deploy,
    google_storage_bucket_object.upload_data_analytics_agent_source_code,
  ]
}

# This random_id resource will generate a new ID whenever the source code archive changes.
# This ID will then be used as a label on the Cloud Run service template, forcing a new revision.
resource "random_id" "cloud_run_revision_nonce" {
  byte_length = 8
  # Triggers a new ID when the source code archive changes
  keepers = {
    archive_hash = data.archive_file.archive_data_analytics_agent_source_code.output_sha
  }
}

# Need to wait for the Docker image to "appear" in the Artifact Repo so Cloud Run can use it.
resource "time_sleep" "cloud_build_time_delay" {
  depends_on      = [null_resource.cloudbuild_data_analytics_agent_docker_image]
  create_duration = "240s"
}


####################################################################################
# Data Analytics Agent - Service Account
####################################################################################
resource "google_service_account" "data_analytics_agent_service_account" {
  project      = var.project_id
  account_id   = "data-analytics-agent-sa"
  display_name = "Service Account for Data Analytics Agent (Cloud Run)"
}

# Read metadata so we can get a list of tables in BigQuery
resource "google_project_iam_member" "data_analytics_agent_sa_bq_metadata_role" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_service_account.data_analytics_agent_service_account
  ]
}

# Run all BigQuery functions (this could be scoped back)
resource "google_project_iam_member" "data_analytics_agent_sa_bq_admin_role" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_project_iam_member.data_analytics_agent_sa_bq_metadata_role
  ]
}

# Call Gemini from Agent
resource "google_project_iam_member" "data_analytics_agent_sa_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_project_iam_member.data_analytics_agent_sa_bq_admin_role
  ]
}

# Data Catalog Search
resource "google_project_iam_member" "data_analytics_agent_sa_dataplex_catalog" {
  project = var.project_id
  role    = "roles/dataplex.admin"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_project_iam_member.data_analytics_agent_sa_vertex_user
  ]
}

# Conversational Analytics
resource "google_project_iam_member" "data_analytics_agent_sa_ca_agent_owner" {
  project = var.project_id
  role    = "roles/geminidataanalytics.dataAgentOwner"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_project_iam_member.data_analytics_agent_sa_dataplex_catalog
  ]
}

# Conversational Analytics Creator
resource "google_project_iam_member" "data_analytics_agent_sa_ca_agent_creator" {
  project = var.project_id
  role    = "roles/geminidataanalytics.dataAgentCreator"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_project_iam_member.data_analytics_agent_sa_ca_agent_owner
  ]
}

# Conversational Analytics individualUser
resource "google_project_iam_member" "data_analytics_agent_sa_ca_individualUser" {
  project = var.project_id
  role    = "roles/cloudaicompanion.individualUser"
  member  = "serviceAccount:${google_service_account.data_analytics_agent_service_account.email}"

  depends_on = [
    google_project_iam_member.data_analytics_agent_sa_ca_agent_creator
  ]
}


####################################################################################
# Cloud Run Deployment - Deploy cloud run and run as sevice account
####################################################################################
resource "google_cloud_run_v2_service" "cloud_run_service_data_analytics_agent" {
  project  = var.project_id
  name     = "data-analytics-agent-ui"
  location = var.cloud_run_region

  launch_stage = "BETA"
  ingress = "INGRESS_TRAFFIC_ALL"
  iap_enabled = true

  template {
    service_account = google_service_account.data_analytics_agent_service_account.email
    containers {
      image = "${var.cloud_run_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/data-analytics-agent"
      ports {
        container_port = 8000
      }
      name = "http1"
      resources {
        limits = {
          cpu = "2"
          memory = "2048Mi"
        }
      }

      # You have to get this by hand since I cannot automate this.
      # You can update the value in the cloud run directly or create a file named "cse-key.txt" and place at the root of this project
      # 1. Go here: https://programmablesearchengine.google.com/controlpanel/create
      # 2. Enter a name and select "Search Entire Web"
      # 3. Copy the CSE Id (you can edit it and copy the "Search engine ID" which is the GOOGLE_CSE_ID)    
      env {
        name  = "AGENT_ENV_GOOGLE_CSE_ID"
        value = fileexists("${path.module}/../../cse-key.txt") ? trimspace(file("${path.module}/../../cse-key.txt")) : "REPLACE-ME"
      }   
    }

    # Use a label with the random_id to force a new revision when the code changes
    labels = {
      "tf-revision-nonce" = random_id.cloud_run_revision_nonce.hex
    }
  }

  scaling {
    scaling_mode = "MANUAL"
    manual_instance_count = 1
  }

  depends_on = [
    null_resource.cloudbuild_data_analytics_agent_docker_image,
    google_service_account.data_analytics_agent_service_account,
    google_artifact_registry_repository.artifact_registry_cloud_run_deploy,
    google_storage_bucket_object.upload_data_analytics_agent_source_code,
    random_id.cloud_run_revision_nonce, 
    time_sleep.cloud_build_time_delay
  ]
}


resource "google_cloud_run_v2_service" "cloud_run_service_data_analytics_agent_api" {
  project  = var.project_id
  name     = "data-analytics-agent-api"
  location = var.cloud_run_region

  launch_stage = "BETA"
  ingress = "INGRESS_TRAFFIC_ALL"
  # For REST API calls to the agent, do not use IAP, you have to do a much of other setup. 
  # Just use IAM
  #iap_enabled = true

  template {
    service_account = google_service_account.data_analytics_agent_service_account.email
    timeout = "900s"    
    containers {
      image = "${var.cloud_run_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/data-analytics-agent"
      ports {
        container_port = 8000
      }
      name = "http1"
      resources {
        limits = {
          cpu = "2"
          memory = "2048Mi"
        }
      }

      # You have to get this by hand since I cannot automate this.
      # You can update the value in the cloud run directly or create a file named "cse-key.txt" and place at the root of this project
      # 1. Go here: https://programmablesearchengine.google.com/controlpanel/create
      # 2. Enter a name and select "Search Entire Web"
      # 3. Copy the CSE Id (you can edit it and copy the "Search engine ID" which is the GOOGLE_CSE_ID)    
      env {
        name  = "AGENT_ENV_GOOGLE_CSE_ID"
        value = fileexists("${path.module}/../../cse-key.txt") ? trimspace(file("${path.module}/../../cse-key.txt")) : "REPLACE-ME"
      }   
    }

    # Use a label with the random_id to force a new revision when the code changes
    labels = {
      "tf-revision-nonce" = random_id.cloud_run_revision_nonce.hex
    }
  }

  scaling {
    scaling_mode = "MANUAL"
    manual_instance_count = 1
  }

  depends_on = [
    null_resource.cloudbuild_data_analytics_agent_docker_image,
    google_service_account.data_analytics_agent_service_account,
    google_artifact_registry_repository.artifact_registry_cloud_run_deploy,
    google_storage_bucket_object.upload_data_analytics_agent_source_code,
    random_id.cloud_run_revision_nonce, 
    time_sleep.cloud_build_time_delay
  ]
}


####################################################################################
# Cloud Run Permissions and Invoker for Colab Enterprise notebook
####################################################################################
# We need to create a service account that our Colab Enterprise notebook will use for impersonation.
# We do not want to store the credentials in the notebook so we will impersonate a service account.
# The service account can then invoke the cloud run which uses an "identity-token" not an "access-token"

resource "google_service_account" "colab_enterprise_notebook_service_account" {
  project      = var.project_id
  account_id   = "colab-agent-service-account"
  display_name = "Service Account for Colab Enterprise Notebook"
}

# IAP
resource "google_cloud_run_v2_service_iam_member" "colab_enterprise_notebook_service_account_token_creator" {
  project  = var.project_id
  location = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.location
  name     = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.colab_enterprise_notebook_service_account.email}"
  depends_on = [
    google_service_account.colab_enterprise_notebook_service_account,
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent
  ]
}

resource "google_cloud_run_v2_service_iam_member" "gcp_user_cloud_run_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.location
  name     = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.name
  role     = "roles/run.invoker"
  member   = "user:${var.gcp_account_name}"
  depends_on = [
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent
  ]
}

# IAM
resource "google_cloud_run_v2_service_iam_member" "colab_enterprise_notebook_service_account_token_creator_api" {
  project  = var.project_id
  location = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.location
  name     = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.colab_enterprise_notebook_service_account.email}"
  depends_on = [
    google_service_account.colab_enterprise_notebook_service_account,
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api
  ]
}

resource "google_cloud_run_v2_service_iam_member" "gcp_user_cloud_run_invoker_api" {
  project  = var.project_id
  location = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.location
  name     = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.name
  role     = "roles/run.invoker"
  member   = "user:${var.gcp_account_name}"
  depends_on = [
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api
  ]
}


resource "google_service_account_iam_member" "gcp_user_cloud_token_creator_colab_sa" {
  service_account_id = google_service_account.colab_enterprise_notebook_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.gcp_account_name}"
  depends_on         = [ google_service_account.colab_enterprise_notebook_service_account ]
}

##################################################################################### 
# IAP user
####################################################################################
# Allow the IAP user to invoke the cloud run (required)
# This account is created when the service is activated and should exist
# Force a service account to be created so Terraform can then add permissions.
# Google creates service accounts upon first use and not when a service API is activated.
# gcloud beta services identity create --service=iap.googleapis.com --project=[PROJECT_ID]
resource "google_project_service_identity" "service_identity_iap" {
  project = var.project_id
  service = "iap.googleapis.com"
}
resource "time_sleep" "service_identity_iap_time_delay" {
  depends_on      = [google_project_service_identity.service_identity_iap]
  create_duration = "30s"
}

resource "google_cloud_run_v2_service_iam_member" "iap_user_cloud_run_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.location
  name     = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-iap.iam.gserviceaccount.com"
  depends_on = [
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent,
    time_sleep.service_identity_iap_time_delay
  ]
}


####################################################################################
# IAP Permissions
####################################################################################

# IAP
# Current User
resource "google_iap_web_cloud_run_service_iam_member" "iap_iam_cloud_run_gcp_account" {
  project                = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.project
  location               = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.location
  cloud_run_service_name = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = "user:${var.gcp_account_name}"
  depends_on             = [ 
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent,
    google_cloud_run_v2_service_iam_member.iap_user_cloud_run_invoker
   ]
}

# So the notebook can run / access the agent
resource "google_iap_web_cloud_run_service_iam_member" "iap_iam_cloud_run_colab_account" {
  project                = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.project
  location               = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.location
  cloud_run_service_name = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = "serviceAccount:${google_service_account.colab_enterprise_notebook_service_account.email}"
  depends_on             = [ 
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent,
    google_cloud_run_v2_service_iam_member.iap_user_cloud_run_invoker,
    google_iap_web_cloud_run_service_iam_member.iap_iam_cloud_run_gcp_account,
    google_service_account.colab_enterprise_notebook_service_account ]
}

# IAM
# Current User
resource "google_iap_web_cloud_run_service_iam_member" "iap_iam_cloud_run_gcp_account_api" {
  project                = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.project
  location               = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.location
  cloud_run_service_name = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = "user:${var.gcp_account_name}"
  depends_on             = [ 
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api
   ]
}

# So the notebook can run / access the agent
resource "google_iap_web_cloud_run_service_iam_member" "iap_iam_cloud_run_colab_account_api" {
  project                = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.project
  location               = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.location
  cloud_run_service_name = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = "serviceAccount:${google_service_account.colab_enterprise_notebook_service_account.email}"
  depends_on             = [ 
    google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api,
    google_iap_web_cloud_run_service_iam_member.iap_iam_cloud_run_gcp_account_api,
    google_service_account.colab_enterprise_notebook_service_account ]
}


####################################################################################
# Output our cloud run Uri and Colab Enterprise Notebook Service Account
####################################################################################
output "cloud_run_service_data_analytics_agent_uri" {
  value = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent.uri
  description = "The URL of the Cloud Run Data Analytics Agent service."
}

output "cloud_run_service_data_analytics_agent_api" {
  value = google_cloud_run_v2_service.cloud_run_service_data_analytics_agent_api.uri
  description = "The URL of the Cloud Run Data Analytics Agent service for REST API calls."
}

output "colab_enterprise_notebook_service_account_email" {
  value = google_service_account.colab_enterprise_notebook_service_account.email
  description = "The email of the colab service account."
}

output "google_search_api_key_value" {
  value = google_apikeys_key.google_search_api_key.key_string
}
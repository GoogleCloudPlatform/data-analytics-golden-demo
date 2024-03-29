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
variable "bigquery_rideshare_llm_raw_dataset" {}
variable "bigquery_rideshare_llm_enriched_dataset" {}
variable "bigquery_rideshare_llm_curated_dataset" {}
variable "gcs_rideshare_lakehouse_raw_bucket" {}
variable "storage_bucket" {}

variable "dataform_region" {}
variable "cloud_function_region" {}
variable "workflow_region" {}
variable "random_extension" {}
variable "gcp_account_name" {}
variable "curl_impersonation" {}
variable "bigquery_region" {}


# Define the list of notebook files to be created
locals {
  notebook_names_rideshare_llm = [ 
    for s in fileset("../colab-enterprise/rideshare-llm/", "*.ipynb") : trimsuffix(s, ".ipynb")
  ]

  notebook_names_taxi_dataset_demo = [ 
    for s in fileset("../colab-enterprise/taxi-dataset-demo/", "*.ipynb") : trimsuffix(s, ".ipynb")
  ]

  notebook_names = concat(local.notebook_names_rideshare_llm, local.notebook_names_taxi_dataset_demo)
}


# Create the notebook files to be uploaded
resource "local_file" "notebooks_rideshare_llm" {
  count    = length(local.notebook_names_rideshare_llm)
  filename = "../terraform-modules/colab-deployment/cloud-function/notebooks/${local.notebook_names_rideshare_llm[count.index]}.ipynb" 
  content = templatefile("../colab-enterprise/rideshare-llm/${local.notebook_names_rideshare_llm[count.index]}.ipynb",
   {
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    bigquery_region = var.bigquery_region

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
    }
  )
}

# Create the notebook files to be uploaded
resource "local_file" "notebooks_taxi" {
  count    = length(local.notebook_names_taxi_dataset_demo)
  filename = "../terraform-modules/colab-deployment/cloud-function/notebooks/${local.notebook_names_taxi_dataset_demo[count.index]}.ipynb" 
  content = templatefile("../colab-enterprise/taxi-dataset-demo/${local.notebook_names_taxi_dataset_demo[count.index]}.ipynb",
   {
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
    }
  )
}


# Upload the Cloud Function source code to a GCS bucket
## Define/create zip file for the Cloud Function source. This includes notebooks that will be uploaded
data "archive_file" "create_notebook_function_zip" {
  type        = "zip"
  output_path = "../tmp/notebooks_function_source.zip"
  source_dir  = "../terraform-modules/colab-deployment/cloud-function/"

  depends_on = [local_file.notebooks_rideshare_llm, local_file.notebooks_taxi]
}


## Upload the zip file of the source code to GCS
resource "google_storage_bucket_object" "function_source_upload" {
  name   = "cloud-functions/notebooks_function_source.zip"
  bucket = "code-${var.storage_bucket}"
  source = data.archive_file.create_notebook_function_zip.output_path
}


# Manage Cloud Function permissions and access
# Create a service account to manage the function
resource "google_service_account" "cloud_function_manage_sa" {
  project      = var.project_id
  account_id   = "notebook-deployment"
  display_name = "Cloud Functions Service Account"
  description  = "Service account used to manage Cloud Function"
}


## Define the IAM roles that are granted to the Cloud Function service account
locals {
  cloud_function_roles = [
    "roles/aiplatform.user",                  // Needs to predict from endpoints
    "roles/aiplatform.serviceAgent",          // Service account role
    "roles/cloudfunctions.admin",             // Service account role to manage access to the remote function
    "roles/dataform.codeEditor",              // Edit access code resources
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/run.invoker",                      // Service account role to invoke the remote function
    "roles/storage.objectViewer"              // Read GCS files
  ]
}

## Assign required permissions to the function service account
resource "google_project_iam_member" "function_manage_roles" {
  project = var.project_id
  count   = length(local.cloud_function_roles)
  role    = local.cloud_function_roles[count.index]
  member  = "serviceAccount:${google_service_account.cloud_function_manage_sa.email}"

  depends_on = [google_service_account.cloud_function_manage_sa]
}

## Grant the Cloud Workflows service account access to act as the Cloud Function service account
resource "google_service_account_iam_member" "workflow_auth_function" {
  service_account_id = google_service_account.cloud_function_manage_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflow_manage_sa.email}"

  depends_on = [
    google_service_account.workflow_manage_sa,
  ]
}

# Setup Dataform repositories to host notebooks
## Create the Dataform repos
resource "google_dataform_repository" "notebook_repo" {
  count        = length(local.notebook_names)
  provider     = google-beta
  project      = var.project_id
  region       = var.dataform_region
  name         = local.notebook_names[count.index]
  display_name = local.notebook_names[count.index]
  labels = {
    "single-file-asset-type" = "notebook"
  }
}

## Grant Cloud Function service account access to write to the repo
resource "google_dataform_repository_iam_member" "function_manage_repo" {
  provider   = google-beta
  project    = var.project_id
  region     = var.dataform_region
  role       = "roles/dataform.admin"
  member     = "serviceAccount:${google_service_account.cloud_function_manage_sa.email}"
  count      = length(local.notebook_names)
  repository = local.notebook_names[count.index]

  depends_on = [ google_service_account.cloud_function_manage_sa, google_dataform_repository.notebook_repo ]
}
# change

## Grant Cloud Workflows service account access to write to the repo
resource "google_dataform_repository_iam_member" "workflow_manage_repo" {
  provider   = google-beta
  project    = var.project_id
  region     = var.dataform_region
  role       = "roles/dataform.admin"
  member     = "serviceAccount:${google_service_account.workflow_manage_sa.email}"
  count      = length(local.notebook_names)
  repository = local.notebook_names[count.index]

  depends_on = [ google_service_account.workflow_manage_sa, google_dataform_repository.notebook_repo  ]
}
# change

# Create and deploy a Cloud Function to deploy notebooks
## Create the Cloud Function
resource "google_cloudfunctions2_function" "notebook_deploy_function" {
  name        = "deploy-notebooks"
  project     = var.project_id
  location    = var.cloud_function_region
  description = "A Cloud Function that deploys sample notebooks."
  build_config {
    runtime     = "python310"
    entry_point = "run_it"
    docker_repository = "projects/${var.project_id}/locations/${var.cloud_function_region}/repositories/gcf-artifacts"

    source {
      storage_source {
        bucket = "code-${var.storage_bucket}"
        object = google_storage_bucket_object.function_source_upload.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    # min_instance_count can be set to 1 to improve performance and responsiveness
    min_instance_count               = 0
    available_memory                 = "512Mi"
    timeout_seconds                  = 300
    max_instance_request_concurrency = 1
    available_cpu                    = "2"
    ingress_settings                 = "ALLOW_ALL"
    all_traffic_on_latest_revision   = true
    service_account_email            = google_service_account.cloud_function_manage_sa.email
    environment_variables = {
      "PROJECT_ID" : var.project_id,
      "DATAFORM_REGION" : var.dataform_region,
      "GCP_ACCOUNT_NAME" : var.gcp_account_name,      
    }
  }

  depends_on = [
    google_project_iam_member.function_manage_roles,
    google_dataform_repository.notebook_repo,
    google_dataform_repository_iam_member.workflow_manage_repo,
    google_dataform_repository_iam_member.function_manage_repo
  ]
}

## Wait for Function deployment to complete
resource "time_sleep" "wait_after_function" {
  create_duration = "15s"
  depends_on      = [google_cloudfunctions2_function.notebook_deploy_function]
}

# Activate the Google Service account
resource "google_project_service_identity" "service_identity_workflows" {
  project = var.project_id
  service = "workflows.googleapis.com"
  depends_on = [ ]
}

# Set up the Workflow
## Create the Workflows service account
resource "google_service_account" "workflow_manage_sa" {
  project      = var.project_id
  account_id   = "cloud-workflow-sa-${var.random_extension}"
  display_name = "Service Account for Cloud Workflows"
  description  = "Service account used to manage Cloud Workflows"
  depends_on = [ google_project_service_identity.service_identity_workflows ]
}


## Define the IAM roles granted to the Workflows service account
locals {
  workflow_roles = [
    "roles/bigquery.connectionUser",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser",
    "roles/run.invoker",
    "roles/storage.objectAdmin",
    "roles/workflows.admin",
  ]
}

## Grant the Workflow service account access
resource "google_project_iam_member" "workflow_manage_sa_roles" {
  count   = length(local.workflow_roles)
  project = var.project_id
  member  = "serviceAccount:${google_service_account.workflow_manage_sa.email}"
  role    = local.workflow_roles[count.index]

  depends_on = [google_service_account.workflow_manage_sa]
}


resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = var.project_id
  location       = var.cloud_function_region
  cloud_function = google_cloudfunctions2_function.notebook_deploy_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.workflow_manage_sa.email}"

  depends_on = [google_project_iam_member.workflow_manage_sa_roles]
}

## Wait for Function deployment to complete
resource "time_sleep" "wait_after_permissions" {
  create_duration = "15s"
  depends_on      = [google_cloudfunctions2_function_iam_member.invoker]
}

## Create the workflow
resource "google_workflows_workflow" "workflow" {
  name            = "initial-workflow"
  project         = var.project_id
  region          = var.workflow_region
  description     = "Runs post Terraform setup steps for Solution in Console"
  service_account = google_service_account.workflow_manage_sa.id

  source_contents = templatefile("../terraform-modules/colab-deployment/workflow/workflow.yaml", {
    function_url  = google_cloudfunctions2_function.notebook_deploy_function.url
    function_name = google_cloudfunctions2_function.notebook_deploy_function.name
  })

  depends_on = [
    time_sleep.wait_after_permissions,
    time_sleep.wait_after_function
  ]
}

# Wait for workflow to initialize
resource "time_sleep" "wait_after_workflow" {
  create_duration = "15s"
  depends_on      = [ google_workflows_workflow.workflow ]
}


/*
data "google_client_config" "current" {
}

## Trigger the execution of the setup workflow with an API call
data "http" "call_workflows_setup" {
  url    = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.workflow_region}/workflows/${google_workflows_workflow.workflow.name}/executions"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
  depends_on = [
    time_sleep.wait_after_workflow
  ]
}
*/

resource "null_resource" "execute_workflow" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.workflow_region}/workflows/${google_workflows_workflow.workflow.name}/executions \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
  --header "Content-Type: application/json"
EOF
  }
  depends_on = [
    time_sleep.wait_after_workflow
  ]
}
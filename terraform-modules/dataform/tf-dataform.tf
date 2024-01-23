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
# Create the Dataform resources
#
# Author: Adam Paternostro
#
# References: https://github.com/GoogleCloudPlatform/magic-modules/blob/main/mmv1/templates/terraform/examples/dataform_repository.tf.erb
#
# Notes: Not all features of Dataform are supported via Terraform at the time this was authored
#        REST API calls were used and can be replaced as additional Terraform support is added
####################################################################################


# Need this version to implement
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
variable "dataform_region" {}
variable "storage_bucket" {}
variable "curl_impersonation" {}
variable "bigquery_region" {}


locals {
  dataform_upload_dataform_json_file = templatefile("../dataform/dataform_golden_demo/demo_flow/dataform.json", 
  { 
    project_id = var.project_id
    bigquery_region = var.bigquery_region
  })
  dataform_create_biglake_table_file = templatefile("../dataform/dataform_golden_demo/demo_flow/definitions/operations/create_biglake_table.sqlx", 
  { 
    processed_bucket = "processed-${var.storage_bucket}"
  })
}


# Create a Git repo
/*
resource "google_sourcerepo_repository" "git_repository" {
  provider = google
  project = var.project_id
  name = "dataform_git_repo"
}
*/

# Create a secret manager
resource "google_secret_manager_secret" "secret" {
  project = var.project_id
  provider = google
  secret_id = "dataform"

  replication {
    auto {}
  }
}


# Set secret.  This is a placeholder so everything is in place, you just need to tie to your Git provider
# NOTE: You will need to replace with your GitHub PAT or GitLab PAT (PAT = Personal Access Token)
# https://cloud.google.com/dataform/docs/connect-repository
resource "google_secret_manager_secret_version" "secret_version" {
  provider = google
  secret = google_secret_manager_secret.secret.id
  secret_data = "REPLAC-ME-WITH-PAT-TOKEN"
  depends_on = [
    google_secret_manager_secret.secret,
  ]  
}


# Create Dataform repo with Git 
resource "google_dataform_repository" "dataform_repository" {
  provider = google
  project  = var.project_id
  region   = var.dataform_region
  name     = "dataform_golden_demo"

/* Not set for demo.  You will need to do this via the UI after updating the secret with your PAT token
  git_remote_settings {
      url = google_sourcerepo_repository.git_repository.url
      default_branch = "main"
      authentication_token_secret_version = google_secret_manager_secret_version.secret_version.id
  }
*/

  depends_on = [
    google_secret_manager_secret_version.secret_version,
  ]  
}

# Dataform will create a sevice account upon first call.  
# Wait for IAM Sync
# e.g. service-361618282238@gcp-sa-dataform.iam.gserviceaccount.com
# The 361618282238 is your Project Number
resource "time_sleep" "create_dataform_repository_time_delay" {
  depends_on      = [google_dataform_repository.dataform_repository]
  create_duration = "30s"
}


# Grant required BigQuery User access for Dataform
resource "google_project_iam_member" "dataform_bigquery_user" {
  project  = var.project_id
  role     = "roles/bigquery.user"
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [
    time_sleep.create_dataform_repository_time_delay
  ]  
}

# The service account need to be able to access the secret
# Dataform's service account is unable to access to the configured secret. 
# Make sure the secret exists and is shared with your Dataform service account: service-361618282238@gcp-sa-dataform.iam.gserviceaccount.com.
resource "google_secret_manager_secret_iam_member" "member" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${var.project_number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [
    time_sleep.create_dataform_repository_time_delay
  ]  
}


# Required since we are setting BigLake permissions
resource "google_project_iam_custom_role" "dataformrole" {
  project     = var.project_id
  role_id     = "DataformRole"
  title       = "Dataform Role"
  description = "Used for Dataform automation"
  permissions = ["bigquery.connections.delegate","bigquery.routines.get"]
}


# Add custom role to Dataform service account
resource "google_project_iam_member" "dataform_custom_role" {
  project  = var.project_id
  role     = google_project_iam_custom_role.dataformrole.id
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [
    google_project_iam_member.dataform_bigquery_user
  ]  
}

####################################################################################################
# Deploy Dataform items (that currently cannot be done via Terraform)
####################################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/create
resource "null_resource" "dataform_create_workspace" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces?workspaceId=demo_flow \
      --data \ '{"name":"demo_flow"}'
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
    ]
}


########################################################################################
# Upload the files to the root directory
########################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/writeFile
resource "null_resource" "dataform_upload_gitignore" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \".gitignore\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/.gitignore")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,

    ]
}


# Upload the Dataform.json file 
resource "null_resource" "dataform_upload_dataform_json" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"dataform.json\", \"contents\" : \"${base64encode(local.dataform_upload_dataform_json_file)}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    ]
}


resource "null_resource" "dataform_upload_package_json" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"package.json\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/package.json")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    ]
}


########################################################################################
# Create "definitions" directory
########################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/makeDirectory
resource "null_resource" "dataform_create_definitions_dir" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    ]
}


########################################################################################
# Create and upload the "definitions/operations" directory
########################################################################################
# definitions/operations
resource "null_resource" "dataform_create_operations_dir" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/operations\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    ]
}


# definitions/operations/create_biglake_table.sqlx
resource "null_resource" "dataform_create_biglake_table" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/operations/create_biglake_table.sqlx\", \"contents\" : \"${base64encode(local.dataform_create_biglake_table_file)}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    ]
}


########################################################################################
# Create and upload the "definitions/reporting" directory
########################################################################################
# definitions/reporting
resource "null_resource" "dataform_create_reporting_dir" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/reporting\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    ]
}


# definitions/operations/taxi_rides_summary.sqlx
resource "null_resource" "dataform_taxi_rides_summary" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/reporting/taxi_rides_summary.sqlx\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/definitions/reporting/taxi_rides_summary.sqlx")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    ]
}


########################################################################################
# Create and upload the "definitions/sources" directory
########################################################################################
# definitions/sources
resource "null_resource" "dataform_create_sources_dir" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/sources\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    ]
}


# definitions/sources/biglake_payment_type.sqlx
resource "null_resource" "dataform_biglake_payment_type" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/sources/biglake_payment_type.sqlx\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/definitions/sources/biglake_payment_type.sqlx")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    ]
}


# definitions/sources/taxi_trips_pub_sub.sqlx
resource "null_resource" "dataform_taxi_trips_pub_sub" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/sources/taxi_trips_pub_sub.sqlx\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/definitions/sources/taxi_trips_pub_sub.sqlx")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    ]
}


########################################################################################
# Create and upload the "definitions/staging" directory
########################################################################################
# definitions/staging
resource "null_resource" "dataform_create_staging_dir" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/staging\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    ]
}


# definitions/staging/rides_group_data.sqlx
resource "null_resource" "dataform_rides_group_data" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/staging/rides_group_data.sqlx\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/definitions/staging/rides_group_data.sqlx")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    null_resource.dataform_create_staging_dir,
    null_resource.dataform_rides_group_data,
    ]
}


# definitions/staging/taxi_parsed_data.sqlx
resource "null_resource" "dataform_taxi_parsed_data" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/staging/taxi_parsed_data.sqlx\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/definitions/staging/taxi_parsed_data.sqlx")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    null_resource.dataform_create_staging_dir,
    null_resource.dataform_rides_group_data,
    null_resource.dataform_taxi_parsed_data,
    ]
}


########################################################################################
# Create and upload the "includes" directory
########################################################################################
# includes
resource "null_resource" "dataform_create_includes_dir" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"includes\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    null_resource.dataform_create_staging_dir,
    null_resource.dataform_rides_group_data,
    null_resource.dataform_taxi_parsed_data,
    ]
}


# includes/CreateBiglake.js
resource "null_resource" "dataform_CreateBiglake" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"includes/CreateBiglake.js\", \"contents\" : \"${filebase64("../dataform/dataform_golden_demo/demo_flow/includes/CreateBiglake.js")}\" }"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    null_resource.dataform_create_staging_dir,
    null_resource.dataform_rides_group_data,
    null_resource.dataform_taxi_parsed_data,
    null_resource.dataform_create_includes_dir,
    ]
}



########################################################################################
# Install the npm packages
# This will create the "package-lock.json" file (which is managed by dataform)
########################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/installNpmPackages
# POST https://dataform.googleapis.com/v1beta1/{workspace=projects/*/locations/*/repositories/*/workspaces/*}:installNpmPackages
resource "null_resource" "dataform_install_npm_packages" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:installNpmPackages \
      --data \ "{}"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    null_resource.dataform_create_staging_dir,
    null_resource.dataform_rides_group_data,
    null_resource.dataform_taxi_parsed_data,
    null_resource.dataform_create_includes_dir,
    null_resource.dataform_CreateBiglake,
    ]
}



########################################################################################
# Commit all the files and changes
########################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/commit
# POST https://dataform.googleapis.com/v1beta1/{name=projects/*/locations/*/repositories/*/workspaces/*}:commit
resource "null_resource" "dataform_git_commit" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/dataform_golden_demo/workspaces/demo_flow:commit \
      --data \ '{ "author": { "name": "Admin", "emailAddress": "admin@paternostro.altostrat.com" }, "commitMessage": "Terraform Commit" }'
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
    time_sleep.create_dataform_repository_time_delay,
    null_resource.dataform_create_workspace,
    null_resource.dataform_upload_gitignore,
    null_resource.dataform_upload_dataform_json,
    null_resource.dataform_upload_package_json,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_operations_dir,
    null_resource.dataform_create_biglake_table,
    null_resource.dataform_create_reporting_dir,
    null_resource.dataform_taxi_rides_summary,
    null_resource.dataform_create_sources_dir,
    null_resource.dataform_biglake_payment_type,
    null_resource.dataform_taxi_trips_pub_sub,
    null_resource.dataform_create_staging_dir,
    null_resource.dataform_rides_group_data,
    null_resource.dataform_taxi_parsed_data,
    null_resource.dataform_create_includes_dir,
    null_resource.dataform_CreateBiglake,
    null_resource.dataform_install_npm_packages
    ]
}


####################################################################################
# Outputs
####################################################################################

output "dataform_repository" {
  value = google_dataform_repository.dataform_repository.name
}

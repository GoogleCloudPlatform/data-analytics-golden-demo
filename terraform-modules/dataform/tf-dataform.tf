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
# Create the GCP resources
#
# Author: Adam Paternostro
#
# https://github.com/GoogleCloudPlatform/magic-modules/blob/main/mmv1/templates/terraform/examples/dataform_repository.tf.erb
####################################################################################

# Need this version to implement
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.42.0"
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "project_number" {}
variable "storage_bucket" {}
variable "curl_impersonation" {}

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
  provider = google
  secret_id = "dataform"

  replication {
    automatic = true
  }
}


# Random string for secret (NOTE: You will need to replace with your GitHub PAT or GitLab PAT)
resource "random_string" "secret_data" {
  length  = 10
  upper   = false
  lower   = true
  numeric = true
  special = false
}


# Set secret
resource "google_secret_manager_secret_version" "secret_version" {
  provider = google
  secret = google_secret_manager_secret.secret.id
  secret_data = "${random_string.secret_data.result}"
  depends_on = [
    google_secret_manager_secret.secret,
  ]  
}


# Create Dataform repo with Git 
resource "google_dataform_repository" "dataform_repository" {
  provider = google
  project  = var.project_id
  region   = "us-central1" # var.region - must be in central during preview
  name     = "dataform_golden_demo"

/*
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

# Required since we are setting BigTable permissions
resource "google_project_iam_custom_role" "dataformrole" {
  role_id     = "DataformRole"
  title       = "Dataform Role"
  description = "Used for Dataform automation"
  permissions = ["bigquery.connections.delegate"]
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces?workspaceId=demo_flow \
      --data \ '{"name":"demo_flow"}'
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository
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
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/.gitignore" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \".gitignore\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
     null_resource.dataform_create_workspace
    ]
}


resource "null_resource" "dataform_upload_dataform_json" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    file_data=$$(cat "../dataform/dataform_golden_demo/demo_flow/dataform.json")
    echo "dataform_upload_dataform_json (file_data): $${file_data}"
    searchString="REPLACE_ME_PROJECT_NAME"
    replaceString="${var.project_id}"
    replaced_data=$(echo "$${file_data//$searchString/$replaceString}")
    echo "dataform_upload_dataform_json (replaced_data): $${replaced_data}"
    data=$(echo $$replaced_data | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"dataform.json\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
     null_resource.dataform_create_workspace
    ]
}


resource "null_resource" "dataform_upload_package_json" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/package.json" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"package.json\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
     null_resource.dataform_create_workspace
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions\" }"
    EOF
  }
  depends_on = [
     null_resource.dataform_create_workspace
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/operations\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir
    ]
}


# definitions/operations/create_biglake_table.sqlx
resource "null_resource" "dataform_create_biglake_table" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    file_data=$$(cat "../dataform/dataform_golden_demo/demo_flow/definitions/operations/create_biglake_table.sqlx")
    echo "dataform_upload_dadataform_create_biglake_tabletaform_json (file_data): $${file_data}"
    searchString="PROCESSED_BUCKET"
    replaceString="processed-${var.storage_bucket}"
    replaced_data=$(echo "$${file_data//$searchString/$replaceString}")
    echo "dataform_create_biglake_table (replaced_data): $${replaced_data}"
    data=$(echo $$replaced_data | base64)    
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/operations/create_biglake_table.sqlx\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,    
    null_resource.dataform_create_operations_dir
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/reporting\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir
    ]
}


# definitions/operations/taxi_rides_summary.sqlx
resource "null_resource" "dataform_taxi_rides_summary" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/definitions/reporting/taxi_rides_summary.sqlx" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/reporting/taxi_rides_summary.sqlx\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_reporting_dir
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/sources\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir
    ]
}


# definitions/sources/biglake_payment_type.sqlx
resource "null_resource" "dataform_biglake_payment_type" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/definitions/sources/biglake_payment_type.sqlx" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/sources/biglake_payment_type.sqlx\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_sources_dir
    ]
}


# definitions/sources/taxi_trips_pub_sub.sqlx
resource "null_resource" "dataform_taxi_trips_pub_sub" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/definitions/sources/taxi_trips_pub_sub.sqlx" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/sources/taxi_trips_pub_sub.sqlx\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_sources_dir
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"definitions/staging\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir
    ]
}


# definitions/staging/rides_group_data.sqlx
resource "null_resource" "dataform_rides_group_data" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/definitions/staging/rides_group_data.sqlx" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/staging/rides_group_data.sqlx\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_staging_dir
    ]
}


# definitions/staging/taxi_parsed_data.sqlx
resource "null_resource" "dataform_taxi_parsed_data" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/definitions/staging/taxi_parsed_data.sqlx" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"definitions/staging/taxi_parsed_data.sqlx\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_staging_dir
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:makeDirectory \
      --data \ "{ \"path\" : \"includes\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir
    ]
}


# includes/CreateBiglake.js
resource "null_resource" "dataform_CreateBiglake" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    data=$$(cat "../dataform/dataform_golden_demo/demo_flow/includes/CreateBiglake.js" | base64)
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:writeFile \
      --data \ "{ \"path\" : \"includes/CreateBiglake.js\", \"contents\" : \"$${data}\" }"
    EOF
  }
  depends_on = [
    null_resource.dataform_create_workspace,
    null_resource.dataform_create_definitions_dir,
    null_resource.dataform_create_includes_dir
    ]
}



########################################################################################
# Install the npm packages
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:installNpmPackages \
      --data \ "{}"
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
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
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/us-central1/repositories/dataform_golden_demo/workspaces/demo_flow:commit \
      --data \ '{ "author": { "name": "Admin", "emailAddress": "admin@paternostro.altostrat.com" }, "commitMessage": "Terraform Commit" }'
    EOF
  }
  depends_on = [
    google_dataform_repository.dataform_repository,
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
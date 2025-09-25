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
variable "bigquery_non_multi_region" {}
variable "dataform_region" {}
variable "project_number" {}
variable "bigquery_agentic_beans_raw_dataset" {}
variable "bigquery_agentic_beans_raw_staging_load_dataset" {}
variable "gcp_account_name" {}

data "google_client_config" "current" {}


####################################################################################
# BigQuery Pipeline - Service Account - Used by Agent for Pipeline / Dataform operations
####################################################################################
resource "google_service_account" "bigquery_pipeline_service_account" {
  project      = var.project_id
  account_id   = "bigquery-pipeline-sa"
  display_name = "Service Account for running BigQuery pipelines (dataform)"
}

# Roles for Dataform account: https://cloud.google.com/dataform/docs/access-control/#dataform-required-roles
resource "google_project_iam_member" "bigquery_pipeline_sa_role_dataEditor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.bigquery_pipeline_service_account.email}"

  depends_on = [
    google_service_account.bigquery_pipeline_service_account
  ]
}

resource "google_project_iam_member" "bigquery_pipeline_sa_role_dataViewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.bigquery_pipeline_service_account.email}"

  depends_on = [
    google_project_iam_member.bigquery_pipeline_sa_role_dataEditor
  ]
}

resource "google_project_iam_member" "bigquery_pipeline_sa_role_userr" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.bigquery_pipeline_service_account.email}"

  depends_on = [
    google_project_iam_member.bigquery_pipeline_sa_role_dataViewer
  ]
}

resource "google_project_iam_member" "bigquery_pipeline_sa_role_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.bigquery_pipeline_service_account.email}"

  depends_on = [
    google_project_iam_member.bigquery_pipeline_sa_role_dataViewer
  ]
}

resource "google_project_iam_member" "bigquery_pipeline_sa_role_dataOwner" {
  project = var.project_id
  role    = "roles/bigquery.dataOwner"
  member  = "serviceAccount:${google_service_account.bigquery_pipeline_service_account.email}"

  depends_on = [
    google_project_iam_member.bigquery_pipeline_sa_role_user
  ]
}

resource "google_project_iam_member" "bigquery_pipeline_sa_role_jobUser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.bigquery_pipeline_service_account.email}"

  depends_on = [
    google_project_iam_member.bigquery_pipeline_sa_role_dataOwner
  ]
}


#------------------------------------------------------------------------------------------------
# Force the dataform service account to get created (only created on first use)
#------------------------------------------------------------------------------------------------
resource "google_project_service_identity" "service_identity_dataform" {
  project = var.project_id
  service = "dataform.googleapis.com"
}

resource "time_sleep" "service_identity_dataform_time_delay" {
  depends_on      = [google_project_service_identity.service_identity_dataform]
  create_duration = "30s"
}

# We need to allow thie service account to impersonate then dataform service account
resource "google_service_account_iam_member" "bigquery_pipeline_service_account_token_creator" {
  service_account_id = google_service_account.bigquery_pipeline_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_project_service_identity.service_identity_dataform.member # "serviceAccount:service-${var.project_number}@gcp-sa-dataform.iam.gserviceaccount.com"
  depends_on         = [ 
    google_project_iam_member.bigquery_pipeline_sa_role_jobUser,
    time_sleep.service_identity_dataform_time_delay 
    ]
  }


####################################################################################
# Deploy the pipeline for the automated data eng agent auto correct pipeline
####################################################################################
resource "google_dataform_repository" "dataform_repository" {
  project = var.project_id
  name = "agentic-beans-repo"
  display_name = "agentic-beans-repo"
  region = var.dataform_region
  deletion_policy = "FORCE"
  service_account = google_service_account.bigquery_pipeline_service_account.name

  depends_on = [google_project_service_identity.service_identity_dataform]
}

resource "time_sleep" "create_dataform_repository_time_delay" {
  depends_on      = [google_dataform_repository.dataform_repository]
  create_duration = "15s"
}

####################################################################################
# Create workspaces: We will create two so we have an unaltered original for the demo
####################################################################################
resource "null_resource" "dataform_create_workspace_telemetry_coffee_machine_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces?workspaceId=telemetry-coffee-machine-original \
      --data \ '{"name":"telemetry-coffee-machine-original"}'
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
    ]
}

resource "null_resource" "dataform_create_workspace_telemetry_coffee_machine_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces?workspaceId=telemetry-coffee-machine-auto \
      --data \ '{"name":"telemetry-coffee-machine-auto"}'
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
    ]
}

####################################################################################
# Create directories: definitions
####################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/makeDirectory
resource "null_resource" "dataform_create_definitions_dir_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:makeDirectory \
      --data \ "{ \"path\" : \"definitions\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original
    ]
}

resource "null_resource" "dataform_create_definitions_dir_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:makeDirectory \
      --data \ "{ \"path\" : \"definitions\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto
    ]
}

####################################################################################
# Create directories: definitions/agentic_beans_raw
####################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/makeDirectory
resource "null_resource" "dataform_create_agentic_beans_raw_dir_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:makeDirectory \
      --data \ "{ \"path\" : \"definitions/agentic_beans_raw\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original
    ]
}

resource "null_resource" "dataform_create_agentic_beans_raw_dir_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:makeDirectory \
      --data \ "{ \"path\" : \"definitions/agentic_beans_raw\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto
    ]
}


####################################################################################
# Create directories: definitions/declarations
####################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/makeDirectory
resource "null_resource" "dataform_create_declarations_dir_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:makeDirectory \
      --data \ "{ \"path\" : \"definitions/declarations\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original,
     null_resource.dataform_create_agentic_beans_raw_dir_original
    ]
}

resource "null_resource" "dataform_create_declarations_dir_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:makeDirectory \
      --data \ "{ \"path\" : \"definitions/declarations\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto,
     null_resource.dataform_create_agentic_beans_raw_dir_auto
    ]
}


########################################################################################
# Upload .gitignore
########################################################################################
resource "local_file" "local_file_gitignore" {
  filename = "../dataform-deploy/telemetry-coffee-machine/.gitignore"
  content = templatefile("../dataform/telemetry-coffee-machine/.gitignore",
    {
      project_id                                  = var.project_id
      bigquery_non_multi_region                   = var.bigquery_non_multi_region
      dataform_region                             = var.dataform_region
      project_number                              = var.project_number
      bigquery_agentic_beans_raw_dataset          = var.bigquery_agentic_beans_raw_dataset
      bigquery_agentic_beans_raw_staging_load_dataset = var.bigquery_agentic_beans_raw_staging_load_dataset
    }
  )
}

# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/writeFile
resource "null_resource" "dataform_upload_gitignore_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:writeFile \
      --data \ "{ \"path\" : \".gitignore\", \"contents\" : \"${base64encode(local_file.local_file_gitignore.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original,
     null_resource.dataform_create_agentic_beans_raw_dir_original,
     null_resource.dataform_create_declarations_dir_original,
     local_file.local_file_gitignore
     ]
}

resource "null_resource" "dataform_upload_gitignore_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:writeFile \
      --data \ "{ \"path\" : \".gitignore\", \"contents\" : \"${base64encode(local_file.local_file_gitignore.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto,
     null_resource.dataform_create_agentic_beans_raw_dir_auto,
     null_resource.dataform_create_declarations_dir_auto,
     local_file.local_file_gitignore
    ]
}


########################################################################################
# Upload workflow_settings.yaml
########################################################################################
resource "local_file" "local_file_workflow_settings" {
  filename = "../dataform-deploy/telemetry-coffee-machine/workflow_settings.yaml" 
  content = templatefile("../dataform/telemetry-coffee-machine/workflow_settings.yaml",
   {
    project_id = var.project_id
    bigquery_non_multi_region = var.bigquery_non_multi_region
    dataform_region = var.dataform_region
    project_number = var.project_number
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    bigquery_agentic_beans_raw_staging_load_dataset = var.bigquery_agentic_beans_raw_staging_load_dataset
    }
  )
}

# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/writeFile
resource "null_resource" "dataform_upload_workflow_settings_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:writeFile \
      --data \ "{ \"path\" : \"workflow_settings.yaml\", \"contents\" : \"${base64encode(local_file.local_file_workflow_settings.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original,
     null_resource.dataform_create_agentic_beans_raw_dir_original,
     null_resource.dataform_create_declarations_dir_original,
     local_file.local_file_workflow_settings
     ]
}

resource "null_resource" "dataform_upload_workflow_settings_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:writeFile \
      --data \ "{ \"path\" : \"workflow_settings.yaml\", \"contents\" : \"${base64encode(local_file.local_file_workflow_settings.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto,
     null_resource.dataform_create_agentic_beans_raw_dir_auto,
     null_resource.dataform_create_declarations_dir_auto,
     local_file.local_file_workflow_settings
    ]
}


########################################################################################
# Upload  definitions/agentic_beans_raw/telemetry_coffee_machine.sqlx
########################################################################################
resource "local_file" "local_file_telemetry_coffee_machine" {
  filename = "../dataform-deploy/telemetry-coffee-machine/definitions/agentic_beans_raw/telemetry_coffee_machine.sqlx" 
  content = templatefile("../dataform/telemetry-coffee-machine/definitions/agentic_beans_raw/telemetry_coffee_machine.sqlx",
   {
    project_id = var.project_id
    bigquery_non_multi_region = var.bigquery_non_multi_region
    dataform_region = var.dataform_region
    project_number = var.project_number
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    bigquery_agentic_beans_raw_staging_load_dataset = var.bigquery_agentic_beans_raw_staging_load_dataset
    }
  )
}


# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/writeFile
resource "null_resource" "dataform_upload_telemetry_coffee_machine_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:writeFile \
      --data \ "{ \"path\" : \"definitions/agentic_beans_raw/telemetry_coffee_machine.sqlx\", \"contents\" : \"${base64encode(local_file.local_file_telemetry_coffee_machine.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original,
     null_resource.dataform_create_agentic_beans_raw_dir_original,
     null_resource.dataform_create_declarations_dir_original,
     local_file.local_file_telemetry_coffee_machine
     ]
}

resource "null_resource" "dataform_upload_telemetry_coffee_machine_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:writeFile \
      --data \ "{ \"path\" : \"definitions/agentic_beans_raw/telemetry_coffee_machine.sqlx\", \"contents\" : \"${base64encode(local_file.local_file_telemetry_coffee_machine.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto,
     null_resource.dataform_create_agentic_beans_raw_dir_auto,
     null_resource.dataform_create_declarations_dir_auto,
     local_file.local_file_telemetry_coffee_machine
    ]
}



########################################################################################
# Upload  definitions/declarations/agentic_beans_raw_staging_load.sqlx
########################################################################################
resource "local_file" "local_file_agentic_beans_raw_staging_load" {
  filename = "../dataform-deploy/telemetry-coffee-machine/definitions/declarations/agentic_beans_raw_staging_load.sqlx" 
  content = templatefile("../dataform/telemetry-coffee-machine/definitions/declarations/agentic_beans_raw_staging_load.sqlx",
   {
    project_id = var.project_id
    bigquery_non_multi_region = var.bigquery_non_multi_region
    dataform_region = var.dataform_region
    project_number = var.project_number
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    bigquery_agentic_beans_raw_staging_load_dataset = var.bigquery_agentic_beans_raw_staging_load_dataset
    }
  )
}

# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/writeFile
resource "null_resource" "dataform_upload_agentic_beans_raw_staging_load_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:writeFile \
      --data \ "{ \"path\" : \"definitions/declarations/agentic_beans_raw_staging_load.sqlx\", \"contents\" : \"${base64encode(local_file.local_file_agentic_beans_raw_staging_load.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original,
     null_resource.dataform_create_agentic_beans_raw_dir_original,
     null_resource.dataform_create_declarations_dir_original,
     local_file.local_file_agentic_beans_raw_staging_load
     ]
}

resource "null_resource" "dataform_upload_agentic_beans_raw_staging_load_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:writeFile \
      --data \ "{ \"path\" : \"definitions/declarations/agentic_beans_raw_staging_load.sqlx\", \"contents\" : \"${base64encode(local_file.local_file_agentic_beans_raw_staging_load.content)}\" }"
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto,
     null_resource.dataform_create_agentic_beans_raw_dir_auto,
     null_resource.dataform_create_declarations_dir_auto,
     local_file.local_file_agentic_beans_raw_staging_load
    ]
}


########################################################################################
# Commit all the files and changes
########################################################################################
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories.workspaces/commit
# POST https://dataform.googleapis.com/v1beta1/{name=projects/*/locations/*/repositories/*/workspaces/*}:commit
resource "null_resource" "dataform_git_commit_original" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-original:commit \
      --data \ '{ "author": { "name": "Admin", "emailAddress": "${var.gcp_account_name}" }, "commitMessage": "Terraform Commit" }'
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_original,
     null_resource.dataform_create_definitions_dir_original,
     null_resource.dataform_create_agentic_beans_raw_dir_original,
     null_resource.dataform_create_declarations_dir_original,
     null_resource.dataform_upload_agentic_beans_raw_staging_load_original,
     null_resource.dataform_upload_telemetry_coffee_machine_original,
     null_resource.dataform_upload_workflow_settings_original,
     null_resource.dataform_upload_gitignore_original
    ]
}

resource "null_resource" "dataform_git_commit_auto" {
provisioner "local-exec" {
  when    = create
  command = <<EOF
    curl \
      --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${google_dataform_repository.dataform_repository.name}/workspaces/telemetry-coffee-machine-auto:commit \
      --data \ '{ "author": { "name": "Admin", "emailAddress": "${var.gcp_account_name}" }, "commitMessage": "Terraform Commit" }'
    EOF
  }
  depends_on = [
     google_dataform_repository.dataform_repository,
     time_sleep.create_dataform_repository_time_delay,
     null_resource.dataform_create_workspace_telemetry_coffee_machine_auto,
     null_resource.dataform_create_definitions_dir_auto,
     null_resource.dataform_create_agentic_beans_raw_dir_auto,
     null_resource.dataform_create_declarations_dir_auto,
     null_resource.dataform_upload_agentic_beans_raw_staging_load_auto,
     null_resource.dataform_upload_telemetry_coffee_machine_auto,
     null_resource.dataform_upload_workflow_settings_auto,
     null_resource.dataform_upload_gitignore_auto
    ]
}



####################################################################################
# Output our cloud run Uri and Colab Enterprise Notebook Service Account
####################################################################################
output "bigquery_pipeline_service_account_email" {
  value = google_service_account.bigquery_pipeline_service_account.email
  description = "The email of the BigQuery Pipeline / DataForm."
}
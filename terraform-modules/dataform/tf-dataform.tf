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


# Create a Git repo
resource "google_sourcerepo_repository" "git_repository" {
  provider = google
  project = var.project_id
  name = "dataform_git_repo"
}


# Create a secret manager
resource "google_secret_manager_secret" "secret" {
  provider = google
  secret_id = "secret"

  replication {
    automatic = true
  }
}

# Random string for secret
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

  git_remote_settings {
      url = google_sourcerepo_repository.git_repository.url
      default_branch = "main"
      authentication_token_secret_version = google_secret_manager_secret_version.secret_version.id
  }

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


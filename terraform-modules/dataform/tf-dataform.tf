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
}


# Create Dataform repo with Git 
resource "google_dataform_repository" "dataform_repository" {
  provider = google
  project = var.project_id
  name = "dataform_golden_demo"

  git_remote_settings {
      url = google_sourcerepo_repository.git_repository.url
      default_branch = "main"
      authentication_token_secret_version = google_secret_manager_secret_version.secret_version.id
  }
}
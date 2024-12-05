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
      version = "5.35.0"
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


data "google_client_config" "current" {
}


# Define the list of notebook files to be created
locals {
  notebooks_to_deploy = [ 
    for s in fileset("../colab-enterprise/", "*.ipynb") : trimsuffix(s, ".ipynb")
  ]  

  notebook_names = local.notebooks_to_deploy # concat(local.TTTT, local.notebooks_to_deploy)
}


# Setup Dataform repositories to host notebooks
# Create the Dataform repos.  This will create all the repos across all directories
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


# Template Substitution - You need one of these blocks per Notebook Directory
resource "local_file" "local_file_notebooks_to_deploy" {
  count    = length(local.notebooks_to_deploy)
  filename = "../terraform-modules/colab-deployment-create-files/notebooks/${local.notebooks_to_deploy[count.index]}.ipynb" 
  content = templatefile("../colab-enterprise/${local.notebooks_to_deploy[count.index]}.ipynb",
   {
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset
    bigquery_region = var.bigquery_region
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket   
    bucket_name = "processed-${var.storage_bucket}"
    }
  )
}


# Deploy notebooks -  You need one of these blocks per Notebook Directory
# https://cloud.google.com/dataform/reference/rest/v1beta1/projects.locations.repositories/commit#WriteFile
#json='{
#  "commitMetadata": {
#    "author": {
#      "name": "Google Data Bean",
#      "emailAddress": "no-reply@google.com"
#    },
#    "commitMessage": "Committing Chocolate A.I. notebook"
#  },
#  "fileOperations": {
#      "content.ipynb": {
#         "writeFile": {
#           "contents" : "..."
#       }
#    }
#  }
#}'

# Write out the curl command content 
# If you do this within a docker/cloud build you can run into issues with the command output display being too long
resource "local_file" "local_file_notebooks_to_deploy_base64" {
  count    = length(local.notebooks_to_deploy)
  filename = "../terraform-modules/colab-deployment-create-files/notebooks_base64/${local.notebooks_to_deploy[count.index]}.base64" 
  content = "{\"commitMetadata\": {\"author\": {\"name\": \"Google Data Bean\",\"emailAddress\": \"no-reply@google.com\"},\"commitMessage\": \"Committing Chocolate A.I. notebook\"},\"fileOperations\": {\"content.ipynb\": {\"writeFile\": {\"contents\" : \"${base64encode(local_file.local_file_notebooks_to_deploy[count.index].content)}\"}}}}"
}

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
variable "multi_region" {}
variable "vertex_ai_region" {}
variable "bigquery_governed_data_raw_dataset" {}
variable "bigquery_governed_data_enriched_dataset" {}
variable "bigquery_governed_data_curated_dataset" {}
variable "bigquery_analytics_hub_publisher_dataset" {}
variable "governed_data_raw_bucket" {}
variable "governed_data_enriched_bucket" {}
variable "governed_data_curated_bucket" {}
variable "governed_data_code_bucket" {}
variable "governed_data_scan_bucket" {}
variable "dataform_region" {}
variable "dataproc_region" {}
variable "dataplex_region" {}
variable "random_extension" {}
variable "gcp_account_name" {}
variable "dataflow_staging_bucket" {}
variable "dataflow_service_account" {}


data "google_client_config" "current" {
}


# Define the list of notebook files to be created
locals {
  colab_enterprise_notebooks = [ 
    for s in fileset("../colab-enterprise/", "*.ipynb") : trimsuffix(s, ".ipynb")
  ]  

  notebook_names = local.colab_enterprise_notebooks # concat(local.TTTT, local.colab_enterprise_notebooks)
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
resource "local_file" "local_file_colab_enterprise_notebooks" {
  count    = length(local.colab_enterprise_notebooks)
  filename = "../terraform-modules/colab-deployment-create-files/notebooks/${local.colab_enterprise_notebooks[count.index]}.ipynb" 
  content = templatefile("../colab-enterprise/${local.colab_enterprise_notebooks[count.index]}.ipynb",
   {
    project_id = var.project_id
    random_extension = var.random_extension
    bigquery_location = var.multi_region
    region = var.vertex_ai_region
    dataproc_region = var.dataproc_region
    dataplex_region = var.dataplex_region
    location = var.vertex_ai_region
    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset
    bigquery_analytics_hub_publisher_dataset = var.bigquery_analytics_hub_publisher_dataset
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
    dataflow_staging_bucket = var.dataflow_staging_bucket
    dataflow_service_account = var.dataflow_service_account
    dataplex_location = "global"
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
#    "commitMessage": "Committing Colab notebook"
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
resource "local_file" "local_file_colab_enterprise_notebooks_base64" {
  count    = length(local.colab_enterprise_notebooks)
  filename = "../terraform-modules/colab-deployment-create-files/notebooks_base64/${local.colab_enterprise_notebooks[count.index]}.base64" 
  content = "{\"commitMetadata\": {\"author\": {\"name\": \"Google Data Bean\",\"emailAddress\": \"no-reply@google.com\"},\"commitMessage\": \"Committing Colab notebook\"},\"fileOperations\": {\"content.ipynb\": {\"writeFile\": {\"contents\" : \"${base64encode(local_file.local_file_colab_enterprise_notebooks[count.index].content)}\"}}}}"
}

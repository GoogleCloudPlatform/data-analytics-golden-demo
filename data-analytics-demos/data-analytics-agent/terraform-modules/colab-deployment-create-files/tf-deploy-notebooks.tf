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
variable "project_number" {}
variable "multi_region" {}
variable "vertex_ai_region" {}
variable "bigquery_agentic_beans_raw_dataset" {}
variable "bigquery_agentic_beans_enriched_dataset" {}
variable "bigquery_agentic_beans_curated_dataset" {}
variable "bigquery_agentic_beans_raw_us_dataset" {}

variable "data_analytics_agent_bucket" {}
variable "data_analytics_agent_code_bucket" {}
variable "dataform_region" {}
variable "random_extension" {}
variable "gcp_account_name" {}
variable "dataflow_staging_bucket" {}
#variable "dataflow_service_account" {}

variable "cloud_run_service_data_analytics_agent_api" {}
variable "colab_enterprise_notebook_service_account_email" {}

variable google_search_api_key_value {}
variable dataplex_region {}
variable conversation_analytics_region {}
variable agent_engine_service_account {}
variable dataform_service_account {}
variable bigquery_non_multi_region{}

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
    project_number = var.project_number
    bigquery_location = var.multi_region
    bigquery_non_multi_region = var.bigquery_non_multi_region
    region = var.vertex_ai_region
    location = var.vertex_ai_region
    dataplex_region = var.dataplex_region
    dataform_region = var.dataform_region
    gcp_account_name = var.gcp_account_name
    bigquery_agentic_beans_raw_dataset      = var.bigquery_agentic_beans_raw_dataset
    bigquery_agentic_beans_enriched_dataset = var.bigquery_agentic_beans_enriched_dataset
    bigquery_agentic_beans_curated_dataset  = var.bigquery_agentic_beans_curated_dataset
    bigquery_agentic_beans_raw_us_dataset   = var.bigquery_agentic_beans_raw_us_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    data_analytics_agent_code_bucket = var.data_analytics_agent_code_bucket
    dataflow_staging_bucket = var.dataflow_staging_bucket
    #dataflow_service_account = var.dataflow_service_account
    cloud_run_service_data_analytics_agent_api = var.cloud_run_service_data_analytics_agent_api
    colab_enterprise_notebook_service_account_email = var.colab_enterprise_notebook_service_account_email
    env_vars_GOOGLE_GENAI_USE_VERTEXAI = "TRUE"
    env_vars_AGENT_ENV_PROJECT_ID = var.project_id
    env_vars_AGENT_ENV_BIGQUERY_REGION = var.bigquery_non_multi_region
    env_vars_AGENT_ENV_DATAPLEX_SEARCH_REGION = "global"
    env_vars_AGENT_ENV_GOOGLE_API_KEY = var.google_search_api_key_value
    env_vars_AGENT_ENV_DATAPLEX_REGION = var.dataplex_region
    env_vars_AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION = var.conversation_analytics_region
    env_vars_AGENT_ENV_VERTEX_AI_REGION = var.vertex_ai_region
    env_vars_AGENT_ENV_BUSINESS_GLOSSARY_REGION = "global"
    env_vars_AGENT_ENV_DATAFORM_REGION = var.dataform_region
    env_vars_AGENT_ENV_DATAFORM_AUTHOR_NAME = var.gcp_account_name
    env_vars_AGENT_ENV_DATAFORM_AUTHOR_EMAIL = var.gcp_account_name
    env_vars_AGENT_ENV_DATAFORM_WORKSPACE_DEFAULT_NAME = "default"
    env_vars_AGENT_ENV_DATAFORM_SERVICE_ACCOUNT = var.dataform_service_account
    env_vars_VERTEX_AI_ENDPOINT = "gemini-2.5-flash"
    env_vars_VERTEX_AI_CONNECTION_NAME = "vertex-ai"
    env_vars_AGENT_ENGINE_SERVICE_ACCOUNT = var.agent_engine_service_account
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

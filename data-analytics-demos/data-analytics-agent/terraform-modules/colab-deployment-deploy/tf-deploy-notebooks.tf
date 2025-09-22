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


data "google_client_config" "current" {
}


# Define the list of notebook files to be created
locals {
  data_analytics_agent_notebooks = [ 
    for s in fileset("../colab-enterprise/", "*.ipynb") : trimsuffix(s, ".ipynb")
  ]  

  notebook_names = local.data_analytics_agent_notebooks # concat(local.TTTT, local.data_analytics_agent_notebooks)
}


resource "null_resource" "commit_data_analytics_agent_notebooks" {
  count        = length(local.data_analytics_agent_notebooks)
  
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    
    when    = create
    command = <<EOF
curl -X POST \
  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${replace(local.data_analytics_agent_notebooks[count.index], ".ipynb", "")}:commit \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --compressed \
  --data "@../terraform-modules/colab-deployment-create-files/notebooks_base64/${local.data_analytics_agent_notebooks[count.index]}.base64"
EOF
  }
  depends_on = []
}
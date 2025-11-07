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


resource "null_resource" "commit_notebooks_to_deploy" {
  count        = length(local.notebooks_to_deploy)
  
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    
    when    = create
    command = <<EOF
curl -X POST \
  https://dataform.googleapis.com/v1beta1/projects/${var.project_id}/locations/${var.dataform_region}/repositories/${replace(local.notebooks_to_deploy[count.index], ".ipynb", "")}:commit \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --compressed \
  --data "@../terraform-modules/colab-deployment-create-files/notebooks_base64/${local.notebooks_to_deploy[count.index]}.base64"
EOF
  }
  depends_on = []
}
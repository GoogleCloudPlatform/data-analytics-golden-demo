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
# Create the GCP resources
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
variable "gcp_account_name" {}
variable "project_id" {}

variable "dataplex_region" {}
variable "multi_region" {}
variable "bigquery_non_multi_region" {}
variable "vertex_ai_region" {}
variable "data_catalog_region" {}
variable "appengine_region" {}
variable "colab_enterprise_region" {}

variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "terraform_service_account" {}

variable "bigquery_agentic_beans_raw_dataset" {}
variable "bigquery_agentic_beans_enriched_dataset" {}
variable "bigquery_agentic_beans_curated_dataset" {}
variable "bigquery_agentic_beans_raw_us_dataset" {}
variable "bigquery_nyc_taxi_curated_dataset" {}
variable "bigquery_data_analytics_agent_metadata_dataset" {}

variable "data_analytics_agent_bucket" {}
variable "data_analytics_agent_code_bucket" {}

data "google_client_config" "current" {
}

####################################################################################
# RAW: UDFs
####################################################################################
resource "google_bigquery_routine" "clean_llmgemini_pro_result_as_json_json" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_raw_dataset
  routine_id      = "gemini_pro_result_as_json"
  routine_type    = "SCALAR_FUNCTION"
  language        = "SQL"

  definition_body = templatefile("../sql-scripts/agentic_beans_raw/gemini_pro_result_as_json.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
  })

  arguments {
    name          = "input"
    argument_kind = "FIXED_TYPE"
    data_type     = jsonencode({ "typeKind" : "JSON" })
  }

  return_type = "{\"typeKind\" :  \"JSON\"}"
}


resource "google_bigquery_routine" "gemini_pro_result_as_string" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_raw_dataset
  routine_id      = "gemini_pro_result_as_string"
  routine_type    = "SCALAR_FUNCTION"
  language        = "SQL"

  definition_body = templatefile("../sql-scripts/agentic_beans_raw/gemini_pro_result_as_string.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
  })

  arguments {
    name          = "input"
    argument_kind = "FIXED_TYPE"
    data_type     = jsonencode({ "typeKind" : "JSON" })
  }
  
  return_type = "{\"typeKind\" :  \"STRING\"}"
}


####################################################################################
# RAW: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "initialize" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_raw_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/agentic_beans_raw/initialize.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}

/*
resource "google_bigquery_routine" "raw_populate_weather" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_raw_dataset
  routine_id      = "populate_weather"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/agentic_beans_raw/populate_weather.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}
*/

####################################################################################
# Enriched: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "initialize_enriched" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_enriched_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/agentic_beans_enriched/initialize.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}


####################################################################################
# Curated: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "initialize_curated" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_curated_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/agentic_beans_curated/initialize.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_dataset = var.bigquery_agentic_beans_raw_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}


####################################################################################
# data_analytics_agent_metadata: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "initialize_data_analytics_agent_metadata" {
  project         = var.project_id
  dataset_id      = var.bigquery_data_analytics_agent_metadata_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/data_analytics_agent_metadata/initialize.sql", 
  { 
    project_id = var.project_id
    bigquery_data_analytics_agent_metadata_dataset = var.bigquery_data_analytics_agent_metadata_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}

resource "google_bigquery_routine" "refresh_vector_metadata" {
  project         = var.project_id
  dataset_id      = var.bigquery_data_analytics_agent_metadata_dataset
  routine_id      = "refresh_vector_metadata"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/data_analytics_agent_metadata/refresh_vector_metadata.sql", 
  { 
    project_id = var.project_id
    bigquery_data_analytics_agent_metadata_dataset = var.bigquery_data_analytics_agent_metadata_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}


####################################################################################
# RAW: Invoke Initalize SP
####################################################################################
resource "null_resource" "call_sp_initialize" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/jobs \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --data '{ "configuration" : { "query" : { "query" : "CALL `${var.project_id}.${var.bigquery_agentic_beans_raw_dataset}.initialize`();", "useLegacySql" : false } } }'
EOF
  }
  depends_on = [
    google_bigquery_routine.initialize,
    google_bigquery_routine.initialize_enriched,
    google_bigquery_routine.initialize_curated,
  ]
}


####################################################################################
# TAXI DATA: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "taxi_initialize" {
  project         = var.project_id
  dataset_id      = var.bigquery_nyc_taxi_curated_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/nyc_taxi_curated/initialize.sql", 
  { 
    project_id = var.project_id
    bigquery_nyc_taxi_curated_dataset = var.bigquery_nyc_taxi_curated_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
    bigquery_non_multi_region = var.bigquery_non_multi_region
  })
}


####################################################################################
# TAXI DATA: Invoke Initalize SP
####################################################################################
resource "null_resource" "taxi_call_sp_initialize" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/jobs \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --data '{ "configuration" : { "query" : { "query" : "CALL `${var.project_id}.${var.bigquery_nyc_taxi_curated_dataset}.initialize`();", "useLegacySql" : false } } }'
EOF
  }
  depends_on = [
    google_bigquery_routine.taxi_initialize
  ]
}



####################################################################################
# RAW US Multi-region: Invoke Initalize SP
####################################################################################
/*
resource "google_bigquery_routine" "raw_us_populate_weather" {
  project         = var.project_id
  dataset_id      = var.bigquery_agentic_beans_raw_us_dataset
  routine_id      = "populate_weather"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/agentic_beans_raw_us/populate_weather.sql", 
  { 
    project_id = var.project_id
    bigquery_agentic_beans_raw_us_dataset = var.bigquery_agentic_beans_raw_us_dataset
    data_analytics_agent_bucket = var.data_analytics_agent_bucket
  })
}
*/
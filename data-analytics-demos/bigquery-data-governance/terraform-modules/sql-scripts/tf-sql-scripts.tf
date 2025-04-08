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

####################################################################################
# Create the GCP resources
#
# Author: Adam Paternostro
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

variable "bigquery_governed_data_raw_dataset" {}
variable "bigquery_governed_data_enriched_dataset" {}
variable "bigquery_governed_data_curated_dataset" {}
variable "bigquery_analytics_hub_publisher_dataset" {}
variable "governed_data_raw_bucket" {}
variable "governed_data_enriched_bucket" {}
variable "governed_data_curated_bucket" {}
variable "governed_data_code_bucket" {}
variable "governed_data_scan_bucket" {}

data "google_client_config" "current" {
}

####################################################################################
# UDFs
####################################################################################
resource "google_bigquery_routine" "clean_llmgemini_model_result_as_json_json" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_raw_dataset
  routine_id      = "gemini_model_result_as_json"
  routine_type    = "SCALAR_FUNCTION"
  language        = "SQL"

  definition_body = templatefile("../sql-scripts/governed_data_raw/gemini_model_result_as_json.sql", 
  { 
    project_id = var.project_id
    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
  })

  arguments {
    name          = "input"
    argument_kind = "FIXED_TYPE"
    data_type     = jsonencode({ "typeKind" : "JSON" })
  }

  return_type = "{\"typeKind\" :  \"JSON\"}"
}


resource "google_bigquery_routine" "gemini_model_result_as_string" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_raw_dataset
  routine_id      = "gemini_model_result_as_string"
  routine_type    = "SCALAR_FUNCTION"
  language        = "SQL"

  definition_body = templatefile("../sql-scripts/governed_data_raw/gemini_model_result_as_string.sql", 
  { 
    project_id = var.project_id
    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
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
resource "google_bigquery_routine" "initialize_raw" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_raw_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_raw_dataset}/initialize.sql", 
  { 
    project_id = var.project_id
    multi_region = var.multi_region

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset

    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
}


####################################################################################
# ENRICHED: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "initialize_enriched" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_enriched_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_enriched_dataset}/initialize.sql", 
  { 
    project_id = var.project_id
    multi_region = var.multi_region

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset

    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
  depends_on = [
    google_bigquery_routine.initialize_raw
  ]
  
}


resource "google_bigquery_routine" "transform_customer" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_enriched_dataset
  routine_id      = "transform_customer"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_enriched_dataset}/transform_customer.sql", 
  { 
    project_id = var.project_id

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset

    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
}


resource "google_bigquery_routine" "transform_product_category" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_enriched_dataset
  routine_id      = "transform_product_category"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_enriched_dataset}/transform_product_category.sql", 
  { 
    project_id = var.project_id

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset

    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
}


resource "google_bigquery_routine" "transform_product" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_enriched_dataset
  routine_id      = "transform_product"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_enriched_dataset}/transform_product.sql", 
  { 
    project_id = var.project_id

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset

    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
}



####################################################################################
# ENRICHED: Spark Transformation
####################################################################################
resource "google_bigquery_routine" "transform_order_pyspark" {
  project         = var.project_id  
  dataset_id      = var.bigquery_governed_data_enriched_dataset
  routine_id      = "transform_order_pyspark"
  routine_type    = "PROCEDURE"
  language        = "PYTHON"

  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_enriched_dataset}/transform_order_pyspark.py", 
  { 
    project_id = var.project_id

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset
    
    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })

  spark_options {
    connection          = "projects/${var.project_id}/locations/${var.multi_region}/connections/spark-connection"
    runtime_version     = "2.1"
    #properties          = {
    #  "dataproc:dataproc.lineage.enabled" : "true" # https://cloud.google.com/dataproc/docs/guides/lineage#enable-data-lineage-at-the-cluster-level
    #}   
    properties          = {
      "spark.openlineage.namespace" : "${var.project_id}"
      "spark.openlineage.appName": "transform_order_pyspark"
    }       
  }
}


# Spark code for dataproc cluster
resource "google_storage_bucket_object" "dataproc_transform_order_pyspark" {
  name        = "dataproc/transform_order_pyspark.py"
  content     = templatefile("../dataproc/transform_order_pyspark.py", 
  { 
    project_id = var.project_id

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset
    
    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
  bucket      = var.governed_data_code_bucket
}

####################################################################################
# CURATED: Stored Procedures
####################################################################################
resource "google_bigquery_routine" "initialize_curated" {
  project         = var.project_id
  dataset_id      = var.bigquery_governed_data_curated_dataset
  routine_id      = "initialize"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/${var.bigquery_governed_data_curated_dataset}/initialize.sql", 
  { 
    project_id = var.project_id
    multi_region = var.multi_region

    bigquery_governed_data_raw_dataset = var.bigquery_governed_data_raw_dataset
    bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
    bigquery_governed_data_curated_dataset = var.bigquery_governed_data_curated_dataset
    bigquery_analytics_hub_publisher_dataset = var.bigquery_analytics_hub_publisher_dataset

    governed_data_raw_bucket = var.governed_data_raw_bucket
    governed_data_enriched_bucket = var.governed_data_enriched_bucket
    governed_data_curated_bucket = var.governed_data_curated_bucket
    governed_data_code_bucket = var.governed_data_code_bucket
    governed_data_scan_bucket = var.governed_data_scan_bucket
  })
  depends_on = [
    google_bigquery_routine.initialize_raw,
    google_bigquery_routine.initialize_enriched
  ]  
}

####################################################################################
# Invoke Initalize SP
####################################################################################
/* THIS RUNS OVER AND OVER AGAIN (for each TF execution) WHICH WILL OVERWRITE THE DATA
data "google_client_config" "current" {
}

# Call the BigQuery initialize stored procedure to initialize the system
data "http" "call_sp_initialize" {
  url    = "https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/jobs"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
  request_body = "{\"configuration\":{\"query\":{\"query\":\"CALL `${var.project_id}.${var.bigquery_governed_data_raw_dataset}.initialize`();\",\"useLegacySql\":false}}}"
  depends_on = [
     google_bigquery_routine.initialize
  ]
}
*/


resource "null_resource" "call_sp_initialize" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/jobs \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --data '{ "configuration" : { "query" : { "query" : "CALL `${var.project_id}.${var.bigquery_governed_data_raw_dataset}.initialize`();", "useLegacySql" : false } } }'
EOF
  }
  depends_on = [
    google_bigquery_routine.initialize_raw,
    google_bigquery_routine.initialize_enriched,
    google_bigquery_routine.transform_product,
    google_bigquery_routine.transform_product_category,
    google_bigquery_routine.transform_customer,
    google_bigquery_routine.transform_order_pyspark,
    google_bigquery_routine.initialize_curated,
  ]
}

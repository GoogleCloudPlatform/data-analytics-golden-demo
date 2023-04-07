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
variable "gcp_account_name" {}
variable "project_id" {}
variable "storage_bucket" {}
variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "spanner_region" {}
variable "bigquery_region" {}
variable "shared_demo_project_id" {}
variable "aws_omni_biglake_dataset_name" {}
variable "aws_omni_biglake_dataset_region" {}
variable "aws_omni_biglake_connection" {}
variable "aws_omni_biglake_s3_bucket" {}
variable "azure_omni_biglake_dataset_name" {}
variable "azure_omni_biglake_connection" {}
variable "azure_omni_biglake_adls_name" {}

variable "bigquery_rideshare_lakehouse_raw_dataset" {}
variable "gcs_rideshare_lakehouse_raw_bucket" {}
variable "bigquery_rideshare_lakehouse_enriched_dataset" {}
variable "gcs_rideshare_lakehouse_enriched_bucket" {}
variable "bigquery_rideshare_lakehouse_curated_dataset" {}
variable "gcs_rideshare_lakehouse_curated_bucket" {}

# Hardcoded
variable "bigquery_taxi_dataset" {
  type        = string
  default     = "taxi_dataset"
}
variable "bigquery_thelook_ecommerce_dataset" {
  type        = string
  default     = "thelook_ecommerce"
}


#===================================================================================
#===================================================================================
# taxi_dataset Dataset
#===================================================================================
#===================================================================================


####################################################################################
# sp_create_demo_dataform
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_demo_dataform" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_demo_dataform"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_create_demo_dataform.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_create_taxi_biglake_tables
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_taxi_biglake_tables" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_taxi_biglake_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_create_taxi_biglake_tables.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_create_taxi_external_tables
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_taxi_external_tables" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_taxi_external_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_create_taxi_external_tables.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })

}


####################################################################################
# sp_create_taxi_internal_tables
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_taxi_internal_tables" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_taxi_internal_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_create_taxi_internal_tables.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })

}


####################################################################################
# sp_demo_biglake_query_acceleration
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_biglake_query_acceleration" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_biglake_query_acceleration"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_biglake_query_acceleration.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    random_extension = var.random_extension
    five_million_small_files_bucket = "sample-shared-data-query-acceleration"
    shared_demo_project_id = var.shared_demo_project_id
  })

}


####################################################################################
# sp_demo_biglake
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_biglake" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_biglake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_biglake.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    random_extension = var.random_extension
    # special case for embedded bash commands
    bqOutputJsonFile = "$${bqOutputJsonFile}"
    bqOutputJson = "$${bqOutputJson}"
    biglake_service_account = "$${biglake_service_account}"
  })

}

####################################################################################
# sp_demo_bigquery_pricing
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_bigquery_pricing" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_bigquery_pricing"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_bigquery_pricing.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })

}


####################################################################################
# sp_demo_bigquery_queries
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_bigquery_queries" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_bigquery_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_bigquery_queries.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })

}


####################################################################################
# sp_demo_bigsearch
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_bigsearch" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_bigsearch"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_bigsearch.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id = var.shared_demo_project_id
  })

}


####################################################################################
# sp_demo_data_quality_columns
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_data_quality_columns" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_data_quality_columns"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_data_quality_columns.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id = var.shared_demo_project_id
  })
}


####################################################################################
# sp_demo_data_quality_table
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_data_quality_table" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_data_quality_table"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_data_quality_table.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id = var.shared_demo_project_id
  })
}


####################################################################################
# sp_demo_data_transfer_service
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_data_transfer_service" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_data_transfer_service"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_data_transfer_service.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })

}


####################################################################################
# sp_demo_datastudio_report
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_datastudio_report" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_datastudio_report"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_datastudio_report.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_delta_lake
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_delta_lake" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_delta_lake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_delta_lake.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })

}


####################################################################################
# sp_demo_export_weather_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_export_weather_data" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_export_weather_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_export_weather_data.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_external_function
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_external_function" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_external_function"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_external_function.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_federated_query
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_federated_query" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_federated_query"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_federated_query.sql", 
  { 
    project_id = var.project_id
    spanner_region = var.spanner_region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_ingest_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_ingest_data" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_ingest_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_ingest_data.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    raw_bucket_name = "raw-${var.storage_bucket}"
    processed_bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_internal_external_table_join
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_internal_external_table_join" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_internal_external_table_join"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_internal_external_table_join.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_json_datatype
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_json_datatype" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_json_datatype"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_json_datatype.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    processed_bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_machine_learning_anomaly_fee_amount
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_machine_learning_anomaly_fee_amount" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_machine_learning_anomaly_fee_amount"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_machine_learning_anomaly_fee_amount.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_machine_learning_import_tensorflow
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_machine_learning_import_tensorflow" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_machine_learning_import_tensorflow"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_machine_learning_import_tensorflow.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_machine_learning_tip_amounts
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_machine_learning_tip_amounts" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_machine_learning_tip_amounts"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_machine_learning_tip_amounts.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_materialized_views_joins
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_materialized_views_joins" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_materialized_views_joins"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_materialized_views_joins.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_security_col_encryption_shredding
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_security_col_encryption_shredding" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_security_col_encryption_shredding"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_security_col_encryption_shredding.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_security
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_security" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_security"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_security.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_taxi_streaming_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_taxi_streaming_data" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_taxi_streaming_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_taxi_streaming_data.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_time_travel_snapshots
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_time_travel_snapshots" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_time_travel_snapshots"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_time_travel_snapshots.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# sp_demo_transactions
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_transactions" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_transactions"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/taxi_dataset/sp_demo_transactions.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


#===================================================================================
#===================================================================================
# thelook_ecommerce Dataset
#===================================================================================
#===================================================================================


####################################################################################
# churn_demo_step_0_create_artifacts
####################################################################################
resource "google_bigquery_routine" "sproc_churn_demo_step_0_create_artifacts" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_0_create_artifacts"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/churn_demo_step_0_create_artifacts.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# churn_demo_step_1_train_classifier
####################################################################################
resource "google_bigquery_routine" "sproc_churn_demo_step_1_train_classifier" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_1_train_classifier"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/churn_demo_step_1_train_classifier.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    project_number = var.project_number
  })
}


####################################################################################
# churn_demo_step_2_evaluate
####################################################################################
resource "google_bigquery_routine" "sproc_churn_demo_step_2_evaluate" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_2_evaluate"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/churn_demo_step_2_evaluate.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# churn_demo_step_3_predict
####################################################################################
resource "google_bigquery_routine" "sproc_churn_demo_step_3_predict" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_3_predict"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/churn_demo_step_3_predict.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# demo_queries
####################################################################################
resource "google_bigquery_routine" "sproc_demo_queries" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "demo_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/demo_queries.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  })
}

####################################################################################
# create_product_deliveries
####################################################################################
resource "google_bigquery_routine" "sproc_create_product_deliveries" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "create_product_deliveries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/create_product_deliveries.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}

####################################################################################
# create_thelook_tables
####################################################################################
resource "google_bigquery_routine" "sproc_create_thelook_tables" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "create_thelook_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  arguments {
    name = "bigquery_region"
    data_type = "{\"typeKind\" :  \"STRING\"}"
  }   
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/create_thelook_tables.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


####################################################################################
# create_product_deliveries_streaming
####################################################################################
resource "google_bigquery_routine" "sproc_create_product_deliveries_streaming" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "create_product_deliveries_streaming"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/thelook_ecommerce/create_product_deliveries_streaming.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}


#===================================================================================
#===================================================================================
# AWS Dataset
#===================================================================================
#===================================================================================


####################################################################################
# sp_demo_aws_omni_create_tables
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_create_tables" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_create_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_create_tables.sql", 
  { 
    project_id = var.project_id
    
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  })
}


####################################################################################
# sp_demo_aws_omni_delta_lake
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_delta_lake" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_delta_lake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_delta_lake.sql", 
  { 
    project_id = var.project_id
    
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  })
}


####################################################################################
# sp_demo_aws_omni_queries
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_queries" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_queries.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset           = var.bigquery_taxi_dataset
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  })
}


####################################################################################
# sp_demo_aws_omni_security_cls
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_security_cls" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_security_cls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_security_cls.sql", 
  { 
    project_id                      = var.project_id
    random_extension                = var.random_extension
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                = var.gcp_account_name
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  })
}


####################################################################################
# sp_demo_aws_omni_security_rls
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_security_rls" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_security_rls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_security_rls.sql", 
  { 
    project_id = var.project_id
    
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                =  var.gcp_account_name
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  })
}


#===================================================================================
#===================================================================================
# Azure Dataset
#===================================================================================
#===================================================================================


####################################################################################
# sp_demo_azure_omni_create_tables
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_create_tables" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_create_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_create_tables.sql", 
  { 
    project_id = var.project_id
    
    shared_demo_project_id          = var.shared_demo_project_id
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  })
}


####################################################################################
# sp_demo_azure_omni_delta_lake
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_delta_lake" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_delta_lake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_delta_lake.sql", 
  { 
    project_id = var.project_id
    
    shared_demo_project_id          = var.shared_demo_project_id
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  })
}


####################################################################################
# sp_demo_azure_omni_queries
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_queries" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_queries.sql", 
  { 
    project_id = var.project_id
    
    bigquery_taxi_dataset           = var.bigquery_taxi_dataset
    shared_demo_project_id          = var.shared_demo_project_id
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  })
}


####################################################################################
# sp_demo_azure_omni_security_cls
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_security_cls" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_security_cls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_security_cls.sql", 
  { 
    project_id                      = var.project_id
    random_extension                = var.random_extension
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                = var.gcp_account_name
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  })
}


####################################################################################
# sp_demo_azure_omni_security_rls
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_security_rls" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_security_rls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_security_rls.sql", 
  { 
    project_id = var.project_id
    
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                =  var.gcp_account_name
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  })
}



#===================================================================================
#===================================================================================
# Rideshare Lakehouse Raw Dataset
#===================================================================================
#===================================================================================

####################################################################################
# sp_create_biglake_object_table
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_biglake_object_table" {
  dataset_id      = var.bigquery_rideshare_lakehouse_raw_dataset
  routine_id      = "sp_create_biglake_object_table"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_raw/sp_create_biglake_object_table.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_create_biglake_tables
####################################################################################
resource "google_bigquery_routine" "sproc_sproc_sp_create_biglake_tables" {
  dataset_id      = var.bigquery_rideshare_lakehouse_raw_dataset
  routine_id      = "sproc_sp_create_biglake_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_raw/sp_create_biglake_tables.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })

}


####################################################################################
# sp_create_raw_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_raw_data" {
  dataset_id      = var.bigquery_rideshare_lakehouse_raw_dataset
  routine_id      = "sp_create_raw_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_raw/sp_create_raw_data.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })

}


####################################################################################
# sp_create_streaming_view
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_streaming_view_raw" {
  dataset_id      = var.bigquery_rideshare_lakehouse_raw_dataset
  routine_id      = "sp_create_streaming_view"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_raw/sp_create_streaming_view.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


#===================================================================================
#===================================================================================
# Rideshare Lakehouse Enriched Dataset
#===================================================================================
#===================================================================================

####################################################################################
# sp_create_streaming_view
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_streaming_view_enriched" {
  dataset_id      = var.bigquery_rideshare_lakehouse_enriched_dataset
  routine_id      = "sp_create_streaming_view"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_enriched/sp_create_streaming_view.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket  
  })

}


####################################################################################
# sp_iceberg_spark_transformation
# NOTE: This is a BigSpark stored procedure (which currently does not have t
#       terraform support).  The Spark specific elements have been commented out.data "
#       Also, currently BigSpark requires allow listing
####################################################################################
resource "google_bigquery_routine" "sproc_sp_iceberg_spark_transformation" {
  dataset_id      = var.bigquery_rideshare_lakehouse_enriched_dataset
  routine_id      = "sp_iceberg_spark_transformation"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_enriched/sp_iceberg_spark_transformation.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_process_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_process_data_enriched" {
  dataset_id      = var.bigquery_rideshare_lakehouse_enriched_dataset
  routine_id      = "sp_process_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_enriched/sp_process_data.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_unstructured_data_analysis
####################################################################################
resource "google_bigquery_routine" "sproc_sp_unstructured_data_analysis" {
  dataset_id      = var.bigquery_rideshare_lakehouse_enriched_dataset
  routine_id      = "sp_unstructured_data_analysis"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_enriched/sp_unstructured_data_analysis.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket 
  })
}


#===================================================================================
#===================================================================================
# Rideshare Lakehouse Curated Dataset
#===================================================================================
#===================================================================================


####################################################################################
# sp_create_looker_studio_view
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_looker_studio_view" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_create_looker_studio_view"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_create_looker_studio_view.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_create_streaming_view
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_streaming_view" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_create_streaming_view"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_create_streaming_view.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_create_website_realtime_dashboard
####################################################################################
resource "google_bigquery_routine" "sproc_sp_create_website_realtime_dashboard" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_create_website_realtime_dashboard"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_create_website_realtime_dashboard.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_demo_data_quality_columns
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_data_quality_columns_rideshare" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_demo_data_quality_columns"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_demo_data_quality_columns.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_demo_data_quality_table
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_data_quality_table_curated" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_demo_data_quality_table"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_demo_data_quality_table.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_demo_script
####################################################################################
resource "google_bigquery_routine" "sproc_sp_demo_script" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_demo_script"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_demo_script.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_model_training
####################################################################################
resource "google_bigquery_routine" "sproc_sp_model_training" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_model_training"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_model_training.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket   
  })
}


####################################################################################
# sp_process_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_process_data_curated" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_process_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_process_data.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket  
  })
}


####################################################################################
# sp_website_score_data
####################################################################################
resource "google_bigquery_routine" "sproc_sp_website_score_data" {
  dataset_id      = var.bigquery_rideshare_lakehouse_curated_dataset
  routine_id      = "sp_website_score_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  arguments {
    name = "ride_distance"
    data_type = "{\"typeKind\" :  \"STRING\"}"
  }   
  arguments {
    name = "is_raining"
    data_type = "{\"typeKind\" :  \"BOOL\"}"
  }   
  arguments {
    name = "is_snowing"
    data_type = "{\"typeKind\" :  \"BOOL\"}"
  }     
  arguments {
    name = "people_traveling_cnt"
    data_type = "{\"typeKind\" :  \"INT64\"}"
  }    
  arguments {
    name = "people_cnt"
    data_type = "{\"typeKind\" :  \"INT64\"}"
  }      
  definition_body = templatefile("../sql-scripts/rideshare_lakehouse_curated/sp_website_score_data.sql", 
  { 
    project_id = var.project_id
    project_number = var.project_number
    
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    bigquery_rideshare_lakehouse_raw_dataset = var.bigquery_rideshare_lakehouse_raw_dataset
    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket
    bigquery_rideshare_lakehouse_enriched_dataset = var.bigquery_rideshare_lakehouse_enriched_dataset
    gcs_rideshare_lakehouse_enriched_bucket = var.gcs_rideshare_lakehouse_enriched_bucket
    bigquery_rideshare_lakehouse_curated_dataset = var.bigquery_rideshare_lakehouse_curated_dataset
    gcs_rideshare_lakehouse_curated_bucket = var.gcs_rideshare_lakehouse_curated_bucket  
  })
}
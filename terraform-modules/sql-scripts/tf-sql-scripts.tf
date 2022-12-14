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
variable "region" {}
variable "zone" {}
variable "storage_bucket" {}
variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "bigquery_region" {}
variable "shared_demo_project_id" {}
variable "aws_omni_biglake_dataset_name" {}
variable "aws_omni_biglake_dataset_region" {}
variable "aws_omni_biglake_connection" {}
variable "aws_omni_biglake_s3_bucket" {}
variable "azure_omni_biglake_dataset_name" {}
variable "azure_omni_biglake_connection" {}
variable "azure_omni_biglake_adls_name" {}

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
data "template_file" "sproc_sp_create_demo_dataform" {
  template = "${file("../sql-scripts/taxi_dataset/sp_create_demo_dataform.sql")}"
  vars = {
    project_id = var.project_id
    project_number = var.project_number
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_create_demo_dataform" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_demo_dataform"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_create_demo_dataform.rendered}"
}


####################################################################################
# sp_create_taxi_external_tables
####################################################################################
data "template_file" "sproc_sp_create_taxi_external_tables" {
  template = "${file("../sql-scripts/taxi_dataset/sp_create_taxi_external_tables.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_create_taxi_external_tables" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_taxi_external_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_create_taxi_external_tables.rendered}"
}


####################################################################################
# sp_create_taxi_internal_tables
####################################################################################
data "template_file" "sproc_sp_create_taxi_internal_tables" {
  template = "${file("../sql-scripts/taxi_dataset/sp_create_taxi_internal_tables.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_create_taxi_internal_tables" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_create_taxi_internal_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_create_taxi_internal_tables.rendered}"
}




####################################################################################
# sp_demo_biglake
####################################################################################
data "template_file" "sproc_sp_demo_biglake" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_biglake.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
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
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_biglake" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_biglake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_biglake.rendered}"
}

####################################################################################
# sp_demo_bigquery_pricing
####################################################################################
data "template_file" "sproc_sp_demo_bigquery_pricing" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_bigquery_pricing.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_bigquery_pricing" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_bigquery_pricing"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_bigquery_pricing.rendered}"
}


####################################################################################
# sp_demo_bigquery_queries
####################################################################################
data "template_file" "sproc_sp_demo_bigquery_queries" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_bigquery_queries.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_bigquery_queries" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_bigquery_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_bigquery_queries.rendered}"
}


####################################################################################
# sp_demo_bigsearch
####################################################################################
data "template_file" "sproc_sp_demo_bigsearch" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_bigsearch.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id = var.shared_demo_project_id
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_bigsearch" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_bigsearch"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_bigsearch.rendered}"
}


####################################################################################
# sp_demo_data_quality_columns
####################################################################################
data "template_file" "sproc_sp_demo_data_quality_columns" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_data_quality_columns.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id = var.shared_demo_project_id
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_data_quality_columns" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_data_quality_columns"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_data_quality_columns.rendered}"
}


####################################################################################
# sp_demo_data_quality_table
####################################################################################
data "template_file" "sproc_sp_demo_data_quality_table" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_data_quality_table.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
    shared_demo_project_id = var.shared_demo_project_id
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_data_quality_table" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_data_quality_table"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_data_quality_table.rendered}"
}


####################################################################################
# sp_demo_data_transfer_service
####################################################################################
data "template_file" "sproc_sp_demo_data_transfer_service" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_data_transfer_service.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_data_transfer_service" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_data_transfer_service"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_data_transfer_service.rendered}"
}


####################################################################################
# sp_demo_datastudio_report
####################################################################################
data "template_file" "sproc_sp_demo_datastudio_report" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_datastudio_report.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_datastudio_report" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_datastudio_report"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_datastudio_report.rendered}"
}


####################################################################################
# sp_demo_delta_lake
####################################################################################
data "template_file" "sproc_sp_demo_delta_lake" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_delta_lake.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_delta_lake" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_delta_lake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_delta_lake.rendered}"
}


####################################################################################
# sp_demo_export_weather_data
####################################################################################
data "template_file" "sproc_sp_demo_export_weather_data" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_export_weather_data.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_export_weather_data" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_export_weather_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_export_weather_data.rendered}"
}



####################################################################################
# sp_demo_external_function
####################################################################################
data "template_file" "sproc_sp_demo_external_function" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_external_function.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_external_function" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_external_function"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_external_function.rendered}"
}


####################################################################################
# sp_demo_federated_query
####################################################################################
data "template_file" "sproc_sp_demo_federated_query" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_federated_query.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_federated_query" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_federated_query"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_federated_query.rendered}"
}


####################################################################################
# sp_demo_ingest_data
####################################################################################
data "template_file" "sproc_sp_demo_ingest_data" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_ingest_data.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    raw_bucket_name = "raw-${var.storage_bucket}"
    processed_bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_ingest_data" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_ingest_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_ingest_data.rendered}"
}



####################################################################################
# sp_demo_internal_external_table_join
####################################################################################
data "template_file" "sproc_sp_demo_internal_external_table_join" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_internal_external_table_join.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_internal_external_table_join" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_internal_external_table_join"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_internal_external_table_join.rendered}"
}


####################################################################################
# sp_demo_json_datatype
####################################################################################
data "template_file" "sproc_sp_demo_json_datatype" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_json_datatype.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    processed_bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_json_datatype" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_json_datatype"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_json_datatype.rendered}"
}


####################################################################################
# sp_demo_machine_learning_anomaly_fee_amount
####################################################################################
data "template_file" "sproc_sp_demo_machine_learning_anomaly_fee_amount" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_machine_learning_anomaly_fee_amount.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_machine_learning_anomaly_fee_amount" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_machine_learning_anomaly_fee_amount"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_machine_learning_anomaly_fee_amount.rendered}"
}


####################################################################################
# sp_demo_machine_learning_import_tensorflow
####################################################################################
data "template_file" "sproc_sp_demo_machine_learning_import_tensorflow" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_machine_learning_import_tensorflow.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_machine_learning_import_tensorflow" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_machine_learning_import_tensorflow"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_machine_learning_import_tensorflow.rendered}"
}


####################################################################################
# sp_demo_machine_learning_tip_amounts
####################################################################################
data "template_file" "sproc_sp_demo_machine_learning_tip_amounts" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_machine_learning_tip_amounts.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_machine_learning_tip_amounts" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_machine_learning_tip_amounts"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_machine_learning_tip_amounts.rendered}"
}


####################################################################################
# sp_demo_materialized_views_joins
####################################################################################
data "template_file" "sproc_sp_demo_materialized_views_joins" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_materialized_views_joins.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_materialized_views_joins" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_materialized_views_joins"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_materialized_views_joins.rendered}"
}


####################################################################################
# sp_demo_security_col_encryption_shredding
####################################################################################
data "template_file" "sproc_sp_demo_security_col_encryption_shredding" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_security_col_encryption_shredding.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_security_col_encryption_shredding" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_security_col_encryption_shredding"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_security_col_encryption_shredding.rendered}"
}


####################################################################################
# sp_demo_security
####################################################################################
data "template_file" "sproc_sp_demo_security" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_security.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_security" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_security"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_security.rendered}"
}


####################################################################################
# sp_demo_taxi_streaming_data
####################################################################################
data "template_file" "sproc_sp_demo_taxi_streaming_data" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_taxi_streaming_data.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_taxi_streaming_data" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_taxi_streaming_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_taxi_streaming_data.rendered}"
}


####################################################################################
# sp_demo_time_travel_snapshots
####################################################################################
data "template_file" "sproc_sp_demo_time_travel_snapshots" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_time_travel_snapshots.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_time_travel_snapshots" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_time_travel_snapshots"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_time_travel_snapshots.rendered}"
}


####################################################################################
# sp_demo_transactions
####################################################################################
data "template_file" "sproc_sp_demo_transactions" {
  template = "${file("../sql-scripts/taxi_dataset/sp_demo_transactions.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_transactions" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "sp_demo_transactions"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_transactions.rendered}"
}


#===================================================================================
#===================================================================================
# thelook_ecommerce Dataset
#===================================================================================
#===================================================================================


####################################################################################
# churn_demo_step_0_create_artifacts
####################################################################################
data "template_file" "sproc_churn_demo_step_0_create_artifacts" {
  template = "${file("../sql-scripts/thelook_ecommerce/churn_demo_step_0_create_artifacts.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_churn_demo_step_0_create_artifacts" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_0_create_artifacts"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_churn_demo_step_0_create_artifacts.rendered}"
}


####################################################################################
# churn_demo_step_1_train_classifier
####################################################################################
data "template_file" "sproc_churn_demo_step_1_train_classifier" {
  template = "${file("../sql-scripts/thelook_ecommerce/churn_demo_step_1_train_classifier.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name

    project_number = var.project_number
  }  
}
resource "google_bigquery_routine" "sproc_churn_demo_step_1_train_classifier" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_1_train_classifier"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_churn_demo_step_1_train_classifier.rendered}"
}


####################################################################################
# churn_demo_step_2_evaluate
####################################################################################
data "template_file" "sproc_churn_demo_step_2_evaluate" {
  template = "${file("../sql-scripts/thelook_ecommerce/churn_demo_step_2_evaluate.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_churn_demo_step_2_evaluate" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_2_evaluate"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_churn_demo_step_2_evaluate.rendered}"
}


####################################################################################
# churn_demo_step_3_predict
####################################################################################
data "template_file" "sproc_churn_demo_step_3_predict" {
  template = "${file("../sql-scripts/thelook_ecommerce/churn_demo_step_3_predict.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_churn_demo_step_3_predict" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "churn_demo_step_3_predict"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_churn_demo_step_3_predict.rendered}"
}


####################################################################################
# demo_queries
####################################################################################
data "template_file" "sproc_demo_queries" {
  template = "${file("../sql-scripts/thelook_ecommerce/demo_queries.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
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
  }  
}
resource "google_bigquery_routine" "sproc_demo_queries" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "demo_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_demo_queries.rendered}"
}

####################################################################################
# create_product_deliveries
####################################################################################
data "template_file" "sproc_create_product_deliveries" {
  template = "${file("../sql-scripts/thelook_ecommerce/create_product_deliveries.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_create_product_deliveries" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "create_product_deliveries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_create_product_deliveries.rendered}"
}

####################################################################################
# create_thelook_tables
####################################################################################
data "template_file" "sproc_create_thelook_tables" {
  template = "${file("../sql-scripts/thelook_ecommerce/create_thelook_tables.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_create_thelook_tables" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "create_thelook_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  arguments {
    name = "bigquery_region"
    data_type = "{\"typeKind\" :  \"STRING\"}"
  }   
  definition_body = "${data.template_file.sproc_create_thelook_tables.rendered}"
}


####################################################################################
# create_product_deliveries_streaming
####################################################################################
data "template_file" "sproc_create_product_deliveries_streaming" {
  template = "${file("../sql-scripts/thelook_ecommerce/create_product_deliveries_streaming.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = "processed-${var.storage_bucket}"
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  }  
}
resource "google_bigquery_routine" "sproc_create_product_deliveries_streaming" {
  dataset_id      = var.bigquery_thelook_ecommerce_dataset
  routine_id      = "create_product_deliveries_streaming"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_create_product_deliveries_streaming.rendered}"
}


#===================================================================================
#===================================================================================
# AWS Dataset
#===================================================================================
#===================================================================================


####################################################################################
# sp_demo_aws_omni_create_tables
####################################################################################
data "template_file" "sproc_sp_demo_aws_omni_create_tables" {
  template = "${file("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_create_tables.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_create_tables" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_create_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_aws_omni_create_tables.rendered}"
}


####################################################################################
# sp_demo_aws_omni_delta_lake
####################################################################################
data "template_file" "sproc_sp_demo_aws_omni_delta_lake" {
  template = "${file("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_delta_lake.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_delta_lake" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_delta_lake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_aws_omni_delta_lake.rendered}"
}


####################################################################################
# sp_demo_aws_omni_queries
####################################################################################
data "template_file" "sproc_sp_demo_aws_omni_queries" {
  template = "${file("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_queries.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset           = var.bigquery_taxi_dataset
    shared_demo_project_id          = var.shared_demo_project_id
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_queries" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_aws_omni_queries.rendered}"
}


####################################################################################
# sp_demo_aws_omni_security_cls
####################################################################################
data "template_file" "sproc_sp_demo_aws_omni_security_cls" {
  template = "${file("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_security_cls.sql")}"
  vars = {
    project_id                      = var.project_id
    region                          = var.region
    random_extension                = var.random_extension
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                = var.gcp_account_name
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_security_cls" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_security_cls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_aws_omni_security_cls.rendered}"
}


####################################################################################
# sp_demo_aws_omni_security_rls
####################################################################################
data "template_file" "sproc_sp_demo_aws_omni_security_rls" {
  template = "${file("../sql-scripts/aws_omni_biglake/sp_demo_aws_omni_security_rls.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                =  var.gcp_account_name
    aws_omni_biglake_dataset_region = var.aws_omni_biglake_dataset_region
    aws_omni_biglake_dataset_name   = var.aws_omni_biglake_dataset_name
    aws_omni_biglake_connection     = var.aws_omni_biglake_connection
    aws_omni_biglake_s3_bucket      = var.aws_omni_biglake_s3_bucket
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_aws_omni_security_rls" {
  dataset_id      = var.aws_omni_biglake_dataset_name
  routine_id      = "sp_demo_aws_omni_security_rls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_aws_omni_security_rls.rendered}"
}


#===================================================================================
#===================================================================================
# Azure Dataset
#===================================================================================
#===================================================================================


####################################################################################
# sp_demo_azure_omni_create_tables
####################################################################################
data "template_file" "sproc_sp_demo_azure_omni_create_tables" {
  template = "${file("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_create_tables.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    shared_demo_project_id          = var.shared_demo_project_id
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_create_tables" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_create_tables"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_azure_omni_create_tables.rendered}"
}


####################################################################################
# sp_demo_azure_omni_delta_lake
####################################################################################
data "template_file" "sproc_sp_demo_azure_omni_delta_lake" {
  template = "${file("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_delta_lake.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    shared_demo_project_id          = var.shared_demo_project_id
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_delta_lake" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_delta_lake"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_azure_omni_delta_lake.rendered}"
}


####################################################################################
# sp_demo_azure_omni_queries
####################################################################################
data "template_file" "sproc_sp_demo_azure_omni_queries" {
  template = "${file("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_queries.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset           = var.bigquery_taxi_dataset
    shared_demo_project_id          = var.shared_demo_project_id
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_queries" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_queries"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_azure_omni_queries.rendered}"
}


####################################################################################
# sp_demo_azure_omni_security_cls
####################################################################################
data "template_file" "sproc_sp_demo_azure_omni_security_cls" {
  template = "${file("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_security_cls.sql")}"
  vars = {
    project_id                      = var.project_id
    region                          = var.region
    random_extension                = var.random_extension
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                = var.gcp_account_name
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_security_cls" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_security_cls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_azure_omni_security_cls.rendered}"
}


####################################################################################
# sp_demo_azure_omni_security_rls
####################################################################################
data "template_file" "sproc_sp_demo_azure_omni_security_rls" {
  template = "${file("../sql-scripts/azure_omni_biglake/sp_demo_azure_omni_security_rls.sql")}"
  vars = {
    project_id = var.project_id
    region = var.region
    shared_demo_project_id          = var.shared_demo_project_id
    gcp_account_name                =  var.gcp_account_name
    azure_omni_biglake_dataset_name = var.azure_omni_biglake_dataset_name
    azure_omni_biglake_adls_name    = var.azure_omni_biglake_adls_name
    azure_omni_biglake_connection   = var.azure_omni_biglake_connection
  }  
}
resource "google_bigquery_routine" "sproc_sp_demo_azure_omni_security_rls" {
  dataset_id      = var.azure_omni_biglake_dataset_name
  routine_id      = "sp_demo_azure_omni_security_rls"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_sp_demo_azure_omni_security_rls.rendered}"
}

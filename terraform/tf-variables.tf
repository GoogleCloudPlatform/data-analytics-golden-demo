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
# Variables (Set in the ../terraform.tfvars.json file) or passed viw command line
####################################################################################

# CONDITIONS: (Always Required)
variable "gcp_account_name" {
  type        = string
  description = "This is the name of the user who be running the demo.  It is used to set security items. (e.g. admin@mydomain.com)"
  validation {
    condition     = length(var.gcp_account_name) > 0
    error_message = "The gcp_account_name is required."
  }
}


# CONDITIONS: (Always Required)
variable "project_id" {
  type        = string
  description = "The GCP Project Id/Name or the Prefix of a name to generate (e.g. data-analytics-demo-xxxxxxxxxx)."
  validation {
    condition     = length(var.project_id) > 0
    error_message = "The project_id is required."
  }
}


# CONDITIONS: (Only If) a GCP Project has already been created.  Otherwise it is not required.
variable "project_number" {
  type        = string
  description = "The GCP Project Number"
  default     = ""
}


# CONDITIONS: (Only If) you have a service account doing the deployment (from DevOps)
variable "deployment_service_account_name" {
  type        = string
  description = "The name of the service account that is doing the deployment.  If empty then the script is creatign a service account."
  default     = ""
}


# CONDITIONS: (Always Required)
variable "org_id" {
  type        = string
  description = "This is org id for the deployment"
  default     = ""
  validation {
    condition     = length(var.org_id) > 0
    error_message = "The org_id is required."
  }
}


# CONDITIONS: (Only If) the project_number is NOT provided and Terraform will be creating the GCP project for you
variable "billing_account" {
  type        = string
  description = "This is the name of the user who the deploy is for.  It is used to set security items for the user/developer. (e.g. admin@mydomain.com)"
  default     = ""
}


# CONDITIONS: (Optional) unless you want a different region/zone
variable "default_region" {
  type        = string
  description = "The GCP region to deploy."
  default     = "us-central1"
  validation {
    condition     = length(var.default_region) > 0
    error_message = "The region is required."
  }
}

variable "default_zone" {
  type        = string
  description = "The GCP zone in the region. Must be in the region."
  default     = "us-central1-a"
  validation {
    condition     = length(var.default_zone) > 0
    error_message = "The zone is required."
  }
}


###############
variable "composer_region" {
  type        = string
  description = "The GCP region for composer."
  default     = "us-west3"
  validation {
    condition     = length(var.composer_region) > 0
    error_message = "The composer region is required."
  }
}

variable "dataform_region" {
  type        = string
  description = "The GCP region for dataform."
  default     = "us-central1"
  validation {
    condition     = length(var.dataform_region) > 0
    error_message = "The dataform region is required."
  }
}

variable "dataplex_region" {
  type        = string
  description = "The GCP region for dataplex."
  default     = "us-central1"
  validation {
    condition     = length(var.dataplex_region) > 0
    error_message = "The dataplex region is required."
  }
}

variable "dataproc_region" {
  type        = string
  description = "The GCP region for dataproc."
  default     = "us-central1"
  validation {
    condition     = length(var.dataproc_region) > 0
    error_message = "The dataproc region is required."
  }
}

variable "dataflow_region" {
  type        = string
  description = "The GCP region for dataflow."
  default     = "us-central1"
  validation {
    condition     = length(var.dataflow_region) > 0
    error_message = "The dataflow region is required."
  }
}

variable "bigquery_region" {
  type        = string
  description = "The GCP region to deploy BigQuery.  This should either match the region or be 'us' or 'eu'.  This also affects the GCS bucket and Data Catalog."
  default     = "us"
  validation {
    condition     = length(var.bigquery_region) > 0
    error_message = "The bigquery region is required."
  }
}

variable "bigquery_non_multi_region" {
  type        = string
  description = "The GCP region that is not multi-region for BigQuery"
  default     = "us-central1"
  validation {
    condition     = length(var.bigquery_non_multi_region) > 0
    error_message = "The bigquery (non-multi) region is required."
  }
}

# If you change this you shoud change spanner_config
variable "spanner_region" {
  type        = string
  description = "The GCP region for the main Spanner node."
  default     = "us-west3"
  validation {
    condition     = length(var.spanner_region) > 0
    error_message = "The spanner region is required."
  }
}

# If you change this you shoud change spanner_region
variable "spanner_config" {
  type        = string
  description = "This should be a spanner config in the region.  See: https://cloud.google.com/spanner/docs/instance-configurations#available-configurations-multi-region"
  default     = "nam8"
  validation {
    condition     = length(var.spanner_config) > 0
    error_message = "The spanner_config is required."
  }
}


variable "datafusion_region" {
  type        = string
  description = "The GCP region for the datafusion."
  default     = "us-central1"
  validation {
    condition     = length(var.datafusion_region) > 0
    error_message = "The datafusion region is required."
  }
}


variable "vertex_ai_region" {
  type        = string
  description = "The GCP region for the vertex ai."
  default     = "us-central1"
  validation {
    condition     = length(var.vertex_ai_region) > 0
    error_message = "The vertex ai region is required."
  }
}

# Should match BigQuery region (non-multiregion)
variable "cloud_function_region" {
  type        = string
  description = "The GCP region for the cloud function."
  default     = "us-central1"
  validation {
    condition     = length(var.cloud_function_region) > 0
    error_message = "The cloud function region is required."
  }
}

variable "data_catalog_region" {
  type        = string
  description = "The GCP region for data catalog items (tag templates)."
  default     = "us-central1"
  validation {
    condition     = length(var.data_catalog_region) > 0
    error_message = "The data catalog region is required."
  }
}

variable "appengine_region" {
  type        = string
  description = "The GCP region for the app engine."
  default     = "us-central"
  validation {
    condition     = length(var.appengine_region) > 0
    error_message = "The app engine region is required."
  }
}

variable "dataproc_serverless_region" {
  type        = string
  description = "The GCP region for dataproc serverless (should match dataplex)."
  default     = "us-central1"
  validation {
    condition     = length(var.dataproc_serverless_region) > 0
    error_message = "The dataproc serverless region is required."
  }
}

variable "cloud_sql_region" {
  type        = string
  description = "The GCP region for Cloud SQL."
  default     = "us-west3"
  validation {
    condition     = length(var.cloud_sql_region) > 0
    error_message = "The Cloud SQL region is required."
  }
}

variable "cloud_sql_zone" {
  type        = string
  description = "The GCP zone for Cloud SQL and Datastream reverse proxy."
  default     = "us-west3-a"
  validation {
    condition     = length(var.cloud_sql_zone) > 0
    error_message = "The Cloud SQL zone is required."
  }
}

# This is in the Airflow data directory
# The IP (allowlist) are hardcoded
variable "datastream_region" {
  type        = string
  description = "The GCP region for Datastream (should match cloud sql region)."
  default     = "us-west3"
  validation {
    condition     = length(var.datastream_region) > 0
    error_message = "The Datastream region is required."
  }
}

variable "colab_enterprise_region" {
  type        = string
  description = "The GCP region for Colab Enterprise (should be close to your BigQuery region)."
  default     = "us-central1"
  validation {
    condition     = length(var.colab_enterprise_region) > 0
    error_message = "The Colal Enterprise region is required."
  }
}


########################################################################################################
# Google specific values (you need to setup your own OMNI)
########################################################################################################
variable "shared_demo_project_id" {
  type        = string
  description = "The name of a shared project that holds the OMNI slots and other sample data "
  default     = "REPLACE_ME_SHARED_DEMO_PROJECT_ID"
}

variable "aws_omni_biglake_dataset_region" {
  type        = string
  description = "The region of AWS OMNI"
  default     = "aws-us-east-1"
}

variable "aws_omni_biglake_dataset_name" {
  type        = string
  description = "The dataset to hold the AWS procedures and tables"
  default     = "aws_omni_biglake"
}

variable "aws_omni_biglake_connection" {
  type        = string
  description = "The AWS connection name"
  default     = "bq_omni_aws_s3"
}

variable "aws_omni_biglake_s3_bucket" {
  type        = string
  description = "The name of the S3 bucket"
  default     = "REPLACE_ME_AWS_S3_BUCKET_NAME"
}

variable "azure_omni_biglake_adls_name" {
  type        = string
  description = "The name of the S3 bucket"
  default     = "REPLACE_ME_AZURE_ADLS_NAME"
}

variable "azure_omni_biglake_dataset_name" {
  type        = string
  description = "The name of the Azure dataset"
  default     = "azure_omni_biglake"
}

variable "azure_omni_biglake_dataset_region" {
  type        = string
  description = "The region of Azure OMNI"
  default     = "azure-eastus2"
}


########################################################################################################
# Some deployments target different environments
########################################################################################################
variable "environment" {
  type        = string
  description = "Where is the script being run from.  Internal system or public GitHub"
  default     = "GITHUB_ENVIRONMENT" #_REPLACEMENT_MARKER (do not remove this text of change the spacing)
}


########################################################################################################
# Not required for this demo, but is part of click to deploy automation
########################################################################################################
variable "data_location" {
  type        = string
  description = "Location of source data file in central bucket"
  default     = ""
}
variable "secret_stored_project" {
  type        = string
  description = "Project where secret is accessing from"
  default     = ""
}
variable "project_name" {
  type        = string
  description = "Project name in which demo deploy"
  default     = ""
}


####################################################################################
# Local Variables 
####################################################################################

# Create a random string for the project/bucket suffix
resource "random_string" "project_random" {
  length  = 10
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  # The project is the provided name OR the name with a random suffix
  local_project_id = var.project_number == "" ? "${var.project_id}-${random_string.project_random.result}" : var.project_id

  # Apply suffix to bucket so the name is unique
  local_storage_bucket = "${var.project_id}-${random_string.project_random.result}"

  # Use the GCP user or the service account running this in a DevOps process
  local_impersonation_account = var.deployment_service_account_name == "" ? "user:${var.gcp_account_name}" : length(regexall("^serviceAccount:", var.deployment_service_account_name)) > 0 ? "${var.deployment_service_account_name}" : "serviceAccount:${var.deployment_service_account_name}"

  local_curl_impersonation = var.environment == "GITHUB_ENVIRONMENT" ? "--impersonate-service-account=${var.deployment_service_account_name}" : ""

  # Make sure you use a Federated Identity: https://cloud.google.com/bigquery/docs/omni-azure-create-connection#federated-identity
  local_azure_omni_biglake_connection = "projects/${var.shared_demo_project_id}/locations/${var.azure_omni_biglake_dataset_region}/connections/bq_omni_azure_adlsgen2 "
}

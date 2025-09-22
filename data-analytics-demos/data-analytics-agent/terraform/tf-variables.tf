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
  description = "The GCP Project Id/Name or the Prefix of a name to generate (e.g. data-analytics-agent-xxxxxxxxxx)."
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

variable "bigquery_agentic_beans_raw_dataset" {
  type        = string
  description = "The raw data for agentic beans.  This data has not been processed."
  default     = "agentic_beans_raw"
  validation {
    condition     = length(var.bigquery_agentic_beans_raw_dataset) > 0
    error_message = "The bigquery data dataset is required."
  }
}


variable "bigquery_agentic_beans_raw_staging_load_dataset" {
  type        = string
  description = "The dataset that contains data loaded directly without any transformations.  The data is then transformed and appended to the raw zone."
  default     = "agentic_beans_raw_staging_load"
  validation {
    condition     = length(var.bigquery_agentic_beans_raw_staging_load_dataset) > 0
    error_message = "The bigquery data dataset is required."
  }
}


variable "bigquery_agentic_beans_enriched_dataset" {
  type        = string
  description = "The enriched data for agentic beans.  This data has been enriched via transmations and AI."
  default     = "agentic_beans_enriched"
  validation {
    condition     = length(var.bigquery_agentic_beans_enriched_dataset) > 0
    error_message = "The bigquery data dataset is required."
  }
}


variable "bigquery_agentic_beans_curated_dataset" {
  type        = string
  description = "The final curated data for agentic beans.  This dataset should be used for analysis."
  default     = "agentic_beans_curated"
  validation {
    condition     = length(var.bigquery_agentic_beans_curated_dataset) > 0
    error_message = "The bigquery data dataset is required."
  }
}


variable "bigquery_agentic_beans_raw_us_dataset" {
  type        = string
  description = "A dataset used for weather data in the multi-region used for querying BigQuery public data."
  default     = "agentic_beans_raw_us"
  validation {
    condition     = length(var.bigquery_agentic_beans_raw_us_dataset) > 0
    error_message = "The bigquery data dataset is required."
  }
}


variable "bigquery_nyc_taxi_curated_dataset" {
  type        = string
  description = "A dataset used for the New York City taxi data."
  default     = "nyc_taxi_curated"
  validation {
    condition     = length(var.bigquery_nyc_taxi_curated_dataset) > 0
    error_message = "The bigquery taxi data dataset is required."
  }
}


variable "bigquery_data_analytics_agent_metadata_dataset" {
  type        = string
  description = "A dataset used for the agent for metadata."
  default     = "data_analytics_agent_metadata"
  validation {
    condition     = length(var.bigquery_data_analytics_agent_metadata_dataset) > 0
    error_message = "The bigquery agent metadata dataset is required."
  }
}





variable "multi_region" {
  type        = string
  description = "The GCP region to deploy BigQuery.  This should either match the region or be 'us' or 'eu'.  This also affects the GCS bucket and Data Catalog."
  default     = "us"
  validation {
    condition     = length(var.multi_region) > 0
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

variable "vertex_ai_region" {
  type        = string
  description = "The GCP region for the vertex ai."
  default     = "us-central1"
  validation {
    condition     = length(var.vertex_ai_region) > 0
    error_message = "The vertex ai region is required."
  }
}

variable "dataform_region" {
  type        = string
  description = "The GCP region for the dataform."
  default     = "us-central1"
  validation {
    condition     = length(var.dataform_region) > 0
    error_message = "The dataform region is required."
  }
}

variable "dataplex_region" {
  type        = string
  description = "The GCP region for the dataplex."
  default     = "us-central1"
  validation {
    condition     = length(var.dataplex_region) > 0
    error_message = "The dataplex region is required."
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

variable "colab_enterprise_region" {
  type        = string
  description = "The GCP region for Colab Enterprise (should be close to your BigQuery region)."
  default     = "us-central1"
  validation {
    condition     = length(var.colab_enterprise_region) > 0
    error_message = "The Colal Enterprise region is required."
  }
}

variable "dataflow_region" {
  type        = string
  description = "The GCP region for DataFlow (should be close to your BigQuery region)."
  default     = "us-central1"
  validation {
    condition     = length(var.dataflow_region) > 0
    error_message = "The DataFlow region is required."
  }
}

variable "kafka_region" {
  type        = string
  description = "The GCP region for Kafka (should be close to your BigQuery region)."
  default     = "us-central1"
  validation {
    condition     = length(var.kafka_region) > 0
    error_message = "The Kafka region is required."
  }
}

variable "cloud_run_region" {
  type        = string
  description = "The cloud run region."
  default     = "us-central1"
  validation {
    condition     = length(var.cloud_run_region) > 0
    error_message = "The Cloud Run region is required."
  }
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
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  # The project is the provided name OR the name with a random suffix
  local_project_id = var.project_number == "" ? "${var.project_id}-${random_string.project_random.result}" : var.project_id

  # Apply suffix to bucket so the name is unique
  data_analytics_agent_bucket = "data-analytics-agent-data-${random_string.project_random.result}"
  code_bucket = "data-analytics-agent-code-${random_string.project_random.result}"
  dataflow_staging_bucket = "dataflow-staging-${random_string.project_random.result}"

  # Use the GCP user or the service account running this in a DevOps process
  local_impersonation_account = var.deployment_service_account_name == "" ? "user:${var.gcp_account_name}" : length(regexall("^serviceAccount:", var.deployment_service_account_name)) > 0 ? "${var.deployment_service_account_name}" : "serviceAccount:${var.deployment_service_account_name}"
}

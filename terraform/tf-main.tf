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
# README
# This is the main entry point into the Terraform creation script
# This script can be run in a different ways:
#  1. Run "source deploy.sh" in the root folder (this for for when you run locally or cloud shell).
#     This will create the GCP project for you and deploy everything.  The logged in user needs to be
#     an Org Admin so the project can be created and permissions set.
#
#  2. If you have a GCP project already created you would run just by passing in the parameters.
#     Review the script deploy-use-existing-project.sh to see the requirements of what is
#     required items and permissions.
#     terraform apply \
#       -var="gcp_account_name=${gcp_account_name}" \
#       -var="project_id=${project_id}" \
#       -var="project_number=${project_number}" \
#       -var="deployment_service_account_name=${service_account_email}" \
#       -var="org_id=${org_id}"
#
# Review the parameters.  If a Project Number is passed in, it is assumed the GCP project has been created.
#
# Author: Adam Paternostro
#
# References:
# Terraform for Google: https://registry.terraform.io/providers/hashicorp/google/latest/docs
#                       https://www.terraform.io/language/resources/provisioners/local-exec
####################################################################################


terraform {
  required_providers {
    google = {
      source                = "hashicorp/google-beta"
      version               = ">= 4.52, < 6"
      configuration_aliases = [google.service_principal_impersonation]
    }
  }
}


####################################################################################
# Providers
# Multiple providers: https://www.terraform.io/language/providers/configuration
# The first is the default (who is logged in) and creates the project and service principal that provisions the resources
# The second is the service account created by the first and is used to create the resources
####################################################################################
# Default provider (uses the logged in user to create the project and service principal for deployment)
provider "google" {
  project = local.local_project_id
}


# Provider that uses service account impersonation (best practice - no exported secret keys to local computers)
provider "google" {
  alias                       = "service_principal_impersonation"
  impersonate_service_account = "${local.local_project_id}@${local.local_project_id}.iam.gserviceaccount.com"
  project                     = local.local_project_id
  region                      = var.default_region
  zone                        = var.default_zone
}


####################################################################################
# Reuseable Modules
####################################################################################
module "project" {
  # Run this as the currently logged in user or the service account (assuming DevOps)
  count           = var.project_number == "" ? 1 : 0
  source          = "../terraform-modules/project"
  project_id      = local.local_project_id
  org_id          = var.org_id
  billing_account = var.billing_account
}


module "service-account" {
  # This creates a service account to run portions of the following deploy by impersonating this account
  source                = "../terraform-modules/service-account"
  project_id            = local.local_project_id
  org_id                = var.org_id
  impersonation_account = local.local_impersonation_account 
  gcp_account_name      = var.gcp_account_name
  environment           = var.environment

  depends_on = [
    module.project
  ]
}


# Enable all the cloud APIs that will be used by using Batch Mode
# Batch mode is enabled on the provider (by default)
module "apis-batch-enable" {
  source = "../terraform-modules/apis-batch-enable"

  project_id                      = local.local_project_id
  project_number                  = var.project_number == "" ? module.project[0].output-project-number : var.project_number

  depends_on = [
    module.project,
    module.service-account
  ]
}

resource "time_sleep" "service_account_api_activation_time_delay" {
  create_duration = "120s"
  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable
  ]  
}


# Uses the new Org Policies method (when a project is created by TF)
module "org-policies" {
  count  = var.environment == "GITHUB_ENVIRONMENT" && var.org_id != "0" ? 1 : 0
  source = "../terraform-modules/org-policies"

  # Use Service Account Impersonation for this step. 
  # NOTE: This step must be done using a service account (a user account cannot change these policies)
  providers = { google = google.service_principal_impersonation }

  project_id = local.local_project_id

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay
  ]
}


# Uses the "Old" Org Policies methods (for when a project is created in advance)
# This is used since the method you cannot specify a project and some orgs deploy with a 
# cloud build account that is in a different domain/org
/*
module "org-policies-deprecated" {
  count  = var.project_number == "" ? 0 : 1
  source = "../terraform-modules/org-policies-deprecated"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  project_id = local.local_project_id

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay
  ]
}
*/

module "resources" {
  source = "../terraform-modules/resources"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  gcp_account_name                  = var.gcp_account_name
  project_id                        = local.local_project_id

  composer_region                   = var.composer_region
  dataform_region                   = var.dataform_region
  dataplex_region                   = var.dataplex_region
  dataproc_region                   = var.dataproc_region
  dataflow_region                   = var.dataflow_region
  bigquery_region                   = var.bigquery_region
  bigquery_non_multi_region         = var.bigquery_non_multi_region
  spanner_region                    = var.spanner_region
  datafusion_region                 = var.datafusion_region
  vertex_ai_region                  = var.vertex_ai_region
  cloud_function_region             = var.cloud_function_region
  data_catalog_region               = var.data_catalog_region
  appengine_region                  = var.appengine_region
  dataproc_serverless_region        = var.dataproc_serverless_region
  cloud_sql_region                  = var.cloud_sql_region
  cloud_sql_zone                    = var.cloud_sql_zone
  datastream_region                 = var.datastream_region
  colab_enterprise_region           = var.colab_enterprise_region

  storage_bucket                    = local.local_storage_bucket
  spanner_config                    = var.spanner_config
  random_extension                  = random_string.project_random.result
  project_number                    = var.project_number == "" ? module.project[0].output-project-number : var.project_number
  deployment_service_account_name   = var.deployment_service_account_name
  curl_impersonation                = local.local_curl_impersonation
  aws_omni_biglake_dataset_region   = var.aws_omni_biglake_dataset_region
  aws_omni_biglake_dataset_name     = var.aws_omni_biglake_dataset_name
  azure_omni_biglake_dataset_name   = var.azure_omni_biglake_dataset_name
  azure_omni_biglake_dataset_region = var.azure_omni_biglake_dataset_region
  terraform_service_account         = module.service-account.deployment_service_account

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay,
    module.org-policies,
  ]
}


####################################################################################
# Deploy BigQuery stored procedures / sql scripts
###################################################################################
module "sql-scripts" {
  source = "../terraform-modules/sql-scripts"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  gcp_account_name                              = var.gcp_account_name
  project_id                                    = local.local_project_id
  storage_bucket                                = local.local_storage_bucket
  random_extension                              = random_string.project_random.result
  project_number                                = var.project_number == "" ? module.project[0].output-project-number : var.project_number
  bigquery_region                               = var.bigquery_region
  spanner_region                                = var.spanner_region
  cloud_function_region                         = var.cloud_function_region
  deployment_service_account_name               = var.deployment_service_account_name
  shared_demo_project_id                        = var.shared_demo_project_id
  aws_omni_biglake_dataset_name                 = var.aws_omni_biglake_dataset_name
  aws_omni_biglake_dataset_region               = var.aws_omni_biglake_dataset_region
  aws_omni_biglake_connection                   = var.aws_omni_biglake_connection
  aws_omni_biglake_s3_bucket                    = var.aws_omni_biglake_s3_bucket
  azure_omni_biglake_dataset_name               = var.azure_omni_biglake_dataset_name
  azure_omni_biglake_connection                 = local.local_azure_omni_biglake_connection
  azure_omni_biglake_adls_name                  = var.azure_omni_biglake_adls_name
  bigquery_rideshare_lakehouse_raw_dataset      = module.resources.bigquery_rideshare_lakehouse_raw_dataset
  gcs_rideshare_lakehouse_raw_bucket            = module.resources.gcs_rideshare_lakehouse_raw_bucket
  bigquery_rideshare_lakehouse_enriched_dataset = module.resources.bigquery_rideshare_lakehouse_enriched_dataset
  gcs_rideshare_lakehouse_enriched_bucket       = module.resources.gcs_rideshare_lakehouse_enriched_bucket
  bigquery_rideshare_lakehouse_curated_dataset  = module.resources.bigquery_rideshare_lakehouse_curated_dataset
  gcs_rideshare_lakehouse_curated_bucket        = module.resources.gcs_rideshare_lakehouse_curated_bucket
  bigquery_rideshare_llm_raw_dataset            = module.resources.bigquery_rideshare_llm_raw_dataset
  bigquery_rideshare_llm_enriched_dataset       = module.resources.bigquery_rideshare_llm_enriched_dataset
  bigquery_rideshare_llm_curated_dataset        = module.resources.bigquery_rideshare_llm_curated_dataset

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay,
    module.org-policies,
    module.resources
  ]
}


# Deploy Dataform
module "dataform-module" {
  source = "../terraform-modules/dataform"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  project_id         = local.local_project_id
  project_number     = var.project_number == "" ? module.project[0].output-project-number : var.project_number
  dataform_region    = var.dataform_region
  storage_bucket     = local.local_storage_bucket
  curl_impersonation = local.local_curl_impersonation
  bigquery_region    = var.bigquery_region
  
  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay,
    module.org-policies,
    module.resources
  ]
}


# Upload files and scripts
module "deploy-files-module" {
  source = "../terraform-modules/deploy-files"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  project_id                      = local.local_project_id
  dataplex_region                 = var.dataplex_region
  storage_bucket                  = local.local_storage_bucket
  random_extension                = random_string.project_random.result
  deployment_service_account_name = var.deployment_service_account_name
  composer_name                   = module.resources.composer_env_name
  composer_dag_bucket             = module.resources.composer_env_dag_bucket
  demo_rest_api_service_uri       = module.resources.demo_rest_api_service_uri
  code_bucket_name                = module.resources.gcs_code_bucket

  bigquery_rideshare_llm_raw_dataset            = module.resources.bigquery_rideshare_llm_raw_dataset
  bigquery_rideshare_llm_enriched_dataset       = module.resources.bigquery_rideshare_llm_enriched_dataset
  bigquery_rideshare_llm_curated_dataset        = module.resources.bigquery_rideshare_llm_curated_dataset
  bigquery_region                               = var.bigquery_region
  gcs_rideshare_lakehouse_raw_bucket            = module.resources.gcs_rideshare_lakehouse_raw_bucket
  cloud_run_service_rideshare_plus_website_url  = module.resources.cloud_run_service_rideshare_plus_website_url

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay,
    module.org-policies,
    module.resources
  ]
}


####################################################################################
# Deploy notebooks to Colab (Dataform)
####################################################################################
module "deploy-notebooks-module" {
  source = "../terraform-modules/colab-deployment/terraform-module"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  project_id                              = local.local_project_id
  bigquery_rideshare_llm_raw_dataset      = module.resources.bigquery_rideshare_llm_raw_dataset
  bigquery_rideshare_llm_enriched_dataset = module.resources.bigquery_rideshare_llm_enriched_dataset
  bigquery_rideshare_llm_curated_dataset  = module.resources.bigquery_rideshare_llm_curated_dataset
  gcs_rideshare_lakehouse_raw_bucket      = module.resources.gcs_rideshare_lakehouse_raw_bucket
  storage_bucket                          = local.local_storage_bucket
  dataform_region                         = var.dataform_region
  cloud_function_region                   = var.cloud_function_region
  workflow_region                         = "us-central1"
  random_extension                        = random_string.project_random.result
  gcp_account_name                        = var.gcp_account_name
  curl_impersonation                      = local.local_curl_impersonation
  bigquery_region                         = var.bigquery_region

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay,
    module.org-policies,
    module.resources
  ]
}


####################################################################################
# Outputs (Gather from sub-modules)
# Not really needed, but are outputted for viewing
####################################################################################
output "gcp_account_name" {
  value = var.gcp_account_name
}

output "project_id" {
  value = local.local_project_id
}

output "project_number" {
  value = var.project_number == "" ? module.project[0].output-project-number : var.project_number
}

output "deployment_service_account_name" {
  value = var.deployment_service_account_name
}

output "org_id" {
  value = var.org_id
}

output "billing_account" {
  value = var.billing_account
}

output "region" {
  value = var.default_region
}

output "zone" {
  value = var.default_zone
}

output "composer_region" {
  value = var.composer_region
}

output "dataform_region" {
  value = var.dataform_region
}

output "dataplex_region" {
  value = var.dataplex_region
}

output "dataproc_region" {
  value = var.dataproc_region
}

output "dataflow_region" {
  value = var.dataflow_region
}

output "bigquery_region" {
  value = var.bigquery_region
}

output "bigquery_non_multi_region" {
  value = var.bigquery_non_multi_region
}

output "spanner_region" {
  value = var.spanner_region
}

output "spanner_config" {
  value = var.spanner_config
}

output "datafusion_region" {
  value = var.datafusion_region
}

output "vertex_ai_region" {
  value = var.vertex_ai_region
}

output "cloud_function_region" {
  value = var.cloud_function_region
}

output "data_catalog_region" {
  value = var.data_catalog_region
}

output "appengine_region" {
  value = var.appengine_region
}

output "dataproc_serverless_region" {
  value = var.dataproc_serverless_region
}

output "cloud_sql_region" {
  value = var.cloud_sql_region
}

output "cloud_sql_zone" {
  value = var.cloud_sql_zone
}

output "datastream_region" {
  value = var.datastream_region
}

output "shared_demo_project_id" {
  value = var.shared_demo_project_id
}

output "aws_omni_biglake_dataset_region" {
  value = var.aws_omni_biglake_dataset_region
}

output "aws_omni_biglake_dataset_name" {
  value = var.aws_omni_biglake_dataset_name
}

output "aws_omni_biglake_connection" {
  value = var.aws_omni_biglake_connection
}

output "aws_omni_biglake_s3_bucket" {
  value = var.aws_omni_biglake_s3_bucket
}

output "azure_omni_biglake_adls_name" {
  value = var.azure_omni_biglake_adls_name
}

output "azure_omni_biglake_dataset_name" {
  value = var.azure_omni_biglake_dataset_name
}

output "azure_omni_biglake_dataset_region" {
  value = var.azure_omni_biglake_dataset_region
}

output "random_string" {
  value = random_string.project_random.result
}

output "local_storage_bucket" {
  value = local.local_storage_bucket
}

output "local_impersonation_account" {
  value = local.local_impersonation_account
}

output "local_curl_impersonation" {
  value = local.local_curl_impersonation
}

output "local_azure_omni_biglake_connection" {
  value = local.local_azure_omni_biglake_connection
}

output "deployment_service_account" {
  value = module.service-account.deployment_service_account
}

output "gcs_raw_bucket" {
  value = module.resources.gcs_raw_bucket
}

output "gcs_processed_bucket" {
  value = module.resources.gcs_processed_bucket
}

output "gcs_code_bucket" {
  value = module.resources.gcs_code_bucket
}

output "default_network" {
  value = module.resources.default_network
}

/*
output "nat-router" {
  value = module.resources.nat-router
}
*/

output "dataproc_subnet_name" {
  value = module.resources.dataproc_subnet_name
}

output "dataproc_subnet_name_ip_cidr_range" {
  value = module.resources.dataproc_subnet_name_ip_cidr_range
}

output "gcs_dataproc_bucket" {
  value = module.resources.gcs_dataproc_bucket
}

output "dataproc_service_account" {
  value = module.resources.dataproc_service_account
}

output "cloudcomposer_account_service_agent_v2_ext" {
  value = module.resources.cloudcomposer_account_service_agent_v2_ext
}

output "composer_subnet" {
  value = module.resources.composer_subnet
}

output "composer_subnet_ip_cidr_range" {
  value = module.resources.composer_subnet_ip_cidr_range
}

output "composer_service_account" {
  value = module.resources.composer_service_account
}

output "composer_env_name" {
  value = module.resources.composer_env_name
}

output "composer_env_dag_bucket" {
  value = module.resources.composer_env_dag_bucket
}

output "dataproc_serverless_subnet_name" {
  value = module.resources.dataproc_serverless_subnet_name
}

output "dataproc_serverless_ip_cidr_range" {
  value = module.resources.dataproc_serverless_ip_cidr_range
}

output "business_critical_taxonomy_aws_id" {
  value = module.resources.business_critical_taxonomy_aws_id
}

output "business_critical_taxonomy_azure_id" {
  value = module.resources.business_critical_taxonomy_azure_id
}

output "business_critical_taxonomy_id" {
  value = module.resources.business_critical_taxonomy_id
}

output "bigquery_external_function" {
  value = module.resources.bigquery_external_function
}

output "cloud_function_connection" {
  value = module.resources.cloud_function_connection
}

output "biglake_connection" {
  value = module.resources.biglake_connection
}

output "dataflow_subnet_name" {
  value = module.resources.dataflow_subnet_name
}

output "dataflow_subnet_ip_cidr_range" {
  value = module.resources.dataflow_subnet_ip_cidr_range
}

output "dataflow_service_account" {
  value = module.resources.dataflow_service_account
}

output "bigquery_taxi_dataset" {
  value = module.resources.bigquery_taxi_dataset
}

output "bigquery_thelook_ecommerce_dataset" {
  value = module.resources.bigquery_thelook_ecommerce_dataset
}

output "bigquery_rideshare_lakehouse_raw_dataset" {
  value = module.resources.bigquery_rideshare_lakehouse_raw_dataset
}

output "bigquery_rideshare_lakehouse_enriched_dataset" {
  value = module.resources.bigquery_rideshare_lakehouse_enriched_dataset
}

output "bigquery_rideshare_lakehouse_curated_dataset" {
  value = module.resources.bigquery_rideshare_lakehouse_curated_dataset
}

output "bigquery_rideshare_llm_raw_dataset" {
  value = module.resources.bigquery_rideshare_llm_raw_dataset
}

output "bigquery_rideshare_llm_enriched_dataset" {
  value = module.resources.bigquery_rideshare_llm_enriched_dataset
}

output "bigquery_rideshare_llm_curated_dataset" {
  value = module.resources.bigquery_rideshare_llm_curated_dataset
}

output "gcs_rideshare_lakehouse_raw_bucket" {
  value = module.resources.gcs_rideshare_lakehouse_raw_bucket
}

output "gcs_rideshare_lakehouse_enriched_bucket" {
  value = module.resources.gcs_rideshare_lakehouse_enriched_bucket
}

output "gcs_rideshare_lakehouse_curated_bucket" {
  value = module.resources.gcs_rideshare_lakehouse_curated_bucket
}

output "spanner_instance_id" {
  value = "spanner-${random_string.project_random.result}"
}

output "dataform_repository" {
  value = module.dataform-module.dataform_repository
}

output "dataplex_taxi_datalake" {
  value = "taxi-data-lake-${random_string.project_random.result}"
}

output "dataplex_taxi_datalake_raw_zone" {
  value = "taxi-raw-zone-${random_string.project_random.result}"
}

output "dataplex_taxi_datalake_curated_zone" {
  value = "taxi-curated-zone-${random_string.project_random.result}"
}

output "dataplex_taxi_datalake_raw_bucket" {
  value = "taxi-raw-bucket-${random_string.project_random.result}"
}

output "dataplex_taxi_datalake_processed_bucket" {
  value = "taxi-processed-bucket-${random_string.project_random.result}"
}

output "dataplex_taxi_datalake_processed_datasets" {
  value = "taxi-processed-datasets-${random_string.project_random.result}"
}

output "dataplex_ecommerce_datalake" {
  value = "ecommerce-data-lake-${random_string.project_random.result}"
}

output "dataplex_ecommerce_datalake_curated_zone" {
  value = "ecommerce-curated-zone-${random_string.project_random.result}"
}

output "dataplex_ecommerce_datalake_processed_datasets" {
  value = "ecommerce-dataset-${random_string.project_random.result}"
}

output "demo_rest_api_service_uri" {
  value = module.resources.demo_rest_api_service_uri
}



# Tells the deploy.sh where to upload the "terraform" output json file
# A file named "tf-output.json" will be places at gs://${terraform-output-bucket}/terraform/output
output "terraform-output-bucket" {
  value = module.resources.gcs_code_bucket
}

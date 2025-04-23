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


####################################################################################
# Provider that uses service account impersonation (best practice - no exported secret keys to local computers)
####################################################################################
provider "google" {
  alias                       = "service_principal_impersonation"
  impersonate_service_account = "${local.local_project_id}@${local.local_project_id}.iam.gserviceaccount.com"
  project                     = local.local_project_id
  region                      = var.default_region
  zone                        = var.default_zone
}


####################################################################################
# Create the project and grants access to the current user
####################################################################################
module "project" {
  # Run this as the currently logged in user or the service account (assuming DevOps)
  count           = var.project_number == "" ? 1 : 0
  source          = "../terraform-modules/project"
  project_id      = local.local_project_id
  org_id          = var.org_id
  billing_account = var.billing_account
}


####################################################################################
# Creates a service account that will be used to deploy the subsequent artifacts
####################################################################################
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


####################################################################################
# Enable all the cloud APIs that will be used by using Batch Mode
# Batch mode is enabled on the provider (by default)
####################################################################################
module "apis-batch-enable" {
  source = "../terraform-modules/apis-batch-enable"

  project_id       = local.local_project_id
  project_number   = var.project_number == "" ? module.project[0].output-project-number : var.project_number

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


####################################################################################
# Turns off certain Org Policies required for deployment
# They will be re-enabled by a second call to Terraform
# This step is Skipped when deploying into an existing project (it is assumed a person disabled by hand)
####################################################################################
module "org-policies" {
  count  = var.environment == "ARGOLIS_ENVIRONMENT" && var.org_id != "0" ? 1 : 0
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


####################################################################################
# This deploy the majority of the Google Cloud Infrastructure
####################################################################################
module "resources" {
  source = "../terraform-modules/resources"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  gcp_account_name                    = var.gcp_account_name
  project_id                          = local.local_project_id
  local_curl_impersonation            = local.local_curl_impersonation

  dataplex_region                     = var.dataplex_region
  multi_region                        = var.multi_region
  bigquery_non_multi_region           = var.bigquery_non_multi_region
  vertex_ai_region                    = var.vertex_ai_region
  data_catalog_region                 = var.data_catalog_region
  appengine_region                    = var.appengine_region
  colab_enterprise_region             = var.colab_enterprise_region
  dataflow_region                     = var.dataflow_region
  dataproc_region                     = var.dataproc_region
  kafka_region                        = var.kafka_region

  random_extension                    = random_string.project_random.result
  project_number                      = var.project_number == "" ? module.project[0].output-project-number : var.project_number
  deployment_service_account_name     = var.deployment_service_account_name

  terraform_service_account           = module.service-account.deployment_service_account

  bigquery_governed_data_raw_dataset      = var.bigquery_governed_data_raw_dataset
  bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
  bigquery_governed_data_curated_dataset  = var.bigquery_governed_data_curated_dataset
  bigquery_analytics_hub_publisher_dataset  = var.bigquery_analytics_hub_publisher_dataset
  bigquery_analytics_hub_subscriber_dataset = var.bigquery_analytics_hub_subscriber_dataset
  governed_data_raw_bucket                = local.governed_data_raw_bucket
  governed_data_enriched_bucket           = local.governed_data_enriched_bucket
  governed_data_curated_bucket            = local.governed_data_curated_bucket
  governed_data_code_bucket               = local.code_bucket
  dataflow_staging_bucket             = local.dataflow_staging_bucket
  governed_data_scan_bucket               = local.governed_data_scan_bucket 

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

  gcp_account_name                    = var.gcp_account_name
  project_id                          = local.local_project_id

  dataplex_region                     = var.dataplex_region
  multi_region                        = var.multi_region
  bigquery_non_multi_region           = var.bigquery_non_multi_region
  vertex_ai_region                    = var.vertex_ai_region
  data_catalog_region                 = var.data_catalog_region
  appengine_region                    = var.appengine_region
  colab_enterprise_region             = var.colab_enterprise_region

  random_extension                    = random_string.project_random.result
  project_number                      = var.project_number == "" ? module.project[0].output-project-number : var.project_number
  deployment_service_account_name     = var.deployment_service_account_name

  terraform_service_account           = module.service-account.deployment_service_account

  bigquery_governed_data_raw_dataset      = var.bigquery_governed_data_raw_dataset
  bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
  bigquery_governed_data_curated_dataset  = var.bigquery_governed_data_curated_dataset
  bigquery_analytics_hub_publisher_dataset = var.bigquery_analytics_hub_publisher_dataset
  governed_data_raw_bucket                = local.governed_data_raw_bucket
  governed_data_enriched_bucket           = local.governed_data_enriched_bucket
  governed_data_curated_bucket            = local.governed_data_curated_bucket
  governed_data_code_bucket               = local.code_bucket
  governed_data_scan_bucket               = local.governed_data_scan_bucket 

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
# Deploy notebooks to Colab -> Create the Dataform repo and files (base64 encoded)
####################################################################################
module "deploy-notebooks-module-create-files" {
  source = "../terraform-modules/colab-deployment-create-files"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  project_id                          = local.local_project_id
  multi_region                        = var.multi_region
  vertex_ai_region                    = var.vertex_ai_region
  bigquery_governed_data_raw_dataset      = var.bigquery_governed_data_raw_dataset
  bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
  bigquery_governed_data_curated_dataset  = var.bigquery_governed_data_curated_dataset
  bigquery_analytics_hub_publisher_dataset = var.bigquery_analytics_hub_publisher_dataset
  governed_data_raw_bucket                = local.governed_data_raw_bucket
  governed_data_enriched_bucket           = local.governed_data_enriched_bucket
  governed_data_curated_bucket            = local.governed_data_curated_bucket
  governed_data_code_bucket               = local.code_bucket
  governed_data_scan_bucket               = local.governed_data_scan_bucket 
  dataform_region                     = "us-central1"
  dataproc_region                     = var.dataproc_region
  dataplex_region                     = var.dataplex_region
  random_extension                    = random_string.project_random.result
  gcp_account_name                    = var.gcp_account_name
  dataflow_staging_bucket             = local.dataflow_staging_bucket
  dataflow_service_account            = module.resources.dataflow_service_account

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
# Deploy notebooks to Colab -> Push the notebooks
# This is done since there is a race condition when the files are base64 encoded
####################################################################################
module "deploy-notebooks-module-deploy" {
  source = "../terraform-modules/colab-deployment-deploy"

  # Use Service Account Impersonation for this step. 
  providers = { google = google.service_principal_impersonation }

  project_id                          = local.local_project_id
  multi_region                        = var.multi_region
  vertex_ai_region                    = var.vertex_ai_region
  bigquery_governed_data_raw_dataset      = var.bigquery_governed_data_raw_dataset
  bigquery_governed_data_enriched_dataset = var.bigquery_governed_data_enriched_dataset
  bigquery_governed_data_curated_dataset  = var.bigquery_governed_data_curated_dataset
  bigquery_analytics_hub_publisher_dataset = var.bigquery_analytics_hub_publisher_dataset
  governed_data_raw_bucket                = local.governed_data_raw_bucket
  governed_data_enriched_bucket           = local.governed_data_enriched_bucket
  governed_data_curated_bucket            = local.governed_data_curated_bucket
  governed_data_code_bucket               = local.code_bucket
  governed_data_scan_bucket               = local.governed_data_scan_bucket 
  dataform_region                     = "us-central1"
  random_extension                    = random_string.project_random.result
  gcp_account_name                    = var.gcp_account_name
  dataflow_staging_bucket             = local.dataflow_staging_bucket
  dataflow_service_account            = module.resources.dataflow_service_account

  depends_on = [
    module.project,
    module.service-account,
    module.apis-batch-enable,
    time_sleep.service_account_api_activation_time_delay,
    module.org-policies,
    module.resources,
    module.deploy-notebooks-module-create-files
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

output "dataplex_region" {
  value = var.dataplex_region
}

output "multi_region" {
  value = var.multi_region
}

output "bigquery_non_multi_region" {
  value = var.bigquery_non_multi_region
}

output "vertex_ai_region" {
  value = var.vertex_ai_region
}

output "data_catalog_region" {
  value = var.data_catalog_region
}

output "appengine_region" {
  value = var.appengine_region
}

output "random_string" {
  value = random_string.project_random.result
}

output "local_impersonation_account" {
  value = local.local_impersonation_account
}


output "deployment_service_account" {
  value = module.service-account.deployment_service_account
}


# Tells the deploy.sh where to upload the "terraform" output json file
# A file named "tf-output.json" will be places at gs://${terraform-output-bucket}/terraform/output
output "terraform-output-bucket" {
  value = local.code_bucket
}

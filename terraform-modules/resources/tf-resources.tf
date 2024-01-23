####################################################################################
# Copyright 2023 Google LLC
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
      version = ">= 4.52, < 6"
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "gcp_account_name" {}
variable "project_id" {}

variable "composer_region" {}
variable "dataform_region" {}
variable "dataplex_region" {}
variable "dataproc_region" {}
variable "dataflow_region" {}
variable "bigquery_region" {}
variable "bigquery_non_multi_region" {}
variable "spanner_region" {}
variable "datafusion_region" {}
variable "vertex_ai_region" {}
variable "cloud_function_region" {}
variable "data_catalog_region" {}
variable "appengine_region" {}
variable "dataproc_serverless_region" {}
variable "cloud_sql_region" {}
variable "cloud_sql_zone" {}
variable "datastream_region" {}
variable "colab_enterprise_region" {}

variable "storage_bucket" {}
variable "spanner_config" {}
variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "curl_impersonation" {}

variable "aws_omni_biglake_dataset_region" {}
variable "aws_omni_biglake_dataset_name" {}
variable "azure_omni_biglake_dataset_name" {}
variable "azure_omni_biglake_dataset_region" {}

variable "terraform_service_account" {}

# Hardcoded
variable "bigquery_taxi_dataset" {
  type    = string
  default = "taxi_dataset"
}
variable "bigquery_thelook_ecommerce_dataset" {
  type    = string
  default = "thelook_ecommerce"
}
variable "bigquery_rideshare_lakehouse_raw_dataset" {
  type    = string
  default = "rideshare_lakehouse_raw"
}
variable "bigquery_rideshare_lakehouse_enriched_dataset" {
  type    = string
  default = "rideshare_lakehouse_enriched"
}
variable "bigquery_rideshare_lakehouse_curated_dataset" {
  type    = string
  default = "rideshare_lakehouse_curated"
}

variable "bigquery_rideshare_llm_raw_dataset" {
  type    = string
  default = "rideshare_llm_raw"
}
variable "bigquery_rideshare_llm_enriched_dataset" {
  type    = string
  default = "rideshare_llm_enriched"
}
variable "bigquery_rideshare_llm_curated_dataset" {
  type    = string
  default = "rideshare_llm_curated"
}

####################################################################################
# Bucket for all data (BigQuery, Spark, etc...)
# This is your "Data Lake" bucket
# If you are using Dataplex you should create a bucket per data lake zone (bronze, silver, gold, etc.)
####################################################################################
resource "google_storage_bucket" "raw_bucket" {
  project                     = var.project_id
  name                        = "raw-${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "processed_bucket" {
  project                     = var.project_id
  name                        = "processed-${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "code_bucket" {
  project                     = var.project_id
  name                        = "code-${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "rideshare_lakehouse_raw" {
  project                     = var.project_id
  name                        = "rideshare-lakehouse-raw-${var.random_extension}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "rideshare_lakehouse_enriched" {
  project                     = var.project_id
  name                        = "rideshare-lakehouse-enriched-${var.random_extension}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "rideshare_lakehouse_curated" {
  project                     = var.project_id
  name                        = "rideshare-lakehouse-curated-${var.random_extension}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}


resource "google_storage_bucket" "iceberg_catalog_bucket" {
  project                     = var.project_id
  name                        = "iceberg-catalog-${var.random_extension}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}


resource "google_storage_bucket" "iceberg_catalog_source_data_bucket" {
  project                     = var.project_id
  name                        = "iceberg-source-data-${var.random_extension}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}


resource "google_storage_bucket" "biglake_managed_table_bucket" {
  project                     = var.project_id
  name                        = "mt-${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

####################################################################################
# Custom Roles
####################################################################################
# Required since we are setting BigLake permissions with BigSpark
resource "google_project_iam_custom_role" "customconnectiondelegate" {
  project     = var.project_id
  role_id     = "CustomConnectionDelegate"
  title       = "Custom Connection Delegate"
  description = "Used for BQ connections"
  permissions = ["biglake.tables.create", "biglake.tables.delete", "biglake.tables.get",
    "biglake.tables.list", "biglake.tables.lock", "biglake.tables.update",
  "bigquery.connections.delegate"]
}

resource "google_project_iam_custom_role" "custom-role-custom-delegate" {
  project     = var.project_id
  role_id     = "CustomDelegate"
  title       = "Custom Delegate"
  description = "Used for BLMS connections"
  permissions = ["bigquery.connections.delegate"]
}

####################################################################################
# Default Network
# The project was not created with the default network.  
# This creates just the network/subnets we need.
####################################################################################
resource "google_compute_network" "default_network" {
  project                 = var.project_id
  name                    = "vpc-main"
  description             = "Default network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "compute_subnet" {
  project                  = var.project_id
  name                     = "compute-subnet"
  ip_cidr_range            = "10.1.0.0/16"
  region                   = var.cloud_sql_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network
  ]
}

# Firewall for NAT Router
resource "google_compute_firewall" "subnet_firewall_rule" {
  project = var.project_id
  name    = "subnet-nat-firewall"
  network = google_compute_network.default_network.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
  source_ranges = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16", "10.4.0.0/16", "10.5.0.0/16"]

  depends_on = [
    google_compute_subnetwork.composer_subnet,
    google_compute_subnetwork.dataproc_subnet,
    google_compute_subnetwork.dataproc_serverless_subnet,
    google_compute_subnetwork.dataflow_subnet
  ]
}

# We want a NAT for every region
locals {
  distinctRegions = distinct([var.composer_region,
    var.dataform_region,
    var.dataplex_region,
    var.dataproc_region,
    var.dataflow_region,
    var.bigquery_non_multi_region,
    var.spanner_region,
    var.datafusion_region,
    var.vertex_ai_region,
    var.cloud_function_region,
    var.data_catalog_region,
    var.dataproc_serverless_region,
    var.cloud_sql_region,
    var.datastream_region
  ])
}

resource "google_compute_router" "nat-router-distinct-regions" {
  project = var.project_id
  count   = length(local.distinctRegions)
  name    = "nat-router-${local.distinctRegions[count.index]}"
  region  = local.distinctRegions[count.index]
  network = google_compute_network.default_network.id

  depends_on = [
    google_compute_firewall.subnet_firewall_rule
  ]
}

resource "google_compute_router_nat" "nat-config-distinct-regions" {
  project                            = var.project_id
  count                              = length(local.distinctRegions)
  name                               = "nat-config-${local.distinctRegions[count.index]}"
  router                             = google_compute_router.nat-router-distinct-regions[count.index].name
  region                             = local.distinctRegions[count.index]
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.nat-router-distinct-regions
  ]
}

####################################################################################
# Datastream
####################################################################################
# Firewall rule for Cloud Shell to SSH in Compute VMs
# A compute VM will be deployed as a SQL Reverse Proxy for Datastream private connectivity
resource "google_compute_firewall" "cloud_shell_ssh_firewall_rule" {
  project = var.project_id
  name    = "cloud-shell-ssh-firewall-rule"
  network = google_compute_network.default_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction   = "INGRESS"
  target_tags = ["ssh-firewall-tag"]

  source_ranges = ["35.235.240.0/20"]

  depends_on = [
    google_compute_network.default_network
  ]
}


# Datastream ingress rules for SQL Reverse Proxy communication
resource "google_compute_firewall" "datastream_ingress_rule_firewall_rule" {
  project = var.project_id
  name    = "datastream-ingress-rule"
  network = google_compute_network.default_network.id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction = "INGRESS"

  source_ranges = ["10.6.0.0/16", "10.7.0.0/29"]

  depends_on = [
    google_compute_network.default_network
  ]
}


# Datastream egress rules for SQL Reverse Proxy communication
resource "google_compute_firewall" "datastream_egress_rule_firewall_rule" {
  project = var.project_id
  name    = "datastream-egress-rule"
  network = google_compute_network.default_network.id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction = "EGRESS"

  destination_ranges = ["10.6.0.0/16", "10.7.0.0/29"]

  depends_on = [
    google_compute_network.default_network
  ]
}


# Create the Datastream Private Connection (takes a while so it is done here and not created on the fly in Airflow)
resource "google_datastream_private_connection" "datastream_cloud-sql-private-connect" {
  project               = var.project_id
  display_name          = "cloud-sql-private-connect"
  location              = var.datastream_region
  private_connection_id = "cloud-sql-private-connect"

  vpc_peering_config {
    vpc    = google_compute_network.default_network.id
    subnet = "10.7.0.0/29"
  }

  depends_on = [
    google_compute_network.default_network
  ]
}


# For Cloud SQL / Datastream demo 
# Allocate an IP address range
# https://cloud.google.com/sql/docs/mysql/configure-private-services-access#allocate-ip-address-range   
resource "google_compute_global_address" "google_compute_global_address_vpc_main" {
  project       = var.project_id
  name          = "google-managed-services-vpc-main"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.default_network.id

  depends_on = [
    google_compute_network.default_network
  ]
}


# Create a private connection
# https://cloud.google.com/sql/docs/mysql/configure-private-services-access#create_a_private_connection
resource "google_service_networking_connection" "google_service_networking_connection_default" {
  # project                 = var.project_id
  network                 = google_compute_network.default_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_compute_global_address_vpc_main.name]

  depends_on = [
    google_compute_network.default_network,
    google_compute_global_address.google_compute_global_address_vpc_main
  ]
}

# Force the service account to get created so we can grant permisssions
resource "google_project_service_identity" "service_identity_servicenetworking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
  depends_on = [
    google_compute_network.default_network,
    google_service_networking_connection.google_service_networking_connection_default
  ]
}

resource "time_sleep" "service_identity_servicenetworking_time_delay" {
  depends_on      = [google_project_service_identity.service_identity_servicenetworking]
  create_duration = "30s"
}


# Add permissions for the database to get created
resource "google_project_iam_member" "iam_service_networking" {
  project = var.project_id
  role    = "roles/servicenetworking.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.service_identity_servicenetworking.email}"
  #member   = "serviceAccount:service-${var.project_number}@service-networking.iam.gserviceaccount.com "

  depends_on = [
    google_compute_network.default_network,
    google_service_networking_connection.google_service_networking_connection_default,
    time_sleep.service_identity_servicenetworking_time_delay
  ]
}


####################################################################################
# Dataproc
####################################################################################
# Subnet for dataproc cluster
resource "google_compute_subnetwork" "dataproc_subnet" {
  project                  = var.project_id
  name                     = "dataproc-subnet"
  ip_cidr_range            = "10.3.0.0/16"
  region                   = var.dataproc_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}

# Firewall rule for dataproc cluster
resource "google_compute_firewall" "dataproc_subnet_firewall_rule" {
  project = var.project_id
  name    = "dataproc-firewall"
  network = google_compute_network.default_network.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
  source_ranges = ["10.3.0.0/16"]

  depends_on = [
    google_compute_subnetwork.dataproc_subnet
  ]
}


# Temp work bucket for dataproc cluster 
# If you do not have a perminate temp bucket random ones will be created (which is messy since you do not know what they are being used for)
resource "google_storage_bucket" "dataproc_bucket" {
  project                     = var.project_id
  name                        = "dataproc-${var.storage_bucket}"
  location                    = var.dataproc_region
  force_destroy               = true
  uniform_bucket_level_access = true
}


# Service account for dataproc cluster
resource "google_service_account" "dataproc_service_account" {
  project      = var.project_id
  account_id   = "dataproc-service-account"
  display_name = "Service Account for Dataproc Environment"
}


# Grant require worker role
resource "google_project_iam_member" "dataproc_service_account_worker_role" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_service_account.dataproc_service_account
  ]
}


# Grant editor (too high) to service account
resource "google_project_iam_member" "dataproc_service_account_editor_role" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_project_iam_member.dataproc_service_account_worker_role
  ]
}

# So dataproc can call theh BigLake connection in BigQuery
resource "google_project_iam_member" "dataproc_customconnectiondelegate" {
  project = var.project_id
  role    = google_project_iam_custom_role.customconnectiondelegate.id
  member  = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_project_iam_member.dataproc_service_account_editor_role
  ]
}

# Create the cluster
# NOTE: This is now done in Airflow, but has kept for reference
/*
resource "google_dataproc_cluster" "mycluster" {
  name     = "testcluster"
  project  = var.project_id
  region   = var.dataproc_region
  graceful_decommission_timeout = "120s"

  cluster_config {
    staging_bucket = "dataproc-${var.storage_bucket}"

    master_config {
      num_instances = 1
      machine_type  = "n1-standard-8"
      disk_config {
        boot_disk_type    = "pd-ssd"
        boot_disk_size_gb = 30
      }
    }

    worker_config {
      num_instances    = 4
      machine_type     = "n1-standard-8"
      disk_config {
        boot_disk_size_gb = 30
        num_local_ssds    = 1
      }
    }

    preemptible_worker_config {
      num_instances = 0
    }

    # Override or set some custom properties
    #software_config {
    #  image_version = "2.0.28-debian10"
    #  override_properties = {
    #    "dataproc:dataproc.allow.zero.workers" = "true"
    #  }
    #}

    gce_cluster_config {
      zone        = var.zone
      subnetwork  = google_compute_subnetwork.dataproc_subnet.id
      service_account = google_service_account.dataproc_service_account.email
      service_account_scopes = ["cloud-platform"]
    }

  }

  depends_on = [


    google_compute_subnetwork.dataproc_subnet,
    google_storage_bucket.dataproc_bucket,
    google_project_iam_member.dataproc_service_account_editor_role,
    google_compute_firewall.dataproc_subnet_firewall_rule
  ]  
}
*/


####################################################################################
# Composer 2
####################################################################################
# Cloud Composer v2 API Service Agent Extension
# The below does not overwrite at the Org level like GCP docs: https://cloud.google.com/composer/docs/composer-2/create-environments#terraform
resource "google_project_iam_member" "cloudcomposer_account_service_agent_v2_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}


# Cloud Composer API Service Agent
resource "google_project_iam_member" "cloudcomposer_account_service_agent" {
  project = var.project_id
  role    = "roles/composer.serviceAgent"
  member  = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"

  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext
  ]
}


resource "google_compute_subnetwork" "composer_subnet" {
  project                  = var.project_id
  name                     = "composer-subnet"
  ip_cidr_range            = "10.2.0.0/16"
  region                   = var.composer_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network
  ]
}


resource "google_service_account" "composer_service_account" {
  project      = var.project_id
  account_id   = "composer-service-account"
  display_name = "Service Account for Composer Environment"
}


resource "google_project_iam_member" "composer_service_account_worker_role" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_service_account.composer_service_account
  ]
}


# The DAGs will be doing a lot of BQ automation
# This role can be scaled down once the DAGs are created (the DAGS do high level Owner automation - just for demo purposes)
resource "google_project_iam_member" "composer_service_account_bq_admin_role" {
  # provider= google.service_principal_impersonation
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_project_iam_member.composer_service_account_worker_role
  ]
}

# Let composer impersonation the service account that can change org policies (for demo purposes)
# This account also will be running Terraform scripts and impersonating this account
resource "google_service_account_iam_member" "cloudcomposer_service_account_impersonation" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.project_id}@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.composer_service_account.email}"
  depends_on         = [google_project_iam_member.composer_service_account_bq_admin_role]
}

# ActAs role
resource "google_project_iam_member" "cloudcomposer_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_service_account_iam_member.cloudcomposer_service_account_impersonation
  ]
}

#fetching latest available Cloud Composer versions in a region for a given project.
data "google_composer_image_versions" "latest_image" {
    region = var.composer_region
}

resource "google_composer_environment" "composer_env" {
  project = var.project_id
  name    = "data-analytics-demo-composer-2"
  region  = var.composer_region

  config {

    software_config {
      #image_version = "composer-2.2.0-airflow-2.5.1" # "composer-2.0.31-airflow-2.3.3"
      image_version = data.google_composer_image_versions.latest_image.image_versions[0].image_version_id

      pypi_packages = {
        psycopg2-binary = "==2.9.6"
      }

      env_variables = {
        ENV_PROJECT_ID     = var.project_id,
        ENV_PROJECT_NUMBER = var.project_number,

        ENV_RAW_BUCKET       = "raw-${var.storage_bucket}",
        ENV_PROCESSED_BUCKET = "processed-${var.storage_bucket}",
        ENV_CODE_BUCKET      = "code-${var.storage_bucket}",

        ENV_COMPOSER_REGION                 = var.composer_region
        ENV_DATAFORM_REGION                 = var.dataform_region
        ENV_DATAPLEX_REGION                 = var.dataplex_region
        ENV_DATAPROC_REGION                 = var.dataproc_region
        ENV_DATAFLOW_REGION                 = var.dataflow_region
        ENV_BIGQUERY_REGION                 = var.bigquery_region
        ENV_BIGQUERY_NON_MULTI_REGION       = var.bigquery_non_multi_region
        ENV_SPANNER_REGION                  = var.spanner_region
        ENV_DATAFUSION_REGION               = var.datafusion_region
        ENV_VERTEX_AI_REGION                = var.vertex_ai_region
        ENV_CLOUD_FUNCTION_REGION           = var.cloud_function_region
        ENV_DATA_CATALOG_REGION             = var.data_catalog_region
        ENV_APPENGINE_REGION                = var.appengine_region
        ENV_DATAPROC_SERVERLESS_REGION      = var.dataproc_serverless_region
        ENV_DATAPROC_SERVERLESS_SUBNET      = "projects/${var.project_id}/regions/${var.dataproc_serverless_region}/subnetworks/dataproc-serverless-subnet",
        ENV_DATAPROC_SERVERLESS_SUBNET_NAME = google_compute_subnetwork.dataproc_serverless_subnet.name,
        ENV_CLOUD_SQL_REGION                = var.cloud_sql_region,
        ENV_CLOUD_SQL_ZONE                  = var.cloud_sql_zone,
        ENV_DATASTREAM_REGION               = var.datastream_region,

        ENV_DATAPROC_BUCKET                      = "dataproc-${var.storage_bucket}",
        ENV_DATAPROC_SUBNET                      = "projects/${var.project_id}/regions/${var.dataproc_region}/subnetworks/dataproc-subnet",
        ENV_DATAPROC_SERVICE_ACCOUNT             = "dataproc-service-account@${var.project_id}.iam.gserviceaccount.com",
        ENV_GCP_ACCOUNT_NAME                     = "${var.gcp_account_name}",
        ENV_TAXI_DATASET_ID                      = google_bigquery_dataset.taxi_dataset.dataset_id,
        ENV_THELOOK_DATASET_ID                   = google_bigquery_dataset.thelook_ecommerce_dataset.dataset_id,
        ENV_SPANNER_INSTANCE_ID                  = "spanner-${var.random_extension}" //google_spanner_instance.spanner_instance.name,
        ENV_DATAFLOW_SUBNET                      = "regions/${var.dataflow_region}/subnetworks/dataflow-subnet",
        ENV_DATAFLOW_SERVICE_ACCOUNT             = "dataflow-service-account@${var.project_id}.iam.gserviceaccount.com",
        ENV_RANDOM_EXTENSION                     = var.random_extension
        ENV_SPANNER_CONFIG                       = var.spanner_config
        ENV_RIDESHARE_LAKEHOUSE_RAW_BUCKET       = google_storage_bucket.rideshare_lakehouse_raw.name
        ENV_RIDESHARE_LAKEHOUSE_ENRICHED_BUCKET  = google_storage_bucket.rideshare_lakehouse_enriched.name
        ENV_RIDESHARE_LAKEHOUSE_CURATED_BUCKET   = google_storage_bucket.rideshare_lakehouse_curated.name
        ENV_RIDESHARE_LAKEHOUSE_RAW_DATASET      = var.bigquery_rideshare_lakehouse_raw_dataset
        ENV_RIDESHARE_LAKEHOUSE_ENRICHED_DATASET = var.bigquery_rideshare_lakehouse_enriched_dataset
        ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET  = var.bigquery_rideshare_lakehouse_curated_dataset

        ENV_RIDESHARE_LLM_RAW_DATASET      = var.bigquery_rideshare_llm_raw_dataset
        ENV_RIDESHARE_LLM_ENRICHED_DATASET = var.bigquery_rideshare_llm_enriched_dataset
        ENV_RIDESHARE_LLM_CURATED_DATASET  = var.bigquery_rideshare_llm_curated_dataset

        ENV_TERRAFORM_SERVICE_ACCOUNT = var.terraform_service_account,

        ENV_RIDESHARE_PLUS_SERVICE_ACCOUNT = google_service_account.cloud_run_rideshare_plus_service_account.email
      }
    }

    # this is designed to be the smallest cheapest Composer for demo purposes
    workloads_config {
      scheduler {
        cpu        = 1
        memory_gb  = 1
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 1
        storage_gb = 1
      }
      worker {
        cpu        = 2
        memory_gb  = 10
        storage_gb = 10
        min_count  = 1
        max_count  = 4
      }
    }

    environment_size = "ENVIRONMENT_SIZE_SMALL"

    node_config {
      network         = google_compute_network.default_network.id
      subnetwork      = google_compute_subnetwork.composer_subnet.id
      service_account = google_service_account.composer_service_account.name
    }

    private_environment_config {
      enable_private_endpoint = true
    }
  }

  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext,
    google_project_iam_member.cloudcomposer_account_service_agent,
    google_compute_subnetwork.composer_subnet,
    google_service_account.composer_service_account,
    google_project_iam_member.composer_service_account_worker_role,
    google_project_iam_member.composer_service_account_bq_admin_role,
    google_compute_router_nat.nat-config-distinct-regions,
    google_service_account.cloud_run_rideshare_plus_service_account
  ]

  timeouts {
    create = "90m"
  }
}


####################################################################################
# BigQuery Datasets
####################################################################################
resource "google_bigquery_dataset" "taxi_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_taxi_dataset
  friendly_name = var.bigquery_taxi_dataset
  description   = "This contains the NYC taxi data"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "thelook_ecommerce_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_thelook_ecommerce_dataset
  friendly_name = var.bigquery_thelook_ecommerce_dataset
  description   = "This contains the Looker eCommerce data"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_lakehouse_raw_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_lakehouse_raw_dataset
  friendly_name = var.bigquery_rideshare_lakehouse_raw_dataset
  description   = "This contains the Rideshare Plus Analytics Raw Zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_lakehouse_enriched_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_lakehouse_enriched_dataset
  friendly_name = var.bigquery_rideshare_lakehouse_enriched_dataset
  description   = "This contains the Rideshare Plus Analytics Curated Zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_lakehouse_curated_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_lakehouse_curated_dataset
  friendly_name = var.bigquery_rideshare_lakehouse_curated_dataset
  description   = "This contains the Rideshare Plus Analytics Curated Zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_llm_raw_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_llm_raw_dataset
  friendly_name = var.bigquery_rideshare_llm_raw_dataset
  description   = "This contains the Rideshare Plus LLM Raw Zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_llm_enriched_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_llm_enriched_dataset
  friendly_name = var.bigquery_rideshare_llm_enriched_dataset
  description   = "This contains the Rideshare Plus LLM Enriched Zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "ideshare_llm_curated_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_llm_curated_dataset
  friendly_name = var.bigquery_rideshare_llm_curated_dataset
  description   = "This contains the Rideshare Plus LLM Curated Zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "aws_omni_biglake_dataset" {
  project       = var.project_id
  dataset_id    = var.aws_omni_biglake_dataset_name
  friendly_name = var.aws_omni_biglake_dataset_name
  description   = "This contains the AWS OMNI NYC taxi data"
  location      = var.aws_omni_biglake_dataset_region
}

resource "google_bigquery_dataset" "azure_omni_biglake_dataset" {
  project       = var.project_id
  dataset_id    = var.azure_omni_biglake_dataset_name
  friendly_name = var.azure_omni_biglake_dataset_name
  description   = "This contains the Azure OMNI NYC taxi data"
  location      = var.azure_omni_biglake_dataset_region
}


# Subnet for bigspark / central region
resource "google_compute_subnetwork" "dataproc_serverless_subnet" {
  project                  = var.project_id
  name                     = "dataproc-serverless-subnet"
  ip_cidr_range            = "10.5.0.0/16"
  region                   = var.bigquery_non_multi_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}

# Needed for BigSpark to Dataproc
resource "google_compute_firewall" "dataproc_serverless_subnet_firewall_rule" {
  project = var.project_id
  name    = "dataproc-serverless-firewall"
  network = google_compute_network.default_network.id

  allow {
    protocol = "all"
  }

  source_ranges = ["10.5.0.0/16"]

  depends_on = [
    google_compute_subnetwork.dataproc_serverless_subnet
  ]
}


####################################################################################
# Data Catalog Taxonomy
# AWS Region
####################################################################################
resource "google_data_catalog_taxonomy" "business_critical_taxonomy_aws" {
  project = var.project_id
  region  = var.aws_omni_biglake_dataset_region
  # Must be unique accross your Org
  display_name           = "Business-Critical-AWS-${var.random_extension}"
  description            = "A collection of policy tags (AWS)"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "low_security_policy_tag_aws" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy_aws.id
  display_name = "AWS Low security"
  description  = "A policy tag normally associated with low security items (AWS)"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy_aws,
  ]
}

resource "google_data_catalog_policy_tag" "high_security_policy_tag_aws" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy_aws.id
  display_name = "AWS High security"
  description  = "A policy tag normally associated with high security items (AWS)"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy_aws
  ]
}

resource "google_data_catalog_policy_tag_iam_member" "member_aws" {
  policy_tag = google_data_catalog_policy_tag.low_security_policy_tag_aws.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = "user:${var.gcp_account_name}"
  depends_on = [
    google_data_catalog_policy_tag.low_security_policy_tag_aws,
  ]
}


####################################################################################
# Data Catalog Taxonomy
# Azure Region
####################################################################################
resource "google_data_catalog_taxonomy" "business_critical_taxonomy_azure" {
  project = var.project_id
  region  = var.azure_omni_biglake_dataset_region
  # Must be unique accross your Org
  display_name           = "Business-Critical-Azure-${var.random_extension}"
  description            = "A collection of policy tags (Azure)"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "low_security_policy_tag_azure" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy_azure.id
  display_name = "Azure Low security"
  description  = "A policy tag normally associated with low security items (Azure)"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy_azure,
  ]
}

resource "google_data_catalog_policy_tag" "high_security_policy_tag_azure" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy_azure.id
  display_name = "Azure High security"
  description  = "A policy tag normally associated with high security items (Azure)"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy_azure
  ]
}

resource "google_data_catalog_policy_tag_iam_member" "member_azure" {
  policy_tag = google_data_catalog_policy_tag.low_security_policy_tag_azure.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = "user:${var.gcp_account_name}"
  depends_on = [
    google_data_catalog_policy_tag.low_security_policy_tag_azure,
  ]
}

####################################################################################
# Dataplex / Data Lineage
####################################################################################
resource "google_project_iam_member" "gcp_roles_datalineage_admin" {
  project = var.project_id
  role    = "roles/datalineage.admin"
  member  = "user:${var.gcp_account_name}"
}

####################################################################################
# Bring in Analytics Hub reference
####################################################################################
# https://cloud.google.com/bigquery/docs/reference/analytics-hub/rest/v1/projects.locations.dataExchanges.listings/subscribe
/*
# https://cloud.google.com/bigquery/docs/reference/analytics-hub/rest/v1/projects.locations.dataExchanges.listings/subscribe
curl --request POST \
  'https://analyticshub.googleapis.com/v1/projects/1057666841514/locations/us/dataExchanges/google_cloud_public_datasets_17e74966199/listings/ghcn_daily_17ee6ceb8e9:subscribe' \
  --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"destinationDataset":{"datasetReference":{"datasetId":"ghcn_daily","projectId":"data-analytics-demo-5qiz4e36kf"},"friendlyName":"ghcn_daily","location":"us","description":"ghcn_daily"}}' \
  --compressed
*/
resource "null_resource" "analyticshub_daily_weather_data" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl --request POST \
    "https://analyticshub.googleapis.com/v1/projects/1057666841514/locations/us/dataExchanges/google_cloud_public_datasets_17e74966199/listings/ghcn_daily_17ee6ceb8e9:subscribe" \
    --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data '{"destinationDataset":{"datasetReference":{"datasetId":"ghcn_daily","projectId":"${var.project_id}"},"friendlyName":"ghcn_daily","location":"us","description":"ghcn_daily"}}' \
    --compressed
    EOF
  }
  depends_on = [
  ]
}


####################################################################################
# Data Catalog Taxonomy
# Taxi US Region
####################################################################################
resource "google_data_catalog_taxonomy" "business_critical_taxonomy" {
  project = var.project_id
  region  = var.bigquery_region
  # Must be unique accross your Org
  display_name           = "Business-Critical-${var.random_extension}"
  description            = "A collection of policy tags"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "low_security_policy_tag" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy.id
  display_name = "Low security"
  description  = "A policy tag normally associated with low security items"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy,
  ]
}

resource "google_data_catalog_policy_tag" "high_security_policy_tag" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy.id
  display_name = "High security"
  description  = "A policy tag normally associated with high security items"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy
  ]
}

resource "google_data_catalog_policy_tag_iam_member" "member" {
  policy_tag = google_data_catalog_policy_tag.low_security_policy_tag.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = "user:${var.gcp_account_name}"
  depends_on = [
    google_data_catalog_policy_tag.low_security_policy_tag,
  ]
}


# Data Masking
resource "google_data_catalog_policy_tag" "data_masking_policy_tag" {
  taxonomy     = google_data_catalog_taxonomy.business_critical_taxonomy.id
  display_name = "Data Masking security"
  description  = "A policy tag that will apply data masking"

  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy
  ]
}

# REST API (no gcloud or Terraform yet)
# https://cloud.google.com/bigquery/docs/reference/bigquerydatapolicy/rest/v1beta1/projects.locations.dataPolicies#datamaskingpolicy

# Create a Hash Rule
resource "null_resource" "deploy_data_masking_sha256" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST \
      https://bigquerydatapolicy.googleapis.com/v1beta1/projects/${var.project_id}/locations/us/dataPolicies?prettyPrint=true \
      --data \ '{"dataMaskingPolicy":{"predefinedExpression":"SHA256"},"dataPolicyId":"Hash_Rule","dataPolicyType":"DATA_MASKING_POLICY","policyTag":"${google_data_catalog_policy_tag.data_masking_policy_tag.id}"}'
    EOF
  }
  depends_on = [
    google_data_catalog_policy_tag.data_masking_policy_tag
  ]
}

# Create a Nullify Rule
resource "null_resource" "deploy_data_masking_nullify" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST \
      https://bigquerydatapolicy.googleapis.com/v1beta1/projects/${var.project_id}/locations/us/dataPolicies?prettyPrint=true \
      --data \ '{"dataMaskingPolicy":{"predefinedExpression":"ALWAYS_NULL"},"dataPolicyId":"Nullify_Rule","dataPolicyType":"DATA_MASKING_POLICY","policyTag":"${google_data_catalog_policy_tag.data_masking_policy_tag.id}"}'
    EOF
  }
  depends_on = [
    null_resource.deploy_data_masking_sha256
  ]
}

# Create a Default-Value Rule
resource "null_resource" "deploy_data_masking_default_value" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST \
      https://bigquerydatapolicy.googleapis.com/v1beta1/projects/${var.project_id}/locations/us/dataPolicies?prettyPrint=true \
      --data \ '{"dataMaskingPolicy":{"predefinedExpression":"DEFAULT_MASKING_VALUE"},"dataPolicyId":"DefaultValue_Rule","dataPolicyType":"DATA_MASKING_POLICY","policyTag":"${google_data_catalog_policy_tag.data_masking_policy_tag.id}"}'
    EOF
  }
  depends_on = [
    null_resource.deploy_data_masking_nullify
  ]
}

# Grant access to the user to the Nullify (you can change during the demo)
resource "null_resource" "deploy_data_masking_iam_permissions" {
  provisioner "local-exec" {
    when    = create
    command = <<EOT
    curl \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      -X POST \
      https://bigquerydatapolicy.googleapis.com/v1beta1/projects/${var.project_id}/locations/us/dataPolicies/Nullify_Rule:setIamPolicy?prettyPrint=true \
      --data \ '{"policy":{"bindings":[{"members":["user:${var.gcp_account_name}"],"role":"roles/bigquerydatapolicy.maskedReader"}]}}'
    EOT
  }
  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy,
    google_data_catalog_policy_tag.data_masking_policy_tag,
    null_resource.deploy_data_masking_sha256,
    null_resource.deploy_data_masking_nullify,
    null_resource.deploy_data_masking_default_value,
  ]
}

####################################################################################
# Cloud Function (BigQuery)
####################################################################################
# Zip the source code
data "archive_file" "bigquery_external_function_zip" {
  type        = "zip"
  source_dir  = "../cloud-functions/bigquery-external-function"
  output_path = "../cloud-functions/bigquery-external-function.zip"

  depends_on = [
    google_storage_bucket.code_bucket
  ]
}

# Upload code
resource "google_storage_bucket_object" "bigquery_external_function_zip_upload" {
  name   = "cloud-functions/bigquery-external-function/bigquery-external-function.zip"
  bucket = google_storage_bucket.code_bucket.name
  source = data.archive_file.bigquery_external_function_zip.output_path

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip
  ]
}


# Deploy the function
resource "google_cloudfunctions_function" "bigquery_external_function" {
  project     = var.project_id
  region      = var.cloud_function_region
  name        = "bigquery_external_function"
  description = "bigquery_external_function"
  runtime     = "python310"

  available_memory_mb          = 256
  source_archive_bucket        = google_storage_bucket.code_bucket.name
  source_archive_object        = google_storage_bucket_object.bigquery_external_function_zip_upload.name
  trigger_http                 = true
  ingress_settings             = "ALLOW_ALL"
  https_trigger_security_level = "SECURE_ALWAYS"
  entry_point                  = "bigquery_external_function"
  environment_variables        =  {
      PROJECT_ID      = var.project_id,
      ENV_CLOUD_FUNCTION_REGION = var.cloud_function_region
    }
  # no-allow-unauthenticated ???
  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload
  ]
}



####################################################################################
# Cloud Function (Rideshare Plis)
####################################################################################
# Zip the source code
data "archive_file" "rideshare_plus_function_zip" {
  type        = "zip"
  source_dir  = "../cloud-functions/rideshare-plus-rest-api"
  output_path = "../cloud-functions/rideshare-plus-rest-api.zip"

  depends_on = [
    google_storage_bucket.code_bucket
  ]
}

# Upload code
resource "google_storage_bucket_object" "rideshare_plus_function_zip_upload" {
  name   = "cloud-functions/rideshare-plus-rest-api/rideshare-plus-rest-api.zip"
  bucket = google_storage_bucket.code_bucket.name
  source = data.archive_file.rideshare_plus_function_zip.output_path

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip
  ]
}

# Deploy the function V2
resource "google_cloudfunctions2_function" "rideshare_plus_function" {
  project     = var.project_id
  location    = var.cloud_function_region
  name        = "demo-rest-api-service"
  description = "demo-rest-api-service"

  build_config {
    runtime     = "python310"
    entry_point = "entrypoint" # Set the entry point 
    source {
      storage_source {
        bucket = google_storage_bucket.code_bucket.name
        object = google_storage_bucket_object.rideshare_plus_function_zip_upload.name
      }
    }
  }

  service_config {
    max_instance_count             = 10
    min_instance_count             = 1
    available_memory               = "256M"
    timeout_seconds                = 60
    ingress_settings               = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    environment_variables = {
      PROJECT_ID      = var.project_id,
      ENV_CODE_BUCKET = "code-${var.storage_bucket}"

    }
  }

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload
  ]
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "rideshare_plus_function_invoker" {
  project        = google_cloudfunctions2_function.rideshare_plus_function.project
  location       = google_cloudfunctions2_function.rideshare_plus_function.location
  cloud_function = google_cloudfunctions2_function.rideshare_plus_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_cloudfunctions2_function.rideshare_plus_function
  ]
}

# Update the Cloud Run to support allUsers used by Cloud Function V2
resource "google_cloud_run_service_iam_binding" "rideshare_plus_function_cloudrun" {
  project  = google_cloudfunctions2_function.rideshare_plus_function.project
  location = google_cloudfunctions2_function.rideshare_plus_function.location
  service  = google_cloudfunctions2_function.rideshare_plus_function.name

  role    = "roles/run.invoker"
  members = ["allUsers"]

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_cloudfunctions2_function.rideshare_plus_function
  ]
}


# Deploy the function (V1)
/*
resource "google_cloudfunctions_function" "rideshare_plus_function" {
  project     = var.project_id
  region      = var.cloud_function_region
  name        = "demo-rest-api-service"
  description = "demo-rest-api-service"
  runtime     = "python310"

  available_memory_mb          = 256
  source_archive_bucket        = google_storage_bucket.code_bucket.name
  source_archive_object        = google_storage_bucket_object.rideshare_plus_function_zip_upload.name
  trigger_http                 = true
  ingress_settings             = "ALLOW_ALL"
  https_trigger_security_level = "SECURE_ALWAYS"
  entry_point                  = "entrypoint"

  environment_variables = {
    PROJECT_ID = var.project_id
  }

  depends_on = [ 
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload
  ]  
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "rideshare_plus_function_invoker" {
  project        = var.project_id
  region         = var.cloud_function_region
  cloud_function = google_cloudfunctions_function.rideshare_plus_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"

  depends_on = [ 
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_cloudfunctions_function.rideshare_plus_function
  ]    
}
*/

####################################################################################
# BigQuery - Connections (BigLake, Functions, etc)
####################################################################################
# Cloud Function connection
# https://cloud.google.com/bigquery/docs/biglake-quickstart#terraform
resource "google_bigquery_connection" "cloud_function_connection" {
  project       = var.project_id
  connection_id = "cloud-function"
  location      = var.bigquery_region
  friendly_name = "cloud-function"
  description   = "cloud-function"
  cloud_resource {}
  depends_on = [
    google_bigquery_connection.cloud_function_connection
  ]
}


# Allow service account to invoke the cloud function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.bigquery_external_function.project
  region         = google_cloudfunctions_function.bigquery_external_function.region
  cloud_function = google_cloudfunctions_function.bigquery_external_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_bigquery_connection.cloud_function_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection
  ]
}


# Allow cloud function service account to read storage [V1 Function]
resource "google_project_iam_member" "bq_connection_iam_cloud_invoker" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection
  ]
}

# Allow cloud function service account to call the STT API
resource "google_project_iam_member" "stt_iam_cloud_invoker" {
  project = var.project_id
  role    = "roles/speech.client"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection
  ]
}



# Allow cloud function service account to read storage [V2 Function]
resource "google_project_iam_member" "cloudfunction_rest_api_iam" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection
  ]
}



# The cloud function needs to read/write to this bucket (code bucket)
resource "google_storage_bucket_iam_member" "function_code_bucket_storage_admin" {
  bucket = google_storage_bucket.code_bucket.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection,
    google_project_iam_member.bq_connection_iam_cloud_invoker
  ]
}

# Allow cloud function service account to run BQ jobs
resource "google_project_iam_member" "cloud_function_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection,
    google_storage_bucket_iam_member.function_code_bucket_storage_admin
  ]
}

# Allow cloud function to access Rideshare BQ Datasets
resource "google_bigquery_dataset_access" "cloud_function_access_bq_rideshare_curated" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_lakehouse_curated_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = "${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_cloudfunctions2_function.rideshare_plus_function,
    google_bigquery_dataset.rideshare_lakehouse_curated_dataset
  ]
}

# For streaming data / view
resource "google_bigquery_dataset_access" "cloud_function_access_bq_rideshare_raw" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_lakehouse_raw_dataset.dataset_id
  role          = "roles/bigquery.dataViewer"
  user_by_email = "${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_cloudfunctions2_function.rideshare_plus_function,
    google_bigquery_dataset.rideshare_lakehouse_raw_dataset
  ]
}

# For streaming data / view [V2 function]
resource "google_bigquery_dataset_access" "cloud_function_access_bq_taxi_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.taxi_dataset.dataset_id
  role          = "roles/bigquery.dataViewer"
  user_by_email = "${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_cloudfunctions2_function.rideshare_plus_function,
    google_bigquery_dataset.taxi_dataset
  ]
}



# BigLake connection
resource "google_bigquery_connection" "biglake_connection" {
  project       = var.project_id
  connection_id = "biglake-connection"
  location      = var.bigquery_region
  friendly_name = "biglake-connection"
  description   = "biglake-connection"
  cloud_resource {}
  depends_on = [
    google_bigquery_connection.cloud_function_connection
  ]
}


# Allow BigLake to read storage
resource "google_project_iam_member" "bq_connection_iam_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}

# Allow BigLake connection to call STT
resource "google_project_iam_member" "bq_connection_iam_stt_client" {
  project = var.project_id
  role    = "roles/speech.client"
  member  = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}


# BigLake Managed Tables
resource "google_storage_bucket_iam_member" "bq_connection_mt_iam_object_owner" {
  bucket = google_storage_bucket.biglake_managed_table_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}


# Allow BigLake to custom role
resource "google_project_iam_member" "biglake_customconnectiondelegate" {
  project = var.project_id
  role    = google_project_iam_custom_role.customconnectiondelegate.id
  member  = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection,
    google_project_iam_custom_role.customconnectiondelegate
  ]
}


# Vertex AI connection
resource "google_bigquery_connection" "vertex_ai_connection" {
  project       = var.project_id
  connection_id = "vertex-ai"
  location      = var.bigquery_region
  friendly_name = "vertex-ai"
  description   = "vertex-ai"
  cloud_resource {}
  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}


# Allow Vertex AI connection to Vertex User
resource "google_project_iam_member" "vertex_ai_connection_vertex_user_role" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_bigquery_connection.vertex_ai_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.vertex_ai_connection
  ]
}


####################################################################################
# BigQuery Table with Column Level Security
####################################################################################
resource "google_bigquery_table" "default" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.taxi_dataset.dataset_id
  table_id   = "taxi_trips_with_col_sec"

  clustering = ["Pickup_DateTime"]

  schema = <<EOF
[
  {
    "name": "Vendor_Id",
    "type": "INTEGER",
    "mode": "NULLABLE"
  },
  {
    "name": "Pickup_DateTime",
    "type": "TIMESTAMP",
    "mode": "NULLABLE"
  },
  {
    "name": "Dropoff_DateTime",
    "type": "TIMESTAMP",
    "mode": "NULLABLE"
  },
  {
    "name": "Passenger_Count",
    "type": "INTEGER",
    "mode": "NULLABLE"
  },
  {
    "name": "Trip_Distance",
    "type": "FLOAT64",
    "mode": "NULLABLE"
  },
  {
    "name": "Rate_Code_Id",
    "type": "INTEGER",
    "mode": "NULLABLE"
  },
  {
    "name": "Store_And_Forward",
    "type": "STRING",
    "mode": "NULLABLE"
  },
  {
    "name": "PULocationID",
    "type": "INTEGER",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.data_masking_policy_tag.id}"]
      }
  },
  {
    "name": "DOLocationID",
    "type": "INTEGER",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.data_masking_policy_tag.id}"]
      }
  },
  {
    "name": "Payment_Type_Id",
    "type": "INTEGER",
    "mode": "NULLABLE"
  },
  {
    "name": "Fare_Amount",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.low_security_policy_tag.id}"]
      }
  },
  {
    "name": "Surcharge",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.low_security_policy_tag.id}"]
      }
  },
  {
    "name": "MTA_Tax",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.low_security_policy_tag.id}"]
      }
  },
  {
    "name": "Tip_Amount",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.high_security_policy_tag.id}"]
      }
  },
  {
    "name": "Tolls_Amount",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.low_security_policy_tag.id}"]
      }
  },
  {
    "name": "Improvement_Surcharge",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.low_security_policy_tag.id}"]
      }
  },
  {
    "name": "Total_Amount",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.high_security_policy_tag.id}"]
      }
  },
  {
    "name": "Congestion_Surcharge",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "policyTags": {
        "names": ["${google_data_catalog_policy_tag.low_security_policy_tag.id}"]
      }
  }     
]
EOF
  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy,
    google_data_catalog_policy_tag.low_security_policy_tag,
    google_data_catalog_policy_tag.high_security_policy_tag,
  ]
}


resource "google_bigquery_table" "taxi_trips_streaming" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.taxi_dataset.dataset_id
  table_id   = "taxi_trips_streaming"

  time_partitioning {
    field = "timestamp"
    type  = "HOUR"
  }

  clustering = ["ride_id"]

  schema = <<EOF
[
  {
    "name": "ride_id",
    "type": "STRING",
    "mode": "NULLABLE"
  },
  {
    "name": "point_idx",
    "type": "INTEGER",
    "mode": "NULLABLE"
  },
  {
    "name": "latitude",
    "type": "FLOAT64",
    "mode": "NULLABLE"
  },
  {
    "name": "longitude",
    "type": "FLOAT64",
    "mode": "NULLABLE"
  },
  {
    "name": "timestamp",
    "type": "TIMESTAMP",
    "mode": "NULLABLE"
  },
  {
    "name": "meter_reading",
    "type": "FLOAT64",
    "mode": "NULLABLE"
  },
  {
    "name": "meter_increment",
    "type": "FLOAT64",
    "mode": "NULLABLE"
  },
  {
    "name": "ride_status",
    "type": "STRING",
    "mode": "NULLABLE"
  },
  {
    "name": "passenger_count",
    "type": "INTEGER",
    "mode": "NULLABLE"
  },
  {
    "name": "product_id",
    "type": "INTEGER",
    "mode": "NULLABLE"
  } 
]
EOF
  depends_on = [
    google_data_catalog_taxonomy.business_critical_taxonomy,
    google_data_catalog_policy_tag.low_security_policy_tag,
    google_data_catalog_policy_tag.high_security_policy_tag,
  ]
}


####################################################################################
# Spanner
####################################################################################
/* This is now part of a DAG

resource "google_spanner_instance" "spanner_instance" {
  project          = var.project_id
  config           = var.spanner_config
  display_name     = "main-instance"
  processing_units = 100
}

resource "google_spanner_database" "spanner_weather_database" {
  project  = var.project_id
  instance = google_spanner_instance.spanner_instance.name
  name     = "weather"
  ddl = [
    "CREATE TABLE weather (station_id STRING(100), station_date DATE, snow_mm_amt FLOAT64, precipitation_tenth_mm_amt FLOAT64, min_celsius_temp FLOAT64, max_celsius_temp FLOAT64) PRIMARY KEY(station_date,station_id)",
  ]
  deletion_protection = false

  depends_on = [
    google_spanner_instance.spanner_instance
  ]
}
*/


####################################################################################
# DataFlow
####################################################################################
# Subnet for dataflow cluster
resource "google_compute_subnetwork" "dataflow_subnet" {
  project                  = var.project_id
  name                     = "dataflow-subnet"
  ip_cidr_range            = "10.4.0.0/16"
  region                   = var.dataflow_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}


# Firewall rule for dataflow cluster
resource "google_compute_firewall" "dataflow_subnet_firewall_rule" {
  project = var.project_id
  name    = "dataflow-firewall"
  network = google_compute_network.default_network.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
  source_ranges = ["10.4.0.0/16"]

  depends_on = [
    google_compute_subnetwork.dataflow_subnet
  ]
}


# Service account for dataflow cluster
resource "google_service_account" "dataflow_service_account" {
  project      = var.project_id
  account_id   = "dataflow-service-account"
  display_name = "Service Account for Dataflow Environment"
}


# Grant editor (too high) to service account
resource "google_project_iam_member" "dataflow_service_account_editor_role" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.dataflow_service_account.email}"

  depends_on = [
    google_service_account.dataflow_service_account
  ]
}



####################################################################################
# Set Impersonation for BigQuery Data Transfer Service for Composer
####################################################################################
# NOTE: In order to for the data transfer server service account "gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
#       to be created, a call must be made to the service.  The below will do a "list" call which
#       will return nothing, but will trigger the cloud to create the service account.  Then
#       IAM permissions can be set for this account.
# resource "null_resource" "trigger_data_trasfer_service_account_create" {
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash","-c"]
#     command     = <<EOF
# if [ -z "$${GOOGLE_APPLICATION_CREDENTIALS}" ]
# then
#     echo "We are not running in a local docker container.  No need to login."
# else
#     echo "We are running in local docker container. Logging in."
#     gcloud auth activate-service-account "${var.deployment_service_account_name}" --key-file="$${GOOGLE_APPLICATION_CREDENTIALS}" --project="${var.project_id}"
#     gcloud config set account "${var.deployment_service_account_name}"
# fi 
# curl "https://bigquerydatatransfer.googleapis.com/v1/projects/${var.project_id}/locations/${var.bigquery_non_multi_region}/transferConfigs" \
#   --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})"  \
#   --header "Accept: application/json" \
#   --compressed
# EOF
#   }
#   depends_on = [
#     google_project_iam_member.cloudcomposer_account_service_agent_v2_ext,
#     google_project_iam_member.cloudcomposer_account_service_agent,
#     google_service_account.composer_service_account
#   ]
# }

# Add the Service Account Short Term Token Minter role to a Google-managed service account used by the BigQuery Data Transfer Service
resource "google_project_service_identity" "service_identity_bigquery_data_transfer" {
  project = var.project_id
  service = "bigquerydatatransfer.googleapis.com"
  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext,
    google_project_iam_member.cloudcomposer_account_service_agent,
    google_service_account.composer_service_account
  ]
}


resource "time_sleep" "create_bigquerydatatransfer_account_time_delay" {
  depends_on      = [google_project_service_identity.service_identity_bigquery_data_transfer]
  create_duration = "30s"
}


resource "google_service_account_iam_member" "service_account_impersonation" {
  service_account_id = google_service_account.composer_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.service_identity_bigquery_data_transfer.email}"
  #                    "serviceAccount:service-${var.project_number}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
  depends_on = [time_sleep.create_bigquerydatatransfer_account_time_delay]
}


resource "google_project_iam_member" "iam_member_bigquerydatatransfer_serviceAgent" {
  project    = var.project_id
  role       = "roles/bigquerydatatransfer.serviceAgent"
  member     = "serviceAccount:${google_project_service_identity.service_identity_bigquery_data_transfer.email}"
  depends_on = [google_service_account_iam_member.service_account_impersonation]
}


####################################################################################
# Dataplex (Tag Templates)
####################################################################################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/data_catalog_tag_template
resource "google_data_catalog_tag_template" "table_dq_tag_template" {
  project         = var.project_id
  tag_template_id = "table_dq_tag_template"
  region          = var.data_catalog_region
  display_name    = "Data-Quality-Table"

  fields {
    field_id     = "table_name"
    display_name = "Table Name"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  fields {
    field_id     = "record_count"
    display_name = "Number of rows in the data asset"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "latest_execution_ts"
    display_name = "Last Data Quality Run Date"
    type {
      primitive_type = "TIMESTAMP"
    }
  }

  fields {
    field_id     = "columns_validated"
    display_name = "Number of columns validated"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "columns_count"
    display_name = "Number of columns in data asset"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "success_pct"
    display_name = "Success Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }
  fields {
    field_id     = "failed_pct"
    display_name = "Failed Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "invocation_id"
    display_name = "Data Quality Invocation Id"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  force_delete = "false"
}


resource "google_data_catalog_tag_template" "column_dq_tag_template" {
  project         = var.project_id
  tag_template_id = "column_dq_tag_template"
  region          = var.data_catalog_region
  display_name    = "Data-Quality-Column"


  fields {
    field_id     = "table_name"
    display_name = "Table Name"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  fields {
    field_id     = "column_id"
    display_name = "Column Name"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id     = "execution_ts"
    display_name = "Last Run Date"
    type {
      primitive_type = "TIMESTAMP"
    }
  }

  fields {
    field_id     = "rule_binding_id"
    display_name = "Rule Binding"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id     = "rule_id"
    display_name = "Rule Id"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id     = "dimension"
    display_name = "Dimension"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id     = "rows_validated"
    display_name = "Rows Validated"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "success_count"
    display_name = "Success Count"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "success_pct"
    display_name = "Success Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "failed_count"
    display_name = "Failed Count"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "failed_pct"
    display_name = "Failed Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "null_count"
    display_name = "Null Count"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "null_pct"
    display_name = "Null Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id     = "invocation_id"
    display_name = "Invocation Id"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  force_delete = "false"

  depends_on = [google_data_catalog_tag_template.table_dq_tag_template]
}


####################################################################################
# App Engine
####################################################################################
resource "google_app_engine_application" "rideshare_plus_app_engine" {
  project     = var.project_id
  location_id = var.appengine_region
}


####################################################################################
# Pub/Sub
####################################################################################
resource "google_project_service_identity" "service_identity_pub_sub" {
  project = var.project_id
  service = "pubsub.googleapis.com"
  depends_on = [
  ]
}

resource "time_sleep" "create_pubsub_account_time_delay" {
  depends_on      = [google_project_service_identity.service_identity_pub_sub]
  create_duration = "30s"
}

# Grant require worker role
resource "google_bigquery_dataset_access" "pubsub_access_bq_taxi_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.taxi_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_project_service_identity.service_identity_pub_sub.email

  depends_on = [
    time_sleep.create_pubsub_account_time_delay
  ]
}


####################################################################################
# Colab Enterprise
####################################################################################
# Subnet for colab enterprise
resource "google_compute_subnetwork" "colab_subnet" {
  project                  = var.project_id
  name                     = "colab-subnet"
  ip_cidr_range            = "10.8.0.0/16"
  region                   = var.colab_enterprise_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}

# https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/projects.locations.notebookRuntimeTemplates
# NOTE: If you want a "when = destroy" example TF please see: 
#       https://github.com/GoogleCloudPlatform/data-analytics-golden-demo/blob/main/cloud-composer/data/terraform/dataplex/terraform.tf#L147
resource "null_resource" "colab_runtime_template" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://${var.colab_enterprise_region}-aiplatform.googleapis.com/ui/projects/${var.project_id}/locations/${var.colab_enterprise_region}/notebookRuntimeTemplates?notebookRuntimeTemplateId=colab-enterprise-template \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
  --header "Content-Type: application/json" \
  --data '{
        displayName: "colab-enterprise-template", 
        description: "colab-enterprise-template",
        isDefault: true,
        machineSpec: {
          machineType: "e2-highmem-4"
        },
        dataPersistentDiskSpec: {
          diskType: "pd-standard",
          diskSizeGb: 500,
        },
        networkSpec: {
          enableInternetAccess: false,
          network: "projects/${var.project_id}/global/networks/vpc-main", 
          subnetwork: "projects/${var.project_id}/regions/${var.colab_enterprise_region}/subnetworks/colab-subnet"
        },
        shieldedVmConfig: {
          enableSecureBoot: true
        }
  }'
EOF
  }
  depends_on = [
    google_compute_subnetwork.colab_subnet
  ]
}

# https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/projects.locations.notebookRuntimes
resource "null_resource" "colab_runtime" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://${var.colab_enterprise_region}-aiplatform.googleapis.com/ui/projects/${var.project_id}/locations/${var.colab_enterprise_region}/notebookRuntimes:assign \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
  --header "Content-Type: application/json" \
  --data '{
      notebookRuntimeTemplate: "projects/${var.project_number}/locations/${var.colab_enterprise_region}/notebookRuntimeTemplates/colab-enterprise-template",
      notebookRuntime: {
        displayName: "colab-enterprise-runtime", 
        description: "colab-enterprise-runtime",
        runtimeUser: "${var.gcp_account_name}"
      }
}'  
EOF
  }
  depends_on = [
    google_compute_subnetwork.colab_subnet,
    null_resource.colab_runtime_template
  ]
}



####################################################################################
# Cloud Run Rideshare Plus Website
####################################################################################
# Service account
# Permissions to storage
# Permissions to BigQuery (JobUser and Datasets)
# Zip up a website
resource "google_service_account" "cloud_run_rideshare_plus_service_account" {
  project      = var.project_id
  account_id   = "rideshare-plus-service-account"
  display_name = "Service Account for Rideshare Plus website"
}


# Grant access to run BigQuery Jobs
resource "google_project_iam_member" "cloud_run_rideshare_plus_service_account_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloud_run_rideshare_plus_service_account.email}"

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account
  ]
}


# Allow access to read/write storage 
/*
resource "google_project_iam_member" "cloud_run_rideshare_plus_service_account_objectadmin" {
  project  = var.project_id
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${google_service_account.cloud_run_rideshare_plus_service_account.email}"

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_project_iam_member.cloud_run_rideshare_plus_service_account_jobuser
  ]
}
*/

# The cloud function needs to read/write to this bucket (code bucket)
resource "google_storage_bucket_iam_member" "cloud_run_rideshare_plus_service_account_objectadmin" {
  bucket = google_storage_bucket.code_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_rideshare_plus_service_account.email}"

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_storage_bucket.code_bucket,
    google_project_iam_member.cloud_run_rideshare_plus_service_account_jobuser
  ]
}


resource "google_bigquery_dataset_access" "cloud_run_rideshare_lakehouse_curated_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_lakehouse_curated_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.rideshare_lakehouse_curated_dataset,
    google_storage_bucket_iam_member.cloud_run_rideshare_plus_service_account_objectadmin
  ]
}


resource "google_bigquery_dataset_access" "cloud_run_rideshare_lakehouse_enriched_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_lakehouse_enriched_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.rideshare_lakehouse_enriched_dataset,
    google_bigquery_dataset_access.cloud_run_rideshare_lakehouse_curated_dataset
  ]
}

resource "google_bigquery_dataset_access" "cloud_run_rideshare_lakehouse_raw_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_lakehouse_raw_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.rideshare_lakehouse_raw_dataset,
    google_bigquery_dataset_access.cloud_run_rideshare_lakehouse_enriched_dataset
  ]
}


resource "google_bigquery_dataset_access" "cloud_run_rideshare_llm_curated_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.ideshare_llm_curated_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.ideshare_llm_curated_dataset,
    google_bigquery_dataset_access.cloud_run_rideshare_lakehouse_raw_dataset
  ]
}


resource "google_bigquery_dataset_access" "cloud_run_rideshare_llm_enriched_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_llm_enriched_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.rideshare_llm_enriched_dataset,
    google_bigquery_dataset_access.cloud_run_rideshare_llm_curated_dataset
  ]
}


resource "google_bigquery_dataset_access" "cloud_run_rideshare_llm_raw_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.rideshare_llm_raw_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.rideshare_llm_raw_dataset,
    google_bigquery_dataset_access.cloud_run_rideshare_llm_enriched_dataset
  ]
}

resource "google_bigquery_dataset_access" "cloud_run_taxi_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.taxi_dataset.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_service_account.cloud_run_rideshare_plus_service_account.email

  depends_on = [
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_bigquery_dataset.taxi_dataset,
    google_bigquery_dataset_access.cloud_run_rideshare_llm_raw_dataset
  ]
}

# Zip the source code
data "archive_file" "cloud_run_rideshare_website_archive_file" {
  type        = "zip"
  source_dir  = "../cloud-run/rideshare-plus-website"
  output_path = "../cloud-run/rideshare-plus-website.zip"

  depends_on = [
    google_storage_bucket.code_bucket
  ]
}

# Upload code
resource "google_storage_bucket_object" "cloud_run_rideshare_website_archive_upload" {
  name   = "cloud-run/rideshare-plus-website/rideshare-plus-website.zip"
  bucket = google_storage_bucket.code_bucket.name
  source = data.archive_file.cloud_run_rideshare_website_archive_file.output_path

  depends_on = [
    google_storage_bucket.code_bucket,
    data.archive_file.cloud_run_rideshare_website_archive_file
  ]
}

# Repo for Docker Image
resource "google_artifact_registry_repository" "artifact_registry_cloud_run_deploy" {
  project       = var.project_id
  location      = var.cloud_function_region
  repository_id = "cloud-run-source-deploy"
  description   = "cloud-run-source-deploy"
  format        = "DOCKER"
}


# Deploy Cloud Run Web App
# This is a C# MVC dotnet core application
# We want cloud build to build an image and deploy to cloud run
/*
gcloud_make = f"gcloud builds submit " + \
        f"--project=\"{project_id}\" " + \
        f"--pack image=\"{cloud_function_region}-docker.pkg.dev/{project_id}/cloud-run-source-deploy/rideshareplus\" " + \
        f"gs://{code_bucket_name}/cloud-run/rideshare-plus-website/rideshare-plus-website.zip"


gcloud_deploy = f"gcloud run deploy demo-rideshare-plus-website " + \
        f"--project=\"{project_id}\" " + \
        f"--image \"{cloud_function_region}-docker.pkg.dev/{project_id}/cloud-run-source-deploy/rideshareplus\" " + \
        f"--region=\"{cloud_function_region}\" " + \
        f"--cpu=1 " + \
        f"--allow-unauthenticated " + \
        f"--service-account=\"{rideshare_plus_service_account}\" " + \
        f"--set-env-vars \"ENV_PROJECT_ID={project_id}\" " + \
        f"--set-env-vars \"ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET={rideshare_lakehouse_curated_dataset}\" " + \
        f"--set-env-vars \"ENV_CODE_BUCKET={code_bucket_name}\" " + \
        f"--set-env-vars \"ENV_RIDESHARE_LLM_CURATED_DATASET={rideshare_llm_curated_dataset}\""
*/
/*
resource "null_resource" "cloudbuild_buildpack_rideshare_plus_image" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
gcloud builds submit \
      --project="${var.project_id}" \
      --pack image="${var.cloud_function_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/rideshareplus" \
      "gs://code-${var.storage_bucket}/cloud-run/rideshare-plus-website/rideshare-plus-website.zip"
    EOF
  }
  depends_on = [
    google_artifact_registry_repository.artifact_registry_cloud_run_deploy,
    google_storage_bucket.code_bucket,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
  ]
}
*/


# This will execute a cloud build job (there does not seem to be a terraform command)
# The cloud build will build a docker image from the .net core code
# The image will be checked into our Artifact Repo
# The source code is from GCS
# Logic (requires "jq")
# 1. Kick off build
# 2. Wait for build to complete in loop
resource "null_resource" "cloudbuild_rideshareplus_docker_image" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
json=$(curl --request POST \
  "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/builds" \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"source":{"storageSource":{"bucket":"${google_storage_bucket.code_bucket.name}","object":"cloud-run/rideshare-plus-website/rideshare-plus-website.zip"}},"steps":[{"name":"gcr.io/cloud-builders/docker","args":["build","-t","${var.cloud_function_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/rideshareplus","."]},{"name":"gcr.io/cloud-builders/docker","args":["push","${var.cloud_function_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/rideshareplus"]}]}' \
  --compressed)

build_id=$(echo $${json} | jq .metadata.build.id --raw-output)
echo "build_id: $${build_id}"

# Loop while it creates
build_status_id="PENDING"
while [[ "$${build_status_id}" == "PENDING" || "$${build_status_id}" == "QUEUED" || "$${build_status_id}" == "WORKING" ]]
    do
    sleep 5
    build_status_json=$(curl \
    "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/builds/$${build_id}" \
    --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})" \
    --header "Accept: application/json" \
    --compressed)

    build_status_id=$(echo $${build_status_json} | jq .status --raw-output)
    echo "build_status_id: $${build_status_id}"
    done

if [[ "$${build_status_id}" != "SUCCESS" ]]; 
then
    echo "Could not build the RidesharePlus Docker image with Cloud Build"
    exit 1;
else
    echo "Cloud Build Successful"
    # For new projects you need to wait up to 240 seconds after your cloud build.
    # The Cloud Run Terraform task is placed after the deployment of Composer which takes 15+ minutes to deploy.
    # sleep 240
fi
EOF
  }
  depends_on = [
    google_artifact_registry_repository.artifact_registry_cloud_run_deploy,
    google_storage_bucket.code_bucket,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
  ]
}


resource "google_cloud_run_service" "cloud_run_service_rideshare_plus_website" {
  project  = var.project_id
  name     = "demo-rideshare-plus-website"
  location = var.cloud_function_region

  template {
    spec {
      timeout_seconds = 120
      service_account_name = google_service_account.cloud_run_rideshare_plus_service_account.email
      containers { 
        image = "${var.cloud_function_region}-docker.pkg.dev/${var.project_id}/cloud-run-source-deploy/rideshareplus"
        env {
            name  = "ENV_PROJECT_ID"
            value = var.project_id
          }
        env {
            name  = "ENV_CODE_BUCKET"
            value = "code-${var.storage_bucket}"
          }
        env {
            name  = "ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET"
            value = var.bigquery_rideshare_lakehouse_curated_dataset
          }
        env {
            name  = "ENV_RIDESHARE_LLM_CURATED_DATASET"
            value = var.bigquery_rideshare_llm_curated_dataset
          }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    #null_resource.cloudbuild_buildpack_rideshare_plus_image,
    null_resource.cloudbuild_rideshareplus_docker_image,
    google_service_account.cloud_run_rideshare_plus_service_account,
    google_artifact_registry_repository.artifact_registry_cloud_run_deploy,
    google_storage_bucket.code_bucket,
    google_storage_bucket_object.rideshare_plus_function_zip_upload,
    google_composer_environment.composer_env,
  ]
}

output "cloud_run_service_rideshare_plus_website_url" {
  value = "${google_cloud_run_service.cloud_run_service_rideshare_plus_website.status[0].url}"
}

data "google_iam_policy" "cloud_run_service_rideshare_plus_website_noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# Set the cloud run to allow anonymous access
resource "google_cloud_run_service_iam_policy" "google_cloud_run_service_iam_policy_noauth" {
  location = google_cloud_run_service.cloud_run_service_rideshare_plus_website.location
  project  = google_cloud_run_service.cloud_run_service_rideshare_plus_website.project
  service  = google_cloud_run_service.cloud_run_service_rideshare_plus_website.name

  policy_data = data.google_iam_policy.cloud_run_service_rideshare_plus_website_noauth.policy_data

  depends_on = [
    google_cloud_run_service.cloud_run_service_rideshare_plus_website
  ]  
}


####################################################################################
# Outputs
####################################################################################

output "gcs_raw_bucket" {
  value = google_storage_bucket.raw_bucket.name
}

output "gcs_processed_bucket" {
  value = google_storage_bucket.processed_bucket.name
}

output "gcs_code_bucket" {
  value = google_storage_bucket.code_bucket.name
}

output "default_network" {
  value = google_compute_network.default_network.name
}

#output "nat-router" {
#  value = google_compute_router.nat-router.name
#}

output "dataproc_subnet_name" {
  value = google_compute_subnetwork.dataproc_subnet.name
}

output "dataproc_subnet_name_ip_cidr_range" {
  value = google_compute_subnetwork.dataproc_subnet.ip_cidr_range
}

output "gcs_dataproc_bucket" {
  value = google_storage_bucket.dataproc_bucket.name
}

output "dataproc_service_account" {
  value = google_service_account.dataproc_service_account.email
}

output "cloudcomposer_account_service_agent_v2_ext" {
  value = google_project_iam_member.cloudcomposer_account_service_agent_v2_ext.member
}

output "composer_subnet" {
  value = google_compute_subnetwork.composer_subnet.name
}

output "composer_subnet_ip_cidr_range" {
  value = google_compute_subnetwork.composer_subnet.ip_cidr_range
}

output "composer_service_account" {
  value = google_service_account.composer_service_account.email
}

output "composer_env_name" {
  value = google_composer_environment.composer_env.name
}

output "composer_env_dag_bucket" {
  value = google_composer_environment.composer_env.config.0.dag_gcs_prefix
}

output "dataproc_serverless_subnet_name" {
  value = google_compute_subnetwork.dataproc_serverless_subnet.name
}

output "dataproc_serverless_ip_cidr_range" {
  value = google_compute_subnetwork.dataproc_serverless_subnet.ip_cidr_range
}

output "business_critical_taxonomy_aws_id" {
  value = google_data_catalog_taxonomy.business_critical_taxonomy_aws.id
}

output "business_critical_taxonomy_azure_id" {
  value = google_data_catalog_taxonomy.business_critical_taxonomy_azure.id
}

output "business_critical_taxonomy_id" {
  value = google_data_catalog_taxonomy.business_critical_taxonomy.id
}

output "bigquery_external_function" {
  value = google_cloudfunctions_function.bigquery_external_function.name
}

output "cloud_function_connection" {
  value = google_bigquery_connection.cloud_function_connection.connection_id
}

output "biglake_connection" {
  value = google_bigquery_connection.biglake_connection.connection_id
}

output "dataflow_subnet_name" {
  value = google_compute_subnetwork.dataflow_subnet.name
}

output "dataflow_subnet_ip_cidr_range" {
  value = google_compute_subnetwork.dataflow_subnet.ip_cidr_range
}

output "dataflow_service_account" {
  value = google_service_account.dataflow_service_account.email
}

output "bigquery_taxi_dataset" {
  value = var.bigquery_taxi_dataset
}

output "bigquery_thelook_ecommerce_dataset" {
  value = var.bigquery_thelook_ecommerce_dataset
}

output "bigquery_rideshare_lakehouse_raw_dataset" {
  value = var.bigquery_rideshare_lakehouse_raw_dataset
}

output "bigquery_rideshare_lakehouse_enriched_dataset" {
  value = var.bigquery_rideshare_lakehouse_enriched_dataset
}

output "bigquery_rideshare_lakehouse_curated_dataset" {
  value = var.bigquery_rideshare_lakehouse_curated_dataset
}

output "gcs_rideshare_lakehouse_raw_bucket" {
  value = google_storage_bucket.rideshare_lakehouse_raw.name
}

output "gcs_rideshare_lakehouse_enriched_bucket" {
  value = google_storage_bucket.rideshare_lakehouse_enriched.name
}

output "gcs_rideshare_lakehouse_curated_bucket" {
  value = google_storage_bucket.rideshare_lakehouse_curated.name
}

output "demo_rest_api_service_uri" {
  value = google_cloudfunctions2_function.rideshare_plus_function.service_config[0].uri
}

output "bigquery_rideshare_llm_raw_dataset" {
  value = var.bigquery_rideshare_llm_raw_dataset
}

output "bigquery_rideshare_llm_enriched_dataset" {
  value = var.bigquery_rideshare_llm_enriched_dataset
}

output "bigquery_rideshare_llm_curated_dataset" {
  value = var.bigquery_rideshare_llm_curated_dataset
}

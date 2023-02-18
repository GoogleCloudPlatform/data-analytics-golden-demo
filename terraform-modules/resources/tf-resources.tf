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
variable "spanner_config" {}
variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "bigquery_region" {}
variable "curl_impersonation" {}

variable "aws_omni_biglake_dataset_region" {}
variable "aws_omni_biglake_dataset_name" {}
variable "azure_omni_biglake_dataset_name" {}
variable "azure_omni_biglake_dataset_region" {}

# Hardcoded
variable "bigquery_taxi_dataset" {
  type        = string
  default     = "taxi_dataset"
}
variable "bigquery_thelook_ecommerce_dataset" {
  type        = string
  default     = "thelook_ecommerce"
}
variable "bigquery_rideshare_lakehouse_raw_dataset" {
  type        = string
  default     = "rideshare_lakehouse_raw"
}
variable "bigquery_rideshare_lakehouse_enriched_dataset" {
  type        = string
  default     = "rideshare_lakehouse_enriched"
}
variable "bigquery_rideshare_lakehouse_curated_dataset" {
  type        = string
  default     = "rideshare_lakehouse_curated"
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
  name                        = "rideshare-lakehouse-raw--${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "rideshare_lakehouse_enriched" {
  project                     = var.project_id
  name                        = "rideshare-lakehouse-enriched--${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "rideshare_lakehouse_curated" {
  project                     = var.project_id
  name                        = "rideshare-lakehouse-curated--${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
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

# Firewall for NAT Router
resource "google_compute_firewall" "subnet_firewall_rule" {
  project  = var.project_id
  name     = "subnet-nat-firewall"
  network  = google_compute_network.default_network.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
  source_ranges = ["10.2.0.0/16","10.3.0.0/16","10.4.0.0/16","10.5.0.0/16"]

  depends_on = [
    google_compute_subnetwork.composer_subnet,
    google_compute_subnetwork.dataproc_subnet,
    google_compute_subnetwork.bigspark_subnet,
    google_compute_subnetwork.dataflow_subnet
  ]
}


# Creation of a router so private IPs can access the internet
resource "google_compute_router" "nat-router" {
  name    = "nat-router"
  region  = var.region
  network  = google_compute_network.default_network.id

  depends_on = [
    google_compute_firewall.subnet_firewall_rule
  ]
}


# Creation of a NAT
resource "google_compute_router_nat" "nat-config" {
  name                               = "nat-config"
  router                             = "${google_compute_router.nat-router.name}"
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.nat-router
  ]
}


####################################################################################
# Dataproc
####################################################################################
# Subnet for dataproc cluster
resource "google_compute_subnetwork" "dataproc_subnet" {
  project       = var.project_id
  name          = "dataproc-subnet"
  ip_cidr_range = "10.3.0.0/16"
  region        = var.region
  network       = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}

# Firewall rule for dataproc cluster
resource "google_compute_firewall" "dataproc_subnet_firewall_rule" {
  project  = var.project_id
  name     = "dataproc-firewall"
  network  = google_compute_network.default_network.id

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
  location                    = var.region
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
  project  = var.project_id
  role     = "roles/dataproc.worker"
  member   = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_service_account.dataproc_service_account
  ]
}


# Grant editor (too high) to service account
resource "google_project_iam_member" "dataproc_service_account_editor_role" {
  project  = var.project_id
  role     = "roles/editor"
  member   = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_project_iam_member.dataproc_service_account_worker_role
  ]
}


# Create the cluster
# NOTE: This is now done in Airflow, but has kept for reference
/*
resource "google_dataproc_cluster" "mycluster" {
  name     = "testcluster"
  project  = var.project_id
  region   = var.region
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
  project  = var.project_id
  role     = "roles/composer.ServiceAgentV2Ext"
  member   = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}


# Cloud Composer API Service Agent
resource "google_project_iam_member" "cloudcomposer_account_service_agent" {
  project  = var.project_id
  role     = "roles/composer.serviceAgent"
  member   = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"

  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext
  ]
}


resource "google_compute_subnetwork" "composer_subnet" {
  project       = var.project_id
  name          = "composer-subnet"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = google_compute_network.default_network.id
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
  project  = var.project_id
  role     = "roles/composer.worker"
  member   = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_service_account.composer_service_account
  ]
}


# The DAGs will be doing a lot of BQ automation
# This role can be scaled down once the DAGs are created (the DAGS do high level Owner automation - just for demo purposes)
resource "google_project_iam_member" "composer_service_account_bq_admin_role" {
  # provider= google.service_principal_impersonation
  project  = var.project_id
  role     = "roles/owner"
  member   = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_project_iam_member.composer_service_account_worker_role
  ]
}

# Let composer impersonation the service account that can change org policies (for demo purposes)
resource "google_service_account_iam_member" "cloudcomposer_service_account_impersonation" {
  service_account_id ="projects/${var.project_id}/serviceAccounts/${var.project_id}@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.composer_service_account.email}"
  depends_on         = [ google_project_iam_member.composer_service_account_bq_admin_role ]
}

# ActAs role
resource "google_project_iam_member" "cloudcomposer_act_as" {
  project  = var.project_id
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_service_account_iam_member.cloudcomposer_service_account_impersonation
  ]
}

resource "google_composer_environment" "composer_env" {
  project  = var.project_id
  name     = "data-analytics-demo-composer-2"
  region   = var.region

  config {

    software_config {
      image_version = "composer-2.0.31-airflow-2.3.3"
      #"composer-2.0.24-airflow-2.2.5" (errors on webserver)
      #"composer-2.0.0-airflow-2.1.4"
      #"composer-2.0.7-airflow-2.2.3"

      env_variables = {
        ENV_RAW_BUCKET               = "raw-${var.storage_bucket}",
        ENV_PROCESSED_BUCKET         = "processed-${var.storage_bucket}",
        ENV_CODE_BUCKET              = "code-${var.storage_bucket}",
        ENV_REGION                   = var.region,
        ENV_ZONE                     = var.zone,
        ENV_DATAPROC_BUCKET          = "dataproc-${var.storage_bucket}",
        ENV_DATAPROC_SUBNET          = "projects/${var.project_id}/regions/${var.region}/subnetworks/dataproc-subnet",
        ENV_DATAPROC_SERVICE_ACCOUNT = "dataproc-service-account@${var.project_id}.iam.gserviceaccount.com",
        ENV_GCP_ACCOUNT_NAME         = "${var.gcp_account_name}",
        ENV_TAXI_DATASET_ID          = google_bigquery_dataset.taxi_dataset.dataset_id,
        ENV_SPANNER_INSTANCE_ID      = "spanner-${var.random_extension}" //google_spanner_instance.spanner_instance.name,
        ENV_BIGQUERY_REGION          = var.bigquery_region,
        ENV_DATAFLOW_SUBNET          = "regions/${var.region}/subnetworks/dataflow-subnet",
        ENV_DATAFLOW_SERVICE_ACCOUNT = "dataflow-service-account@${var.project_id}.iam.gserviceaccount.com",
        ENV_RANDOM_EXTENSION         = var.random_extension
        ENV_SPANNER_CONFIG           = var.spanner_config
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
    #google_spanner_database.spanner_weather_database
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
  description   = "This contains the rideshare plus raw zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_lakehouse_enriched_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_lakehouse_enriched_dataset
  friendly_name = var.bigquery_rideshare_lakehouse_enriched_dataset
  description   = "This contains the rideshare plus enriched zone"
  location      = var.bigquery_region
}

resource "google_bigquery_dataset" "rideshare_lakehouse_curated_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_rideshare_lakehouse_curated_dataset
  friendly_name = var.bigquery_rideshare_lakehouse_curated_dataset
  description   = "This contains the rideshare plus curated zone"
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

# Temp work bucket for BigSpark
resource "google_storage_bucket" "bigspark_bucket" {
  project                     = var.project_id
  name                        = "bigspark-${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# Subnet for bigspark / central region
resource "google_compute_subnetwork" "bigspark_subnet" {
  project                  = var.project_id
  name                     = "bigspark-subnet"
  ip_cidr_range            = "10.5.0.0/16"
  region                   = "us-central1" # var.region - must be in central during preview
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}

# Needed for BigSpark to Dataproc
resource "google_compute_firewall" "bigspark_subnet_firewall_rule" {
  project  = var.project_id
  name     = "bigspark-firewall"
  network  = google_compute_network.default_network.id

  allow {
    protocol = "all"
  }

  source_ranges = ["10.5.0.0/16"]

  depends_on = [
    google_compute_subnetwork.bigspark_subnet
  ]
}


####################################################################################
# Data Catalog Taxonomy
# AWS Region
####################################################################################
resource "google_data_catalog_taxonomy" "business_critical_taxonomy_aws" {
  project  = var.project_id
  region   = var.aws_omni_biglake_dataset_region
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
  project  = var.project_id
  region   = var.azure_omni_biglake_dataset_region
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
# Data Catalog Taxonomy
# Taxi US Region
####################################################################################
resource "google_data_catalog_taxonomy" "business_critical_taxonomy" {
  project  = var.project_id
  region   = var.bigquery_region
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
  region      = "us-central1"
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


# Deploy the function
resource "google_cloudfunctions_function" "rideshare_plus_function" {
  project     = var.project_id
  region      = "us-central1"
  name        = "rideshare_plus_rest_api"
  description = "rideshare_plus_rest_api"
  runtime     = "python310"

  available_memory_mb          = 256
  source_archive_bucket        = google_storage_bucket.code_bucket.name
  source_archive_object        = google_storage_bucket_object.rideshare_plus_function_zip_upload.name
  trigger_http                 = true
  ingress_settings             = "ALLOW_ALL"
  https_trigger_security_level = "SECURE_ALWAYS"
  entry_point                  = "entrypoint"
  depends_on = [ 
    google_storage_bucket.code_bucket,
    data.archive_file.rideshare_plus_function_zip,
    google_storage_bucket_object.rideshare_plus_function_zip_upload
  ]  
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "rideshare_plus_function_invoker" {
  project        = var.project_id
  region         = "us-central1"
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

####################################################################################
# BigQuery - Connections (BigLake, Functions, etc)
####################################################################################
# Cloud Function connection
# https://cloud.google.com/bigquery/docs/biglake-quickstart#terraform
resource "google_bigquery_connection" "cloud_function_connection" {
   connection_id = "cloud-function"
   location      = "US"
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


# Allow cloud function service account to read storage
resource "google_project_iam_member" "bq_connection_iam_cloud_invoker" {
  project  = var.project_id
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"

  depends_on = [ 
    google_storage_bucket.code_bucket,
    data.archive_file.bigquery_external_function_zip,
    google_storage_bucket_object.bigquery_external_function_zip_upload,
    google_cloudfunctions_function.bigquery_external_function,
    google_bigquery_connection.cloud_function_connection
  ]
}


# BigLake connection
resource "google_bigquery_connection" "biglake_connection" {
   connection_id = "biglake-connection"
   location      = "US"
   friendly_name = "biglake-connection"
   description   = "biglake-connection"
   cloud_resource {}
   depends_on = [ 
      google_bigquery_connection.cloud_function_connection
   ]
}


# Allow BigLake to read storage
resource "google_project_iam_member" "bq_connection_iam_object_viewer" {
  project  = var.project_id
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection
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
    type = "HOUR"
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
  project       = var.project_id
  name          = "dataflow-subnet"
  ip_cidr_range = "10.4.0.0/16"
  region        = var.region
  network       = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
  ]
}


# Firewall rule for dataflow cluster
resource "google_compute_firewall" "dataflow_subnet_firewall_rule" {
  project  = var.project_id
  name     = "dataflow-firewall"
  network  = google_compute_network.default_network.id

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
  project  = var.project_id
  role     = "roles/editor"
  member   = "serviceAccount:${google_service_account.dataflow_service_account.email}"

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
resource "null_resource" "trigger_data_trasfer_service_account_create" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command     = <<EOF
if [ -z "$${GOOGLE_APPLICATION_CREDENTIALS}" ]
then
    echo "We are not running in a local docker container.  No need to login."
else
    echo "We are running in local docker container. Logging in."
    gcloud auth activate-service-account "${var.deployment_service_account_name}" --key-file="$${GOOGLE_APPLICATION_CREDENTIALS}" --project="${var.project_id}"
    gcloud config set account "${var.deployment_service_account_name}"
fi 
curl "https://bigquerydatatransfer.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/transferConfigs" \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${var.curl_impersonation})"  \
  --header "Accept: application/json" \
  --compressed
EOF
  }
  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext,
    google_project_iam_member.cloudcomposer_account_service_agent,
    google_service_account.composer_service_account
  ]
}


resource "time_sleep" "create_bigquerydatatransfer_account_time_delay" {
  depends_on      = [null_resource.trigger_data_trasfer_service_account_create]
  create_duration = "30s"
}


resource "google_service_account_iam_member" "service_account_impersonation" {
  service_account_id = google_service_account.composer_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${var.project_number}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
  depends_on         = [ time_sleep.create_bigquerydatatransfer_account_time_delay ]
}
/*
resource "google_service_account_iam_binding" "service_account_impersonation" {
  provider           = google
  service_account_id = google_service_account.composer_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:service-${var.project_number}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
  ]

  depends_on = [
    time_sleep.create_bigquerydatatransfer_account_time_delay,
  ]
}
*/


####################################################################################
# Dataplex (Tag Templates)
####################################################################################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/data_catalog_tag_template
resource "google_data_catalog_tag_template" "table_dq_tag_template" {
  tag_template_id = "table_dq_tag_template"
  region = "us-central1"
  display_name = "Data-Quality-Table"

  fields {
    field_id = "table_name"
    display_name = "Table Name"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  fields {
    field_id = "record_count"
    display_name = "Number of rows in the data asset"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "latest_execution_ts"
    display_name = "Last Data Quality Run Date"
    type {
      primitive_type = "TIMESTAMP"
    }
  }

  fields {
    field_id = "columns_validated"
    display_name = "Number of columns validated"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "columns_count"
    display_name = "Number of columns in data asset"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "success_pct"
    display_name = "Success Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }
  fields {
    field_id = "failed_pct"
    display_name = "Failed Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "invocation_id"
    display_name = "Data Quality Invocation Id"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  force_delete = "false"
}


resource "google_data_catalog_tag_template" "column_dq_tag_template" {
  tag_template_id = "column_dq_tag_template"
  region = "us-central1"
  display_name = "Data-Quality-Column"


  fields {
    field_id = "table_name"
    display_name = "Table Name"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  fields {
    field_id = "column_id"
    display_name = "Column Name"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id = "execution_ts"
    display_name = "Last Run Date"
    type {
      primitive_type = "TIMESTAMP"
    }
  }

  fields {
    field_id = "rule_binding_id"
    display_name = "Rule Binding"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id = "rule_id"
    display_name = "Rule Id"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id = "dimension"
    display_name = "Dimension"
    type {
      primitive_type = "STRING"
    }
  }

  fields {
    field_id = "rows_validated"
    display_name = "Rows Validated"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "success_count"
    display_name = "Success Count"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "success_pct"
    display_name = "Success Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "failed_count"
    display_name = "Failed Count"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "failed_pct"
    display_name = "Failed Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

 fields {
    field_id = "null_count"
    display_name = "Null Count"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "null_pct"
    display_name = "Null Percentage"
    type {
      primitive_type = "DOUBLE"
    }
  }

  fields {
    field_id = "invocation_id"
    display_name = "Invocation Id"
    type {
      primitive_type = "STRING"
    }
    is_required = true
  }

  force_delete = "false"

  depends_on      = [google_data_catalog_tag_template.table_dq_tag_template]
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

output "nat-router" {
  value = google_compute_router.nat-router.name
}

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

output "gcs_bigspark_bucket" {
  value = google_storage_bucket.bigspark_bucket.name
}

output "bigspark_subnet_name" {
  value = google_compute_subnetwork.bigspark_subnet.name
}

output "bigspark_subnet_ip_cidr_range" {
  value = google_compute_subnetwork.bigspark_subnet.ip_cidr_range
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

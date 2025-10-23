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
variable "local_curl_impersonation" {}
variable "dataplex_region" {}
variable "multi_region" {}
variable "bigquery_non_multi_region" {}
variable "vertex_ai_region" {}
variable "data_catalog_region" {}
variable "appengine_region" {}
variable "colab_enterprise_region" {}
variable "dataflow_region" {}
variable "dataproc_region" {}
variable "kafka_region" {}

variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "terraform_service_account" {}

variable "bigquery_governed_data_raw_dataset" {}
variable "bigquery_governed_data_enriched_dataset" {}
variable "bigquery_governed_data_curated_dataset" {}
variable "bigquery_analytics_hub_publisher_dataset" {}
variable "bigquery_analytics_hub_subscriber_dataset" {}
variable "governed_data_raw_bucket" {}
variable "governed_data_enriched_bucket" {}
variable "governed_data_curated_bucket" {}
variable "governed_data_code_bucket" {}
variable "governed_data_scan_bucket" {}
variable "dataflow_staging_bucket" {}

data "google_client_config" "current" {
}

####################################################################################
# Bucket for all data (BigQuery, Spark, etc...)
# This is your "Data Lake" bucket
# If you are using Dataplex you should create a bucket per data lake zone (bronze, silver, gold, etc.)
####################################################################################
resource "google_storage_bucket" "google_storage_bucket_governed_data_raw_bucket" {
  project                     = var.project_id
  name                        = var.governed_data_raw_bucket
  location                    = var.multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_governed_data_enriched_bucket" {
  project                     = var.project_id
  name                        = var.governed_data_enriched_bucket
  location                    = var.multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_governed_data_curated_bucket" {
  project                     = var.project_id
  name                        = var.governed_data_curated_bucket
  location                    = var.multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_governed_data_code_bucket" {
  project                     = var.project_id
  name                        = var.governed_data_code_bucket
  location                    = var.multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_governed_data_scan_bucket" {
  project                     = var.project_id
  name                        = var.governed_data_scan_bucket
  location                    = var.dataplex_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_dataflow_staging" {
  project                     = var.project_id
  name                        = var.dataflow_staging_bucket
  location                    = var.multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
  soft_delete_policy {
    retention_duration_seconds = 0
  }
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

resource "google_compute_subnetwork" "colab_enterprise_subnet" {
  project                  = var.project_id
  name                     = "colab-enterprise-subnet"
  ip_cidr_range            = "10.1.0.0/16"
  region                   = var.colab_enterprise_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network
  ]
}


resource "google_compute_subnetwork" "dataflow_subnet" {
  project                  = var.project_id
  name                     = "dataflow-subnet"
  ip_cidr_range            = "10.2.0.0/16"
  region                   = var.dataflow_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
    google_compute_subnetwork.colab_enterprise_subnet
  ]
}

resource "google_compute_subnetwork" "kafka_subnet" {
  project                  = var.project_id
  name                     = "kafka-subnet"
  ip_cidr_range            = "10.3.0.0/16"
  region                   = var.kafka_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
    google_compute_subnetwork.colab_enterprise_subnet
  ]
}

resource "google_compute_subnetwork" "dataproc_subnet" {
  project                  = var.project_id
  name                     = "dataproc-subnet"
  ip_cidr_range            = "10.4.0.0/16"
  region                   = var.dataproc_region
  network                  = google_compute_network.default_network.id
  private_ip_google_access = true

  depends_on = [
    google_compute_network.default_network,
    google_compute_subnetwork.colab_enterprise_subnet,
    google_compute_subnetwork.kafka_subnet
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
  source_ranges = ["10.1.0.0/16","10.2.0.0/16","10.3.0.0/16","10.4.0.0/16"]

  depends_on = [
    google_compute_subnetwork.colab_enterprise_subnet,
    google_compute_subnetwork.dataflow_subnet,
    google_compute_subnetwork.kafka_subnet
  ]
}

# We want a NAT for every region
locals {
  distinctRegions = distinct([var.colab_enterprise_region, var.dataflow_region, var.kafka_region])
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
# BigQuery Datasets
####################################################################################
resource "google_bigquery_dataset" "google_bigquery_dataset_governed_data_raw" {
  project       = var.project_id
  dataset_id    = var.bigquery_governed_data_raw_dataset
  friendly_name = var.bigquery_governed_data_raw_dataset
  description   = "This dataset contains the raw data for the demo."
  location      = var.multi_region
}

resource "google_bigquery_dataset" "google_bigquery_dataset_governed_data_enriched" {
  project       = var.project_id
  dataset_id    = var.bigquery_governed_data_enriched_dataset
  friendly_name = var.bigquery_governed_data_enriched_dataset
  description   = "This dataset contains the enriched data for the demo."
  location      = var.multi_region
}

resource "google_bigquery_dataset" "google_bigquery_dataset_governed_data_curated" {
  project       = var.project_id
  dataset_id    = var.bigquery_governed_data_curated_dataset
  friendly_name = var.bigquery_governed_data_curated_dataset
  description   = "This dataset contains the curated data for the demo."
  location      = var.multi_region
}


resource "google_bigquery_dataset" "google_bigquery_dataset_analytics_hub_publisher" {
  project       = var.project_id
  dataset_id    = var.bigquery_analytics_hub_publisher_dataset
  friendly_name = var.bigquery_analytics_hub_publisher_dataset
  description   = "This dataset contains the analytics hub publisher data data for the demo."
  location      = var.multi_region
}


####################################################################################
# IAM for cloud build
####################################################################################
# Needed per https://cloud.google.com/build/docs/cloud-build-service-account-updates
resource "google_project_iam_member" "cloudfunction_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
}

# Needed per https://cloud.google.com/build/docs/cloud-build-service-account-updates
# Allow cloud function service account to read storage [V2 Function]
resource "google_project_iam_member" "cloudfunction_objectViewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_iam_member.cloudfunction_builder
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
# BigQuery - Connections (BigLake, Functions, etc)
####################################################################################
# Vertex AI connection
resource "google_bigquery_connection" "vertex_ai_connection" {
  project       = var.project_id
  connection_id = "vertex-ai"
  location      = var.multi_region
  friendly_name = "vertex-ai"
  description   = "vertex-ai"
  cloud_resource {}
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

# BigLake connection
resource "google_bigquery_connection" "biglake_connection" {
  project       = var.project_id
  connection_id = "biglake-connection"
  location      = var.multi_region
  friendly_name = "biglake-connection"
  description   = "biglake-connection"
  cloud_resource {}
}

resource "time_sleep" "biglake_connection_time_delay" {
  depends_on      = [google_bigquery_connection.biglake_connection]
  create_duration = "30s"
}

# Allow BigLake to read storage (at project level, you can do each bucket individually)
resource "google_project_iam_member" "bq_connection_iam_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    time_sleep.biglake_connection_time_delay
  ]
}


# BigLake connection (Dataplex Region: us-central1)
resource "google_bigquery_connection" "biglake_connection_dataplex_region" {
  project       = var.project_id
  connection_id = "biglake-connection-dataplex"
  location      = var.dataplex_region
  friendly_name = "biglake-connection-dataplex"
  description   = "biglake-connection-dataplex"
  cloud_resource {}
}

resource "time_sleep" "biglake_connection_dataplex_region_time_delay" {
  depends_on      = [google_bigquery_connection.biglake_connection_dataplex_region]
  create_duration = "30s"
}

# Allow BigLake to read storage (at project level, you can do each bucket individually)
resource "google_project_iam_member" "bq_connection_dataplex_region_iam_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_bigquery_connection.biglake_connection_dataplex_region.cloud_resource[0].service_account_id}"

  depends_on = [
    time_sleep.biglake_connection_dataplex_region_time_delay
  ]
}


####################################################################################
# Colab Enterprise
####################################################################################
# https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/projects.locations.notebookRuntimeTemplates
# NOTE: If you want a "when = destroy" example TF please see: 
#       https://github.com/GoogleCloudPlatform/data-analytics-golden-demo/blob/main/cloud-composer/data/terraform/dataplex/terraform.tf#L147
resource "null_resource" "colab_runtime_template" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://${var.colab_enterprise_region}-aiplatform.googleapis.com/ui/projects/${var.project_id}/locations/${var.colab_enterprise_region}/notebookRuntimeTemplates?notebookRuntimeTemplateId=colab-enterprise-template \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --data '{
        displayName: "colab-enterprise-template", 
        description: "colab-enterprise-template",
        isDefault: true,
        machineSpec: {
          machineType: "e2-highmem-4"
        },
        networkSpec: {
          enableInternetAccess: false,
          network: "projects/${var.project_id}/global/networks/vpc-main", 
          subnetwork: "projects/${var.project_id}/regions/${var.colab_enterprise_region}/subnetworks/${google_compute_subnetwork.colab_enterprise_subnet.name}"
        },
        shieldedVmConfig: {
          enableSecureBoot: true
        }
  }'
EOF
  }
  depends_on = [
    google_compute_subnetwork.colab_enterprise_subnet
  ]
}

# https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/projects.locations.notebookRuntimes
resource "null_resource" "colab_runtime" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  https://${var.colab_enterprise_region}-aiplatform.googleapis.com/ui/projects/${var.project_id}/locations/${var.colab_enterprise_region}/notebookRuntimes:assign \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
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
    null_resource.colab_runtime_template
  ]
}


####################################################################################
# New Service Account - For Continuous Queries
####################################################################################
resource "google_service_account" "kafka_continuous_query_service_account" {
  project      = var.project_id
  account_id   = "kafka-continuous-query"
  display_name = "kafka-continuous-query"
}

# Needs access to BigQuery
resource "google_project_iam_member" "kafka_continuous_query_service_account_bigquery_admin" {
  project  = var.project_id
  role     = "roles/bigquery.admin"
  member   = "serviceAccount:${google_service_account.kafka_continuous_query_service_account.email}"

  depends_on = [
    google_service_account.kafka_continuous_query_service_account
  ]
}

# Needs access to Pub/Sub
resource "google_project_iam_member" "kafka_continuous_query_service_account_pubsub_admin" {
  project  = var.project_id
  role     = "roles/pubsub.admin"
  member   = "serviceAccount:${google_service_account.kafka_continuous_query_service_account.email}"

  depends_on = [
    google_project_iam_member.kafka_continuous_query_service_account_bigquery_admin
  ]
}


####################################################################################
# Pub/Sub (Topic and Subscription)
####################################################################################
resource "google_pubsub_topic" "google_pubsub_topic_governed_data_topic" {
  project  = var.project_id
  name = "pubsub-governed-data-topic"
  message_retention_duration = "86400s"
}

resource "google_pubsub_subscription" "google_pubsub_subscription_governed_data_subscription" {
  project  = var.project_id  
  name  = "pubsub-governed-data-subscription"
  topic = google_pubsub_topic.google_pubsub_topic_governed_data_topic.id

  message_retention_duration = "86400s"
  retain_acked_messages      = false

  expiration_policy {
    ttl = "86400s"
  }

  retry_policy {
    minimum_backoff = "10s"
  }

  enable_message_ordering    = false

  depends_on = [
    google_pubsub_topic.google_pubsub_topic_governed_data_topic
  ]
}


####################################################################################
# DataFlow Service Account
####################################################################################
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
# Dataproc Service Account
####################################################################################
# Service account for dataproc cluster
resource "google_service_account" "dataproc_service_account" {
  project      = var.project_id
  account_id   = "dataproc-service-account"
  display_name = "Service Account for Dataproc Environment"
}


# Grant editor (too high) to service account
resource "google_project_iam_member" "dataproc_service_account_editor_role" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_service_account.dataproc_service_account
  ]
}


####################################################################################
# Dataplex: https://cloud.google.com/dataplex/docs/terraform
####################################################################################
/*
resource "google_dataplex_entry_group" "entry_group_customer_02" {
  project = var.project_id
  entry_group_id = "entry-group-customer-02"
  location = "global"

  labels = { "tag": "test-tf" }
  display_name = "Customer 02 (entry group)"
  description = "Customer 02 entry group used for customer data"
}


resource "google_dataplex_entry_group" "entry_group_customer_01" {
  project = var.project_id
  entry_group_id = "entry-group-customer-01"
  location = "us"

  labels = { "tag": "test-tf" }
  display_name = "Customer 01 (entry group)"
  description = "Customer 01 entry group used for customer data"
}


resource "google_dataplex_aspect_type" "aspect_type_pii_01" {
  project = var.project_id  
  aspect_type_id = "aspect-type-pii-01"
  location = "us"

  labels = { "tag": "test-tf" }
  display_name = "PII 01 (aspect type)"
  description = "PII data aspect type"
  metadata_template = <<EOF
{
  "name": "tf-test-template",
  "type": "record",
  "recordFields": [
    {
      "name": "type",
      "type": "enum",
      "annotations": {
        "displayName": "Type",
        "description": "Specifies the type of view represented by the entry."
      },
      "index": 1,
      "constraints": {
        "required": true
      },
      "enumValues": [
        {
          "name": "VIEW",
          "index": 1
        }
      ]
    }
  ]
}
EOF
}


resource "google_dataplex_entry_type" "entry_type_customer_01" {
  project = var.project_id
  entry_type_id = "entry-type-customer-01"
  location = "us"

  labels = { "tag": "test-tf" }
  display_name = "Customer 01 (entry type)"
  description = "Customer 01 entry type"

  type_aliases = ["TABLE", "DATABASE"]
  platform = "GCS"
  system = "BigQuery"

  required_aspects {
    type = google_dataplex_aspect_type.aspect_type_pii_01.name
  }

  depends_on = [google_dataplex_aspect_type.aspect_type_pii_01]
}
*/

# entry_group (no children?)
# aspect_type (no children, not avilable)
# entry_type (pii aspect type child)
# entry (using curl below)

/*
# List the Entry Types
curl \
  'https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryTypes' \
  --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  --header 'Accept: application/json' \
  --compressed

# List the Entry Groups
curl \
  'https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups' \
  --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  --header 'Accept: application/json' \
  --compressed

# List the Aspect Types
curl \
  'https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/aspectTypes' \
  --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  --header 'Accept: application/json' \
  --compressed


# Create a 'custom' Entry (Custom-Entry) and place in Entry Group (Entry-Group-Customer) and
# assign Entry Type (entry-type-customer-02) which uses Aspect (aspect-type-pii-02)
curl -X POST \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/entry-group-customer-01/entries?entry_id=navjot \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'entry_type': 'projects/governed-data-0t2p4zvntp/locations/us/entryTypes/entry-type-customer-01',
  'aspects': {
    'governed-data-0t2p4zvntp.us.aspect-type-pii-01': {
      'data':{'type': 'VIEW'}
      }
  }
}"


# Set a name?
curl -X POST \
https://dataplex.googleapis.com/v1/projects/governed-data-wbi0cbgkhe/locations/us/entryGroups/entry-group-customer-01/entries?entry_id=adamp \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'name' : 'Paternostro',
  'entry_type': 'projects/governed-data-wbi0cbgkhe/locations/us/entryTypes/entry-type-customer-01',
  'aspects': {
    'governed-data-wbi0cbgkhe.us.aspect-type-pii-01': {
      'data':{'type': 'VIEW'}
      }
  }
}"    


curl -X POST \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/entry-group-customer-01/entries?entry_id=navjot01 \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'display_name' : 'Navjot Singh 01',
  'description' : 'My description',
  'entry_type': 'projects/governed-data-0t2p4zvntp/locations/us/entryTypes/entry-type-customer-01',
  'aspects': {
    'governed-data-0t2p4zvntp.us.aspect-type-pii-01': {
      'data':{'type': 'VIEW'}
      }
  }
}"

# View the entry in the entry group
curl \
  'https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/entry-group-customer/entries' \
  --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  --header 'Accept: application/json' \
  --compressed


# Delete a custom entry (you must create test_entry first)
curl -X DELETE \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/entry-group-customer/entries/test_entry \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--compressed


# Add Aspect Type to an existing BigQuery table
# NOTE: You can put this in the data JSON: 'entry_type': 'projects/governed-data-0t2p4zvntp/locations/us/entryTypes/entry-type-customer-01'
#       This will make this aspect Aspect Required and the system Aspects as optional (this might be a bug)
curl -X PATCH \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/governed-data-0t2p4zvntp/datasets/governed_data/tables/campaign?update_mask=aspects \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'entry_type': 'projects/governed-data-0t2p4zvntp/locations/us/entryTypes/entry-type-customer-01',
  'aspects': {
    'governed-data-0t2p4zvntp.us.aspect-type-pii-01': {
      'data':{'type': 'VIEW'}
      }
  }
}"


# Update metadata (built in fields) on a BigQuery table
curl -X PATCH \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/governed-data-0t2p4zvntp/datasets/governed_data/tables/campaign?update_mask=aspects \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'aspects': {
    'dataplex-types.global.overview': {
      'data': { 
        'content': 'Hi This is a test'
      }
    }, 
    'dataplex-types.global.contacts': {
      'data': {
        'identities': [
          {'role':'Tech Lead','name':'Adam Paternostro'},
          {'role':'SME','name':'Sam Iyer'}
        ]
      }
    }
  }
}
"

# Add Aspect Type to an existing BigQuery table
curl -X PATCH \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/governed-data-0t2p4zvntp/datasets/governed_data/tables/campaign?update_mask=aspects \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'aspects': {
    'governed-data-0t2p4zvntp.us.aspect-type-pii-01': {
      'data':{'type': 'VIEW'}
      }
  }
}"


# Add Aspect Type to an existing BigQuery column
# To add a global aspect use this: 'dataplex-types.$GLOBAL_LOCATION.generic@Schema.column':
curl -X PATCH \
https://dataplex.googleapis.com/v1/projects/governed-data-0t2p4zvntp/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/governed-data-0t2p4zvntp/datasets/governed_data/tables/campaign?update_mask=aspects \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
--data \
"{
  'aspects': {
    'governed-data-0t2p4zvntp.us.aspect-type-pii-01@Schema.menu_id': {
      'data':{'type': 'VIEW'}
      }
  }
}"


*/

/*
resource "null_resource" "dataplex_custom_entry_01" {
  triggers = {
    project_id               = var.project_id
    dataplex_region          = "us"
    entry_group_id           = google_dataplex_entry_group.entry_group_customer_01.entry_group_id
    entry_type_id            = google_dataplex_entry_type.entry_type_customer_01.entry_type_id
    aspect_id                = google_dataplex_aspect_type.aspect_type_pii_01.aspect_type_id
    entry_id                 = "custom-entry-01"
    local_curl_impersonation = var.local_curl_impersonation
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOF
      curl -X POST \
      https://dataplex.googleapis.com/v1/projects/${self.triggers.project_id}/locations/${self.triggers.dataplex_region}/entryGroups/${self.triggers.entry_group_id}/entries?entry_id=${self.triggers.entry_id} \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${self.triggers.local_curl_impersonation})" \
      --header "Content-Type: application/json" \
      --compressed \
      --data \
      "{
        'entry_type': 'projects/${self.triggers.project_id}/locations/${self.triggers.dataplex_region}/entryTypes/${self.triggers.entry_type_id}',
        'aspects': {
          '${self.triggers.project_id}.${self.triggers.dataplex_region}.${self.triggers.aspect_id}': {
            'data':{'type': 'VIEW'}
            }
        }
      }"
    EOF
    }

  # Bash variable do not use currly brackets to avoid double dollars signs for Terraform
  provisioner "local-exec" {
    when = destroy
    command = <<EOF
      curl -X DELETE \
      https://dataplex.googleapis.com/v1/projects/${self.triggers.project_id}/locations/${self.triggers.dataplex_region}/entryGroups/${self.triggers.entry_group_id}/entries/${self.triggers.entry_id} \
      --header "Authorization: Bearer $(gcloud auth print-access-token ${self.triggers.local_curl_impersonation})" \
      --header "Content-Type: application/json" \
      --compressed
    EOF
  }

  depends_on = [
    google_dataplex_entry_group.entry_group_customer_01,
    google_dataplex_aspect_type.aspect_type_pii_01,
    google_dataplex_entry_type.entry_type_customer_01
    ]
}
*/


####################################################################################
# Analytics Hub
####################################################################################

resource "google_bigquery_analytics_hub_data_exchange" "analytics_hub_data_exchange" {
  project          = var.project_id
  location         = var.multi_region
  data_exchange_id = "governed_data_data_exchange"
  display_name     = "BigQuery Data Governance Analytics Hub Data Exchange"
  description      = "BigQuery Data Governance Analytics Hub Data Exchange"
  primary_contact  = var.gcp_account_name
}

resource "google_bigquery_analytics_hub_listing" "analytics_hub_listing" {
  project          = var.project_id
  location         = var.multi_region
  data_exchange_id = google_bigquery_analytics_hub_data_exchange.analytics_hub_data_exchange.data_exchange_id
  listing_id       = "governed_data_data_listing"
  display_name     = "BigQuery Governance Data Listing"
  description      = "BigQuery Governance Data Listing"
  primary_contact  = var.gcp_account_name

  bigquery_dataset {
    dataset = google_bigquery_dataset.google_bigquery_dataset_analytics_hub_publisher.id
  }

  restricted_export_config {
    enabled               = true
    restrict_query_result = true
  }
}

####################################################################################
# Bring in Analytics Hub reference
####################################################################################
# https://cloud.google.com/bigquery/docs/reference/analytics-hub/rest/v1/projects.locations.dataExchanges.listings/subscribe
resource "null_resource" "analyticshub_daily_weather_data" {
  provisioner "local-exec" {
    when    = create  
    command = <<EOF
  curl --request POST \
    "https://analyticshub.googleapis.com/v1/projects/${var.project_number}/locations/${var.multi_region}/dataExchanges/governed_data_data_exchange/listings/governed_data_data_listing:subscribe" \
    --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data '{"destinationDataset":{"datasetReference":{"datasetId":"${var.bigquery_analytics_hub_subscriber_dataset}","projectId":"${var.project_id}"},"friendlyName":"${var.bigquery_analytics_hub_subscriber_dataset}","location":"${var.multi_region}","description":"${var.bigquery_analytics_hub_subscriber_dataset}"}}' \
    --compressed
    EOF
  }
  depends_on = [
    google_bigquery_analytics_hub_listing.analytics_hub_listing
  ]
}

####################################################################################
# Copy raw files
####################################################################################
resource "null_resource" "copy_raw_files_customer" {
  provisioner "local-exec" {
    when    = create  
    command = <<EOF
  curl --request POST \
    "https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-bytes%2Fdata-governance%2Fv1%2Fcustomer%2Fcustomer.avro/copyTo/b/${var.governed_data_raw_bucket}/o/customer%2Fcustomer.avro" \
    --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data '' \
    --compressed
    EOF
  }
  depends_on = [
    google_storage_bucket.google_storage_bucket_governed_data_raw_bucket
  ]
}

resource "null_resource" "copy_raw_files_customer_transaction" {
  provisioner "local-exec" {
    when    = create  
    command = <<EOF
  curl --request POST \
    "https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-bytes%2Fdata-governance%2Fv1%2Fcustomer_transaction%2Fcustomer_transaction.parquet/copyTo/b/${var.governed_data_raw_bucket}/o/customer_transaction%2Fcustomer_transaction.parquet" \
    --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data '' \
    --compressed
    EOF
  }
  depends_on = [
    google_storage_bucket.google_storage_bucket_governed_data_raw_bucket
  ]
}

resource "null_resource" "copy_raw_files_product" {
  provisioner "local-exec" {
    when    = create  
    command = <<EOF
  curl --request POST \
    "https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-bytes%2Fdata-governance%2Fv1%2Fproduct%2Fproduct.json/copyTo/b/${var.governed_data_raw_bucket}/o/product%2Fproduct.json" \
    --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data '' \
    --compressed
    EOF
  }
  depends_on = [
    google_storage_bucket.google_storage_bucket_governed_data_raw_bucket
  ]
}

resource "null_resource" "copy_raw_files_product_category" {
  provisioner "local-exec" {
    when    = create  
    command = <<EOF
  curl --request POST \
    "https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-bytes%2Fdata-governance%2Fv1%2Fproduct_category%2Fproduct_category.csv/copyTo/b/${var.governed_data_raw_bucket}/o/product_category%2Fproduct_category.csv" \
    --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data '' \
    --compressed
    EOF
  }
  depends_on = [
    google_storage_bucket.google_storage_bucket_governed_data_raw_bucket
  ]
}


####################################################################################
# Spark
####################################################################################

# Spark connection
resource "google_bigquery_connection" "spark_connection" {
  project       = var.project_id
  connection_id = "spark-connection"
  location      = var.multi_region
  friendly_name = "spark-connection"
  description   = "spark-connection"
  spark {}
}

resource "time_sleep" "spark_connection_time_delay" {
  depends_on      = [google_bigquery_connection.spark_connection]
  create_duration = "30s"
}

resource "google_project_iam_member" "spark_connection_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_bigquery_connection.spark_connection.spark[0].service_account_id}"

  depends_on = [
    time_sleep.spark_connection_time_delay,
  ]
}

resource "google_bigquery_dataset_access" "spark_connection_raw_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.google_bigquery_dataset_governed_data_raw.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_bigquery_connection.spark_connection.spark[0].service_account_id

  depends_on = [
    time_sleep.spark_connection_time_delay,
    google_bigquery_dataset.google_bigquery_dataset_governed_data_raw
  ]
}

resource "google_bigquery_dataset_access" "spark_connection_enriched_dataset" {
  project       = var.project_id
  dataset_id    = google_bigquery_dataset.google_bigquery_dataset_governed_data_enriched.dataset_id
  role          = "roles/bigquery.dataOwner"
  user_by_email = google_bigquery_connection.spark_connection.spark[0].service_account_id

  depends_on = [
    time_sleep.spark_connection_time_delay,
    google_bigquery_dataset.google_bigquery_dataset_governed_data_enriched
  ]
}

# Set bucket Object Admin on Raw 
resource "google_storage_bucket_iam_member" "spark_connection_object_admin_code_bucket" {
  bucket = google_storage_bucket.google_storage_bucket_governed_data_code_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_bigquery_connection.spark_connection.spark[0].service_account_id}"

  depends_on = [
    time_sleep.spark_connection_time_delay,
    google_storage_bucket.google_storage_bucket_governed_data_code_bucket
  ]
}


####################################################################################
# Additional Dataplex Permissions
####################################################################################
# Grant require metadata role
resource "google_project_iam_member" "user_bigquery_metadata" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "user:${var.gcp_account_name}"
}

# Grant dataplex admin
resource "google_project_iam_member" "user_dataplex_admin" {
  project = var.project_id
  role    = "roles/dataplex.admin"
  member  = "user:${var.gcp_account_name}"
  depends_on = [google_project_iam_member.user_bigquery_metadata]
}

# Grant aspect type owner
resource "google_project_iam_member" "user_aspect_type_owner" {
  project = var.project_id
  role    = "roles/dataplex.aspectTypeOwner"
  member  = "user:${var.gcp_account_name}"
  depends_on = [google_project_iam_member.user_dataplex_admin]
}


####################################################################################
# Upload Dataplex Oracle
####################################################################################
resource "google_storage_bucket_object" "metadata_import_golden_demo" {
  name        = "oracle-export-metadata/metadata_import_golden_demo.json"
  content = templatefile("../sample-data/metadata_import_golden_demo.json", 
  { 
    project_id = var.project_id
    governed_data_code_bucket = var.governed_data_code_bucket
  })
  bucket      = var.governed_data_code_bucket
  depends_on = [ google_storage_bucket.google_storage_bucket_governed_data_code_bucket ]
}

resource "google_storage_bucket_object" "oracle-metadata-import-golden-demo" {
  name        = "oracle-exports/oracle-metadata-import-golden-demo.jsonl"
  content = templatefile("../sample-data/oracle-metadata-import-golden-demo.jsonl", 
  { 
    project_id = var.project_id
  })
  bucket      = var.governed_data_code_bucket
  depends_on = [ google_storage_bucket.google_storage_bucket_governed_data_code_bucket ]
}


####################################################################################
# DLP Service account
####################################################################################
#------------------------------------------------------------------------------------------------
# Force the DLP service account to get created (only created on first use)
#------------------------------------------------------------------------------------------------
resource "google_project_service_identity" "service_identity_dlp" {
  project = var.project_id
  service = "dlp.googleapis.com"
}

#resource "time_sleep" "service_identity_dataform_time_delay" {
#  depends_on      = [google_project_service_identity.service_identity_dlp]
#  create_duration = "30s"
#}

####################################################################################
# Outputs
####################################################################################
output "dataflow_service_account" {
  value = google_service_account.dataflow_service_account.email
}

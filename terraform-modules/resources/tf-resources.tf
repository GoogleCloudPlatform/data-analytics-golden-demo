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
      version = "4.15.0"
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

# Hardcoded
variable "bigquery_taxi_dataset" {
  type        = string
  default     = "taxi_dataset"
}
variable "bigquery_thelook_ecommerce_dataset" {
  type        = string
  default     = "thelook_ecommerce"
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
      image_version = "composer-2.0.24-airflow-2.2.5"
      #"composer-2.0.0-airflow-2.1.4"
      #"composer-2.0.7-airflow-2.2.3"

      env_variables = {
        ENV_RAW_BUCKET               = "raw-${var.storage_bucket}",
        ENV_PROCESSED_BUCKET         = "processed-${var.storage_bucket}",
        ENV_REGION                   = var.region,
        ENV_ZONE                     = var.zone,
        ENV_DATAPROC_BUCKET          = "dataproc-${var.storage_bucket}",
        ENV_DATAPROC_SUBNET          = "projects/${var.project_id}/regions/${var.region}/subnetworks/dataproc-subnet",
        ENV_DATAPROC_SERVICE_ACCOUNT = "dataproc-service-account@${var.project_id}.iam.gserviceaccount.com",
        ENV_GCP_ACCOUNT_NAME         = "${var.gcp_account_name}",
        ENV_TAXI_DATASET_ID          = google_bigquery_dataset.taxi_dataset.dataset_id,
        ENV_SPANNER_INSTANCE_ID      = google_spanner_instance.spanner_instance.name,
        ENV_BIGQUERY_REGION          = var.bigquery_region,
        ENV_DATAFLOW_SUBNET          = "regions/${var.region}/subnetworks/dataflow-subnet",
        ENV_DATAFLOW_SERVICE_ACCOUNT = "dataflow-service-account@${var.project_id}.iam.gserviceaccount.com",
        ENV_RANDOM_EXTENSION         = var.random_extension
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
  }

  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext,
    google_project_iam_member.cloudcomposer_account_service_agent,
    google_compute_subnetwork.composer_subnet,
    google_service_account.composer_service_account,
    google_project_iam_member.composer_service_account_worker_role,
    google_project_iam_member.composer_service_account_bq_admin_role,
    google_spanner_database.spanner_weather_database
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

# Temp work bucket for BigSpark
resource "google_storage_bucket" "bigspark_bucket" {
  project                     = var.project_id
  name                        = "bigspark-${var.storage_bucket}"
  location                    = var.bigquery_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# Subnet for dataflow cluster
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
    google_data_catalog_taxonomy.business_critical_taxonomy,
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
    "mode": "NULLABLE"
  },
  {
    "name": "DOLocationID",
    "type": "INTEGER",
    "mode": "NULLABLE"
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
curl "https://bigquerydatatransfer.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/transferConfigs" --header "Authorization: Bearer $(gcloud auth application-default print-access-token)"  --header "Accept: application/json" --compressed
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
# Outputs
####################################################################################

output "output-composer-name" {
  value = google_composer_environment.composer_env.name
}

output "output-composer-region" {
  value = google_composer_environment.composer_env.region
}

output "output-composer-dag-bucket" {
  value = google_composer_environment.composer_env.config.0.dag_gcs_prefix
}

output "output-spanner-instance-id" {
  value = google_spanner_instance.spanner_instance.name
}
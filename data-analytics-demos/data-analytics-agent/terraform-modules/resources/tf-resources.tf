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
# Create the GCP resources
#
# Author: Adam Paternostro
####################################################################################


terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "6.40.0"
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "gcp_account_name" {}
variable "project_id" {}

variable "dataplex_region" {}
variable "multi_region" {}
variable "bigquery_non_multi_region" {}
variable "vertex_ai_region" {}
variable "data_catalog_region" {}
variable "appengine_region" {}
variable "colab_enterprise_region" {}
variable "dataflow_region" {}
variable "kafka_region" {}

variable "random_extension" {}
variable "project_number" {}
variable "deployment_service_account_name" {}
variable "terraform_service_account" {}

variable "bigquery_agentic_beans_raw_dataset" {}
variable "bigquery_agentic_beans_enriched_dataset" {}
variable "bigquery_agentic_beans_curated_dataset" {}
variable "bigquery_agentic_beans_raw_us_dataset" {}
variable "bigquery_agentic_beans_raw_staging_load_dataset" {}
variable "bigquery_data_analytics_agent_metadata_dataset" {}


variable "data_analytics_agent_bucket" {}
variable "data_analytics_agent_code_bucket" {}
variable "dataflow_staging_bucket" {}

variable "bigquery_nyc_taxi_curated_dataset" {}

data "google_client_config" "current" {
}

####################################################################################
# Bucket for all data (BigQuery, Spark, etc...)
# This is your "Data Lake" bucket
# If you are using Dataplex you should create a bucket per data lake zone (bronze, silver, gold, etc.)
####################################################################################
resource "google_storage_bucket" "google_storage_bucket_data_analytics_agent_bucket" {
  project                     = var.project_id
  name                        = var.data_analytics_agent_bucket
  location                    = var.bigquery_non_multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_data_analytics_agent_code_bucket" {
  project                     = var.project_id
  name                        = var.data_analytics_agent_code_bucket
  location                    = var.bigquery_non_multi_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "google_storage_bucket_dataflow_staging" {
  project                     = var.project_id
  name                        = var.dataflow_staging_bucket
  location                    = var.bigquery_non_multi_region
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
  source_ranges = ["10.1.0.0/16","10.2.0.0/16","10.3.0.0/16"]

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
resource "google_bigquery_dataset" "google_bigquery_agentic_beans_raw_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_agentic_beans_raw_dataset
  friendly_name = var.bigquery_agentic_beans_raw_dataset
  description   = "The raw data for agentic beans.  This data has not been processed."
  location      = var.bigquery_non_multi_region
}

resource "google_bigquery_dataset" "google_bigquery_agentic_beans_enriched_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_agentic_beans_enriched_dataset
  friendly_name = var.bigquery_agentic_beans_enriched_dataset
  description   = "The enriched data for agentic beans.  This data has been enriched via transmations and AI."
  location      = var.bigquery_non_multi_region
}

resource "google_bigquery_dataset" "google_bigquery_agentic_beans_curated_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_agentic_beans_curated_dataset
  friendly_name = var.bigquery_agentic_beans_curated_dataset
  description   = "The final curated data for agentic beans.  This dataset should be used for analysis."
  location      = var.bigquery_non_multi_region
}

/*
resource "google_bigquery_dataset" "google_bigquery_agentic_beans_raw_us_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_agentic_beans_raw_us_dataset
  friendly_name = var.bigquery_agentic_beans_raw_us_dataset
  description   = "A dataset used for weather data in the multi-region used for querying BigQuery public data."
  location      = var.multi_region
}
*/

resource "google_bigquery_dataset" "google_bigquery_agentic_beans_raw_staging_load_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_agentic_beans_raw_staging_load_dataset
  friendly_name = var.bigquery_agentic_beans_raw_staging_load_dataset
  description   = "The dataset that contains data loaded directly without any transformations.  The data is then transformed and appended to the raw zone."
  location      = var.bigquery_non_multi_region
}


resource "google_bigquery_dataset" "google_bigquery_data_analytics_agent_metadata_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_data_analytics_agent_metadata_dataset
  friendly_name = var.bigquery_data_analytics_agent_metadata_dataset
  description   = "The dataset that metadata used by the Google Agent Development Kit."
  location      = var.bigquery_non_multi_region
}


resource "google_bigquery_dataset" "google_bigquery_nyc_taxi_curated_dataset" {
  project       = var.project_id
  dataset_id    = var.bigquery_nyc_taxi_curated_dataset
  friendly_name = var.bigquery_nyc_taxi_curated_dataset
  description   = "A dataset used for the curated New York City taxi data."
  location      = var.bigquery_non_multi_region
}

####################################################################################
# Table
####################################################################################
resource "google_bigquery_table" "telemetry_coffee_machine_table" {
  project     = var.project_id
  dataset_id  = google_bigquery_dataset.google_bigquery_agentic_beans_raw_staging_load_dataset.dataset_id
  table_id    = "telemetry_coffee_machine"
  description = "Raw telemetry data from coffee machines.  This data is loaded straight from the coffee trucks and then transformed to the raw dataset."

  clustering = [
    "telemetry_timestamp"
  ]

  schema = jsonencode([
    {
      name        = "telemetry_coffee_machine_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "A unique identifier for each telemetry reading."
    },
    {
      name        = "telemetry_load_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "A unique identifier for the batch load."
    },
    {
      name        = "machine_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The foreign key referencing the 'machine_id' from the 'machine_dim' table."
    },
    {
      name        = "truck_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The foreign key referencing the 'truck_id' from the 'truck' table, indicating which truck this machine belongs to."
    },
    {
      name        = "telemetry_timestamp"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The timestamp when the telemetry reading was recorded by the machine."
    },
    {
      name        = "boiler_temperature_celsius"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The current temperature of the machine's boiler in Celsius."
    },
    {
      name        = "brew_pressure_bar"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The current pressure during brewing in bars."
    },
    {
      name        = "water_flow_rate_ml_per_sec"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The water flow rate during brewing in milliliters per second."
    },
    {
      name        = "grinder_motor_rpm"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The revolutions per minute (RPM) of the coffee grinder's motor."
    },
    {
      name        = "grinder_motor_torque_nm"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The torque applied by the grinder motor in Newton-meters."
    },
    {
      name        = "water_reservoir_level_percent"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The percentage of water remaining in the machine's reservoir."
    },
    {
      name        = "bean_hopper_level_grams"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The quantity of coffee beans remaining in the hopper in grams."
    },
    {
      name        = "total_brew_cycles_counter"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Cumulative count of brew cycles completed by the machine."
    },
    {
      name        = "last_error_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "The most recent error code reported by the machine."
    },
    {
      name        = "last_error_description"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "A description for the most recent error code."
    },
    {
      name        = "power_consumption_watts"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Current power consumption of the machine in Watts."
    },
    {
      name        = "cleaning_cycle_status"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Current status of the cleaning cycle (e.g., 'completed', 'in_progress', 'due')."
    }
  ])

  deletion_protection = false 

  depends_on = [
    google_bigquery_dataset.google_bigquery_agentic_beans_raw_staging_load_dataset
  ]
}


# Load the bad data for the data quality check
resource "null_resource" "load_telemetry_coffee_machine_table" {
#  triggers = {
#    always_run = timestamp()
#  }  
  provisioner "local-exec" {
    when    = create
    command = <<EOF
  curl -X POST \
  "https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/jobs" \
  --header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
  --header "Content-Type: application/json" \
  --data '{ "configuration" : { "query" : { "query" : "LOAD DATA INTO `agentic_beans_raw_staging_load.telemetry_coffee_machine` FROM FILES ( format = \"AVRO\", enable_logical_types = true, uris = [\"gs://data-analytics-golden-demo/data-analytics-agent/v1/Data-Export/load_telemetry_coffee_machine/telemetry_coffee_machine_*.avro\"]);", "useLegacySql" : false } } }'
EOF
  }
  depends_on = [
    google_bigquery_table.telemetry_coffee_machine_table
  ]
}



# Creates the rules for the data quality check
resource "google_dataplex_datascan" "basic_quality_scan" {
  location       = var.dataplex_region
  data_scan_id   = "telemetry-coffee-machine-staging-load-dq"
  display_name   = "telemetry-coffee-machine-staging-load-dq"
  description    = "Data Quality scan on the raw data loaded from the telemetry."
  project        = var.project_id

  data {
    resource = "//bigquery.googleapis.com/projects/${var.project_id}/datasets/${var.bigquery_agentic_beans_raw_staging_load_dataset}/tables/telemetry_coffee_machine" 
  }

  execution_spec {
    trigger {
      on_demand {} # Or use `schedule { cron = "0 0 * * *" }` for daily scans
    }
  }

  data_quality_spec {
    # Add this post_scan_actions block to export results
    post_scan_actions {
      bigquery_export {
        # Specify the full BigQuery table resource name for results export
        results_table = "//bigquery.googleapis.com/projects/${var.project_id}/datasets/${var.bigquery_agentic_beans_raw_staging_load_dataset}/tables/telemetry_coffee_machine_data_quality"
      }
    }

    # Rule for bean_hopper_level_grams
    rules {
      name        = "bean-hopper-level-grams-regex-decimal"
      column      = "bean_hopper_level_grams"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+(\\.\\d+)?$"
      }
    }

    # Rule for boiler_temperature_celsius
    rules {
      name        = "boiler-temperature-celsius-regex-decimal"
      column      = "boiler_temperature_celsius"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+(\\.\\d+)?$"
      }
    }

    # Rule for brew_pressure_bar
    rules {
      name        = "brew-pressure-bar-regex-decimal"
      column      = "brew_pressure_bar"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "\\d+(\\.\\d+)?"
      }
    }

    # Rule for grinder_motor_rpm
    rules {
      name        = "grinder-motor-rpm-regex-whole-number"
      column      = "grinder_motor_rpm"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+$"
      }
    }

    # Rule for grinder_motor_torque_nm
    rules {
      name        = "grinder-motor-torque-nm-regex-decimal"
      column      = "grinder_motor_torque_nm"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+(\\.\\d+)?$"
      }
    }

    # Rule for machine_id
    rules {
      name        = "machine-id-regex-whole-number"
      column      = "machine_id"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+$"
      }
    }

    # Rule for power_consumption_watts
    rules {
      name        = "power-consumption-watts-whole-number"
      column      = "power_consumption_watts"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+$"
      }
    }

    # Rule for telemetry_timestamp
    rules {
      name        = "telemetry-timestamp-rule-valid-date"
      column      = "telemetry_timestamp"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2} UTC$"
      }
    }

    # Rule for total_brew_cycles_counter
    rules {
      name        = "total-brew-cycles-counter-regex-whole-number"
      column      = "total_brew_cycles_counter"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+$"
      }
    }

    # Rule for truck_id
    rules {
      name        = "truck-id-regex-whole-number"
      column      = "truck_id"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+$"
      }
    }

    # Rule for water_flow_rate_ml_per_sec
    rules {
      name        = "water-flow-rate-ml-per-sec-regex-decimal"
      column      = "water_flow_rate_ml_per_sec"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+(\\.\\d+)?$"
      }
    }

    # Rule for water_reservoir_level_percent
    rules {
      name        = "water-reservoir-level-percent-regex-decimal"
      column      = "water_reservoir_level_percent"
      dimension   = "VALIDITY"
      ignore_null = false
      regex_expectation {
        regex = "^\\d+(\\.\\d{1,2})?$"
      }
    }

  }
  depends_on = [
    google_bigquery_dataset.google_bigquery_agentic_beans_raw_staging_load_dataset,
    google_bigquery_table.telemetry_coffee_machine_table
  ]
}


# Start the data quality scan
resource "time_sleep" "create_basic_quality_scan_time_delapy" {
  depends_on      = [ google_dataplex_datascan.basic_quality_scan]
  create_duration = "30s"
}

resource "null_resource" "start_basic_quality_scan" {
  triggers = {
    always_run = timestamp()
  }  
  provisioner "local-exec" {
    when    = create
    command = <<EOF
echo "Starting scan"
curl -X POST \
https://dataplex.googleapis.com/v1/projects/${var.project_id}/locations/${var.dataplex_region}/dataScans/telemetry-coffee-machine-staging-load-dq:run \
--header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
--header "Content-Type: application/json" \
--data '{}'

echo "Running Patch to update BigQuery UI"
curl -X PATCH \
https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/datasets/${var.bigquery_agentic_beans_raw_staging_load_dataset}/tables/telemetry_coffee_machine \
--header "Authorization: Bearer ${data.google_client_config.current.access_token}" \
--header "Content-Type: application/json" \
--data '{"labels":{ "dataplex-dq-published-project":"${var.project_id}","dataplex-dq-published-location":"${var.dataplex_region}","dataplex-dq-published-scan":"telemetry-coffee-machine-staging-load-dq"}}'

EOF
  }
  depends_on = [
    time_sleep.create_basic_quality_scan_time_delapy,
    google_dataplex_datascan.basic_quality_scan
  ]
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
# BigQuery Roles
####################################################################################

resource "google_project_iam_member" "gcp_roles_bigquery_metadata_viewer" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "user:${var.gcp_account_name}"
}



####################################################################################
# BigQuery - Connections (BigLake, Functions, etc)
####################################################################################
# Vertex AI connection
resource "google_bigquery_connection" "vertex_ai_connection" {
  project       = var.project_id
  connection_id = "vertex-ai"
  location      = var.bigquery_non_multi_region
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
  location      = var.bigquery_non_multi_region
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

####################################################################################
# Colab Enterprise
####################################################################################
# https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/projects.locations.notebookRuntimeTemplates
# NOTE: If you want a "when = destroy" example TF please see: 
#       https://github.com/GoogleCloudPlatform/data-analytics-demos/data-analytics-golden-demo/blob/main/cloud-composer/data/terraform/dataplex/terraform.tf#L147
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
/*
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
*/


####################################################################################
# Pub/Sub (Topic and Subscription)
####################################################################################
resource "google_pubsub_topic" "google_pubsub_topic_bq_continuous_query" {
  project  = var.project_id
  name = "bq-continuous-query"
  message_retention_duration = "86400s"
}

resource "google_pubsub_subscription" "google_pubsub_subscription_bq_continuous_query" {
  project  = var.project_id  
  name  = "bq-continuous-query"
  topic = google_pubsub_topic.google_pubsub_topic_bq_continuous_query.id

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
    google_pubsub_topic.google_pubsub_topic_bq_continuous_query
  ]
}


####################################################################################
# Agent Engine Service Account
####################################################################################
resource "google_service_account" "agent_engine_service_account" {
  project      = var.project_id
  account_id   = "agent-engine-service-account"
  display_name = "Service Account for Agent Engine"
}


# Grant editor (too high) to service account
resource "google_project_iam_member" "agent_engine_service_account_editor_role" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.agent_engine_service_account.email}"

  depends_on = [
    google_service_account.agent_engine_service_account
  ]
}


resource "google_project_iam_member" "agent_engine_service_account_bq_metadata_role" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_service_account.agent_engine_service_account.email}"

  depends_on = [
    google_service_account.agent_engine_service_account,
    google_project_iam_member.agent_engine_service_account_editor_role
  ]
}


resource "google_project_iam_member" "agent_engine_service_account_agent_engine_role" {
  project = var.project_id
  role    = "roles/aiplatform.reasoningEngineServiceAgent"
  member  = "serviceAccount:${google_service_account.agent_engine_service_account.email}"

  depends_on = [
    google_service_account.agent_engine_service_account,
    google_project_iam_member.agent_engine_service_account_editor_role,
    google_project_iam_member.agent_engine_service_account_bq_metadata_role
  ]
}


####################################################################################
# Copy files (menu images)
####################################################################################
/*
original_string_template = '"curl -X POST \\"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F1.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F1.png\\"  --header \\"Authorization: Bearer ${data.google_client_config.current.access_token}\\" --header \\"Content-Length: 0\\""'

generated_commands = []

# Loop from 1 to 99 (inclusive) to replace 1.png with 1.png, 2.png, ..., 99.png
for i in range(1, 100):
    replacement_png = f"{i}.png"
    
    # Replace all occurrences of "1.png" with the new string
    # The original_string_template is designed to already include the outer double quotes
    # and correctly escaped inner double quotes, as required for Terraform HCL.
    modified_string = original_string_template.replace("1.png", replacement_png)
    generated_commands.append(modified_string)

print("locals {")
print("  file_names = [ ")
for j, command_string in enumerate(generated_commands):
    # Add a comma at the end of each line, except for the last one
    comma = "," if j < len(generated_commands) - 1 else ""
    print(f"    {command_string}{comma}")
print("  ]")
print("}")
*/

locals {
  file_names = [ 
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F1.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F1.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F2.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F2.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F3.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F3.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F4.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F4.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F5.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F5.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F6.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F6.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F7.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F7.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F8.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F8.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F9.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F9.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct-categories%2F10.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct-categories%2F10.png\" --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",

    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F1.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F1.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F2.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F2.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F3.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F3.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F4.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F4.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F5.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F5.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F6.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F6.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F7.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F7.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F8.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F8.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F9.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F9.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F10.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F10.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F11.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F11.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F12.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F12.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F13.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F13.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F14.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F14.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F15.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F15.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F16.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F16.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F17.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F17.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F18.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F18.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F19.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F19.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F20.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F20.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F21.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F21.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F22.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F22.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F23.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F23.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F24.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F24.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F25.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F25.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F26.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F26.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F27.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F27.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F28.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F28.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F29.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F29.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F30.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F30.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F31.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F31.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F32.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F32.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F33.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F33.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F34.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F34.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F35.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F35.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F36.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F36.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F37.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F37.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F38.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F38.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F39.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F39.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F40.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F40.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F41.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F41.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F42.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F42.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F43.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F43.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F44.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F44.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F45.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F45.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F46.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F46.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F47.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F47.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F48.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F48.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F49.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F49.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F50.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F50.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F51.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F51.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F52.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F52.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F53.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F53.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F54.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F54.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F55.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F55.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F56.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F56.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F57.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F57.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F58.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F58.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F59.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F59.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F60.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F60.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F61.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F61.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F62.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F62.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F63.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F63.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F64.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F64.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F65.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F65.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F66.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F66.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F67.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F67.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F68.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F68.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F69.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F69.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F70.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F70.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F71.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F71.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F72.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F72.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F73.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F73.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F74.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F74.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F75.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F75.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F76.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F76.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F77.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F77.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F78.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F78.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F79.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F79.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F80.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F80.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F81.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F81.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F82.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F82.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F83.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F83.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F84.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F84.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F85.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F85.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F86.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F86.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F87.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F87.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F88.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F88.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F89.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F89.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F90.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F90.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F91.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F91.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F92.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F92.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F93.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F93.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F94.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F94.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F95.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F95.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F96.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F96.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F97.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F97.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F98.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F98.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\"",
    "curl -X POST \"https://storage.googleapis.com/storage/v1/b/data-analytics-golden-demo/o/data-analytics-agent%2Fv1%2Fimages%2Fproduct%2F99.png/rewriteTo/b/${var.data_analytics_agent_bucket}/o/images%2Fproduct%2F99.png\"  --header \"Authorization: Bearer ${data.google_client_config.current.access_token}\" --header \"Content-Length: 0\""

  ]
}

resource "null_resource" "copy_data_files" {
  count    = length(local.file_names)
  provisioner "local-exec" {
    when    = create
    command = "${local.file_names[count.index]}"
  }
  depends_on = [  google_storage_bucket.google_storage_bucket_data_analytics_agent_bucket ]
}



####################################################################################
# Outputs
####################################################################################
output "agent_engine_service_account" {
  value = google_service_account.agent_engine_service_account.email
}

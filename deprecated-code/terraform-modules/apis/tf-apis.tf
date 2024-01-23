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
# Enables the APIs used by the resources
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
variable "project_id" {}


####################################################################################
# Enable Google APIs that are required
# NOTE: There are lots of time delays so thing proprogate before use.
# TODO: Reduce the time delays to a minimum (right now it works, just has a lot of 30 second delays)
# gcloud services list --enabled (to see what is enabled if you click in the console)
#
# Reference: https://developers.google.com/apis-explorer (to get an API name)
####################################################################################
resource "google_project_service" "enable_api_cloudresourcemanager" {
  project                    = var.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true

  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_cloudresourcemanager_time_delay" {
  depends_on      = [google_project_service.enable_api_cloudresourcemanager]
  create_duration = "30s"
}


# Service Management
resource "google_project_service" "enable_api_servicemanagement" {
  project                    = var.project_id
  service                    = "servicemanagement.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_servicemanagement_time_delay" {
  depends_on      = [google_project_service.enable_api_servicemanagement]
  create_duration = "30s"
}


# Org Policy
resource "google_project_service" "enable_api_orgpolicy" {
  project                    = var.project_id
  service                    = "orgpolicy.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,time_sleep.enable_api_servicemanagement_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_orgpolicy_time_delay" {
  depends_on      = [google_project_service.enable_api_orgpolicy]
  create_duration = "30s"
}


# Compute
resource "google_project_service" "enable_api_compute" {
  project                    = var.project_id
  service                    = "compute.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_compute_time_delay" {
  depends_on      = [google_project_service.enable_api_compute]
  create_duration = "30s"
}


# BigQuery
resource "google_project_service" "enable_api_bigquerystorage" {
  project                    = var.project_id
  service                    = "bigquerystorage.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_bigquerystorage_time_delay" {
  depends_on      = [google_project_service.enable_api_bigquerystorage]
  create_duration = "30s"
}


resource "google_project_service" "enable_api_bigquerydatatransfer" {
  project                    = var.project_id
  service                    = "bigquerydatatransfer.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_bigquerystorage_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_bigquerydatatransfer_time_delay" {
  depends_on      = [google_project_service.enable_api_bigquerydatatransfer]
  create_duration = "30s"
}


resource "google_project_service" "enable_api_bigqueryreservations" {
  project                    = var.project_id
  service                    = "bigqueryreservation.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_bigquerystorage_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_bigqueryreservations_time_delay" {
  depends_on      = [google_project_service.enable_api_bigqueryreservations]
  create_duration = "30s"
}


resource "google_project_service" "enable_api_bigqueryconnection" {
  project                    = var.project_id
  service                    = "bigqueryconnection.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_bigquerystorage_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_bigqueryconnection_time_delay" {
  depends_on      = [google_project_service.enable_api_bigqueryconnection]
  create_duration = "30s"
}


# Composer
resource "google_project_service" "enable_api_composer" {
  project                    = var.project_id
  service                    = "composer.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                                time_sleep.enable_api_servicemanagement_time_delay,
                                time_sleep.enable_api_compute_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_composer_time_delay" {
  depends_on      = [google_project_service.enable_api_composer]
  create_duration = "30s"
}


# Dataproc
resource "google_project_service" "enable_api_dataproc" {
  project                    = var.project_id
  service                    = "dataproc.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_dataproc_time_delay" {
  depends_on      = [google_project_service.enable_api_dataproc]
  create_duration = "30s"
}


# Data Catalog
resource "google_project_service" "enable_api_datacatalog" {
  project                    = var.project_id
  service                    = "datacatalog.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_datacatalog_time_delay" {
  depends_on      = [google_project_service.enable_api_datacatalog]
  create_duration = "30s"
}


# Vertex AI
resource "google_project_service" "enable_api_aiplatform" {
  project                    = var.project_id
  service                    = "aiplatform.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_aiplatform_time_delay" {
  depends_on      = [google_project_service.enable_api_aiplatform]
  create_duration = "30s"
}


resource "google_project_service" "enable_api_notebooks" {
  project                    = var.project_id
  service                    = "notebooks.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_aiplatform_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_notebooks_time_delay" {
  depends_on      = [google_project_service.enable_api_notebooks]
  create_duration = "30s"
}


# Spanner
resource "google_project_service" "enable_api_spanner" {
  project                    = var.project_id
  service                    = "spanner.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_spanner_time_delay" {
  depends_on      = [google_project_service.enable_api_spanner]
  create_duration = "30s"
}


# Dataflow
resource "google_project_service" "enable_api_dataflow" {
  project                    = var.project_id
  service                    = "dataflow.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_dataflow_time_delay" {
  depends_on      = [google_project_service.enable_api_dataflow]
  create_duration = "30s"
}


# Analytics Hub
resource "google_project_service" "enable_api_analyticshub" {
  project                    = var.project_id
  service                    = "analyticshub.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_bigquerystorage_time_delay,
                                time_sleep.enable_api_bigquerydatatransfer_time_delay,
                                time_sleep.enable_api_bigqueryconnection_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_analyticshub_time_delay" {
  depends_on      = [google_project_service.enable_api_analyticshub]
  create_duration = "5s"
}


# Cloud KMS
resource "google_project_service" "enable_api_cloudkms" {
  project                    = var.project_id
  service                    = "cloudkms.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_cloudkms_time_delay" {
  depends_on      = [google_project_service.enable_api_cloudkms]
  create_duration = "5s"
}


# Dataproc metastore (required for Dataplex, even though we do not create a metastore)
resource "google_project_service" "enable_api_metastore" {
  project                    = var.project_id
  service                    = "metastore.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay,
                               time_sleep.enable_api_datacatalog_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_metastore_time_delay" {
  depends_on      = [google_project_service.enable_api_metastore]
  create_duration = "5s"
}


# Dataplex
resource "google_project_service" "enable_api_dataplex" {
  project                    = var.project_id
  service                    = "dataplex.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay,
                               time_sleep.enable_api_datacatalog_time_delay,
                               time_sleep.enable_api_metastore_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_dataplex_time_delay" {
  depends_on      = [google_project_service.enable_api_dataplex]
  create_duration = "5s"
}


# BigQuery Data Masking
resource "google_project_service" "enable_api_bigquerydatapolicy" {
  project                    = var.project_id
  service                    = "bigquerydatapolicy.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  depends_on                 = [time_sleep.enable_api_cloudresourcemanager_time_delay,
                               time_sleep.enable_api_servicemanagement_time_delay,
                               time_sleep.enable_api_compute_time_delay,
                               time_sleep.enable_api_datacatalog_time_delay]
  timeouts {
    create = "15m"
  }
}

resource "time_sleep" "enable_api_bigquerydatapolicy_time_delay" {
  depends_on      = [google_project_service.enable_api_bigquerydatapolicy]
  create_duration = "5s"
}


#-----------------------------------------------------------------------------------
# Overall Time Deplay for API Enable Commands (You must update this if you add a new API above)
# https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep
# The APIs take some time to proprogate through the cloud
#-----------------------------------------------------------------------------------
resource "time_sleep" "time_sleep_enable_api" {
  create_duration = "90s"

  depends_on = [
                time_sleep.enable_api_cloudresourcemanager_time_delay, 
                time_sleep.enable_api_servicemanagement_time_delay,
                time_sleep.enable_api_orgpolicy_time_delay,
                time_sleep.enable_api_compute_time_delay,
                time_sleep.enable_api_bigquerystorage_time_delay,
                time_sleep.enable_api_bigquerydatatransfer_time_delay,
                time_sleep.enable_api_bigqueryreservations_time_delay,
                time_sleep.enable_api_bigqueryconnection_time_delay,
                time_sleep.enable_api_composer_time_delay,
                time_sleep.enable_api_dataproc_time_delay,
                time_sleep.enable_api_datacatalog_time_delay,
                time_sleep.enable_api_aiplatform_time_delay,
                time_sleep.enable_api_notebooks_time_delay,
                time_sleep.enable_api_spanner_time_delay,
                time_sleep.enable_api_dataflow_time_delay,
                time_sleep.enable_api_cloudkms_time_delay,
  ]
}

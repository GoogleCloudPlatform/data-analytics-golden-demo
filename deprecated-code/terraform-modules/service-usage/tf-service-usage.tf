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
# NOTE: This uses teh logged in user to run this
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
resource "google_project_service" "gcp_services_serviceusage" {
  project                    = var.project_id
  service                    = "serviceusage.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = true
  timeouts {
    create = "15m"
  }
}
# Sleep to let this propagate.  Without this enabled then other cannot be enabled.
resource "time_sleep" "enable_api_serviceusage_time_delay" {
  depends_on      = [google_project_service.gcp_services_serviceusage]
  create_duration = "240s"
}

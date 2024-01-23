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
# Create the GCP project
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
variable "org_id" {}
variable "billing_account" {}


####################################################################################
# New Project
####################################################################################
resource "google_project" "project" {
  name            = var.project_id
  project_id      = var.project_id
  billing_account = var.billing_account
  org_id          = var.org_id
  timeouts {
    create = "15m"
  }
}


####################################################################################
# Outputs
####################################################################################
output "output-project-number" {
  value = google_project.project.number
}

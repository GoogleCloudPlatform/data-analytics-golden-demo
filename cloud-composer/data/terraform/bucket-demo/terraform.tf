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
# YouTube: https://youtu.be/2Qu29_hR2Z0

####################################################################################
# Implementing your own Terraform scripts in the demo
# YouTube: https://youtu.be/2Qu29_hR2Z0
####################################################################################

####################################################################################
# Provider with service account impersonation
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

# Provider that uses service account impersonation (best practice - no exported secret keys to local computers)
provider "google" {
  alias                       = "service_principal_impersonation"
  impersonate_service_account = var.impersonate_service_account
  project                     = var.project_id
}


####################################################################################
# Deployment Specific Resources (typically you customize this)
####################################################################################

resource "google_storage_bucket" "bucket-demo" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.bucket_region
  force_destroy               = true
  uniform_bucket_level_access = true
}
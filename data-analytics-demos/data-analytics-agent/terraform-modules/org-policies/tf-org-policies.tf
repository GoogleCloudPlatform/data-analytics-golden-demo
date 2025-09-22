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
# Deploys the Org Policies when running locally or cloud shell
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
variable "project_id" {}


####################################################################################
# Organizational Policies 
####################################################################################
# Needed for Colab Enterprise notebooks
/*
resource "google_org_policy_policy" "org_policy_require_shielded_vm" {
  name     = "projects/${var.project_id}/policies/compute.requireShieldedVm"
  parent   = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}
*/

# To set service accounts (since sometimes they cause a voliation)
/*
resource "google_org_policy_policy" "org_policy_allowed_policy_member_domains" {
  name     = "projects/${var.project_id}/policies/iam.allowedPolicyMemberDomains"
  parent   = "projects/${var.project_id}"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }
}
*/

####################################################################################
# Time Delay for Org Policies
####################################################################################
# https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep
# The org policies take some time to proprogate.  
# If you do not wait the below resource will fail.
/*
resource "time_sleep" "time_sleep_org_policies" {
  create_duration = "90s"

  depends_on = [
    google_org_policy_policy.org_policy_require_shielded_vm,
  ]
}
*/
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
# This uses an older TF API to set Org Policies
# This is required when deploying using Click-to-Deploy since the
# cloud build account is in a different org.
#
# NOTE: google_org_policy_policy does not work with automated bulids, you have to use google_project_organization_policy
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
# Organizational Policies
####################################################################################
# Composer Policy
# This fixes this Error: googleapi: Error 400: You can't create a Composer environment due to Organization Policy constraints in the selected project.
#│ Policy constraints/compute.requireOsLogin must be disabled., failedPrecondition
/*
resource "google_org_policy_policy" "org_policy_require_os_login" {
  name     = "projects/${var.project_number}/policies/compute.requireOsLogin"
  parent   = "projects/${var.project_number}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }

  depends_on = [
    time_sleep.time_sleep_enable_api
  ]
}
*/

/*
(1) Not all instances running in IGM after 38.775874294s. 
Expected 1, running 0, transitioning 1. Current errors: [CONDITION_NOT_MET]: 
Instance 'gk3-REPLACE-REGION-bigquery-de-default-pool-1c3a5888-l77b' creation failed: 
Constraint constraints/compute.vmExternalIpAccess violated for project 381177525636. 
Add instance projects/big-query-demo-08/zones/REPLACE-REGION-c/instances/gk3-REPLACE-REGION-bigquery-de-default-pool-1c3a5888-l77b to the constraint to use external IP with it (2) 
Not all instances running in IGM after 40.768471262s. 
Expected 1, running 0, transitioning 1. Current errors: [CONDITION_NOT_MET]: 
Instance 'gk3-REPLACE-REGION-bigquery-de-default-pool-77d8d73d-q12x' creation failed: 
Constraint constraints/compute.vmExternalIpAccess violated for project 381177525636. 
Add instance projects/big-query-demo-08/zones/REPLACE-REGION-b/instances/gk3-REPLACE-REGION-bigquery-de-default-pool-77d8d73d-q12x to the constraint to use external IP with it.
*/
/*
resource "google_org_policy_policy" "org_policy_vm_external_ip_access" {
  name     = "projects/${var.project_number}/policies/compute.vmExternalIpAccess"
  parent   = "projects/${var.project_number}"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }
  depends_on = [
    time_sleep.time_sleep_enable_api
  ]
}


# Error: Error waiting for creating Dataproc cluster: Error code 9, message: Constraint constraints/compute.requireShieldedVm violated for project projects/big-query-demo-09. Secure Boot is not enabled in the 'shielded_instance_config' field. 
# See https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints for more information.
resource "google_org_policy_policy" "org_policy_require_shielded_vm" {
  name     = "projects/${var.project_number}/policies/compute.requireShieldedVm"
  parent   = "projects/${var.project_number}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }

  depends_on = [
    time_sleep.time_sleep_enable_api
  ]
}
*/


resource "google_project_organization_policy" "org_policy_require_os_login" {
  project     = var.project_id
  constraint = "compute.requireOsLogin"
  boolean_policy {
    enforced = false
  }
}


resource "google_project_organization_policy" "org_policy_vm_external_ip_access" {
  project     = var.project_id
  constraint = "compute.vmExternalIpAccess"
  list_policy {
    allow {
      all = true
    }
  }
}


resource "google_project_organization_policy" "org_policy_require_shielded_vm" {
  project     = var.project_id
  constraint = "compute.requireShieldedVm"
  boolean_policy {
    enforced = false
  }
}


####################################################################################
# Time Delay for Org Policies
####################################################################################
# https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep
# The org policies take some time to proprogate.  
# If you do not wait the below resource will fail.
resource "time_sleep" "time_sleep_org_policies" {
  create_duration = "90s"

  depends_on = [
    google_project_organization_policy.org_policy_require_os_login,
    google_project_organization_policy.org_policy_vm_external_ip_access,
    google_project_organization_policy.org_policy_require_shielded_vm
  ]
}
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
# Deploys the Org Policies when running locally or cloud shell
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
#
# This file is empty on purpose.  We will run the Terraform apply command a second time with this file.
# By running terraform apply with this empty file it will "destroy" the org policies.
# This will set them back to "Inherit from Parent".
#


# Composer Policy and Dataproc Serverless { this needs to remain until the Dataproc team changes their code }
# This fixes this Error: googleapi: Error 400: You can't create a Composer environment due to Organization Policy constraints in the selected project.
# Policy constraints/compute.requireOsLogin must be disabled., failedPrecondition
resource "google_org_policy_policy" "org_policy_require_os_login" {
  name     = "projects/${var.project_id}/policies/compute.requireOsLogin"
  parent   = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}


# (1) Not all instances running in IGM after 38.775874294s. 
# Expected 1, running 0, transitioning 1. Current errors: [CONDITION_NOT_MET]: 
# Instance 'gk3-REPLACE-REGION-bigquery-de-default-pool-1c3a5888-l77b' creation failed: 
# Constraint constraints/compute.vmExternalIpAccess violated for project 381177525636. 
# Add instance projects/big-query-demo-08/zones/REPLACE-REGION-c/instances/gk3-REPLACE-REGION-bigquery-de-default-pool-1c3a5888-l77b to the constraint to use external IP with it (2) 
# Not all instances running in IGM after 40.768471262s. 
# Expected 1, running 0, transitioning 1. Current errors: [CONDITION_NOT_MET]: 
# Instance 'gk3-REPLACE-REGION-bigquery-de-default-pool-77d8d73d-q12x' creation failed: 
# Constraint constraints/compute.vmExternalIpAccess violated for project 381177525636. 
# Add instance projects/big-query-demo-08/zones/REPLACE-REGION-b/instances/gk3-REPLACE-REGION-bigquery-de-default-pool-77d8d73d-q12x to the constraint to use external IP with it.
# resource "google_org_policy_policy" "org_policy_vm_external_ip_access" {
#   name     = "projects/${var.project_id}/policies/compute.vmExternalIpAccess"
#   parent   = "projects/${var.project_id}"
# 
#   spec {
#     rules {
#       allow_all = "TRUE"
#     }
#   }
# }


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

# To deploy the cloud function
/*
resource "google_org_policy_policy" "org_policy_allowed_ingress_settings" {
  name     = "projects/${var.project_id}/policies/cloudfunctions.allowedIngressSettings"
  parent   = "projects/${var.project_id}"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }
}


resource "google_org_policy_policy" "org_policy_allowed_ingress" {
  name     = "projects/${var.project_id}/policies/run.allowedIngress"
  parent   = "projects/${var.project_id}"

  spec {
    rules {
      allow_all = "TRUE"
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

/*
# For Datastream to create the peer network
resource "google_org_policy_policy" "org_policy_allowed_vpc_peering" {
  name     = "projects/${var.project_id}/policies/compute.restrictVpcPeering"
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
    google_org_policy_policy.org_policy_require_os_login,
    google_org_policy_policy.org_policy_require_shielded_vm,
    google_org_policy_policy.org_policy_allowed_ingress_settings,
    google_org_policy_policy.org_policy_allowed_policy_member_domains
  ]
}
*/
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
# Create the service principal and sets permissions for impersonation
# The service account is currently "not used" since you cannot conditionally set a TF provider with impersonation
# It does work when you run Terraform as as user, but not as a service account (which impersonates another service account)
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
variable "impersonation_account" {} //  "user:${var.gcp_account_name}" or "serviceAccount:${var.deployment_service_account_name}"
variable "gcp_account_name" {}
variable "environment" {}


####################################################################################
# Grant current user owner access and the impersonation account (which might be the same account)
####################################################################################
# Add owner role to the gcp user
resource "google_project_iam_member" "gcp_account_owner" {
  count  = var.environment == "GITHUB_ENVIRONMENT" && var.org_id != "0" ? 1 : 0
  project  = var.project_id
  role     = "roles/owner"
  member   = "user:${var.gcp_account_name}"
}


resource "google_project_iam_member" "impersonation_account_owner" {
  project  = var.project_id
  role     = "roles/owner"
  member   = "${var.impersonation_account}"

  depends_on = [
    google_project_iam_member.gcp_account_owner
  ]  
}


####################################################################################
# New Service Account - uses to deploy resources
# Customers typically create a service account that manages resources.  
# Having resource "tied" to an employee (or user account) is not ideal.
####################################################################################
resource "google_service_account" "service_account" {
  account_id   = var.project_id
  project      = var.project_id
  display_name = "Terraform Service Account"
}


# Add owner role to the new service account
# Owner role is required since we will be setting other IAM permissions (can we do lower than Owner?)
resource "google_project_iam_member" "service_account_owner" {
  project  = var.project_id
  role     = "roles/owner"
  member   = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_service_account.service_account
  ]
}


resource "google_project_iam_member" "service_account_cloud_function_v2" {
  project  = var.project_id
  role     = "roles/cloudfunctions.admin"
  member   = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_service_account.service_account,
    google_project_iam_member.service_account_owner
  ]
}


# Allow the service account to override organization policies on this project
resource "google_organization_iam_member" "organization" {
  count  = var.environment == "GITHUB_ENVIRONMENT" && var.org_id != "0" ? 1 : 0
  org_id   = var.org_id
  role     = "roles/orgpolicy.policyAdmin"
  member   = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_service_account.service_account
  ]
}


####################################################################################
# Set Impersonation
####################################################################################
# If a user is running this script then add them to the role serviceAccountTokenCreator 
# If a service account is running this script then add them to the role serviceAccountTokenCreator 
# Subsequent Terraform script will now use impersonation to finish the deployment
/*
resource "google_service_account_iam_binding" "service_account_impersonation" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    var.impersonation_account
  ]

  depends_on = [
    google_service_account.service_account
  ]
}
*/
# The above replaces all memebers, this just adds one
resource "google_service_account_iam_member" "service_account_impersonation" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.impersonation_account
  depends_on         = [ google_service_account.service_account ]
}


# This time delay was placed in the Main TF script
# It can take 60+ seconds or so for the permission to actually propragate
#resource "time_sleep" "service_account_impersonation_time_delay" {
#  depends_on      = [google_service_account_iam_member.service_account_impersonation]
#  create_duration = "90s"
#}


####################################################################################
# Outputs
####################################################################################

output "deployment_service_account" {
  value = google_service_account.service_account.email
}

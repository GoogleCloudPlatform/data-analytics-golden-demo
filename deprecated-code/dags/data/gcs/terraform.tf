variable "project_id" {
  type        = string
  description = "The current project"
  validation {
    condition     = length(var.project_id) > 0
    error_message = "The project_id is required."
  }
}

variable "impersonate_service_account" {
  type        = string
  description = "We want to impersonate the Terraform service account"
  default     = "us-west2"
  validation {
    condition     = length(var.impersonate_service_account) > 0
    error_message = "The impersonate_service_account is required."
  }
}

variable "bucket_name" {
  type        = string
  description = "The name of the bucket to create"
  validation {
    condition     = length(var.bucket_name) > 0
    error_message = "The bucket_name is required."
  }
}

variable "bucket_region" {
  type        = string
  description = "The region in which to create the bucket"
  validation {
    condition     = length(var.bucket_region) > 0
    error_message = "The bucket_region is required."
  }
}


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
#  region                      = var.default_region
#  zone                        = var.default_zone
}

resource "google_storage_bucket" "test_bucket" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.bucket_region
  force_destroy               = true
  uniform_bucket_level_access = true
}
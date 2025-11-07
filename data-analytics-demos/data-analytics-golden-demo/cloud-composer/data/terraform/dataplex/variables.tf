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
# Implementing your own Terraform scripts in the demo
# YouTube: https://youtu.be/2Qu29_hR2Z0
####################################################################################

####################################################################################
# Common Variables (typically always required)
####################################################################################
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
  default     = ""
  validation {
    condition     = length(var.impersonate_service_account) > 0
    error_message = "The impersonate_service_account is required."
  }
}


####################################################################################
# Deployment Specific Variables (typically you customize this)
####################################################################################
variable "dataplex_region" {
  type        = string
  description = "The dataplex_region of the dataplex"
  validation {
    condition     = length(var.dataplex_region) > 0
    error_message = "The dataplex_region is required."
  }
}

variable "raw_bucket_name" {
  type        = string
  description = "The raw_bucket_name"
  validation {
    condition     = length(var.raw_bucket_name) > 0
    error_message = "The raw_bucket_name is required."
  }
}

variable "processed_bucket_name" {
  type        = string
  description = "The processed_bucket_name"
  validation {
    condition     = length(var.processed_bucket_name) > 0
    error_message = "The processed_bucket_name is required."
  }
}

variable "taxi_dataset_id" {
  type        = string
  description = "The taxi_dataset_id"
  validation {
    condition     = length(var.taxi_dataset_id) > 0
    error_message = "The taxi_dataset_id is required."
  }
}

variable "thelook_dataset_id" {
  type        = string
  description = "The thelook_dataset_id"
  validation {
    condition     = length(var.thelook_dataset_id) > 0
    error_message = "The thelook_dataset_id is required."
  }
}

variable "random_extension" {
  type        = string
  description = "The random_extension"
  validation {
    condition     = length(var.random_extension) > 0
    error_message = "The random_extension is required."
  }
}

variable "rideshare_raw_bucket" {
  type        = string
  description = "The rideshare_raw_bucket"
  validation {
    condition     = length(var.rideshare_raw_bucket) > 0
    error_message = "The rideshare_raw_bucket is required."
  }
}

variable "rideshare_enriched_bucket" {
  type        = string
  description = "The rideshare_enriched_bucket"
  validation {
    condition     = length(var.rideshare_enriched_bucket) > 0
    error_message = "The rideshare_enriched_bucket is required."
  }
}

variable "rideshare_curated_bucket" {
  type        = string
  description = "The rideshare_curated_bucket"
  validation {
    condition     = length(var.rideshare_curated_bucket) > 0
    error_message = "The rideshare_curated_bucket is required."
  }
}

variable "rideshare_raw_dataset" {
  type        = string
  description = "The rideshare_raw_dataset"
  validation {
    condition     = length(var.rideshare_raw_dataset) > 0
    error_message = "The rideshare_raw_dataset is required."
  }
}

variable "rideshare_enriched_dataset" {
  type        = string
  description = "The rideshare_enriched_dataset"
  validation {
    condition     = length(var.rideshare_enriched_dataset) > 0
    error_message = "The rideshare_enriched_dataset is required."
  }
}

variable "rideshare_curated_dataset" {
  type        = string
  description = "The rideshare_curated_dataset"
  validation {
    condition     = length(var.rideshare_curated_dataset) > 0
    error_message = "The rideshare_curated_dataset is required."
  }
}

variable "rideshare_llm_raw_dataset" {
  type        = string
  description = "The rideshare_raw_dataset"
  validation {
    condition     = length(var.rideshare_llm_raw_dataset) > 0
    error_message = "The rideshare_llm_raw_dataset is required."
  }
}

variable "rideshare_llm_enriched_dataset" {
  type        = string
  description = "The rideshare_llm_enriched_dataset"
  validation {
    condition     = length(var.rideshare_llm_enriched_dataset) > 0
    error_message = "The rideshare_llm_enriched_dataset is required."
  }
}

variable "rideshare_llm_curated_dataset" {
  type        = string
  description = "The rideshare_llm_curated_dataset"
  validation {
    condition     = length(var.rideshare_llm_curated_dataset) > 0
    error_message = "The rideshare_llm_curated_dataset is required."
  }
}

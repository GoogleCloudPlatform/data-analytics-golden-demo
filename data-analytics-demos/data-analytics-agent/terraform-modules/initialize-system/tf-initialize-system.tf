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
variable "bigquery_agentic_beans_raw_dataset" {}
variable "bigquery_agentic_beans_enriched_dataset" {}
variable "bigquery_agentic_beans_curated_dataset" {}
variable "bigquery_agentic_beans_raw_us_dataset" {}


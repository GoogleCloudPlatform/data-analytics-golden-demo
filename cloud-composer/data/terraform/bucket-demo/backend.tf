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
# Backend State (place in "code" bucket)
# Saving this locally in the airflow data folder kept experiencing issues
####################################################################################
terraform {
 backend "gcs" {
   bucket  = "${code_bucket_name}"
   prefix  = "airflow-terraform-state/bucket-demo"
 }
}
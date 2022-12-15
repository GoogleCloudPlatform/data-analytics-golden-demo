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
# README
#
# This script will delete all the Terraform lock and state files in the 01 and 02 directories
# This will basically reset Terraform and you will need to run a "terraform init" again in each directory
# This is useful for testing.  Typically you will run the 01-deploy.sh script or run the terraform
# commands directly in the 01 or 02 directories.  Then you might want to create a new GCP project.  You 
# will update the terraform.tfvars-TEMPLATE.json file (project name, storage account) and then start fresh.
# It it typically easier to just delete the whole GCP project via the GCP portal or command line.
# (e.g. gcloud projects delete PROJECT_ID_OR_NUMBER)
#
# Author: Adam Paternostro
# Terraform for Google: https://registry.terraform.io/providers/hashicorp/google/latest/docs
####################################################################################

rm -r ./terraform/.terraform
rm ./terraform/.terraform.lock.hcl
rm ./terraform/terraform.tfstate
rm ./terraform/terraform.tfstate.backup
rm ./terraform/tf-output.json
rm ./terraform/iceberg-spark-runtime-3.1_2.12-0.14.0.jar
rm ./terraform/spark-bigquery-with-dependencies_2.12-0.26.0.jar

rm notebooks-with-substitution/*.ipynb
rm notebooks-with-substitution/*.tmp

rm bigspark-with-substitution/*.py
rm bigspark-with-substitution/*.tmp

rm -rf sample-data/rideshare_trips-with-substitution/_delta_log/*
rm -rf sample-data/rideshare_trips-with-substitution/_symlink_format_manifest/*
rm -rf sample-data/rideshare_trips-with-substitution/Rideshare_Vendor_Id=1/*
rm -rf sample-data/rideshare_trips-with-substitution/Rideshare_Vendor_Id=2/*

#rm key-file-*.json
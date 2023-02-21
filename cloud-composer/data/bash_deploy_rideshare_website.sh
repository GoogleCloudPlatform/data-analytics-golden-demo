#!/bin/bash

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

# Deploys the Rideshare Plus App Engine website

# Hardcoded for now (until more regions are activated)
PROJECT_ID="{{ params.project_id }}"


##########################################################################################
# Deploy website
##########################################################################################

# The files are here and the template values have been replaced
cd /home/airflow/gcs/data/rideshare-website

gcloud app deploy ./app.yaml --project="${PROJECT_ID}" --quiet

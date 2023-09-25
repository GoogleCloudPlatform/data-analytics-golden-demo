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

BASE_ADDRESS="notebooks.googleapis.com"

# Hardcoded for now (until more regions are activated)
LOCATION="{{ params.vertex_ai_region }}"
PROJECT_ID="{{ params.project_id }}"
AUTH_TOKEN=$(gcloud auth application-default print-access-token)
RUNTIME_ID="demo-runtime"
OWNER_EMAIL="{{ params.gcp_account_name }}"
DATAPROC_SERVICE_ACCOUNT="{{ params.dataproc_account_name }}"
# The image URL is set to specific version
IMAGE_URL=projects/cloud-notebooks-managed/global/images/beatrix-notebooks-v20221108

# As a specific user using the latest image version
#RUNTIME_BODY='{
#  "access_config": {
#    "access_type": "SINGLE_USER",
#    "runtime_owner": "${OWNER_EMAIL}"
#  }
#}'

# Run as a service account with a specific notebook version
RUNTIME_BODY="{
  'access_config': {
      'access_type': 'SERVICE_ACCOUNT',
          'runtime_owner': '${DATAPROC_SERVICE_ACCOUNT}'
	    },
  'virtual_machine': {
      'virtual_machine_config': {
          'metadata': {'image-url': '${IMAGE_URL}'},
    }  
  }      
}"

curl -X POST https://${BASE_ADDRESS}/v1/projects/$PROJECT_ID/locations/$LOCATION/runtimes?runtime_id=${RUNTIME_ID} -d "${RUNTIME_BODY}" \
	 -H "Content-Type: application/json" \
	 -H "Authorization: Bearer $AUTH_TOKEN" -v

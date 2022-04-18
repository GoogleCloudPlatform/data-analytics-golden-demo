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
#LOCATION="{{ params.region }}"
LOCATION="us-central1"
PROJECT_ID="{{ params.project_id }}"
AUTH_TOKEN=$(gcloud auth application-default print-access-token)
RUNTIME_ID="demo-runtime"
OWNER_EMAIL="{{ params.gcp_account_name }}"
RUNTIME_BODY="{
  'access_config': {
      'access_type': 'SINGLE_USER',
          'runtime_owner': '${OWNER_EMAIL}'
	    },
}"

curl -X POST https://${BASE_ADDRESS}/v1/projects/$PROJECT_ID/locations/$LOCATION/runtimes?runtime_id=${RUNTIME_ID} -d "${RUNTIME_BODY}" \
	 -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $AUTH_TOKEN" -v

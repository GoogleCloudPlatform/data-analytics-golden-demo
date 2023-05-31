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

# TODO: move to Terraform, but cannot find a working example for spanner (they just show cloudsql)
# Terraform: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_connection
# REST API:  https://cloud.google.com/bigquery/docs/reference/bigqueryconnection/rest/v1beta1/projects.locations.connections#Connection
# bq ls --connection --project_id=big-query-demo-09 --location=REPLACE-spanner_region --format json

STR=$(bq ls --connection --project_id={{ params.project_id }} --location={{ params.spanner_region }} --format json)
SUB='bq_spanner_connection'
if [[ "$STR" == *"$SUB"* ]]; then
    bq rm --connection --location={{ params.spanner_region }}  bq_spanner_connection
    sleep 15
fi
bq mk --connection \
    --connection_type='CLOUD_SPANNER' \
    --properties="{\"database\":\"projects/{{ params.project_id }}/instances/{{ params.spanner_instance_id}}/databases/weather\"}" \
    --project_id="{{ params.project_id }}" \
    --location="{{ params.spanner_region }}" \
    bq_spanner_connection
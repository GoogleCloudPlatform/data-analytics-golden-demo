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

# Author:  Adam Paternostro
# Summary: Runs the procedure to create the Object Table.  This table is created first
#          in a pipeline in order to provide time for it to automatically refresh data
#          from the GCS bucket it is monitoring

# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import airflow
from airflow.utils import trigger_rule
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': None,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
    'dagrun_timeout' : timedelta(minutes=60),
}

project_id            = os.environ['ENV_PROJECT_ID'] 
bigquery_region       = os.environ['ENV_BIGQUERY_REGION'] 

rideshare_lakehouse_raw_sp_create_biglake_object_table="CALL `{}.rideshare_lakehouse_raw.sp_create_biglake_object_table`();".format(project_id)

with airflow.DAG('sample-rideshare-hydrate-object-table',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:
 
    rideshare_lakehouse_raw_sp_create_biglake_object_table = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_raw_sp_create_biglake_object_table",
        location=bigquery_region,
        configuration={
            "query": {
                "query": rideshare_lakehouse_raw_sp_create_biglake_object_table,
                "useLegacySql": False,
            }
        })  
 
    rideshare_lakehouse_raw_sp_create_biglake_object_table

# [END dag]

####################################################################################
# Copyright 2023 Google LLC
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
# Summary: Runs all the stored procedures necessary to hydrate the raw, enriched and curated zone of 
#          the Rideshare Analytics Lakehouse

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
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.operators import bash_operator

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

project_id                         = os.environ['ENV_PROJECT_ID'] 
bigquery_region                    = os.environ['ENV_BIGQUERY_REGION'] 
env_rideshare_llm_curated_dataset  = os.environ['ENV_RIDESHARE_LLM_CURATED_DATASET'] 
env_rideshare_lakehouse_raw_bucket = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_BUCKET'] 

sp_reset_demo="CALL `{}.{}.sp_reset_demo`();".format(project_id,env_rideshare_llm_curated_dataset)
gsutil_copy_data="gsutil -m -q cp -r gs://data-analytics-golden-demo/rideshare-lakehouse-raw-bucket/rideshare_llm_export/v1/* gs://{}/rideshare_llm_export/".format(env_rideshare_lakehouse_raw_bucket)
gsutil_copy_audios="gsutil -m -q cp -r gs://data-analytics-golden-demo/rideshare-lakehouse-raw-bucket/rideshare_audios/v1/*.mp3 gs://{}/rideshare_audios/".format(env_rideshare_lakehouse_raw_bucket)

with airflow.DAG('sample-rideshare-llm-hydrate-data',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Copy data
    copy_rideshare_llm_data = bash_operator.BashOperator(
        task_id="copy_rideshare_llm_data",
        bash_command=gsutil_copy_data,
    )
    # Copy audios
    copy_rideshare_audios = bash_operator.BashOperator(
        task_id="copy_rideshare_audios",
        bash_command=gsutil_copy_audios,
    )

    # Initialize Raw, Enriched and Curated Zones
    sp_initialize_all_data = BigQueryInsertJobOperator(
        task_id="sp_initialize_all_data",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_reset_demo,
                "useLegacySql": False,
            }
        })
  
    copy_rideshare_llm_data >> copy_rideshare_audios >> sp_initialize_all_data


# [END dag]
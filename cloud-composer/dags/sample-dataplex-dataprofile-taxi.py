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
# Summary: Cretes a Managed notebook within your project
#          Currently, there are no gcloud commands for this; therefore, the REST API is used.


# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import airflow
from airflow.operators import bash_operator
from airflow.utils import trigger_rule
from airflow.operators.python_operator import PythonOperator
import google.auth
import google.auth.transport.requests
from airflow.contrib.operators import bigquery_operator
from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
import json

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

dataplex_region                      = os.environ['ENV_DATAPLEX_REGION'] 
project_id                           = os.environ['ENV_PROJECT_ID'] 
taxi_dataset                         = os.environ['ENV_TAXI_DATASET_ID'] 
thelook_dataset                      = os.environ['ENV_THELOOK_DATASET_ID']
rideshare_lakehouse_raw_dataset      = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_DATASET'] 
rideshare_lakehouse_enriched_dataset = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_DATASET'] 
rideshare_lakehouse_curated_dataset  = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET'] 
rideshare_llm_raw_dataset            = os.environ['ENV_RIDESHARE_LLM_RAW_DATASET'] 
rideshare_llm_enriched_dataset       = os.environ['ENV_RIDESHARE_LLM_ENRICHED_DATASET'] 
rideshare_llm_curated_dataset        = os.environ['ENV_RIDESHARE_LLM_CURATED_DATASET'] 

params_list = { 
    "project_id" : project_id,
    "dataplex_region": dataplex_region,
    "taxi_dataset": taxi_dataset,
    "thelook_dataset" : thelook_dataset,
    "rideshare_lakehouse_raw_dataset" : rideshare_lakehouse_raw_dataset,
    "rideshare_lakehouse_enriched_dataset" : rideshare_lakehouse_enriched_dataset,
    "rideshare_lakehouse_curated_dataset" : rideshare_lakehouse_curated_dataset,
    "rideshare_llm_raw_dataset" : rideshare_llm_raw_dataset,
    "rideshare_llm_enriched_dataset" : rideshare_llm_enriched_dataset,
    "rideshare_llm_curated_dataset" : rideshare_llm_curated_dataset,
    }


with airflow.DAG('sample-dataplex-dataprofile-taxi',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Setup a BigQuery federated query connection so we can query BQ and Spanner using a single SQL command
    dataplex_data_profile = bash_operator.BashOperator(
          task_id='bash_dataplex_dataprofile_taxi',
          bash_command='bash_dataplex_dataprofile_taxi.sh',
          params=params_list,
          dag=dag
      )


    # DAG Graph
    dataplex_data_profile

# [END dag]
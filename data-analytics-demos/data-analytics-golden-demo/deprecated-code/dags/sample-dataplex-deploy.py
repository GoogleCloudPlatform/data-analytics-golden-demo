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
# Summary: 
# Setup DataPlex in this project
# Create a Data Lake for Taxi data and for eCommerce data
# Create the zones (raw and curated) for each lake
# Add the assetes to each zone (buckets, BigQuery datasets)


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

project_id                = os.environ['ENV_PROJECT_ID'] 
raw_bucket_name           = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name     = os.environ['ENV_PROCESSED_BUCKET'] 
dataplex_region           = os.environ['ENV_DATAPLEX_REGION'] 
taxi_dataset_id           = os.environ['ENV_TAXI_DATASET_ID']
thelook_dataset_id        = os.environ['ENV_THELOOK_DATASET_ID']
random_extension          = os.environ['ENV_RANDOM_EXTENSION']
rideshare_raw_bucket      = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_BUCKET']
rideshare_enriched_bucket = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_BUCKET']
rideshare_curated_bucket  = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_BUCKET']

params_list = { 
    "project_id" : project_id,
    "dataplex_region": dataplex_region,
    "raw_bucket": raw_bucket_name,
    "processed_bucket": processed_bucket_name,
    "taxi_dataset": taxi_dataset_id,
    "thelook_dataset": thelook_dataset_id,
    "random_extension": random_extension,
    "rideshare_raw_bucket": rideshare_raw_bucket,
    "rideshare_enriched_bucket": rideshare_enriched_bucket,
    "rideshare_curated_bucket": rideshare_curated_bucket,
    }


with airflow.DAG('sample-dataplex-deploy',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Setup DataPlex in this project
    # Create a Data Lake for Taxi data and for eCommerce data
    # Create the zones (raw and curated) for each lake
    # Add the assetes to each zone (buckets, BigQuery datasets)
    deploy_dataplex = bash_operator.BashOperator(
          task_id='deploy_dataplex',
          bash_command='bash_deploy_dataplex.sh',
          params=params_list,
          dag=dag
      )


    # DAG Graph
    deploy_dataplex

# [END dag]
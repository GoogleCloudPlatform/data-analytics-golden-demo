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
# Summary: Runs a data quality check against BigQuery


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
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateEmptyDatasetOperator
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

project_id                      = os.environ['ENV_PROJECT_ID'] 
taxi_dataset_id                 = os.environ['ENV_TAXI_DATASET_ID']
processed_bucket_name           = os.environ['ENV_PROCESSED_BUCKET'] 
yaml_path                       = "gs://" + processed_bucket_name + "/dataplex/dataplex_data_quality_taxi.yaml"
bigquery_region                 = os.environ['ENV_BIGQUERY_REGION']
taxi_dataset_id                 = os.environ['ENV_TAXI_DATASET_ID']
thelook_dataset_id              = os.environ['ENV_THELOOK_DATASET_ID']
vpc_subnet_name                 = os.environ['ENV_DATAPROC_SERVERLESS_SUBNET_NAME']
dataplex_region                 = os.environ['ENV_DATAPLEX_REGION']
service_account_to_run_dataplex = "dataproc-service-account@" + project_id + ".iam.gserviceaccount.com"
random_extension                = os.environ['ENV_RANDOM_EXTENSION']
taxi_dataplex_lake_name         = "taxi-data-lake-" + random_extension
data_quality_dataset_id         = "dataplex_data_quality"

# NOTE: This is case senstive for some reason
bigquery_region = bigquery_region.upper()

params_list = { 
    "project_id" : project_id,
    "taxi_dataset": taxi_dataset_id,
    "thelook_dataset": thelook_dataset_id,
    "yaml_path": yaml_path,
    "bigquery_region": bigquery_region,
    "thelook_dataset": thelook_dataset_id,
    "taxi_dataplex_lake_name": taxi_dataplex_lake_name,
    "vpc_subnet_name": vpc_subnet_name,
    "dataplex_region": dataplex_region,
    "service_account_to_run_dataplex": service_account_to_run_dataplex,
    "random_extension": random_extension
    }


# Create the dataset to hold the data quality results
# NOTE: This has to be in the same region as the BigQuery dataset we are performing our data quality checks
with airflow.DAG('sample-dataplex-run-data-quality',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Create the dataset for holding dataplex data quality results
    create_data_quality_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="create_dataset", 
        location=bigquery_region,
        project_id=project_id,
        dataset_id=data_quality_dataset_id,
        exists_ok=True
    )

    # Create a data quality task
    dataplex_data_quality = bash_operator.BashOperator(
          task_id='dataplex_data_quality',
          bash_command='bash_deploy_dataplex_data_quality.sh',
          params=params_list,
          dag=dag
      )


    # DAG Graph
    create_data_quality_dataset >> dataplex_data_quality

# [END dag]
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

project_id                      = os.environ['GCP_PROJECT'] 
taxi_dataset_id                 = os.environ['ENV_TAXI_DATASET_ID']
processed_bucket_name           = os.environ['ENV_PROCESSED_BUCKET'] 
yaml_path                       = "gs://" + processed_bucket_name + "/dataplex/dataplex_data_quality_taxi.yaml"
bigquery_region                 = os.environ['ENV_BIGQUERY_REGION']
taxi_dataset_id                 = os.environ['ENV_TAXI_DATASET_ID']
thelook_dataset_id              = "thelook_ecommerce"
vpc_subnet_name                 = "bigspark-subnet"
dataplex_region                 = "us-central1"
service_account_to_run_dataplex = "dataproc-service-account@" + project_id + ".iam.gserviceaccount.com"
random_extension                = os.environ['ENV_RANDOM_EXTENSION']
taxi_dataplex_lake_name         = "taxi-data-lake-" + random_extension

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
sql="""
CREATE SCHEMA IF NOT EXISTS `{project_id}`.dataplex_data_quality
  OPTIONS (
    description = 'Dataplex Data Quality',
    location='{bigquery_region}');
""".format(project_id=project_id,bigquery_region=bigquery_region)


with airflow.DAG('sample-dataplex-run-data-quality',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Create the dataset for holding dataplex data quality results
    create_data_quality_dataset = bigquery_operator.BigQueryOperator(
        task_id='create_data_quality_dataset',
        sql=sql,
        location=bigquery_region,
        use_legacy_sql=False)


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
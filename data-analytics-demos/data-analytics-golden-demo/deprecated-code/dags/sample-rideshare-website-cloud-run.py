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
# Summary: Deploys the Cloud Run website from Source Files


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

project_id                          = os.environ['ENV_PROJECT_ID'] 
cloud_function_region               = os.environ['ENV_CLOUD_FUNCTION_REGION'] 
code_bucket_name                    = os.environ['ENV_CODE_BUCKET'] 
rideshare_lakehouse_curated_dataset = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET'] 
rideshare_llm_curated_dataset       = os.environ['ENV_RIDESHARE_LLM_CURATED_DATASET'] 
rideshare_plus_service_account      = os.environ['ENV_RIDESHARE_PLUS_SERVICE_ACCOUNT'] 

gcloud_make = f"gcloud builds submit " + \
        f"--project=\"{project_id}\" " + \
        f"--pack image=\"{cloud_function_region}-docker.pkg.dev/{project_id}/cloud-run-source-deploy/rideshareplus\" " + \
        f"gs://{code_bucket_name}/cloud-run/rideshare-plus-website/rideshare-plus-website.zip"


gcloud_deploy = f"gcloud run deploy demo-rideshare-plus-website " + \
        f"--project=\"{project_id}\" " + \
        f"--image \"{cloud_function_region}-docker.pkg.dev/{project_id}/cloud-run-source-deploy/rideshareplus\" " + \
        f"--region=\"{cloud_function_region}\" " + \
        f"--cpu=1 " + \
        f"--allow-unauthenticated " + \
        f"--service-account=\"{rideshare_plus_service_account}\" " + \
        f"--set-env-vars \"ENV_PROJECT_ID={project_id}\" " + \
        f"--set-env-vars \"ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET={rideshare_lakehouse_curated_dataset}\" " + \
        f"--set-env-vars \"ENV_CODE_BUCKET={code_bucket_name}\" " + \
        f"--set-env-vars \"ENV_RIDESHARE_LLM_CURATED_DATASET={rideshare_llm_curated_dataset}\""

params_list = { }


with airflow.DAG('sample-rideshare-website-cloud-run',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Build the source code
    gcloud_make = bash_operator.BashOperator(
          task_id='gcloud_make',
          bash_command=gcloud_make,
          params=params_list,
          dag=dag
      )

    # Deploy the website
    gcloud_deploy = bash_operator.BashOperator(
          task_id='gcloud_deploy',
          bash_command=gcloud_deploy,
          params=params_list,
          dag=dag
      )

    # DAG Graph
    gcloud_make >> gcloud_deploy

# [END dag]
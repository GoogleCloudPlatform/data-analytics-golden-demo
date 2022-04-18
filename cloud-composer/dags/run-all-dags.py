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
# Summary: Deploys Public Previiew features that require allowlisting
#          This is not part of Step 3 since items in this DAG will fail to deploy if your
#          project does not have a particular feature enabled.


# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import airflow
#from airflow.operators import bash_operator
#from airflow.contrib.operators import dataproc_operator
from airflow.utils import trigger_rule
#from airflow.contrib.operators import bigquery_operator
#from airflow.operators.python_operator import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': None,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'dagrun_timeout' : timedelta(minutes=60),
}


with airflow.DAG('run-all-dags',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    step_01_taxi_data_download = TriggerDagRunOperator(
        task_id="step_01_taxi_data_download",
        trigger_dag_id="step-01-taxi-data-download",
        wait_for_completion=True
    )        

    step_02_taxi_data_processing = TriggerDagRunOperator(
        task_id="step_02_taxi_data_processing",
        trigger_dag_id="step-02-taxi-data-processing",
        wait_for_completion=True
    )   

    step_03_bigquery_deploy_assets = TriggerDagRunOperator(
        task_id="step_03_bigquery_deploy_assets",
        trigger_dag_id="step-03-bigquery-deploy-assets",
        wait_for_completion=True
    )        

    # DAG Graph
    step_01_taxi_data_download >> step_02_taxi_data_processing >> \
        step_03_bigquery_deploy_assets 

# [END dag]
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
# Summary: Creates a Postgres Cloud SQL instance
#          Creates a database
#          Creates a table with some data
#          Creates a datastream job from Cloud SQL to BigQuery

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
import json
from pathlib import Path
import psycopg2


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

project_id         = os.environ['ENV_PROJECT_ID'] 
root_password      = os.environ['ENV_RANDOM_EXTENSION'] 
cloud_sql_region   = os.environ['ENV_CLOUD_SQL_REGION']
datastream_region  = os.environ['ENV_DATASTREAM_REGION']
cloud_sql_zone     = os.environ['ENV_CLOUD_SQL_ZONE'] 

params_list = { 
    'project_id'        : project_id,
    'root_password'     : root_password, 
    'cloud_sql_region'  : cloud_sql_region, 
    'datastream_region' : datastream_region, 
    'cloud_sql_zone'    : cloud_sql_zone
    }    


with airflow.DAG('sample-datastream-private-ip-destroy',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Create the Postgres Instance and Database
    datastream_private_ip_destroy = bash_operator.BashOperator(
          task_id='datastream_private_ip_destroy',
          bash_command='sample_datastream_private_ip_destroy.sh',
          params=params_list,
          dag=dag
          )

    # DAG Graph
    datastream_private_ip_destroy

# [END dag]
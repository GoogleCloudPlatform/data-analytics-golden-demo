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
# Summary: Deploys the Rideshare Plus website that is hosted by App Engine


# [START dag]
import os
from datetime import datetime, timedelta
import airflow
from airflow.utils import trigger_rule
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

project_id = os.environ['ENV_PROJECT_ID'] 


params_list = { 
    "project_id" : project_id
    }


with airflow.DAG('sample-rideshare-website',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Deploys an App Engine website
    deploy_website = bash_operator.BashOperator(
          task_id='deploy_website',
          bash_command='bash_deploy_rideshare_website.sh',
          params=params_list,
          dag=dag
      )


    # DAG Graph
    deploy_website


# [END dag]
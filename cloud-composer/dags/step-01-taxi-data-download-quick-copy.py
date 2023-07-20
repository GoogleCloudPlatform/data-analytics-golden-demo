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
# Summary: Quickly copies data from a public storage account versus downloading the files

# [START dag]
from datetime import datetime, timedelta
import os
import airflow
from airflow.operators import bash_operator
from airflow.utils import trigger_rule


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


raw_bucket_name       = os.environ['ENV_RAW_BUCKET'] 
gsutil_copy_command   = "gsutil -m cp -r gs://data-analytics-golden-demo/raw-bucket/raw gs://{}/".format(raw_bucket_name)


with airflow.DAG('step-01-taxi-data-download-quick-copy',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    gsutil_copy_command_task = bash_operator.BashOperator(
        task_id="gsutil_copy_command_task",
        bash_command=gsutil_copy_command,
    )

    gsutil_copy_command_task

# [END dag]
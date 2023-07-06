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
# Summary: Install Terraform and executes the Terraform script
#          This same DAG is used for the Destroy DAG. Copy and paste this and just
#          change the ' terraform_destroy= "-destroy" ' line
          

# [START dag]
from datetime import datetime, timedelta
import os
import airflow
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

project_id                     = os.environ['ENV_PROJECT_ID'] 
impersonate_service_account    = "data-analytics-demo-kczbg9ogek@data-analytics-demo-kczbg9ogek.iam.gserviceaccount.com" # os.environ['ENV_TERRAFORM_IMPERSONATION_ACCOUNT'] 
bucket_name                    = "paternostroadam"
bucket_region                  = "us-central1"
airflow_data_path_to_tf_script = "/home/airflow/gcs/data/terraform/gcs"
terraform_destroy              = ""
#terraform_destroy              = "-destroy"

suffix = "deploy"
if terraform_destroy == "-destroy":
    suffix = "destroy"

params_list = { 
    'airflow_data_path_to_tf_script' : airflow_data_path_to_tf_script,
    'project_id'                     : project_id,
    'impersonate_service_account'    : impersonate_service_account, 
    'bucket_name'                    : bucket_name, 
    'bucket_region'                  : bucket_region, 
    'terraform_destroy'              : terraform_destroy
    }


with airflow.DAG('sample-gcs-terraform-' + suffix,
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The Composer Service Account will Impersonate the Terraform service account

    # You need to ensure Terraform is installed and since they can be many worker nodes you want the
    # install to be in the same step versus risking a seperate operator that might run on a different node
    execute_terraform = bash_operator.BashOperator(
          task_id='execute_terraform',
          bash_command='sample_terraform_gcs.sh',
          params=params_list,
          dag=dag
          )

    # DAG Graph
    execute_terraform

# [END dag]
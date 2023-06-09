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
# Summary: Install Terraform and executes the Terrform script
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

airflow_data_path_to_tf_script = "/home/airflow/gcs/data/terraform/dataplex"
#terraform_destroy              = ""
terraform_destroy              = "-destroy"

project_id                  = os.environ['ENV_PROJECT_ID'] 
impersonate_service_account = "data-analytics-demo-kczbg9ogek@data-analytics-demo-kczbg9ogek.iam.gserviceaccount.com" # os.environ['ENV_TERRAFORM_IMPERSONATION_ACCOUNT'] 

dataplex_region             = os.environ['ENV_DATAPLEX_REGION'] 
raw_bucket_name             = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name       = os.environ['ENV_PROCESSED_BUCKET'] 
taxi_dataset_id             = os.environ['ENV_TAXI_DATASET_ID']
thelook_dataset_id          = "thelook_ecommerce"
random_extension            = os.environ['ENV_RANDOM_EXTENSION']
rideshare_raw_bucket        = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_BUCKET']
rideshare_enriched_bucket   = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_BUCKET']
rideshare_curated_bucket    = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_BUCKET']
rideshare_raw_dataset       = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_DATASET']
rideshare_enriched_dataset  = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_DATASET']
rideshare_curated_dataset   = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET']


suffix = "deploy"
if terraform_destroy == "-destroy":
    suffix = "destroy"

params_list = { 
    'airflow_data_path_to_tf_script' : airflow_data_path_to_tf_script,
    'project_id'                     : project_id,
    'impersonate_service_account'    : impersonate_service_account, 
    'dataplex_region'                : dataplex_region, 
    'raw_bucket_name'                : raw_bucket_name, 
    'processed_bucket_name'          : processed_bucket_name, 
    'taxi_dataset_id'                : taxi_dataset_id, 
    'thelook_dataset_id'             : thelook_dataset_id, 
    'random_extension'               : random_extension, 
    'rideshare_raw_bucket'           : rideshare_raw_bucket, 
    'rideshare_enriched_bucket'      : rideshare_enriched_bucket, 
    'rideshare_curated_bucket'       : rideshare_curated_bucket, 
    'rideshare_raw_dataset'          : rideshare_raw_dataset,
    'rideshare_enriched_dataset'     : rideshare_enriched_dataset,
    'rideshare_curated_dataset'      : rideshare_curated_dataset,
    'terraform_destroy'              : terraform_destroy
    }


with airflow.DAG('sample-dataplex-' + suffix,
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The Composer Service Account will Impersonate the Terrform service account

    # You need to ensure Terraform is installed and since they can be many worker nodes you want the
    # install to be in the same step versus risking a seperate operator that might run on a different node
    execute_terraform = bash_operator.BashOperator(
          task_id='execute_terraform',
          bash_command='sample_terraform_dataplex.sh',
          params=params_list,
          dag=dag
          )

    # DAG Graph
    execute_terraform

# [END dag]
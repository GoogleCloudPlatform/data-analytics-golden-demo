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
#          This DAG will perform the Deploy and the Destroy
#          Terraform will deploy this file twice (once named xxx-deploy and xxx-destroy)
#          The destroy will run every 15 minutes and based upon the auto_delete_hours the assets will be deleted

# [START dag]
from datetime import datetime, timedelta
import os
import json
import airflow
from airflow.operators import bash_operator
from airflow.operators.python_operator import PythonOperator


####################################################################################
# Set these values (the DAG name and the auto-delete time)
####################################################################################
airflow_data_path_to_tf_script = "/home/airflow/gcs/data/terraform/dataplex"
dag_prefix_name = "sample-dataplex"
auto_delete_hours = 120 # 5 days # set to zero to never delete
terraform_bash_file = "sample_terraform_dataplex.sh"

# Required for deployment
project_id                  = os.environ['ENV_PROJECT_ID'] 
impersonate_service_account = os.environ['ENV_TERRAFORM_SERVICE_ACCOUNT'] 

# Parameters to Terraform
dataplex_region             = os.environ['ENV_DATAPLEX_REGION'] 
raw_bucket_name             = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name       = os.environ['ENV_PROCESSED_BUCKET'] 
taxi_dataset_id             = os.environ['ENV_TAXI_DATASET_ID']
thelook_dataset_id          = os.environ['ENV_THELOOK_DATASET_ID']
random_extension            = os.environ['ENV_RANDOM_EXTENSION']
rideshare_raw_bucket        = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_BUCKET']
rideshare_enriched_bucket   = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_BUCKET']
rideshare_curated_bucket    = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_BUCKET']
rideshare_raw_dataset       = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_DATASET']
rideshare_enriched_dataset  = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_DATASET']
rideshare_curated_dataset   = os.environ['ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET']

rideshare_llm_raw_dataset       = os.environ['ENV_RIDESHARE_LLM_RAW_DATASET']
rideshare_llm_enriched_dataset  = os.environ['ENV_RIDESHARE_LLM_ENRICHED_DATASET']
rideshare_llm_curated_dataset   = os.environ['ENV_RIDESHARE_LLM_CURATED_DATASET']


####################################################################################
# Set if we are deploy or a destroy script based on the Python file name (suffix)
# Based upon the filename the "terraform destroy" will be invoked
# This means the sample-xxx-deploy and sample-xxx-destroy contain the SAME EXACT code
####################################################################################
dag_display_name = ""
terraform_destroy = ""
is_deploy_or_destroy = ""
terraform_bash_script_deploy = ""
terraform_bash_script_destroy = ""
env_run_bash_deploy=""
print("os.path.basename(__file__):", os.path.basename(__file__))
if "destroy" in os.path.basename(__file__):
    env_run_bash_deploy="false"
    terraform_bash_script_deploy = "echo 'Skiping Deploy'"
    terraform_bash_script_destroy = terraform_bash_file
    is_deploy_or_destroy = "destroy"
    dag_display_name = dag_prefix_name + "-destroy"
    terraform_destroy = "-destroy" # parameter to terraform script
    schedule_interval=timedelta(minutes=15)
else:
    env_run_bash_deploy="true"
    terraform_bash_script_deploy = terraform_bash_file
    terraform_bash_script_destroy = "echo 'Skiping Destroy'"
    is_deploy_or_destroy = "deploy"
    dag_display_name = dag_prefix_name + "-deploy"
    schedule_interval=None


params_list = { 
    'airflow_data_path_to_tf_script' : airflow_data_path_to_tf_script,
    'project_id'                     : project_id,
    'impersonate_service_account'    : impersonate_service_account,
    'terraform_destroy'              : terraform_destroy,
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
    'rideshare_llm_raw_dataset'      : rideshare_llm_raw_dataset,
    'rideshare_llm_enriched_dataset' : rideshare_llm_enriched_dataset,
    'rideshare_llm_curated_dataset'  : rideshare_llm_curated_dataset
    }


####################################################################################
# Common items
####################################################################################
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': None,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'dagrun_timeout' : timedelta(minutes=60),
    }


# Write out a file that will log when we deployed
# This file can then be used for auto-delete
def write_deployment_file(deploy_or_destroy):
    print("BEGIN: write_deployment_file")
    if deploy_or_destroy == "deploy":
        run_datetime = datetime.now()
        data = {
            "deployment_datetime" : run_datetime.strftime("%m/%d/%Y %H:%M:%S"),
        }
        with open('/home/airflow/gcs/data/' + dag_prefix_name + '.json', 'w') as f:
            json.dump(data, f)
        print("data: ", data)
    else:
        print("write_deployment_file is skipped since this DAG is not a deployment DAG.")
    print("END: write_deployment_file")


# Determine if it is tiem to delete the environment if necessary
def delete_environment(deploy_or_destroy):
    print("BEGIN: delete_environment")
    delete_environment = False
    if deploy_or_destroy == "destroy":
        filePath = '/home/airflow/gcs/data/' + dag_prefix_name + '.json'
        if os.path.exists(filePath):
            with open(filePath) as f:
                data = json.load(f)
            
            print("deployment_datetime: ", data['deployment_datetime'])
            deployment_datetime = datetime.strptime(data['deployment_datetime'], "%m/%d/%Y %H:%M:%S")
            difference = deployment_datetime - datetime.now()
            print("difference.total_seconds(): ", abs(difference.total_seconds()))
            # Test for auto_delete_hours hours
            if auto_delete_hours == 0:
                print("No auto delete set auto_delete_hours:",auto_delete_hours)
            else:
                if abs(difference.total_seconds()) > (auto_delete_hours * 60 * 60):
                    print("Deleting Environment >", auto_delete_hours, " hours")
                    delete_environment = True
        else:
            print("Json files does not exist (no environment deployed)")
    else:
        print("delete_environment is skipped since this DAG is not a destroy DAG.")
    
    if delete_environment:       
        return "true"
    else:
        return "false"


# Removes the deployment file so we do not keep re-deleting
def delete_deployment_file(delete_environment):
    print("BEGIN: delete_deployment_file")
    print("delete_environment:",delete_environment)
    if delete_environment == "true":
        print("Deleting file:", '/home/airflow/gcs/data/' + dag_prefix_name + '.json')
        os.remove('/home/airflow/gcs/data/' + dag_prefix_name + '.json')
    print("END: delete_deployment_file")


with airflow.DAG(dag_display_name,
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 catchup=False,
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Either run manually or every 15 minutes (for auto delete)
                 schedule_interval=schedule_interval) as dag:

    # NOTE: The Composer Service Account will Impersonate the Terraform service account

    # This will deploy the Terraform code if this DAG ends with "-deploy"
    execute_terraform_deploy = bash_operator.BashOperator(
        task_id='execute_terraform_deploy',
        bash_command=terraform_bash_file,
        params=params_list,
        execution_timeout=timedelta(minutes=60),
        env={"ENV_RUN_BASH": env_run_bash_deploy},
        append_env=True,
        dag=dag
        )

    # This will write out the deployment time to a file if this DAG ends with "-deploy"
    write_deployment_file = PythonOperator(
        task_id='write_deployment_file',
        python_callable= write_deployment_file,
        op_kwargs = { "deploy_or_destroy" : is_deploy_or_destroy },
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        ) 
    
    # This determine if it is time to delete the deployment if this DAG ends with "-destroy"
    delete_environment = PythonOperator(
        task_id='delete_environment',
        python_callable= delete_environment,
        op_kwargs = { "deploy_or_destroy" : is_deploy_or_destroy },
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        ) 
    
    # This will delete the deployment if this DAG ends with "-destroy" and delete_environment = True (time to delete has passed)
    execute_terraform_destroy = bash_operator.BashOperator(
        task_id='execute_terraform_destroy',
        bash_command=terraform_bash_file,
        params=params_list,
        execution_timeout=timedelta(minutes=60),
        env={"ENV_RUN_BASH": "{{ task_instance.xcom_pull(task_ids='delete_environment') }}"},
        append_env=True,
        dag=dag
        )

    # This will delete the deployment "file" if this DAG ends with "-destroy" and delete_environment = True (time to delete has passed)
    delete_deployment_file = PythonOperator(
        task_id='delete_deployment_file',
        python_callable= delete_deployment_file,
        op_kwargs = { "delete_environment" : "{{ task_instance.xcom_pull(task_ids='delete_environment') }}" },
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        )        
    
    # DAG Graph
    execute_terraform_deploy >> write_deployment_file >> delete_environment >> execute_terraform_destroy >> delete_deployment_file

# [END dag]
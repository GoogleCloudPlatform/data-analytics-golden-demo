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
# Summary: Creates and runs a BigQuery data transfer which can be used to transfer data for Dataset copies or
#          Cloud Storage,Google Ad Manager,Google Ads,Google Merchant Center (beta),Google Play,Search Ads 360 (beta), YouTube Channel reports,, YouTube Content Owner reports,Amazon S3, Teradata,Amazon Redshift

# NOTE:    This creates the destination dataset and the transfer, but you only need to
#          perform thess steps once.  You "should" test for their existance before creating.
#          If you want to run this twice, then you should delete the "{your dataset}__public_copy" 
#          (not your main one) and delete the Data Transfer Service.  You can always run the data
#          transfer service via the cloud console.

# NOTE: You will need to run this command after the first time this DAG is run and fails.
#       The service account is not created until DTS is run?
# gcloud iam service-accounts add-iam-policy-binding \
# composer-service-account@{{ params.project_id }}.iam.gserviceaccount.com \
# --member='serviceAccount:service-{{ params.project_number }}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com' \
# --role='roles/iam.serviceAccountTokenCreator'


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
import json
from airflow.models import TaskInstance
from airflow.operators.python import get_current_context

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

project_id      = os.environ['ENV_PROJECT_ID'] 
bigquery_region = os.environ['ENV_BIGQUERY_REGION'] 

params_list = { 
    "project_id" : project_id,
    "bigquery_region" : bigquery_region,
    }


bq_create_connection= \
"bq mk --connection " + \
    "--location=\"" + bigquery_region + "\" " + \
    "--project_id=\"" + project_id + "\" " + \
    "--connection_type=CLOUD_RESOURCE " + \
    "biglake-connection" + \
    "|| true"

bq_show_connections= \
"bq show --connection " + \
    "--location=\"" + bigquery_region + "\" " + \
    "--project_id=\"" + project_id + "\" " + \
    "--format=json " + \
    "biglake-connection > /home/airflow/gcs/data/bq-connection.json"

# Allow accounts from other domains
change_org_policy= \
"echo \"name: projects/" + project_id + "/policies/iam.allowedPolicyMemberDomains\" > iam_allowedPolicyMemberDomains.yaml; " + \
"echo \"spec:\" >> iam_allowedPolicyMemberDomains.yaml; " + \
"echo \"  rules:\" >> iam_allowedPolicyMemberDomains.yaml; " + \
"echo \"  - allow_all: true\" >> iam_allowedPolicyMemberDomains.yaml; " + \
"cat iam_allowedPolicyMemberDomains.yaml;" + \
"gcloud org-policies --impersonate-service-account \"" + project_id + "@" + project_id + ".iam.gserviceaccount.com" + "\" set-policy iam_allowedPolicyMemberDomains.yaml; "

grant_iam= \
"serviceAccount=$(cat /home/airflow/gcs/data/serviceAccountId.txt); " + \
"echo \"serviceAccount: ${serviceAccount}\" ; " + \
"gcloud projects add-iam-policy-binding \"" + project_id + "\" " + \
    "--member=\"serviceAccount:${serviceAccount}\" " + \
    "--role='roles/storage.objectViewer'"

# Get the connection service principal
def parse_json():
    with open('/home/airflow/gcs/data/bq-connection.json') as f:
        data = json.load(f)
    print(data)
    service_account=data["cloudResource"]["serviceAccountId"]
    with open('/home/airflow/gcs/data/serviceAccountId.txt', 'w') as f:
        f.write(service_account)


with airflow.DAG('step-04-create-biglake-connection',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:


#    bq_create_connection = bash_operator.BashOperator(
#          task_id='bq_create_connection',
#          bash_command='bash_create_biglake_connection.sh',
#          params=params_list,
#          dag=dag
#      )

    bq_create_connection = bash_operator.BashOperator(
        task_id="bq_create_connection",
        bash_command=bq_create_connection,
    )

    bq_show_connections = bash_operator.BashOperator(
        task_id="bq_show_connections",
        bash_command=bq_show_connections,
    )

    parse_connections = PythonOperator(
        task_id='parse_connections',
        python_callable= parse_json,
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        )    
        
    change_org_policy = bash_operator.BashOperator(
        task_id="change_org_policy",
        bash_command=change_org_policy  
    )

    # Wait for policies to take affect
    sleep_2_minutes = bash_operator.BashOperator(
        task_id="sleep_2_minutes",
        bash_command="sleep 120"  
    )

    grant_iam = bash_operator.BashOperator(
        task_id="grant_iam",
        bash_command=grant_iam  
    )
    # DAG Graph
    bq_create_connection >> bq_show_connections >> parse_connections >> change_org_policy >> sleep_2_minutes >> grant_iam
    

# [END dag]
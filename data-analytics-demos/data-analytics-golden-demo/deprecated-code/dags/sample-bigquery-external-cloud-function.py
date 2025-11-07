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
# Summary: Creates a BigQuery connection to call an external Cloud Function
#          Deploys the Cloud Function code (in data directory of Composer)
#          Sets some org policies for deployment
#          Grants the BigQuery connection (service principal) invoker access to the Cloud Function
#
# Run the stored procedure: sp_demo_external_function to do the demo


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

project_id            = os.environ['ENV_PROJECT_ID'] 
bigquery_region       = os.environ['ENV_BIGQUERY_REGION'] 
processed_bucket_name = "gs://" + os.environ['ENV_PROCESSED_BUCKET'] 

params_list = { 
    "project_id" : project_id,
    "bigquery_region" : bigquery_region,
    }


bq_create_connection= \
"bq mk --connection " + \
    "--location=\"" + bigquery_region + "\" " + \
    "--project_id=\"" + project_id + "\" " + \
    "--connection_type=CLOUD_RESOURCE " + \
    "cloud-function" + \
    "|| true"


bq_show_connections= \
"bq show --connection " + \
    "--location=\"" + bigquery_region + "\" " + \
    "--project_id=\"" + project_id + "\" " + \
    "--format=json " + \
    "cloud-function > /home/airflow/gcs/data/bq-connection-cf.json"


# Allow accounts from other domains
change_org_policy_allowedPolicyMemberDomains= \
"echo \"name: projects/" + project_id + "/policies/iam.allowedPolicyMemberDomains\" > iam_allowedPolicyMemberDomains.yaml; " + \
"echo \"spec:\" >> iam_allowedPolicyMemberDomains.yaml; " + \
"echo \"  rules:\" >> iam_allowedPolicyMemberDomains.yaml; " + \
"echo \"  - allow_all: true\" >> iam_allowedPolicyMemberDomains.yaml; " + \
"cat iam_allowedPolicyMemberDomains.yaml;" + \
"gcloud org-policies --impersonate-service-account \"" + project_id + "@" + project_id + ".iam.gserviceaccount.com" + "\" set-policy iam_allowedPolicyMemberDomains.yaml; " 


# BigQuery connection service principal access to call function
grant_iam_function_invoker= \
"serviceAccount=$(cat /home/airflow/gcs/data/serviceAccountId-cf.txt); " + \
"echo \"serviceAccount: ${serviceAccount}\" ; " + \
"gcloud functions add-iam-policy-binding bigquery_external_function " + \
    "--project=\"" + project_id + "\" " + \
    "--region=\"REPLACE-REGION\" " + \
    "--member=\"serviceAccount:${serviceAccount}\" " + \
    "--role='roles/cloudfunctions.invoker'"


#SET: constraints/cloudfunctions.allowedIngressSettings
#TO: ALLOW_ALL
change_org_policy_allowedIngressSettings = \
"echo \"name: projects/" + project_id + "/policies/cloudfunctions.allowedIngressSettings\" > iam_allowedIngressSettings.yaml; " + \
"echo \"spec:\" >> iam_allowedIngressSettings.yaml; " + \
"echo \"  rules:\" >> iam_allowedIngressSettings.yaml; " + \
"echo \"  - allow_all: true\" >> iam_allowedIngressSettings.yaml; " + \
"cat iam_allowedIngressSettings.yaml;" + \
"gcloud org-policies --impersonate-service-account \"" + project_id + "@" + project_id + ".iam.gserviceaccount.com" + "\" set-policy iam_allowedIngressSettings.yaml; " 



# Public calls (No anonymous calls, we will add the service principal)
deploy_cloud_function= \
"cd /home/airflow/gcs/data/bigquery-external-function; " + \
"gcloud functions deploy bigquery_external_function " + \
    "--project=\"" + project_id + "\" " + \
    "--region=\"REPLACE-REGION\" " +  \
    "--runtime=\"python310\" " +  \
    "--ingress-settings=\"all\" " +  \
    "--no-allow-unauthenticated " + \
    "--trigger-http"


# Cloud function access to read bucket
grant_bucket_iam = "gsutil iam ch \"serviceAccount:" + project_id + "@appspot.gserviceaccount.com:objectViewer\" " + processed_bucket_name


# Sample call from project
# NOTE: You must be in the project to call (run from Cloud Shell)
#       The function has an external IP address, but require authenication
curl_command = \
"curl -m 70 -X POST https://REPLACE-REGION-" + project_id + ".cloudfunctions.net/bigquery_external_function " + \
    "-H \"Authorization: bearer $(gcloud auth print-identity-token)\" " + \
    "-H \"Content-Type: application/json\" " + \
    "-d '{  " + \
    "    \"userDefinedContext\": {\"mode\":\"detect_labels_uri\" }, " + \
    "    \"calls\":[ [\"gs://cloud-samples-data/vision/label/setagaya.jpeg\"]] " + \
    "}'"

"""
curl -m 70 -X POST https://REPLACE-REGION-${project}.cloudfunctions.net/bigquery_external_function \
    -H "Authorization: bearer $(gcloud auth print-identity-token)" \
    -H "Content-Type: application/json" \
    -d '{ 
        "userDefinedContext": {"mode":"detect_labels_uri" },
        "calls":[ ["gs://cloud-samples-data/vision/label/setagaya.jpeg"]]
    }'
"""

# Get the connection service principal
def parse_json():
    with open('/home/airflow/gcs/data/bq-connection-cf.json') as f:
        data = json.load(f)
    print(data)
    service_account=data["cloudResource"]["serviceAccountId"]
    with open('/home/airflow/gcs/data/serviceAccountId-cf.txt', 'w') as f:
        f.write(service_account)


with airflow.DAG('sample-bigquery-external-cloud-function',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # For function to deploy with "All" parameter
    change_org_policy_allowedIngressSettings = bash_operator.BashOperator(
        task_id="change_org_policy_allowedIngressSettings",
        bash_command=change_org_policy_allowedIngressSettings,
    )

    # To allow the BQ service connection to be added (sometimes service connections are considered external)
    change_org_policy_allowedPolicyMemberDomains = bash_operator.BashOperator(
        task_id="change_org_policy_allowedPolicyMemberDomains",
        bash_command=change_org_policy_allowedPolicyMemberDomains  
    )
    
    # Deploy the function
    deploy_cloud_function = bash_operator.BashOperator(
        task_id="deploy_cloud_function",
        bash_command=deploy_cloud_function  
    )

    # Wait for policies to take affect
    sleep_2_minutes = bash_operator.BashOperator(
        task_id="sleep_2_minutes",
        bash_command="sleep 120"  
    )

    # Create the connection (to the function)
    bq_create_connection = bash_operator.BashOperator(
        task_id="bq_create_connection",
        bash_command=bq_create_connection,
    )

    # Extract the service principal name
    bq_show_connections = bash_operator.BashOperator(
        task_id="bq_show_connections",
        bash_command=bq_show_connections,
    )

    # Parse the JSON after the extraction
    parse_connections = PythonOperator(
        task_id='parse_connections',
        python_callable= parse_json,
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        )    
        
    # So the BQ connection can invoke the Cloud Function
    grant_iam_function_invoker = bash_operator.BashOperator(
        task_id="grant_iam_function_invoker",
        bash_command=grant_iam_function_invoker  
    )

    # So the cloud function can read from a bucket
    grant_bucket_iam = bash_operator.BashOperator(
        task_id="grant_bucket_iam",
        bash_command=grant_bucket_iam  
    )

    # DAG Graph
    change_org_policy_allowedIngressSettings >> change_org_policy_allowedPolicyMemberDomains >> \
        sleep_2_minutes >> \
        deploy_cloud_function >> \
        bq_create_connection >> bq_show_connections >> parse_connections >> \
        grant_iam_function_invoker >> \
        grant_bucket_iam

# [END dag]
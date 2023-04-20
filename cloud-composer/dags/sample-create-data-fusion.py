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
# Summary: Creates a data fusion instance and waits for the instance to come online ()

# [START dag]
from datetime import datetime, timedelta
from airflow.operators import bash_operator
from airflow.utils import trigger_rule
from airflow.operators.python_operator import PythonOperator
import requests
import sys
import os
import logging
import airflow
import google.auth
import google.auth.transport.requests
import time




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
region                = os.environ['ENV_DATAFUSION_REGION'] 
datafusion_name       = "data-fusion-prod-01"


# Creates a data fusion instance (name hardcoded)
# NOTE: There is a data fusion airflow operator, this is designed to show the REST API call for other tooling as well
def create_data_fusion(project_id, region, datafusion_name):

    # Get auth (default service account running composer worker node)
    creds, project = google.auth.default()
    auth_req = google.auth.transport.requests.Request() # required to acess access token
    creds.refresh(auth_req)
    access_token=creds.token
    auth_header = { 'Authorization'   : "Bearer " + access_token ,
                    'Accept'          : 'application/json',
                    'Content-Type'    : 'application/json'
    }

    # call rest api with bearer token
    createUri="https://datafusion.googleapis.com/v1beta1/projects/{}/locations/{}/instances?instanceId={}".format(project_id,region,datafusion_name)
    # https://cloud.google.com/data-fusion/docs/reference/rest/v1beta1/projects.locations.instances#Instance
    request_body= '{ "labels" : { "env" : "prod" } }'


    try:
        response = requests.post(createUri, headers=auth_header, data=request_body)
        response.raise_for_status()
        print("Create Data Fusion")
    except requests.exceptions.RequestException as err:
        print(err)
        raise err


# Waits for the instance to come online
def wait_for_data_fusion_provisioning(project_id, region, datafusion_name):

    # Get auth (default service account running composer worker node)
    creds, project = google.auth.default()
    auth_req = google.auth.transport.requests.Request() # required to acess access token
    creds.refresh(auth_req)
    access_token=creds.token
    auth_header = {'Authorization' : "Bearer " + access_token }


    instanceState = "CREATING"
    i = 1

    while instanceState == "CREATING":

        time.sleep(30)
            
        # Check the state
        stateDataFusion="https://datafusion.googleapis.com/v1beta1/projects/{}/locations/{}/instances/{}".format(project_id,region,datafusion_name)

        try:
            response = requests.get(stateDataFusion, headers=auth_header)
            response.raise_for_status()
            print("Checking State of Data Fusion Deployment")
        except requests.exceptions.RequestException as err:
            print(err)
            raise err

        instanceState = response.json()['state']

        print("Checking Data Fusion State ({}) value: {}".format(i, instanceState))
        print("JSON: ", response.json())
        i = i + 1
        
        """ Sample Response
        {
            "name": "projects/data-analytics-demo-z4x77nbcc3/locations/us-central1/instances/qadatafusion",
            "type": "BASIC",
            "networkConfig": {},
            "createTime": "2022-06-29T13:21:24.874523833Z",
            "updateTime": "2022-06-29T13:32:28.762387202Z",
            "state": "RUNNING",
            "serviceEndpoint": "https://qadatafusion-data-analytics-demo-z4x77nbcc3-dot-usw1.datafusion.googleusercontent.com",
            "version": "6.6.0",
            "serviceAccount": "cloud-datafusion-management-sa@wcb6888d249fbda6c-tp.iam.gserviceaccount.com",
            "displayName": "QADataFusion",
            "availableVersion": [
                {
                "versionNumber": "6.7.0"
                }
            ],
            "apiEndpoint": "https://qadatafusion-data-analytics-demo-z4x77nbcc3-dot-usw1.datafusion.googleusercontent.com/api",
            "gcsBucket": "gs://df-2432185209294608530-52ppjphxvyi6zaykaizbbqaaaa",
            "p4ServiceAccount": "service-1074332558384@gcp-sa-datafusion.iam.gserviceaccount.com",
            "tenantProjectId": "wcb6888d240fbda7c-tp",
            "dataprocServiceAccount": "1074332558384-compute@developer.gserviceaccount.com"
        }
        """


     
with airflow.DAG('sample-create-data-fusion',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Show creating data fusion via the REST API
    create_data_fusion = PythonOperator(
        task_id='create_data_fusion',
        python_callable= create_data_fusion,
        op_kwargs = { "project_id" : project_id, 
                      "region" : region,
                      "datafusion_name" : datafusion_name,
                       },
        execution_timeout=timedelta(minutes=10),
        dag=dag,
        )    

    # Wait for the instance to come online
    wait_for_data_fusion_provisioning = PythonOperator(
        task_id='wait_for_data_fusion_provisioning',
        python_callable= wait_for_data_fusion_provisioning,
        op_kwargs = { "project_id" : project_id, 
                      "region" : region,
                      "datafusion_name" : datafusion_name,
                       },
        execution_timeout=timedelta(minutes=60),
        dag=dag,
        )    

    # DAG Graph
    create_data_fusion >> wait_for_data_fusion_provisioning
    

# [END dag]
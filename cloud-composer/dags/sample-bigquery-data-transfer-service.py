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
taxi_dataset_id       = os.environ['ENV_TAXI_DATASET_ID']


# Detination dataset for the dataset copy
dataset_copy_id=taxi_dataset_id + "_public_copy"


# Create the destination dataset
bq_create_dataset_command= \
    "bq mk " + \
    "--dataset " + \
    "--location=\"" + bigquery_region + "\" " + \
    dataset_copy_id


# Create a transfer
bq_copy_dataset_command= \
    "bq mk --transfer_config " + \
    "--project_id=\""+ project_id + "\" " + \
    "--data_source=cross_region_copy " + \
    "--target_dataset=\"" + dataset_copy_id + "\" " + \
    "--display_name=\"Copy Public NYC Taxi Data\" " + \
    "--no_auto_scheduling " + \
    "--params='" + \
        "{\"source_dataset_id\":\"new_york_taxi_trips\"," + \
         "\"source_project_id\":\"bigquery-public-data\"," + \
         "\"overwrite_destination_table\":\"true\"}'"


# Shows the output of your data transfer service listings.  This lets your query the name based upon the description
# bq ls --transfer_config --transfer_location=REPLACE-REGION --format=json
# [{"name":"projects/55121552096/locations/REPLACE-REGION/transferConfigs/6204b922-0000-2446-add8-089e08254a24","destinationDatasetId":"test_dataset_id","displayName":"Copy Public NYC Taxi Data","updateTime":"2022-01-31T15:41:06.120914Z","dataSourceId":"cross_region_copy","params":{"source_dataset_id":"new_york_taxi_trips","overwrite_destination_table":true,"source_project_id":"bigquery-public-data"},"userId":"-8510066568950052504","datasetRegion":"REPLACE-REGION","emailPreferences":{},"scheduleOptions":{"disableAutoScheduling":true}}]

# Command to start a transfer
# JQ is not installed on the Composer worker nodes.  Need to call via an API.

#bq_start_transfer_command= \
#    "transfersJSON=$(bq ls --transfer_config --transfer_location=" + bigquery_region + " --format=json) && \ " + \
#    "transferConfigFilter=$(echo \"${transfersJSON}\" | jq '.[] | select(.displayName == \"Copy Public NYC Taxi Data\")') && \ " + \
#    "transferConfig=$(echo \"${transferConfigFilter}\" | jq .name --raw-output) && \ " + \
#    "bq mk --run_time=" + currentDataString + "T00:00:00.00Z --transfer_run ${transferConfig}"


# Queries the data transfer service and after locating the dataset copy starts it
def list_data_transfers(project_id, bigquery_region):
    currentDataString=datetime.today().strftime('%Y-%m-%d') + "T00:00:00.00Z"
    bq_start_transfer_command="bq mk --run_time=" + currentDataString + " --transfer_run transferConfig"

    # Get auth (default service account running composer worker node)
    creds, project = google.auth.default()
    auth_req = google.auth.transport.requests.Request() # required to acess access token
    creds.refresh(auth_req)
    access_token=creds.token
    auth_header = {'Authorization' : "Bearer " + access_token }

    # call rest api with bearer token
    uri="https://bigquerydatatransfer.googleapis.com/v1/projects/" + project_id + "/locations/" + bigquery_region + "/transferConfigs"
    
    try:
        response = requests.get(uri, headers=auth_header)
        response.raise_for_status()
        print("Queried Data Transfer Service")
    except requests.exceptions.RequestException as err:
        print(err)
        raise err

    # Parse return JSON
    #print(response.json())
    #{'transferConfigs': [{'name': 'projects/55121552096/locations/REPLACE-REGION/transferConfigs/621e6e79-0000-26c5-8ed3-001a114471f4', 'destinationDatasetId': 'taxi_dataset_public_copy', 'displayName': 'Copy Public NYC Taxi Data', 'updateTime': '2022-01-31T17:53:22.824517Z', 'dataSourceId': 'cross_region_copy', 'params': {'source_dataset_id': 'new_york_taxi_trips', 'source_project_id': 'bigquery-public-data', 'overwrite_destination_table': True}, 'userId': '-8510066568950052504', 'datasetRegion': 'REPLACE-REGION', 'emailPreferences': {}, 'scheduleOptions': {'disableAutoScheduling': True}}, {'name': 'projects/55121552096/locations/REPLACE-REGION/transferConfigs/621ea667-0000-26c5-8ed3-001a114471f4', 'destinationDatasetId': 'taxi_dataset_public_copy', 'displayName': 'Copy Public NYC Taxi Data', 'updateTime': '2022-01-31T18:07:50.028629Z', 'dataSourceId': 'cross_region_copy', 'params': {'source_project_id': 'bigquery-public-data', 'source_dataset_id': 'new_york_taxi_trips', 'overwrite_destination_table': True}, 'userId': '-8510066568950052504', 'datasetRegion': 'REPLACE-REGION', 'emailPreferences': {}, 'scheduleOptions': {'disableAutoScheduling': True}}]}
    transferConfigName = ""
    for element in response.json()['transferConfigs']:
        if element['displayName'] == 'Copy Public NYC Taxi Data':
            transferConfigName=element['name']
            print("transferConfigName: " + transferConfigName)
            break   
    
    # Start the Transfer
    # https://cloud.google.com/bigquery-transfer/docs/reference/datatransfer/rest/v1/projects.locations.transferConfigs/startManualRuns
    uri="https://bigquerydatatransfer.googleapis.com/v1/" + transferConfigName + ":startManualRuns"
    request_body = { "requestedRunTime" : currentDataString }
    
    try:
        response = requests.post(uri, headers=auth_header, data=request_body)
        response.raise_for_status()
        print("Started Data Transfer Service for Dataset Copy")
    except requests.exceptions.RequestException as err:
        print(err)
        raise err


    
with airflow.DAG('sample-bigquery-data-transfer-service',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands
    # Access to create a data transfer and access to BQ to create a dataset

    # Show some BQ commands
    bq_create_dataset = bash_operator.BashOperator(
        task_id="bq_create_dataset",
        bash_command=bq_create_dataset_command,
    )

    bq_copy_dataset = bash_operator.BashOperator(
        task_id="bq_copy_dataset",
        bash_command=bq_copy_dataset_command,
    )

    # Does not work since JQ is not installed and did not want to install
    #bq_start_transfer = bash_operator.BashOperator(
    #    task_id="bq_start_transfer",
    #    bash_command=bq_start_transfer_command,
    #)

    # Show starting a data tranfer via the REST API
    start_transfer = PythonOperator(
        task_id='start_transfer',
        python_callable= list_data_transfers,
        op_kwargs = { "project_id" : project_id, 
                      "bigquery_region" : bigquery_region },
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        )    

    # DAG Graph
    bq_create_dataset >> bq_copy_dataset >> start_transfer
    

# [END dag]
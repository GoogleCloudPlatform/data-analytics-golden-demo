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
# Summary: Stops the Spanner instance job started by the sample-bigquery-start-spanner DAG

# [START dag]
from datetime import datetime, timedelta
from airflow.operators import bash_operator
from airflow.utils import trigger_rule
from airflow.operators.python_operator import PythonOperator
import requests
import sys
import os
import logging
import json
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
spanner_region        = os.environ['ENV_SPANNER_REGION'] 
spanner_instance_id   = os.environ['ENV_SPANNER_INSTANCE_ID']

spanner_uri = "projects/" + project_id + "/instances/" + spanner_instance_id

delete_bigquery_connection="bq rm --connection --location=\"" + spanner_region + "\" bq_spanner_connection"


# Opens the json written out when the job was started
# Checks for 4 hours
# Stops the job and deletes the json file
# NOTE: This assumes only 1 job has been started and is not designed for many jobs
def delete_spanner_instance(spanner_uri):
    print("delete_spanner_instance")
    filePath = "/home/airflow/gcs/data/write_spanner_run_datetime.json"
    deleteSpannerInstance = False
    if os.path.exists(filePath):
        with open(filePath) as f:
            data = json.load(f)
        
        print("run_datetime: ", data['run_datetime'])
        print("spanner_instance_id: ", data['spanner_instance_id'])
        run_datetime = datetime.strptime(data['run_datetime'], "%m/%d/%Y %H:%M:%S")
        spanner_instance_id = data['spanner_instance_id']
        difference = run_datetime - datetime.now()
        print("difference.total_seconds(): ", abs(difference.total_seconds()))
        # Test for 4 hours
        # if difference.total_seconds() > (4 * 60 * 60):
        if abs(difference.total_seconds()) > (4 * 60 * 60):
            print("Deleting Spanner Instance > 4 hours")
            deleteSpannerInstance = True
    else:
        print("Json files does not exist (no Spanner Instance deployed)")

    if deleteSpannerInstance:
        # Get auth (default service account running composer worker node)
        creds, project = google.auth.default()
        auth_req = google.auth.transport.requests.Request() # required to acess access token
        creds.refresh(auth_req)
        access_token=creds.token
        auth_header = {
            'Authorization' : "Bearer " + access_token,
            'Accept' : 'application/json',
            'Content-Type' : 'application/json' }
        # print("auth_header: ", auth_header)

        # call rest api with bearer token
        # DELETE https://cloud.google.com/spanner/docs/reference/rest/v1/projects.instances/delete
        uri="https://spanner.googleapis.com/v1/" + spanner_uri
        print("uri: ", uri)

        # request_body = { "requestedState" : "JOB_STATE_CANCELLED" }

        """
        # https://cloud.google.com/spanner/docs/reference/rest/v1/projects.instances/delete
        curl --request DELETE \
        'https://spanner.googleapis.com/v1/adam?key=[YOUR_API_KEY]' \
        --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
        --header 'Accept: application/json' \
        --compressed

        """

        try:
            response = requests.delete(uri, headers=auth_header)
            response.raise_for_status()
            print("Deleted Spanner Instance")
            os.remove(filePath)
        except requests.exceptions.RequestException as err:
            print("Error: ", err)
            raise err


with airflow.DAG('sample-bigquery-stop-spanner',
                 default_args=default_args,
                 start_date=datetime(2022, 1, 1),
                 catchup=False,
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Run every 15 minutes
                 schedule_interval=timedelta(minutes=15)) as dag:


    # Delete the Spanner instnace after 4 hours
    delete_spanner_instance = PythonOperator(
        task_id='delete_spanner_instance',
        python_callable= delete_spanner_instance,
        op_kwargs = { "spanner_uri" : spanner_uri },
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        ) 

    # Delete BigQuery Spanner connection
    """  Should only run if > 4 hours
    delete_bigquery_connection = bash_operator.BashOperator(
         task_id="delete_bigquery_connection",
        bash_command=delete_bigquery_connection,
    )
    """

    # DAG Graph
    delete_spanner_instance
    
# [END dag]
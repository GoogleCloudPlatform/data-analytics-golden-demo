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
# Summary: Stops the Dataflow job started by the sample-dataflow-streaming-bigquery DAG

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
region                = os.environ['ENV_DATAFLOW_REGION'] 

# Opens the json written out when the job was started
# Checks for 4 hours
# Stops the job and deletes the json file
# NOTE: This assumes only 1 job has been started and is not designed for many jobs
def stop_dataflow_job():
    print("stop_dataflow_job")
    filePath = "/home/airflow/gcs/data/write_dataflow_job_id.json"
    stopJob = False
    if os.path.exists(filePath):
        with open(filePath) as f:
            data = json.load(f)
        
        print("run_datetime: ", data['run_datetime'])
        print("dataflow_job_id: ", data['dataflow_job_id'])
        run_datetime = datetime.strptime(data['run_datetime'], "%m/%d/%Y %H:%M:%S")
        dataflow_job_id = data['dataflow_job_id']
        difference = run_datetime - datetime.now()
        print("difference.total_seconds(): ", abs(difference.total_seconds()))
        # Test for 4 hours
        # if difference.total_seconds() > (4 * 60 * 60):
        if abs(difference.total_seconds()) > (4 * 60 * 60):
            print("Stopping job > 4 hours")
            stopJob = True
    else:
        print("Json files does not exist (no Dataflow job deployed)")

    if stopJob:
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
        # PUT https://dataflow.googleapis.com/v1b3/projects/{projectId}/locations/{location}/jobs/{jobId}
        #     https://dataflow.googleapis.com/v1b3/projects/data-analytics-demo-ja3y7o1hnz/locations/REPLACE-REGION/jobs/2022-05-17_09_05_35-7404530975856425200
        uri="https://dataflow.googleapis.com/v1b3/projects/" + project_id + "/locations/" + region + "/jobs/" + dataflow_job_id
        print("uri: ", uri)

        request_body = { "requestedState" : "JOB_STATE_CANCELLED" }

        """
        # https://cloud.google.com/dataflow/docs/reference/rest/v1b3/projects.locations.jobs/update
        curl --request PUT \
            'https://dataflow.googleapis.com/v1b3/projects/data-analytics-demo-ja3y7o1hnz/locations/REPLACE-REGION/jobs/2022-05-17_09_05_35-7404530975856425200' \
            --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --data '{"requestedState":"JOB_STATE_CANCELLED"}' \
            --compressed
        """

        try:
            response = requests.put(uri, headers=auth_header, data=json.dumps(request_body))
            response.raise_for_status()
            print("Cancelled Dataflow Job")
            os.remove(filePath)
        except requests.exceptions.RequestException as err:
            print("Error: ", err)
            raise err


with airflow.DAG('sample-dataflow-stop-streaming-job',
                 default_args=default_args,
                 start_date=datetime(2022, 1, 1),
                 catchup=False,
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Run every 15 minutes
                 schedule_interval=timedelta(minutes=15)) as dag:


    # Show starting a data tranfer via the REST API
    stop_dataflow_job = PythonOperator(
        task_id='stop_dataflow_job',
        python_callable= stop_dataflow_job,
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        ) 

    
    # DAG Graph
    stop_dataflow_job
    
# [END dag]
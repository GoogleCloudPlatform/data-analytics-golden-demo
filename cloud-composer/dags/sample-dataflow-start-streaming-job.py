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
# Summary: Starts the Dataflow Pipeline that reads the public Pub/Sub NYC Taxi streaming data
####
# NOTE:    The Dataflow job will be STOPPED by the Airflow  DAG (sample-dataflow-stop-streaming-job) after 4 hours of streaming.
#          This will keep you from running up a large GCP bill.
####

# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import json
import airflow
from airflow.operators import bash_operator
from airflow.utils import trigger_rule
from airflow.providers.apache.beam.operators.beam import BeamRunPythonPipelineOperator
from airflow.providers.google.cloud.operators.dataflow import DataflowConfiguration
from airflow.operators.python_operator import PythonOperator


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
raw_bucket_name       = os.environ['ENV_RAW_BUCKET'] 
taxi_dataset_id       = os.environ['ENV_TAXI_DATASET_ID'] 
dataproc_bucket       = os.environ['ENV_DATAPROC_BUCKET'] 
dataflow_subnet       = os.environ['ENV_DATAFLOW_SUBNET'] 
serviceAccount        = os.environ['ENV_DATAFLOW_SERVICE_ACCOUNT'] 

output_table     = project_id + ":" + taxi_dataset_id + ".taxi_trips_streaming"
dataflow_py_file = "gs://" + raw_bucket_name + "/dataflow/streaming-taxi-data.py"
tempLocation     = "gs://" + dataproc_bucket + "/dataflow-temp/"

print("output_table:     " + output_table)
print("dataflow_py_file: " + dataflow_py_file)
print("tempLocation:     " + tempLocation)
print("serviceAccount:   " + serviceAccount)
print("dataflow_subnet:  " + dataflow_subnet)


def write_dataflow_job_id(dataflow_job_id):
    run_datetime = datetime.now()
    print("dataflow_job_id: ", dataflow_job_id)
    data = {
        "run_datetime" : run_datetime.strftime("%m/%d/%Y %H:%M:%S"),
        "dataflow_job_id" : dataflow_job_id
    }
    with open('/home/airflow/gcs/data/write_dataflow_job_id.json', 'w') as f:
        json.dump(data, f)
        

with airflow.DAG('sample-dataflow-start-streaming-job',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:


    # Start Dataflow Python Streaming job
    # DEPRECATED:  https://airflow.apache.org/docs/apache-airflow-providers-google/stable/operators/cloud/dataflow.html
    # NEW:         https://airflow.apache.org/docs/apache-airflow-providers-apache-beam/stable/_api/airflow/providers/apache/beam/operators/beam/index.html
    # NEW EXAMPLE: https://github.com/apache/airflow/blob/main/airflow/providers/apache/beam/example_dags/example_beam.py

    # airflow.providers.apache.beam.operators.beam.BeamRunPythonPipelineOperator
    # (*, py_file, runner='DirectRunner', default_pipeline_options=None, 
    # pipeline_options=None, py_interpreter='python3', py_options=None, 
    # py_requirements=None, py_system_site_packages=False, 
    # gcp_conn_id='google_cloud_default', delegate_to=None, 
    # dataflow_config=None, **kwargs)[source]
    start_dataflow = BeamRunPythonPipelineOperator(
            task_id="start_dataflow",
            py_file=dataflow_py_file,
            runner="DataflowRunner",
            default_pipeline_options= {
                'tempLocation'      : tempLocation,
                'output'            : output_table,
                'streaming'         : True,
                'serviceAccount'    : serviceAccount,
                "network"           : "vpc-main",
                'subnetwork'        : dataflow_subnet,
                'no_use_public_ips' : True,
                'maxNumWorkers'     : 5
            },
            py_interpreter='python3',
            py_requirements=['google-cloud-pubsub==2.1.0','google-cloud-bigquery-storage==2.13.2','apache-beam[gcp]==2.42.0'],
            py_system_site_packages=False,
            dataflow_config=DataflowConfiguration(
                job_name="taxi-dataflow-streaming-bigquery",
                project_id = project_id,
                location = region,
                drain_pipeline = True,
                wait_until_finished = False
            ),
    )

    

    # Show starting a data tranfer via the REST API
    write_dataflow_job_id = PythonOperator(
        task_id='write_dataflow_job_id',
        python_callable= write_dataflow_job_id,
        op_kwargs = { "dataflow_job_id" : "{{task_instance.xcom_pull('start_dataflow')['dataflow_job_id']}}" },
        execution_timeout=timedelta(minutes=1),
        dag=dag,
        ) 

    
    # DAG Graph
    start_dataflow >> write_dataflow_job_id
    
# [END dag]
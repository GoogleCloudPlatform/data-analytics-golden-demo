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
# Summary: Waits until the table has data in it
#          You could call: https://cloud.google.com/bigquery/docs/reference/system-procedures#bqrefresh_external_metadata_cache
#          The above call requires your table refresh to be set to Manual.

# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import airflow
import time
from airflow.utils import trigger_rule
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.operators.python_operator import PythonOperator
from google.cloud import bigquery

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

project_id              = os.environ['ENV_PROJECT_ID'] 
bigquery_region         = os.environ['ENV_BIGQUERY_REGION'] 
rideshare_lakehouse_raw = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_DATASET']

# In BQ object tables take some time to initialize themselves with data
# We need to wait for the data to show up before we process the data
def wait_for_object_table():
    # Wait for job to start
    print ("wait_for_object_table STARTED, sleeping for 15 seconds for jobs to start")
    time.sleep(15)
    rowCount = 0


    client = bigquery.Client()
    sql1 = f"CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('{project_id}.{rideshare_lakehouse_raw}.biglake_rideshare_images');"   
    sql2 = f"SELECT COUNT(*) AS RowCount FROM `{project_id}.{rideshare_lakehouse_raw}.biglake_rideshare_images`;"   
 

    # Run for for so many interations
    counter  = 1
    while (counter < 60):    
        try:
            query_job1 = client.query(sql1)
            query_job2 = client.query(sql2)

            for row in query_job2:
                # Row values can be accessed by field name or index.
                print("RowCount = {}".format(row["RowCount"]))
                rowCount = int(str(row["RowCount"]))

            if rowCount == 0:
                print("Sleeping...")
                time.sleep(15)
            else:
                print("Exiting")
                return True
        except requests.exceptions.RequestException as err:
            print(err)
            raise err
        counter = counter + 1

    errorMessage = "The process (wait_for_object_table) run for too long.  Increase the number of iterations."
    raise Exception(errorMessage)


with airflow.DAG('sample-rideshare-object-table-delay',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:
 
    wait_for_object_table = PythonOperator(
        task_id='wait_for_object_table',
        python_callable= wait_for_object_table,
        execution_timeout=timedelta(minutes=300),
        dag=dag,
        ) 

    wait_for_object_table

# [END dag]

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
# Summary: Creates a Postgres Cloud SQL instance
#          Creates a database
#          Creates a table with some data
#          Creates a datastream job from Cloud SQL to BigQuery

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
import json
from pathlib import Path
import psycopg2
import time
import random

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

project_id         = os.environ['ENV_PROJECT_ID'] 
root_password      = os.environ['ENV_RANDOM_EXTENSION'] 
cloud_sql_region   = os.environ['ENV_CLOUD_SQL_REGION']
datastream_region  = os.environ['ENV_DATASTREAM_REGION']

params_list = { 
    'project_id'        : project_id,
    'root_password'     : root_password, 
    'cloud_sql_region'  : cloud_sql_region, 
    'datastream_region' : datastream_region, 
    }    


# Create the table
# Set the datastream replication items
def run_postgres_sql(database_password):
    print("start run_postgres_sql")
    ipAddress = Path('/home/airflow/gcs/data/postgres_public_ip_address.txt').read_text()
    print("ipAddress:", ipAddress)

    database_name = "demodb"
    postgres_user = "postgres"

    conn = psycopg2.connect(
    host=ipAddress,
    database=database_name,
    user=postgres_user,
    password=database_password)

    with open('/home/airflow/gcs/data/postgres_create_generated_data.sql', 'r') as file:
        generate_data = file.readlines()

    try:
        # This runs for about 5+ hours
        cur = conn.cursor()
        for loop in range(10):
            for sql in generate_data:
                if sql.startswith("--") == False:
                    # print("SQL: ", sql)
                    cur.execute(sql)
                if loop % 10 == 0:
                    time.sleep(1)
                    print("Loop: ", loop)
                    conn.commit()
        cur.close()
        conn.commit()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()


with airflow.DAG('sample-datastream-public-ip-generate-data',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    run_postgres_sql_task = PythonOperator(
        task_id='run_postgres_sql_task',
        python_callable=run_postgres_sql,
        op_kwargs = { "database_password" : root_password },
        dag=dag
        )
    
    # DAG Graph
    run_postgres_sql_task

# [END dag]
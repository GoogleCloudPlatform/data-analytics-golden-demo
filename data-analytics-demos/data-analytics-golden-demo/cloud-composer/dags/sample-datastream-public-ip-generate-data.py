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
    ipAddress = ipAddress.replace("\n", "")
    print("ipAddress:", ipAddress)

    database_name = "demodb"
    postgres_user = "postgres"

    conn = psycopg2.connect(
    host=ipAddress,
    database=database_name,
    user=postgres_user,
    password=database_password)

   # create default config
    config_data = {
        "interation_count" : 0,
        "min_index" : 1,
        "max_index" : 10010000,
        "current_index": 1
    }

    if os.path.exists('/home/airflow/gcs/data/datastream-public-ip-generate-data.json'):
        # read the data
        datastream_cdc_config_json = Path('/home/airflow/gcs/data/datastream-public-ip-generate-data.json').read_text()
        config_data = json.loads(datastream_cdc_config_json)
    else:
        # write the default config
        with open('/home/airflow/gcs/data/datastream-public-ip-generate-data.json', 'w') as f:
            json.dump(config_data, f)

    try:
        # This runs for 4 hours
        cur = conn.cursor()
        client = bigquery.Client()
        
        # Loop for 4 hours (14400 seconds)
        start_time = datetime.now()
        loop_count = 0
        while (datetime.now() - start_time).total_seconds() < 14400 :
            print("interation_count:",config_data["interation_count"])
            print("min_index:",config_data["min_index"])
            print("max_index:",config_data["max_index"])
            print("current_index:",config_data["current_index"])
            
            for index in range(config_data["current_index"], config_data["max_index"], 50):
                loop_count = loop_count + 1
                bigquery_sql = "SELECT sql_statement, table_name " + \
                                        " FROM taxi_dataset.datastream_cdc_data " + \
                                        "WHERE execution_order BETWEEN {} AND {};".format(index, index+49)
                # print("bigquery_sql: ", bigquery_sql)
                query_job = client.query(bigquery_sql)
                results = query_job.result()  # Waits for job to complete.

                for row in results:
                    # print("row.table_name:", row.table_name)
                    # print("row.sql_statement:", row.sql_statement)

                    if config_data["interation_count"] == 0:
                        # okay to execute
                        cur.execute(row.sql_statement)
                    else:
                        if row.table_name != "driver":
                            # okay to execute (we do not want to create duplicate drivers)
                            cur.execute(row.sql_statement)

                if index+49 >= config_data["max_index"]:
                    config_data["interation_count"] = config_data["interation_count"] + 1
                    config_data["current_index"] = 1

                conn.commit()
                config_data["current_index"] = index+49
                # Write the file ever so often
                if loop_count % 100 == 0:
                    print("bigquery_sql: ", bigquery_sql)
                    print("loop_count: ", loop_count)
                    print("config_data[current_index]: ", config_data["current_index"])
                    with open('/home/airflow/gcs/data/datastream-public-ip-generate-data.json', 'w') as f:
                        json.dump(config_data, f)                    

                if (datetime.now() - start_time).total_seconds() > 14400:
                    break

        # Save
        with open('/home/airflow/gcs/data/datastream-public-ip-generate-data.json', 'w') as f:
            json.dump(config_data, f)
        
        cur.close()
        conn.commit()

        # Save our state
        with open('/home/airflow/gcs/data/datastream-public-ip-generate-data.json', 'w') as f:
            json.dump(config_data, f)

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
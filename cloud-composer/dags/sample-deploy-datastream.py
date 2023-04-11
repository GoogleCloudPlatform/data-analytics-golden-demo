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

project_id         = os.environ['GCP_PROJECT'] 
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
    ipAddress = Path('/home/airflow/gcs/data/postgres_ip_address.txt').read_text()
    print("ipAddress:", ipAddress)

    database_name = "guestbook"
    postgres_user = "postgres"

    conn = psycopg2.connect(
    host=ipAddress,
    database=database_name,
    user=postgres_user,
    password=database_password)

    commands = (
        "CREATE TABLE entries (guestName VARCHAR(255), content VARCHAR(255), entryID SERIAL PRIMARY KEY);",
        "INSERT INTO entries (guestName, content) values ('first guest', 'I got here!');",
        "INSERT INTO entries (guestName, content) values ('second guest', 'Me too!');",
        "CREATE PUBLICATION datastream_publication FOR ALL TABLES;",
        "ALTER USER " + postgres_user + " with replication;",
        "SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('datastream_replication_slot', 'pgoutput');",
        "CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD '" + database_password + "';",
        "GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;",
        "GRANT USAGE ON SCHEMA public TO datastream_user ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;"
        )

    try:
        cur = conn.cursor()
        for command in commands:
            cur.execute(command)
        cur.close()
        conn.commit()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()


with airflow.DAG('sample-deploy-datastream',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands
    # This requires the Composer service account to be an Org Admin
    # Or you need to manaully disable the contraint sql.restrictAuthorizedNetworks (sample code is in bash_create_datastream_postgres_database.sh)

    # Create the Postgres Instance and Database
    #create_datastream_postgres_database_task = bash_operator.BashOperator(
    #      task_id='create_datastream_postgres_database_task',
    #      bash_command='bash_create_datastream_postgres_database.sh',
    #      params=params_list,
    #      dag=dag
    #      )

    #run_postgres_sql_task = PythonOperator(
    #    task_id='run_postgres_sql_task',
    #    python_callable=run_postgres_sql,
    #    op_kwargs = { "database_password" : root_password },
    #    dag=dag
    #    )    


    # Configure datastream
    bash_create_datastream_task = bash_operator.BashOperator(
          task_id='bash_create_datastream_task',
          bash_command='bash_create_datastream.sh',
          params=params_list,
          dag=dag
      )

    # DAG Graph
    bash_create_datastream_task

# [END dag]
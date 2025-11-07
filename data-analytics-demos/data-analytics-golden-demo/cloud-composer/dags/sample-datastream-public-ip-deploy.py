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
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
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

project_id         = os.environ['ENV_PROJECT_ID'] 
root_password      = os.environ['ENV_RANDOM_EXTENSION'] 
cloud_sql_region   = os.environ['ENV_CLOUD_SQL_REGION']
datastream_region  = os.environ['ENV_DATASTREAM_REGION']
bigquery_region    = os.environ['ENV_BIGQUERY_REGION'] 

params_list = { 
    'project_id'        : project_id,
    'root_password'     : root_password, 
    'cloud_sql_region'  : cloud_sql_region, 
    'datastream_region' : datastream_region, 
    'datastream_region' : datastream_region, 
    'bigquery_region'   : bigquery_region
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

    # Datastream failed to read from the PostgreSQL replication slot datastream_replication_slot. Make sure that the slot exists and that Datastream has the necessary permissions to access it.
    # Datastream failed to find the publication datastream_publication. Make sure that the publication exists and that Datastream has the necessary permissions to access it.
    with open('/home/airflow/gcs/data/postgres_create_schema.sql', 'r') as file:
        table_commands = file.readlines()

    with open('/home/airflow/gcs/data/postgres_create_datastream_replication.sql', 'r') as file:
        replication_commands = file.readlines()

    """    table_commands = (
            "CREATE TABLE IF NOT EXISTS entries (guestName VARCHAR(255), content VARCHAR(255), entryID SERIAL PRIMARY KEY);",
            "INSERT INTO entries (guestName, content) values ('first guest', 'I got here!');",
            "INSERT INTO entries (guestName, content) values ('second guest', 'Me too!');",
            )

        replication_commands = (
            "CREATE PUBLICATION datastream_publication FOR ALL TABLES;",
            "ALTER USER " + postgres_user + " with replication;",
            "SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('datastream_replication_slot', 'pgoutput');",
            "CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD '" + database_password + "';",
            "GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;",
            "GRANT USAGE ON SCHEMA public TO datastream_user;",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;"
            )
    """
    
    # You can get these through the DataStream UI.  Click through and press the button for the SQL to run.
    # CREATE PUBLICATION [MY_PUBLICATION] FOR ALL TABLES;
    # alter user <curr_user> with replication;
    # SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT ('[REPLICATION_SLOT_NAME]', 'pgoutput');
    # CREATE USER [MY_USER] WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD '[MY_PASSWORD]';
    # GRANT SELECT ON ALL TABLES IN SCHEMA [MY_SCHEMA] TO [MY_USER];
    # GRANT USAGE ON SCHEMA [MY_SCHEMA] TO [MY_USER];
    # ALTER DEFAULT PRIVILEGES IN SCHEMA [MY_SCHEMA] GRANT SELECT ON TABLES TO [MY_USER];    

    try:
        # Create table first in order to avoid "cannot create logical replication slot in transaction that has performed writes"
        table_cursor = conn.cursor()
        for sql in table_commands:
            print("SQL: ", sql)
            if sql.startswith("--"):
                continue
            if sql.strip() == "":
                continue
            table_cursor.execute(sql)
        table_cursor.close()
        conn.commit()

        # Run Datastream necessary commands (these change by database type)
        replication_cur = conn.cursor()
        for command in replication_commands:
            sql = command
            print("SQL: ", sql)
            if sql.startswith("--"):
                continue
            if sql.strip() == "":
                continue
            sql = sql.replace("<<POSTGRES_USER>>",postgres_user);
            sql = sql.replace("<<DATABASE_PASSWORD>>",database_password);
            replication_cur.execute(sql)
            conn.commit()
        replication_cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print("ERROR: ", error)
    finally:
        if conn is not None:
            conn.close()


with airflow.DAG('sample-datastream-public-ip-deploy',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands
    # This requires the Composer service account to be an Org Admin
    # Or you need to manaully disable the contraint sql.restrictAuthorizedNetworks (sample code is in sample_datastream_public_ip_deploy_postgres.sh)

    # Create the Postgres Instance and Database
    create_datastream_postgres_database_task = bash_operator.BashOperator(
          task_id='create_datastream_postgres_database_task',
          bash_command='sample_datastream_public_ip_deploy_postgres.sh',
          params=params_list,
          dag=dag
          )

    run_postgres_sql_task = PythonOperator(
        task_id='run_postgres_sql_task',
        python_callable=run_postgres_sql,
        op_kwargs = { "database_password" : root_password },
        dag=dag
        )    

    # Configure datastream
    bash_create_datastream_task = bash_operator.BashOperator(
          task_id='bash_create_datastream_task',
          bash_command='sample_datastream_public_ip_deploy_datastream.sh',
          params=params_list,
          dag=dag
      )

    # DAG Graph
    create_datastream_postgres_database_task >> run_postgres_sql_task >> bash_create_datastream_task

# [END dag]
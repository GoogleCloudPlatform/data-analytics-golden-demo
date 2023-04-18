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
# Summary: Export BigQuery public data to cloud storage.
#          Creates a Spanner manifest files and uploads to cloud storage.
#          Starts a Dataflow job that ingests the data from storage to Spanner
#          Create a BigQuery Federated connection so BQ can query Spanner directly
#          NOTE: BigQuery can query the public data, but this was done to show a Federated Query with public data (which just happens to be in BQ)


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
import google.auth
import google.auth.transport.requests
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
import json

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': None,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'dagrun_timeout' : timedelta(minutes=60),
}

project_id            = os.environ['ENV_PROJECT_ID'] 
region                = os.environ['ENV_SPANNER_REGION'] 
bigquery_region       = os.environ['ENV_BIGQUERY_REGION'] 
spanner_instance_id   = os.environ['ENV_SPANNER_INSTANCE_ID']
processed_bucket_name = os.environ['ENV_PROCESSED_BUCKET'] 
raw_bucket_name       = os.environ['ENV_RAW_BUCKET'] 

params_list = { 
    "project_id" : project_id,
    "region": region,
    "bigquery_region" : bigquery_region,
    "processed_bucket_name" : processed_bucket_name,
    "raw_bucket_name" : raw_bucket_name,
    "spanner_instance_id" : spanner_instance_id,
    }

sql="""
EXPORT DATA
OPTIONS(
  uri='gs://{processed_bucket_name}/spanner/weather/*.csv',
  format='CSV',
  overwrite=true,
  header=false,
  field_delimiter=',')
AS 
WITH JustRainSnowMinMaxTempData AS
(
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2022`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2021`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2020`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2019`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2018`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2017`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2016`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2015`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
)
SELECT id   AS station_id,
       date AS station_date,
       SNOW AS snow_mm_amt,
       PRCP AS precipitation_tenth_mm_amt,
       TMIN AS min_celsius_temp,
       TMAX AS max_celsius_temp,
  FROM JustRainSnowMinMaxTempData
PIVOT(MAX(value) FOR element IN ('SNOW','PRCP','TMIN','TMAX'))
ORDER BY date;
""".format(processed_bucket_name=processed_bucket_name)


LOCAL_PATH_SPANNER_MANIFEST_FILE = "/home/airflow/gcs/data/spanner-manifest.json"
BUCKET_RELATIVE_PATH="spanner/weather/"

# Delete the table before loading
gcloud_truncate_table=("gcloud spanner databases execute-sql weather " + \
  "--instance={spanner_instance_id} " + \
  "--sql='DELETE FROM weather WHERE true;'").format(\
    spanner_instance_id=spanner_instance_id)

# Dataflow template command to run a Spanner import from CSV files
gcloud_load_weather_table=("gcloud dataflow jobs run importspannerweatherdata " + \
  "--gcs-location gs://dataflow-templates-{region}/latest/GCS_Text_to_Cloud_Spanner " + \
  "--region {region} " + \
  "--max-workers 1 " + \
  "--num-workers 1 " + \
  "--service-account-email \"dataflow-service-account@{project_id}.iam.gserviceaccount.com\" " + \
  "--worker-machine-type \"n1-standard-4\" " + \
  "--staging-location gs://{raw_bucket_name} " + \
  "--network vpc-main " + \
  "--subnetwork regions/{region}/subnetworks/dataflow-subnet  " + \
  "--disable-public-ips " + \
  "--parameters " + \
  "instanceId={spanner_instance_id}," + \
  "databaseId=weather," + \
  "spannerProjectId={project_id}," + \
  "importManifest=gs://{processed_bucket_name}/spanner/weather/spanner-manifest.json").format(\
    region=region,
    processed_bucket_name=processed_bucket_name,
    raw_bucket_name=raw_bucket_name,
    project_id=project_id,
    spanner_instance_id=spanner_instance_id)


# Creates a JSON file that is required for the Dataflow job that loads Spanner
def write_spanner_manifest(processed_bucket_name,file_path):
    spanner_template_json={
      "tables": [
        {
          "table_name": "weather",
          "file_patterns": ["gs://" + processed_bucket_name + "/spanner/weather/*.csv"],
          "columns": [
            {"column_name": "station_id", "type_name": "STRING"},
            {"column_name": "station_date", "type_name": "DATE"},
            {"column_name": "snow_mm_amt", "type_name": "FLOAT64"},
            {"column_name": "precipitation_tenth_mm_amt", "type_name": "FLOAT64"},
            {"column_name": "min_celsius_temp", "type_name": "FLOAT64"},
            {"column_name": "max_celsius_temp", "type_name": "FLOAT64"}
          ]
        }
      ]
    }

    print(spanner_template_json)

    try:
        with open(file_path, 'w') as f:
            json.dump(spanner_template_json, f)            
    except Exception as e:
      print(e)
      raise e


with airflow.DAG('sample-bigquery-export-spanner-import',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands
    # Access to create a data transfer and access to BQ to create a dataset
    # Access to spanner is required

    # Run a BigQuery stored procedure that exports data to a storage bucket
    export_public_weather_data = BigQueryInsertJobOperator(
    task_id="export_public_weather_data",
    location=bigquery_region,
    configuration={
        "query": {
            "query": sql,
            "useLegacySql": False,
        }
    })
    
    # Save a template file locally and then upload to GCS (Spanner needs this for importing)
    write_spanner_manifest_file = PythonOperator(
        task_id='write_spanner_manifest_file',
        python_callable= write_spanner_manifest,
        op_kwargs = { "processed_bucket_name" : processed_bucket_name, 
                      "file_path" :  LOCAL_PATH_SPANNER_MANIFEST_FILE},
        dag=dag,
        )    

    upload_spanner_manifest_file = LocalFilesystemToGCSOperator(
        task_id="upload_spanner_manifest_file",
        src=LOCAL_PATH_SPANNER_MANIFEST_FILE,
        dst=BUCKET_RELATIVE_PATH,
        bucket=processed_bucket_name,
    )

    # Delete all records from the spanner table (to avoid dups)
    truncate_spanner_table = bash_operator.BashOperator(
        task_id="truncate_spanner_table",
        bash_command=gcloud_truncate_table,
    )

    # Run a Dataflow job that will import the data to spanner (this can take a few minutes to run)
    dataflow_load_spanner_table = bash_operator.BashOperator(
        task_id="dataflow_load_spanner_table",
        bash_command=gcloud_load_weather_table,
    )

    # Setup a BigQuery federated query connection so we can query BQ and Spanner using a single SQL command
    create_spanner_connection = bash_operator.BashOperator(
          task_id='create_spanner_connection',
          bash_command='bash_create_spanner_connection.sh',
          params=params_list,
          dag=dag
      )


    # DAG Graph
    export_public_weather_data >> \
      write_spanner_manifest_file >> upload_spanner_manifest_file >> \
      truncate_spanner_table >> dataflow_load_spanner_table >> \
      create_spanner_connection

# [END dag]
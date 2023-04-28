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
# Summary: Processes the downloaded Taxi data in the bucket to Parquet, CSV, JSON

# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import airflow
from airflow.utils import trigger_rule
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator


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

sql_taxi_external_tables="CALL `{}.taxi_dataset.sp_create_taxi_external_tables`();".format(project_id)
sql_taxi_internal_tables="CALL `{}.taxi_dataset.sp_create_taxi_internal_tables`();".format(project_id)
sql_create_product_deliveries="CALL `{}.thelook_ecommerce.create_product_deliveries`();".format(project_id)
sql_create_thelook_tables="CALL `{}.thelook_ecommerce.create_thelook_tables`('{}');".format(project_id,bigquery_region)
sql_taxi_biglake_tables="CALL `{}.taxi_dataset.sp_create_taxi_biglake_tables`();".format(project_id)

with airflow.DAG('step-03-hydrate-tables',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

 
    sql_taxi_external_tables = BigQueryInsertJobOperator(
    task_id="sql_taxi_external_tables",
    location=bigquery_region,
    configuration={
        "query": {
            "query": sql_taxi_external_tables,
            "useLegacySql": False,
        }
    })
    
    sql_taxi_internal_tables = BigQueryInsertJobOperator(
    task_id="sql_taxi_internal_tables",
    location=bigquery_region,
    configuration={
        "query": {
            "query": sql_taxi_internal_tables,
            "useLegacySql": False,
        }
    })

    sql_taxi_biglake_tables = BigQueryInsertJobOperator(
    task_id="sql_taxi_biglake_tables",
    location=bigquery_region,
    configuration={
        "query": {
            "query": sql_taxi_biglake_tables,
            "useLegacySql": False,
        }
    })  
    
    sql_create_product_deliveries = BigQueryInsertJobOperator(
    task_id="sql_create_product_deliveries",
    location=bigquery_region,
    configuration={
        "query": {
            "query": sql_create_product_deliveries,
            "useLegacySql": False,
        }
    })

    sql_create_thelook_tables = BigQueryInsertJobOperator(
    task_id="sql_create_thelook_tables",
    location=bigquery_region,
    configuration={
        "query": {
            "query": sql_create_thelook_tables,
            "useLegacySql": False,
        }
    }) 
    

    sql_taxi_external_tables >> sql_taxi_internal_tables >> sql_taxi_biglake_tables >> \
        sql_create_product_deliveries >> sql_create_thelook_tables

# [END dag]
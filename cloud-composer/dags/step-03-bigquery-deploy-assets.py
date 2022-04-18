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
# Summary: Deploys the code to BQ as stored procedures so users can run and reference

# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import airflow
#from airflow.operators import bash_operator
#from airflow.contrib.operators import dataproc_operator
from airflow.utils import trigger_rule
from airflow.contrib.operators import bigquery_operator
#from airflow.operators.python_operator import PythonOperator

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

project_id       = os.environ['GCP_PROJECT'] 
bucket_name      = os.environ['ENV_MAIN_BUCKET'] 
region           = os.environ['ENV_REGION'] 
gcp_account_name = os.environ['ENV_GCP_ACCOUNT_NAME']
dataset_id       = os.environ['ENV_DATASET_ID']
params_list = { 
    "project_id" : project_id,
    "region": region,
    "bucket_name": bucket_name,
    "gcp_account_name": gcp_account_name,
    "dataset_id": dataset_id
    }

with airflow.DAG('step-03-bigquery-deploy-assets',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # External Tables on Data Lake
    sp_create_taxi_external_tables = bigquery_operator.BigQueryOperator(
        task_id='sp_create_taxi_external_tables',
        sql=f"sp_create_taxi_external_tables.sql",
        params=params_list,
        use_legacy_sql=False)

    # Ingest Data Lake to Internal tables
    sp_create_taxi_internal_tables = bigquery_operator.BigQueryOperator(
        task_id='sp_create_taxi_internal_tables',
        sql=f"sp_create_taxi_internal_tables.sql",
        params=params_list,
        use_legacy_sql=False)

    # Materialized Views demo
    sp_demo_materialized_views_joins = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_materialized_views_joins',
        sql=f"sp_demo_materialized_views_joins.sql",
        params=params_list,
        use_legacy_sql=False)

    # Show ad-hoc pricing and quotas controls
    sp_demo_bigquery_pricing = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_bigquery_pricing',
        sql=f"sp_demo_bigquery_pricing.sql",
        params=params_list,
        use_legacy_sql=False)

    # Show security dataset, table, auth views, row level security
    sp_demo_security = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_security',
        sql=f"sp_demo_security.sql",
        params=params_list,
        use_legacy_sql=False)

    # Show JOINs between external/internal tables
    sp_demo_internal_external_table_join = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_internal_external_table_join',
        sql=f"sp_demo_internal_external_table_join.sql",
        params=params_list,
        use_legacy_sql=False)

    # Shows Rank, Partition, Pivot (analytic commands)
    sp_demo_bigquery_queries = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_bigquery_queries',
        sql=f"sp_demo_bigquery_queries.sql",
        params=params_list,
        use_legacy_sql=False)

    # Shows Time Travel and Snapshots
    sp_demo_time_travel_snapshots = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_time_travel_snapshots',
        sql=f"sp_demo_time_travel_snapshots.sql",
        params=params_list,
        use_legacy_sql=False)

    # Shows Time Travel and Snapshots
    sp_demo_transactions = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_transactions',
        sql=f"sp_demo_transactions.sql",
        params=params_list,
        use_legacy_sql=False)

    # Machine Learning (Tip Amount)
    sp_demo_machine_learning_tip_amounts = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_machine_learning_tip_amounts',
        sql=f"sp_demo_machine_learning_tip_amounts.sql",
        params=params_list,
        use_legacy_sql=False)        

    # Machine Learning (Anomalies)
    sp_demo_machine_leaning_anomoly_fee_amount = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_machine_leaning_anomoly_fee_amount',
        sql=f"sp_demo_machine_leaning_anomoly_fee_amount.sql",
        params=params_list,
        use_legacy_sql=False)   

    # Add more data and show Data Transfer Service
    sp_demo_data_transfer_service = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_data_transfer_service',
        sql=f"sp_demo_data_transfer_service.sql",
        params=params_list,
        use_legacy_sql=False)   

    # Data extract for weather data for Spanner    
    sp_demo_export_weather_data = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_export_weather_data',
        sql=f"sp_demo_export_weather_data.sql",
        params=params_list,
        use_legacy_sql=False)  

    # Federated queries to Spanner
    sp_demo_federated_query = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_federated_query',
        sql=f"sp_demo_federated_query.sql",
        params=params_list,
        use_legacy_sql=False)  

    # Report table for DataStudio report
    sp_demo_datastudio_report = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_datastudio_report',
        sql=f"sp_demo_datastudio_report.sql",
        params=params_list,
        use_legacy_sql=False)  

    # Report table for DataStudio report
    sp_demo_biglake = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_biglake',
        sql=f"sp_demo_biglake.sql",
        params=params_list,
        use_legacy_sql=False) 

    # For importing tensorflow model from notebooks
    sp_demo_machine_learning_import_tensorflow = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_machine_learning_import_tensorflow',
        sql=f"sp_demo_machine_learning_import_tensorflow.sql",
        params=params_list,
        use_legacy_sql=False) 

     # Json data type
    # To get your project allowlisted visit: https://cloud.google.com/bigquery/docs/reference/standard-sql/json-data        
    sp_demo_json_datatype = bigquery_operator.BigQueryOperator(
        task_id='sp_demo_json_datatype',
        sql=f"sp_demo_json_datatype.sql",
        params=params_list,
        use_legacy_sql=False)

    # DAG Graph
    sp_create_taxi_external_tables >> sp_create_taxi_internal_tables >> \
        [
            sp_demo_materialized_views_joins,
            sp_demo_bigquery_pricing,
            sp_demo_security,
            sp_demo_internal_external_table_join,
            sp_demo_bigquery_queries,
            sp_demo_time_travel_snapshots,
            sp_demo_transactions,
            sp_demo_machine_learning_tip_amounts,
            sp_demo_machine_leaning_anomoly_fee_amount,
            sp_demo_data_transfer_service,
            sp_demo_export_weather_data,
            sp_demo_federated_query,
            sp_demo_datastudio_report,
            sp_demo_biglake,
            sp_demo_machine_learning_import_tensorflow,
            sp_demo_json_datatype
        ]

# [END dag]
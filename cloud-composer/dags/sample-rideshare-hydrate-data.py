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
# Summary: Runs all the stored procedures necessary to hydrate the raw, enriched and curated zone of 
#          the Rideshare Analytics Lakehouse

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
from airflow.operators.trigger_dagrun import TriggerDagRunOperator


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

sp_rideshare_lakehouse_raw_sp_create_raw_data="CALL `{}.rideshare_lakehouse_raw.sp_create_raw_data`();".format(project_id)
sp_rideshare_lakehouse_raw_sp_create_biglake_object_table="CALL `{}.rideshare_lakehouse_raw.sp_create_biglake_object_table`();".format(project_id)
sp_rideshare_lakehouse_raw_sp_create_streaming_view="CALL `{}.rideshare_lakehouse_raw.sp_create_streaming_view`();".format(project_id)
sp_rideshare_lakehouse_raw_sproc_sp_create_biglake_tables="CALL `{}.rideshare_lakehouse_raw.sproc_sp_create_biglake_tables`();".format(project_id)

sp_rideshare_lakehouse_enriched_sp_process_data="CALL `{}.rideshare_lakehouse_enriched.sp_process_data`();".format(project_id)
sp_rideshare_lakehouse_enriched_sp_iceberg_spark_transformation="CALL `{}.rideshare_lakehouse_enriched.sp_iceberg_spark_transformation`();".format(project_id)
sp_rideshare_lakehouse_enriched_sp_unstructured_data_analysis="CALL `{}.rideshare_lakehouse_enriched.sp_unstructured_data_analysis`();".format(project_id)
sp_rideshare_lakehouse_enriched_sp_create_streaming_view="CALL `{}.rideshare_lakehouse_enriched.sp_create_streaming_view`();".format(project_id)

sp_rideshare_lakehouse_curated_sp_process_data="CALL `{}.rideshare_lakehouse_curated.sp_process_data`();".format(project_id)
sp_rideshare_lakehouse_curated_sp_create_streaming_view="CALL `{}.rideshare_lakehouse_curated.sp_create_streaming_view`();".format(project_id)
sp_rideshare_lakehouse_curated_sp_create_looker_studio_view="CALL `{}.rideshare_lakehouse_curated.sp_create_looker_studio_view`();".format(project_id)
sp_rideshare_lakehouse_curated_sp_create_website_realtime_dashboard="CALL `{}.rideshare_lakehouse_curated.sp_create_website_realtime_dashboard`();".format(project_id)
sp_rideshare_lakehouse_curated_sp_model_training="CALL `{}.rideshare_lakehouse_curated.sp_model_training`();".format(project_id)


with airflow.DAG('sample-rideshare-hydrate-data',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    rideshare_lakehouse_raw_sp_create_raw_data = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_raw_sp_create_raw_data",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_raw_sp_create_raw_data,
                "useLegacySql": False,
            }
        })
 
    rideshare_lakehouse_raw_sp_create_biglake_object_table = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_raw_sp_create_biglake_object_table",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_raw_sp_create_biglake_object_table,
                "useLegacySql": False,
            }
        })  
 
    rideshare_lakehouse_raw_sp_create_streaming_view = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_raw_sp_create_streaming_view",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_raw_sp_create_streaming_view,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_raw_sproc_sp_create_biglake_tables = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_raw_sproc_sp_create_biglake_tables",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_raw_sproc_sp_create_biglake_tables,
                "useLegacySql": False,
            }
        })            

    rideshare_lakehouse_enriched_sp_process_data = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_enriched_sp_process_data",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_enriched_sp_process_data,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_enriched_sp_unstructured_data_analysis = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_enriched_sp_unstructured_data_analysis",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_enriched_sp_unstructured_data_analysis,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_enriched_sp_create_streaming_view = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_enriched_sp_create_streaming_view",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_enriched_sp_create_streaming_view,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_curated_sp_process_data = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_curated_sp_process_data",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_curated_sp_process_data,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_curated_sp_create_streaming_view = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_curated_sp_create_streaming_view",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_curated_sp_create_streaming_view,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_curated_sp_create_looker_studio_view = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_curated_sp_create_looker_studio_view",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_curated_sp_create_looker_studio_view,
                "useLegacySql": False,
            }
        })  
      
    rideshare_lakehouse_curated_sp_create_website_realtime_dashboard = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_curated_sp_create_website_realtime_dashboard",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_curated_sp_create_website_realtime_dashboard,
                "useLegacySql": False,
            }
        })  

    rideshare_lakehouse_curated_sp_model_training = BigQueryInsertJobOperator(
        task_id="rideshare_lakehouse_curated_sp_model_training",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_rideshare_lakehouse_curated_sp_model_training,
                "useLegacySql": False,
            }
        })  

    # BigSpark
    #rideshare_lakehouse_enriched_sp_iceberg_spark_transformation = BigQueryInsertJobOperator(
    #    task_id="rideshare_lakehouse_enriched_sp_iceberg_spark_transformation",
    #    location=bigquery_region,
    #    configuration={
    #        "query": {
    #            "query": sp_rideshare_lakehouse_enriched_sp_iceberg_spark_transformation,
    #            "useLegacySql": False,
    #        }
    #    })  

    # Run Dataproc (until BigSpark is public)
    sample_rideshare_iceberg_serverless = TriggerDagRunOperator(
        task_id="sample_rideshare_iceberg_serverless",
        trigger_dag_id="sample-rideshare-iceberg-serverless",
        wait_for_completion=True
    )          

    # Process Iceberg using Dataproc Serverless Spark
    rideshare_lakehouse_raw_sp_create_raw_data >> rideshare_lakehouse_raw_sp_create_biglake_object_table >> \
        rideshare_lakehouse_raw_sp_create_streaming_view >> rideshare_lakehouse_raw_sproc_sp_create_biglake_tables >> \
        rideshare_lakehouse_enriched_sp_process_data >> sample_rideshare_iceberg_serverless >> \
        rideshare_lakehouse_enriched_sp_unstructured_data_analysis >> \
        rideshare_lakehouse_enriched_sp_create_streaming_view >> \
        rideshare_lakehouse_curated_sp_process_data >> rideshare_lakehouse_curated_sp_create_streaming_view >> \
        rideshare_lakehouse_curated_sp_create_looker_studio_view >> rideshare_lakehouse_curated_sp_create_website_realtime_dashboard >> \
        rideshare_lakehouse_curated_sp_model_training

    # Process Iceberg using BigSpark (still in preview)
    #rideshare_lakehouse_raw_sp_create_raw_data >> rideshare_lakehouse_raw_sp_create_biglake_object_table >> \
    #    rideshare_lakehouse_raw_sp_create_streaming_view >> rideshare_lakehouse_raw_sproc_sp_create_biglake_tables >> \
    #    rideshare_lakehouse_enriched_sp_process_data >> rideshare_lakehouse_enriched_sp_iceberg_spark_transformation >> \
    #    rideshare_lakehouse_enriched_sp_unstructured_data_analysis >> \
    #    rideshare_lakehouse_enriched_sp_create_streaming_view >> \
    #    rideshare_lakehouse_curated_sp_process_data >> rideshare_lakehouse_curated_sp_create_streaming_view >> \
    #    rideshare_lakehouse_curated_sp_create_looker_studio_view >> rideshare_lakehouse_curated_sp_create_website_realtime_dashboard >> \
    #    rideshare_lakehouse_curated_sp_model_training

# [END dag]

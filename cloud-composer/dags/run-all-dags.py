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
# Summary: Deploys Public Previiew features that require allowlisting
#          This is not part of Step 3 since items in this DAG will fail to deploy if your
#          project does not have a particular feature enabled.


# [START dag]
from datetime import datetime, timedelta
import sys
import os
import logging
import airflow
from airflow.utils import trigger_rule
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator

project_id            = os.environ['ENV_PROJECT_ID'] 
bigquery_region       = os.environ['ENV_BIGQUERY_REGION'] 

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

sp_datastream_cdc_data="CALL `{}.taxi_dataset.sp_create_datastream_cdc_data`();".format(project_id)

step_01_trigger_dag_id = "step-01-taxi-data-download"
step_02_trigger_dag_id = "step-02-taxi-data-processing"

# Quick copy (comment this out to actually process the data from source)
step_01_trigger_dag_id = "step-01-taxi-data-download-quick-copy"
step_02_trigger_dag_id = "step-02-taxi-data-processing-quick-copy"


with airflow.DAG('run-all-dags',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval='@once') as dag:

    step_01_taxi_data_download = TriggerDagRunOperator(
        task_id="step_01_taxi_data_download",
        trigger_dag_id=step_01_trigger_dag_id,
        wait_for_completion=True
    )        

    step_02_taxi_data_processing = TriggerDagRunOperator(
        task_id="step_02_taxi_data_processing",
        trigger_dag_id=step_02_trigger_dag_id,
        wait_for_completion=True
    )   

    step_03_hydrate_tables = TriggerDagRunOperator(
        task_id="step_03_hydrate_tables",
        trigger_dag_id="step-03-hydrate-tables",
        wait_for_completion=True
    )    

    # Start the streaming job so we have some seed data
    # This job will be stopped after 4 hours (by the stop job)
    sample_dataflow_start_streaming_job = TriggerDagRunOperator(
        task_id="sample_dataflow_start_streaming_job",
        trigger_dag_id="sample-dataflow-start-streaming-job",
        wait_for_completion=True
    )  

    # Download 250+ images for the object table
    sample_rideshare_download_images = TriggerDagRunOperator(
        task_id="sample_rideshare_download_images",
        trigger_dag_id="sample-rideshare-download-images",
        wait_for_completion=True
    )  

    # Deploy website to App Engine
    sample_rideshare_website = TriggerDagRunOperator(
        task_id="sample_rideshare_website",
        trigger_dag_id="sample-rideshare-website",
        wait_for_completion=True
    )  
    
    # Run all stored procedures in the raw, enriched and curated zone
    sample_rideshare_hydrate_data = TriggerDagRunOperator(
        task_id="sample_rideshare_hydrate_data",
        trigger_dag_id="sample-rideshare-hydrate-data",
        wait_for_completion=True
    )  

     # Download object table seed data and ML models
    sample_seed_unstructured_data = TriggerDagRunOperator(
        task_id="sample_seed_unstructured_data",
        trigger_dag_id="sample-seed-unstructured-data",
        wait_for_completion=True
    )   

    sp_datastream_cdc_data = BigQueryInsertJobOperator(
        task_id="sp_datastream_cdc_data",
        location=bigquery_region,
        configuration={
            "query": {
                "query": sp_datastream_cdc_data,
                "useLegacySql": False,
            }
        }) 

    sample_rideshare_llm_hydrate_data = TriggerDagRunOperator(
        task_id="sample_rideshare_llm_hydrate_data",
        trigger_dag_id="sample-rideshare-llm-hydrate-data",
        wait_for_completion=True
    )             
 
    sample_dataplex_dataprofile_ridehshare_llm = TriggerDagRunOperator(
        task_id="sample_dataplex_dataprofile_ridehshare_llm",
        trigger_dag_id="sample-dataplex-dataprofile-ridehshare-llm",
        wait_for_completion=True
    )  
 
    sample_dataplex_dataprofile_taxi = TriggerDagRunOperator(
        task_id="sample_dataplex_dataprofile_taxi",
        trigger_dag_id="sample-dataplex-dataprofile-taxi",
        wait_for_completion=True
    )  
 
    sample_dataplex_dataprofile_thelook = TriggerDagRunOperator(
        task_id="sample_dataplex_dataprofile_thelook",
        trigger_dag_id="sample-dataplex-dataprofile-thelook",
        wait_for_completion=True
    ) 
 
    sample_dataplex_dataprofile_rideshare_lakehouse = TriggerDagRunOperator(
        task_id="sample_dataplex_dataprofile_rideshare_lakehouse",
        trigger_dag_id="sample-dataplex-dataprofile-rideshare-lakehouse",
        wait_for_completion=True
    ) 

    # DAG Graph
    step_01_taxi_data_download >> [step_02_taxi_data_processing, sample_seed_unstructured_data, sample_rideshare_download_images]
    step_02_taxi_data_processing >> [step_03_hydrate_tables, sample_rideshare_website]
    step_03_hydrate_tables >> [sample_dataplex_dataprofile_taxi, sample_dataplex_dataprofile_thelook, sample_dataflow_start_streaming_job, sp_datastream_cdc_data, sample_rideshare_hydrate_data]
    sample_rideshare_hydrate_data >> sample_dataplex_dataprofile_rideshare_lakehouse
    sample_rideshare_llm_hydrate_data >> sample_dataplex_dataprofile_ridehshare_llm

# [END dag]
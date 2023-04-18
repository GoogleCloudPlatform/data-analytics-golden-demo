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
#from airflow.operators import bash_operator
from airflow.contrib.operators import dataproc_operator
from airflow.utils import trigger_rule
#from airflow.contrib.operators import bigquery_operator
#from airflow.operators.python_operator import PythonOperator





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

project_id               = os.environ['ENV_PROJECT_ID'] 
raw_bucket_name          = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name    = os.environ['ENV_PROCESSED_BUCKET'] 
pyspark_code             = "gs://" + raw_bucket_name + "/pyspark-code/convert_taxi_to_parquet.py"
region                   = os.environ['ENV_DATAPROC_REGION'] 
# zone                     = os.environ['ENV_ZONE'] 
yellow_source            = "gs://" + raw_bucket_name + "/raw/taxi-data/yellow/*/*.parquet"
green_source             = "gs://" + raw_bucket_name + "/raw/taxi-data/green/*/*.parquet"
destination              = "gs://" + processed_bucket_name + "/processed/taxi-data/"
dataproc_bucket          = os.environ['ENV_DATAPROC_BUCKET'] 
dataproc_subnet          = os.environ['ENV_DATAPROC_SUBNET'] 
dataproc_service_account = os.environ['ENV_DATAPROC_SERVICE_ACCOUNT'] 

# For small test run
# yellow_source   = "gs://big-query-demo-09/test-taxi/yellow/*.parquet"
# green_source    = "gs://big-query-demo-09/test-taxi/green/*.parquet"
# destination     = "gs://big-query-demo-09/test-taxi/dest/"

# https://cloud.google.com/dataproc/docs/reference/rest/v1/ClusterConfig
CLUSTER_CONFIG = {
    "config_bucket" : dataproc_bucket,
    "temp_bucket": dataproc_bucket,
    "master_config": {
        "num_instances": 1,
        "machine_type_uri": "n1-standard-8",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 30},
    },
    "worker_config": {
        "num_instances": 4,
        "machine_type_uri": "n1-standard-8",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 30},
    },
    "gce_cluster_config" :{
        "subnetwork_uri" : dataproc_subnet,
        "service_account" : dataproc_service_account,
        "service_account_scopes" : ["https://www.googleapis.com/auth/cloud-platform"],
        "internal_ip_only" : True,
        "shielded_instance_config" : { 
            "enable_secure_boot" : True,
            "enable_vtpm": True,
            "enable_integrity_monitoring": True
            }
    }
}

# if you want to specify the zone
#    "gce_cluster_config" :{
#        "zone_uri" : zone,
#        "subnetwork_uri" : dataproc_subnet,
#        "service_account" : dataproc_service_account,
#        "service_account_scopes" : ["https://www.googleapis.com/auth/cloud-platform"]
#    }


with airflow.DAG('step-02-taxi-data-processing',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Create cluster
    create_dataproc_cluster = dataproc_operator.DataprocClusterCreateOperator(
        default_args=default_args,
        task_id='create-dataproc-cluster',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-{{ ts_nodash.lower() }}',
        cluster_config=CLUSTER_CONFIG,
    )

    # Run the Spark code to processes the raw CSVs to a processed folder
    run_dataproc_spark = dataproc_operator.DataProcPySparkOperator(
        default_args=default_args,
        task_id='task-taxi-data',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-{{ ts_nodash.lower() }}',
        main=pyspark_code,
        arguments=[yellow_source, green_source, destination])


    # Delete Cloud Dataproc cluster
    delete_dataproc_cluster = dataproc_operator.DataprocClusterDeleteOperator(
        default_args=default_args,
        task_id='delete-dataproc-cluster',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-{{ ts_nodash.lower() }}',
        # Setting trigger_rule to ALL_DONE causes the cluster to be deleted even if the Dataproc job fails.
        trigger_rule=trigger_rule.TriggerRule.ALL_DONE)

    create_dataproc_cluster >> run_dataproc_spark >> delete_dataproc_cluster

# [END dag]
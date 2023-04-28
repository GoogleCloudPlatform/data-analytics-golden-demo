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
# Summary: Processes the downloaded Taxi data and saves to Iceberg tables (one green and one yellow table)
# To see the tables on storage:
#   Go to your "gs://processed...." bucket
#   Click on iceberg-warehouse folder
#   There is a default folder (our default warehouse)
#   There are tables under the folder
#   There are then data directories and metadata directories to view

# [START dag]
from google.cloud import storage
from datetime import datetime, timedelta
import sys
import os
import logging
import airflow
from airflow.contrib.operators import dataproc_operator
from airflow.utils import trigger_rule


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': None,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
    'dagrun_timeout' : timedelta(minutes=120),
}

project_id                 = os.environ['ENV_PROJECT_ID'] 
raw_bucket_name             = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name       = os.environ['ENV_PROCESSED_BUCKET'] 
pyspark_code_create_tables  = "gs://" + raw_bucket_name + "/pyspark-code/convert_taxi_to_iceberg_create_tables.py"
pyspark_code_update_data    = "gs://" + raw_bucket_name + "/pyspark-code/convert_taxi_to_iceberg_data_updates.py"
region                      = os.environ['ENV_DATAPROC_REGION'] 
yellow_source               = "gs://" + raw_bucket_name + "/raw/taxi-data/yellow/*/*.parquet"
green_source                = "gs://" + raw_bucket_name + "/raw/taxi-data/green/*/*.parquet"
dataproc_bucket             = os.environ['ENV_DATAPROC_BUCKET'] 
dataproc_subnet             = os.environ['ENV_DATAPROC_SUBNET'] 
dataproc_service_account    = os.environ['ENV_DATAPROC_SERVICE_ACCOUNT']

icebergWarehouse            = "gs://" + processed_bucket_name + "/iceberg-warehouse"
icebergJARFile              = "gs://" + raw_bucket_name + "/pyspark-code/iceberg-spark-runtime-3.1_2.12-0.14.0.jar"


# https://cloud.google.com/dataproc/docs/reference/rest/v1/ClusterConfig
CLUSTER_CONFIG = {
    "config_bucket" : dataproc_bucket,
    "temp_bucket": dataproc_bucket,
    "software_config": {
        "image_version": "2.0.47-debian10"
    },    
    "master_config": {
        "num_instances": 1,
        "machine_type_uri": "n1-standard-8",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 30, "num_local_ssds":2},
    },
    "worker_config": {
        "num_instances": 2,
        "machine_type_uri": "n1-standard-16",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 30, "num_local_ssds":2},
    },
    "gce_cluster_config" :{
        "subnetwork_uri" : dataproc_subnet,
        "service_account" : dataproc_service_account,
        "internal_ip_only" : True,
        "service_account_scopes" : ["https://www.googleapis.com/auth/cloud-platform"],
        "shielded_instance_config" : { 
            "enable_secure_boot" : True,
            "enable_vtpm": True,
            "enable_integrity_monitoring": True
            }
    }
}

with airflow.DAG('sample-iceberg-create-tables-update-data',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Create cluster
    create_dataproc_iceberg_cluster = dataproc_operator.DataprocClusterCreateOperator(
        default_args=default_args,
        task_id='create-dataproc-iceberg-cluster',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-iceberg-{{ ts_nodash.lower() }}',
        cluster_config=CLUSTER_CONFIG,
    )

    # Process taxi data into Iceberg table format
    create_iceberg_tables = dataproc_operator.DataProcPySparkOperator(
        default_args=default_args,
        task_id='create-iceberg-tables',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-iceberg-{{ ts_nodash.lower() }}',
        dataproc_jars=[icebergJARFile],
        main=pyspark_code_create_tables,
        arguments=[yellow_source, green_source, icebergWarehouse])

    # Perform data updates to the Iceberg data
    perform_iceberg_data_updates = dataproc_operator.DataProcPySparkOperator(
        default_args=default_args,
        task_id='perform-iceberg-data-updates',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-iceberg-{{ ts_nodash.lower() }}',
        dataproc_jars=[icebergJARFile],
        main=pyspark_code_update_data,
        arguments=[icebergWarehouse])

    # Delete Cloud Dataproc cluster
    delete_dataproc_iceberg_cluster = dataproc_operator.DataprocClusterDeleteOperator(
        default_args=default_args,
        task_id='delete-dataproc-iceberg-cluster',
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-iceberg-{{ ts_nodash.lower() }}',
        # Setting trigger_rule to ALL_DONE causes the cluster to be deleted even if the Dataproc job fails.
        trigger_rule=trigger_rule.TriggerRule.ALL_DONE)

    create_dataproc_iceberg_cluster >> \
        create_iceberg_tables >> \
        perform_iceberg_data_updates >> \
        delete_dataproc_iceberg_cluster

# [END dag]
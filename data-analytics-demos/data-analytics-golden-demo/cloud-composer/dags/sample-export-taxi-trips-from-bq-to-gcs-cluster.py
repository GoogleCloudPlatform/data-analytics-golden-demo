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
# Summary: Runs a Dataproc Cluster to export the taxi_trips table to GCS
#          The spark code (in the dataproc folder: export_taxi_data_from_bq_to_gcs.py) exports the data
#          as parquet and is partitioned by year-month-day-hour-minute.  This generates alot of files!
#          The goal is to place a BigLake table with a feature to show fast performance with lots of small files.
#          Many small files on a data lake is a common performance issue, so we want to show to to address this
#          with BigQuery.
# NOTE:    This can take hours to run!
#          This exports data for several years!
#          To Run: Edit the export_taxi_data_from_bq_to_gcs.py file and change the following:
#                   years = [2021, 2020, 2019] =>  years = [2021]
#                   for data_month in range(1, 13): => for data_month in range(1, 2):
#          The above will export 1 year/month instead of 3 years and 12 months per year

# [START dag]
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow.models.dag import DAG
from airflow.providers.google.cloud.operators.dataproc import (
    DataprocCreateClusterOperator,
    DataprocDeleteClusterOperator,
    DataprocSubmitJobOperator,
)
from airflow.utils.trigger_rule import TriggerRule

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email": None,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 0,
    "retry_delay": timedelta(minutes=5),
    "dagrun_timeout": timedelta(minutes=600),
}

project_id = os.environ.get("ENV_PROJECT_ID")
raw_bucket_name = os.environ.get("ENV_RAW_BUCKET")
processed_bucket_name = f"gs://{os.environ.get('ENV_PROCESSED_BUCKET')}"
pyspark_code = f"gs://{raw_bucket_name}/pyspark-code/export_taxi_data_from_bq_to_gcs.py"
region = os.environ.get("ENV_DATAPROC_REGION")
dataproc_bucket = os.environ.get("ENV_DATAPROC_BUCKET")
dataproc_subnet = os.environ.get("ENV_DATAPROC_SUBNET")
dataproc_service_account = os.environ.get("ENV_DATAPROC_SERVICE_ACCOUNT")
taxi_dataset_id = os.environ.get("ENV_TAXI_DATASET_ID")
jar_file = f"gs://{raw_bucket_name}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar"
CLUSTER_NAME = 'process-taxi-trips-export-{{ ts_nodash.lower() }}'


# https://cloud.google.com/dataproc/docs/reference/rest/v1/ClusterConfig
CLUSTER_CONFIG = {
    "master_config": {
        "num_instances": 1,
        "machine_type_uri": "n1-standard-8",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 30, "num_local_ssds": 2},
    },
    "worker_config": {
        "num_instances": 3,
        "machine_type_uri": "n1-standard-16",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 30, "num_local_ssds": 2},
    },
    "gce_cluster_config": {
        "subnetwork_uri": dataproc_subnet,
        "service_account": dataproc_service_account,
        "internal_ip_only": True,
        "service_account_scopes": ["https://www.googleapis.com/auth/cloud-platform"],
        "shielded_instance_config": {
            "enable_secure_boot": True,
            "enable_vtpm": True,
            "enable_integrity_monitoring": True,
        },
    },
    "temp_bucket": dataproc_bucket,
}

PYSPARK_JOB = {
    "reference": {"project_id": project_id},
    "placement": {"cluster_name": CLUSTER_NAME},
    "pyspark_job": {
        "main_python_file_uri": pyspark_code,
        "args": [project_id, taxi_dataset_id, dataproc_bucket, processed_bucket_name],
        "jar_file_uris": [jar_file],
    },
}


with DAG(
    "sample-export-taxi-trips-from-bq-to-gcs-cluster",
    default_args=default_args,
    start_date=datetime(2021, 1, 1),
    # Not scheduled, trigger only
    schedule=None,
    catchup=False,
) as dag:
    # Create cluster
    create_dataproc_export_cluster = DataprocCreateClusterOperator(
        task_id="create-dataproc-export-cluster",
        project_id=project_id,
        region=region,
        cluster_name=CLUSTER_NAME,
        cluster_config=CLUSTER_CONFIG,
    )

    # Run the Spark code to processes the raw files to a processed folder
    run_dataproc_export_spark = DataprocSubmitJobOperator(
        task_id="task-taxi-trips-export",
        project_id=project_id,
        region=region,
        job=PYSPARK_JOB,
    )

    # Delete Cloud Dataproc cluster
    delete_dataproc_export_cluster = DataprocDeleteClusterOperator(
        task_id="delete-dataproc-export-cluster",
        project_id=project_id,
        region=region,
        cluster_name=CLUSTER_NAME,
        # Setting trigger_rule to ALL_DONE causes the cluster to be deleted
        # even if the Dataproc job fails.
        trigger_rule=TriggerRule.ALL_DONE,
    )

    create_dataproc_export_cluster >> run_dataproc_export_spark >> delete_dataproc_export_cluster

# [END dag]
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
from __future__ import annotations

import os
from datetime import datetime, timedelta

import airflow
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
    "dagrun_timeout": timedelta(minutes=60),
}

project_id = os.environ.get("ENV_PROJECT_ID")
raw_bucket_name = os.environ.get("ENV_RAW_BUCKET")
processed_bucket_name = os.environ.get("ENV_PROCESSED_BUCKET")
pyspark_code = f"gs://{raw_bucket_name}/pyspark-code/convert_taxi_to_parquet.py"
region = os.environ.get("ENV_DATAPROC_REGION")
yellow_source = f"gs://{raw_bucket_name}/raw/taxi-data/yellow/*/*.parquet"
green_source = f"gs://{raw_bucket_name}/raw/taxi-data/green/*/*.parquet"
destination = f"gs://{processed_bucket_name}/processed/taxi-data/"
dataproc_bucket = os.environ.get("ENV_DATAPROC_BUCKET")
dataproc_subnet = os.environ.get("ENV_DATAPROC_SUBNET")
dataproc_service_account = os.environ.get("ENV_DATAPROC_SERVICE_ACCOUNT")


# https://cloud.google.com/dataproc/docs/reference/rest/v1/ClusterConfig
CLUSTER_CONFIG = {
    "master_config": {
        "num_instances": 1,
        "machine_type_uri": "n1-standard-8",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 100},
    },
    "worker_config": {
        "num_instances": 8,
        "machine_type_uri": "n1-standard-8",
        "disk_config": {"boot_disk_type": "pd-ssd", "boot_disk_size_gb": 100},
    },
    "gce_cluster_config": {
        "subnetwork_uri": dataproc_subnet,
        "service_account": dataproc_service_account,
        "service_account_scopes": ["https://www.googleapis.com/auth/cloud-platform"],
        "internal_ip_only": True,
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
    "placement": {"cluster_name": 'process-taxi-data-{{ ts_nodash.lower() }}'},
    "pyspark_job": {
        "main_python_file_uri": pyspark_code,
        "args": [yellow_source, green_source, destination],
    },
}


with DAG(
    "step-02-taxi-data-processing",
    default_args=default_args,
    start_date=datetime(2021, 1, 1),
    # Not scheduled, trigger only
    schedule_interval=None,
    catchup=False,
) as dag:
    # Create cluster
    create_dataproc_cluster = DataprocCreateClusterOperator(
        task_id="create-dataproc-cluster",
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-{{ ts_nodash.lower() }}',
        cluster_config=CLUSTER_CONFIG,
    )

    # Run the Spark code to processes the raw CSVs to a processed folder
    run_dataproc_spark = DataprocSubmitJobOperator(
        task_id="task-taxi-data",
        project_id=project_id,
        region=region,
        job=PYSPARK_JOB,
    )

    # Delete Cloud Dataproc cluster
    delete_dataproc_cluster = DataprocDeleteClusterOperator(
        task_id="delete-dataproc-cluster",
        project_id=project_id,
        region=region,
        cluster_name='process-taxi-data-{{ ts_nodash.lower() }}',
        # Setting trigger_rule to ALL_DONE causes the cluster to be deleted
        # even if the Dataproc job fails.
        trigger_rule=TriggerRule.ALL_DONE,
    )

    create_dataproc_cluster >> run_dataproc_spark >> delete_dataproc_cluster

# [END dag]
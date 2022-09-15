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
# Summary: Runs a Dataproc Serverless to export the taxi_trips table to GCS
#          The spark code (in the dataproc folder: export_taxi_data_from_bq_to_gcs.py) exports the data
#          as parquet and is partitioned by year-month-day-hour-minute.  This generates alot of files!
#          The goal is to place a BigLake table with a feature to show fast performance with lots of small files.
#          Many small files on a data lake is a common performance issue, so we want to show to to address this
#          with BigQuery.
# NOTE:    This can take hours to run!
#          This is not practical to run due to the large amount of data.  Please run the sample-export-taxi-trips-from-bq-to-gcs-cluster DAG
#          This is provided as a Spark Serveless example!

# [START dag]
import os
import logging
import airflow
from datetime import datetime, timedelta
from airflow import models
from airflow.providers.google.cloud.operators.dataproc import (
    DataprocCreateBatchOperator, DataprocDeleteBatchOperator, DataprocGetBatchOperator, DataprocListBatchesOperator

)

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': None,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
    'dagrun_timeout' : timedelta(minutes=600),
}

project_id               = os.environ['GCP_PROJECT'] 
# hardcoded (using this region since us-west2 is not available)
region                   = "us-central1" 
raw_bucket_name          = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name    = "gs://" + os.environ['ENV_PROCESSED_BUCKET'] 
pyspark_code             = "gs://" + raw_bucket_name + "/pyspark-code/export_taxi_data_from_bq_to_gcs.py"
jar_file                 = "gs://" + raw_bucket_name + "/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar"
# hardcoded the subnet name
dataproc_subnet          = "bigspark-subnet"
dataproc_service_account = os.environ['ENV_DATAPROC_SERVICE_ACCOUNT'] 
dataproc_bucket          = os.environ['ENV_DATAPROC_BUCKET'] 
bigspark_bucket          = os.environ['ENV_RAW_BUCKET'].replace("raw-","bigspark-")
taxi_dataset_id          = os.environ['ENV_TAXI_DATASET_ID'] 

data_year = "2022"
data_month = "1"

"""
gcloud beta dataproc batches submit pyspark \
    --project="data-analytics-demo-4s42tmb9uw" \
    --region="us-central1" \
    --batch="batch-003"  \
    gs://raw-data-analytics-demo-4s42tmb9uw/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
    --jars gs://raw-data-analytics-demo-4s42tmb9uw/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
    --subnet="bigspark-subnet" \
    --deps-bucket="gs://dataproc-data-analytics-demo-4s42tmb9uw" \
    --service-account="dataproc-service-account@data-analytics-demo-4s42tmb9uw.iam.gserviceaccount.com" \
    -- data-analytics-demo-4s42tmb9uw taxi_dataset bigspark-data-analytics-demo-4s42tmb9uw gs://processed-data-analytics-demo-4s42tmb9uw

"""

# https://cloud.google.com/dataproc-serverless/docs/reference/rpc/google.cloud.dataproc.v1#google.cloud.dataproc.v1.PySparkBatch
# https://cloud.google.com/dataproc-serverless/docs/reference/rpc/google.cloud.dataproc.v1#batch
BATCH_CONFIG = {
    'pyspark_batch':
        {
            'main_python_file_uri': pyspark_code,
            'jar_file_uris': [ jar_file ],
            'args': [project_id, taxi_dataset_id, bigspark_bucket, processed_bucket_name, data_year, data_month ]
        },
    'environment_config':
        {'execution_config':
                {
                    'subnetwork_uri': dataproc_subnet,
                    'service_account' : dataproc_service_account
                    }
            },
    'runtime_config':
        {'properties':
            {
                'spark.app.name': 'DataprocServerlessAirflowDAG'
            }
        }
    }

with airflow.DAG('sample-export-taxi-trips-from-bq-to-gcs-serverless',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Create serverless batch
    # https://airflow.apache.org/docs/apache-airflow-providers-google/stable/operators/cloud/dataproc.html#create-a-batch
    dataproc_serverless = DataprocCreateBatchOperator(
        task_id="dataproc_serverless_export_taxi_trips",
        project_id=project_id,
        region=region,
        batch_id="taxi-trips-export-{{ ds_nodash }}-{{ ts_nodash.lower() }}",
        batch=BATCH_CONFIG
    )

    # {{run_id}} = "Batch ID 'taxi-trips-export-manual__2022-09-13T21:46:52.639478+00:00' must conform to pattern '[a-z0-9][a-z0-9\-]{2,61}[a-z0-9]'"

    dataproc_serverless

# [END dag]
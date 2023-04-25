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
#          This exports data for several years!
#          To Run: Edit the export_taxi_data_from_bq_to_gcs.py file and change the following:
#                   years = [2021, 2020, 2019] =>  years = [2021]
#                   for data_month in range(1, 13): => for data_month in range(1, 2):
#          The above will export 1 year/month instead of 3 years and 12 months per year

# [START dag]
import os
import logging
import airflow
from datetime import datetime, timedelta
from airflow import models
from airflow.providers.google.cloud.operators.dataproc import (DataprocCreateBatchOperator, DataprocDeleteBatchOperator, DataprocGetBatchOperator, DataprocListBatchesOperator)

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

project_id               = os.environ['ENV_PROJECT_ID'] 
region                   = os.environ['ENV_DATAPROC_SERVERLESS_REGION']
raw_bucket_name          = os.environ['ENV_RAW_BUCKET'] 
processed_bucket_name    = "gs://" + os.environ['ENV_PROCESSED_BUCKET'] 
pyspark_code             = "gs://" + raw_bucket_name + "/pyspark-code/rideshare_iceberg_serverless.py"
jar_file                 = "gs://spark-lib/biglake/biglake-catalog-iceberg1.2.0-0.1.0-with-dependencies.jar"

# hardcoded the subnet name
dataproc_subnet          = os.environ['ENV_DATAPROC_SERVERLESS_SUBNET_NAME']
dataproc_service_account = os.environ['ENV_DATAPROC_SERVICE_ACCOUNT'] 
dataproc_bucket          = os.environ['ENV_DATAPROC_BUCKET'] 
taxi_dataset_id          = os.environ['ENV_TAXI_DATASET_ID'] 

iceberg_catalog                = "rideshare_iceberg_catalog"
iceberg_warehouse              = "rideshare_lakehouse_enriched"
bq_rideshare_enriched_dataset  = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_DATASET'] 
bq_rideshare_raw_dataset       = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_DATASET'] 
rideshare_raw_bucket           = os.environ['ENV_RIDESHARE_LAKEHOUSE_RAW_BUCKET'] 
rideshare_enriched_bucket      = os.environ['ENV_RIDESHARE_LAKEHOUSE_ENRICHED_BUCKET'] 

bigquery_region                = os.environ['ENV_BIGQUERY_REGION']

# https://cloud.google.com/dataproc-serverless/docs/reference/rpc/google.cloud.dataproc.v1#google.cloud.dataproc.v1.PySparkBatch
# https://cloud.google.com/dataproc-serverless/docs/reference/rpc/google.cloud.dataproc.v1#batch
BATCH_CONFIG = {
    'pyspark_batch':
        {
            'main_python_file_uri': pyspark_code,
            'jar_file_uris': [ jar_file ],
            'args': [project_id,iceberg_catalog,iceberg_warehouse,bq_rideshare_enriched_dataset,bq_rideshare_raw_dataset,rideshare_raw_bucket,rideshare_enriched_bucket,bigquery_region]
        },
    'environment_config':
        {'execution_config':
                {
                    'subnetwork_uri': dataproc_subnet,
                    'service_account' : dataproc_service_account
                    }
            },
    'runtime_config':
        {
            'version' : '1.0',
            'properties':
                {
                    "spark.sql.catalog.{}.blms_catalog".format(iceberg_catalog) : iceberg_catalog,
                    "spark.sql.catalog.{}.gcp_project".format(iceberg_catalog)  : project_id,
                    "spark.jars.packages" : "org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:0.14.1,org.apache.spark:spark-avro_2.12:3.3.1",
                    "spark.sql.catalog.{}.catalog-impl".format(iceberg_catalog) : "org.apache.iceberg.gcp.biglake.BigLakeCatalog",
                    "spark.sql.catalog.{}.gcp_location".format(iceberg_catalog) : bigquery_region, \
                    "spark.sql.catalog.{}".format(iceberg_catalog)              : "org.apache.iceberg.spark.SparkCatalog",
                    "spark.sql.catalog.{}.warehouse".format(iceberg_catalog)    : "gs://{}/{}".format(rideshare_enriched_bucket,iceberg_catalog)
                }
        }
    }


with airflow.DAG('sample-rideshare-iceberg-serverless',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Create serverless batch
    # https://airflow.apache.org/docs/apache-airflow-providers-google/stable/operators/cloud/dataproc.html#create-a-batch
    rideshare_iceberg_serverless = DataprocCreateBatchOperator(
        task_id="rideshare_iceberg_serverless",
        project_id=project_id,
        region=region,
        batch_id="rideshare-iceberg-serverless-{{ ds_nodash }}-{{ ts_nodash.lower() }}",
        batch=BATCH_CONFIG
    )

    # {{run_id}} = "Batch ID 'taxi-trips-export-manual__2022-09-13T21:46:52.639478+00:00' must conform to pattern '[a-z0-9][a-z0-9\-]{2,61}[a-z0-9]'"

    rideshare_iceberg_serverless

# [END dag]
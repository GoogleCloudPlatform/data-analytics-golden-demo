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
# Summary: Runs a dataplex data quality job against the taxi trips table
#          Polls the job until it completes
#          Reads the data quality results (from BigQuery) and updates the taxi trips in the data catalog assigning a tag template
#          The user can see the data quality results by searching for the taxi trips table in data catalog
#          Reads the data quality results (from BigQuery) and updates the taxi trips [COLUMN Level] in the data catalog assigning a tag template
#          The user can see the data quality results by searching for the taxi trips table in data catalog by clicking on the Schema view
#
# References: 
#   https://github.com/GoogleCloudPlatform/cloud-data-quality
#   https://cloud.google.com/dataplex/docs/check-data-quality
#   https://github.com/GoogleCloudPlatform/cloud-data-quality/blob/main/scripts/dataproc-workflow-composer/clouddq_composer_dataplex_task_job.py

from datetime import datetime, timedelta
import requests
import sys
import os
import logging
import json
import time

import airflow
from airflow.operators import bash_operator
from airflow.utils import trigger_rule
from airflow.operators.python_operator import PythonOperator

from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateEmptyDatasetOperator
from airflow.providers.google.cloud.operators.dataplex import DataplexCreateTaskOperator

from google.cloud import bigquery
from google.protobuf.duration_pb2 import Duration

import google.auth
import google.auth.transport.requests
from google.cloud import datacatalog_v1

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

project_id                            = os.environ['ENV_PROJECT_ID'] 
taxi_dataset_id                       = os.environ['ENV_TAXI_DATASET_ID']
code_bucket_name                      = os.environ['ENV_CODE_BUCKET'] 
yaml_path                             = "gs://" + code_bucket_name + "/dataplex/data-quality/dataplex_data_quality_taxi.yaml"
bigquery_region                       = os.environ['ENV_BIGQUERY_REGION']
taxi_dataset_id                       = os.environ['ENV_TAXI_DATASET_ID']
thelook_dataset_id                    = os.environ['ENV_THELOOK_DATASET_ID']
vpc_subnet_name                       = os.environ['ENV_DATAPROC_SERVERLESS_SUBNET_NAME']
dataplex_region                       = os.environ['ENV_DATAPLEX_REGION'] 
service_account_to_run_dataplex       = "dataproc-service-account@" + project_id + ".iam.gserviceaccount.com"
random_extension                      = os.environ['ENV_RANDOM_EXTENSION']
taxi_dataplex_lake_name               = "taxi-data-lake-" + random_extension
data_quality_dataset_id               = "dataplex_data_quality"
data_quality_table_name               = "data_quality_results"
DATAPLEX_PUBLIC_GCS_BUCKET_NAME       = f"dataplex-clouddq-artifacts-{dataplex_region}"
CLOUDDQ_EXECUTABLE_FILE_PATH          = f"gs://{DATAPLEX_PUBLIC_GCS_BUCKET_NAME}/clouddq-executable.zip"
CLOUDDQ_EXECUTABLE_HASHSUM_FILE_PATH  = f"gs://{DATAPLEX_PUBLIC_GCS_BUCKET_NAME}/clouddq-executable.zip.hashsum" 
FULL_TARGET_TABLE_NAME                = f"{project_id}.{data_quality_dataset_id}.{data_quality_table_name}"  
TRIGGER_SPEC_TYPE                     = "ON_DEMAND"  

spark_python_script_file        = f"gs://{DATAPLEX_PUBLIC_GCS_BUCKET_NAME}/clouddq_pyspark_driver.py"

# NOTE: This is case senstive for some reason
bigquery_region = bigquery_region.upper()

# https://cloud.google.com/dataplex/docs/reference/rpc/google.cloud.dataplex.v1
# https://cloud.google.com/dataplex/docs/reference/rpc/google.cloud.dataplex.v1#google.cloud.dataplex.v1.Task.InfrastructureSpec.VpcNetwork
data_quality_config = {
    "spark": {
        "python_script_file": spark_python_script_file,
        "file_uris": [CLOUDDQ_EXECUTABLE_FILE_PATH,
                      CLOUDDQ_EXECUTABLE_HASHSUM_FILE_PATH,
                      yaml_path
                      ],
        "infrastructure_spec" : {
            "vpc_network" : {
                "sub_network" : vpc_subnet_name
            }
        },                      
    },
    "execution_spec": {
        "service_account": service_account_to_run_dataplex,
        "max_job_execution_lifetime" : Duration(seconds=2*60*60),
        "args": {
            "TASK_ARGS": f"clouddq-executable.zip, \
                 ALL, \
                 {yaml_path}, \
                --gcp_project_id={project_id}, \
                --gcp_region_id={bigquery_region}, \
                --gcp_bq_dataset_id={data_quality_dataset_id}, \
                --target_bigquery_summary_table={FULL_TARGET_TABLE_NAME}"
        }
    },
    "trigger_spec": {
        "type_": TRIGGER_SPEC_TYPE
    },
    "description": "CloudDQ Airflow Task"
}


# Check on the status of the job
# Call the rest API of dataplex and then get the dataproc job and then check the status of the dataproc job
def get_clouddq_task_status(task_id):
    # Wait for job to start
    print ("get_clouddq_task_status STARTED, sleeping for 60 seconds for jobs to start")
    time.sleep(60)

    # Get auth (default service account running composer worker node)
    creds, project = google.auth.default()
    auth_req = google.auth.transport.requests.Request() # required to acess access token
    creds.refresh(auth_req)
    access_token=creds.token
    auth_header = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + access_token
    }

    uri = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/lakes/{taxi_dataplex_lake_name}/tasks/{task_id}/jobs"
    serviceJob = ""

    # Get the jobs
    # Get the status of each job (or the first for the demo)
    try:
        response = requests.get(uri, headers=auth_header)
        print("get_clouddq_task_status response status code: ", response.status_code)
        print("get_clouddq_task_status response status text: ", response.text)
        response_json = json.loads(response.text)
        if response.status_code == 200:
            if ("jobs" in response_json and len(response_json["jobs"]) > 0):
                serviceJob = response_json["jobs"][0]["serviceJob"]
                print("get_clouddq_task_status serviceJob: ", serviceJob)
            else:
                errorMessage = "Could not find serviceJob in REST API response"
                raise Exception(errorMessage)
        else:
            errorMessage = "REAT API (serviceJob) response returned response.status_code: " + str(response.status_code)
            raise Exception(errorMessage)
    except requests.exceptions.RequestException as err:
        print(err)
        raise err

    dataproc_job_id = serviceJob.replace(f"projects/{project_id}/locations/{dataplex_region}/batches/","")
    print ("dataproc_job_id: ", dataproc_job_id)
    serviceJob_uri  = f"https://dataproc.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/batches/{dataproc_job_id}"
    print ("serviceJob_uri:", serviceJob_uri)

    # Run for for so many interations
    counter  = 1
    while (counter < 60):    
        try:
            response = requests.get(serviceJob_uri, headers=auth_header)
            print("get_clouddq_task_status response status code: ", response.status_code)
            print("get_clouddq_task_status response status text: ", response.text)
            response_json = json.loads(response.text)
            if response.status_code == 200:
                if ("state" in response_json):
                    task_status = response_json["state"]
                    print("get_clouddq_task_status task_status: ", task_status)
                    if (task_status == 'SUCCEEDED'):
                        return True
                    
                    if (task_status == 'FAILED' 
                        or task_status == 'CANCELLED'
                        or task_status == 'ABORTED'):
                        errorMessage = "Task failed with status of: " + task_status
                        raise Exception(errorMessage)

                    # Assuming state is RUNNING or PENDING
                    time.sleep(30)
                else:
                    errorMessage = "Could not find Job State in REST API response"
                    raise Exception(errorMessage)
            else:
                errorMessage = "REAT API response returned response.status_code: " + str(response.status_code)
                raise Exception(errorMessage)
        except requests.exceptions.RequestException as err:
            print(err)
            raise err
        counter = counter + 1

    errorMessage = "The process (get_clouddq_task_status) run for too long.  Increase the number of iterations."
    raise Exception(errorMessage)


# Run a SQL query to get the consolidated table results
# Attach a tag template in data catalog at the table level for taxi trips
# NOTE: This will overrite the template over and over (not add new one)
def attach_tag_template_to_table():
    client = bigquery.Client()
    query_job = client.query(f"CALL `{project_id}.{taxi_dataset_id}.sp_demo_data_quality_table`();")
    results = query_job.result()  # Waits for job to complete.

    for row in results:
      # print("{} : {} views".format(row.url, row.view_count))
      datacatalog_client = datacatalog_v1.DataCatalogClient()

      resource_name = (
          f"//bigquery.googleapis.com/projects/{project_id}"
          f"/datasets/{taxi_dataset_id}/tables/taxi_trips"
      )
      table_entry = datacatalog_client.lookup_entry(
          request={"linked_resource": resource_name}
      )

      # Attach a Tag to the table.
      tag = datacatalog_v1.types.Tag()

      tag.template = f"projects/{project_id}/locations/{dataplex_region}/tagTemplates/table_dq_tag_template"
      tag.name = "table_dq_tag_template"

      tag.fields["table_name"] = datacatalog_v1.types.TagField()
      tag.fields["table_name"].string_value = "taxi_trips"

      tag.fields["record_count"] = datacatalog_v1.types.TagField()
      tag.fields["record_count"].double_value = row.record_count

      tag.fields["latest_execution_ts"] = datacatalog_v1.types.TagField()
      tag.fields["latest_execution_ts"].timestamp_value = row.latest_execution_ts

      tag.fields["columns_validated"] = datacatalog_v1.types.TagField()
      tag.fields["columns_validated"].double_value = row.columns_validated

      tag.fields["columns_count"] = datacatalog_v1.types.TagField()
      tag.fields["columns_count"].double_value = row.columns_count

      tag.fields["success_pct"] = datacatalog_v1.types.TagField()
      tag.fields["success_pct"].double_value = row.success_percentage

      tag.fields["failed_pct"] = datacatalog_v1.types.TagField()
      tag.fields["failed_pct"].double_value = row.failed_percentage

      tag.fields["invocation_id"] = datacatalog_v1.types.TagField()
      tag.fields["invocation_id"].string_value = row.invocation_id

      # Get the existing tempates (we need to remove the existing one if it exists (we cannot have dups))
      print ("attach_tag_template_to_table table_entry.name: ", table_entry.name)
      page_result = datacatalog_client.list_tags(parent=table_entry.name)

      existing_name = ""
      # template: "projects/data-analytics-demo-ra5migwp3l/locations/REPLACE-REGION/tagTemplates/table_dq_tag_template"
      # Handle the response
      for response in page_result:
        print("response: ", response)
        if (response.template == tag.template):
            existing_name = response.name
            break

      # This technically will rermove the same template if we are in a loop
      # We should ideally have more than 1 template for different reasons since a specific template cannot be assigned more than once to a table,
      # but you can assign different templates.
      if (existing_name != ""):
        print(f"Delete tag: {existing_name}")
        datacatalog_client.delete_tag(name=existing_name)

      # https://cloud.google.com/python/docs/reference/datacatalog/latest/google.cloud.datacatalog_v1.services.data_catalog.DataCatalogClient#google_cloud_datacatalog_v1_services_data_catalog_DataCatalogClient_create_tag
      tag = datacatalog_client.create_tag(parent=table_entry.name, tag=tag)
      print(f"Created tag: {tag.name}")


# Run a SQL query to get the column result
# Attach a tag template in data catalog at the column level for taxi trips
# NOTE: This will overrite the template over and over (not add new one)
def attach_tag_template_to_columns():
    client = bigquery.Client()
    # This should just return a single column once (this code is not meant to handle the same column twice)
    # If you have the same column twice the code will overwrite the first results.  You should aggregate the
    # results together or apply different tag templates per result.
    query_job = client.query(f"CALL `{project_id}.{taxi_dataset_id}.sp_demo_data_quality_columns`();")
    results = query_job.result()  # Waits for job to complete.

    for row in results:
      datacatalog_client = datacatalog_v1.DataCatalogClient()

      resource_name = (
          f"//bigquery.googleapis.com/projects/{project_id}"
          f"/datasets/{taxi_dataset_id}/tables/taxi_trips"
      )
      table_entry = datacatalog_client.lookup_entry(
          request={"linked_resource": resource_name}
      )

      # Attach a Tag to the table.
      tag = datacatalog_v1.types.Tag()

      tag.template = f"projects/{project_id}/locations/{dataplex_region}/tagTemplates/column_dq_tag_template"
      tag.name = "column_dq_tag_template"
      tag.column = row.column_id


      tag.fields["table_name"] = datacatalog_v1.types.TagField()
      tag.fields["table_name"].string_value = "taxi_trips"

      tag.fields["invocation_id"] = datacatalog_v1.types.TagField()
      tag.fields["invocation_id"].string_value = row.invocation_id

      tag.fields["execution_ts"] = datacatalog_v1.types.TagField()
      tag.fields["execution_ts"].timestamp_value = row.execution_ts

      tag.fields["column_id"] = datacatalog_v1.types.TagField()
      tag.fields["column_id"].string_value = row.column_id

      tag.fields["rule_binding_id"] = datacatalog_v1.types.TagField()
      tag.fields["rule_binding_id"].string_value = row.rule_binding_id

      tag.fields["rule_id"] = datacatalog_v1.types.TagField()
      tag.fields["rule_id"].string_value = row.rule_id

      tag.fields["dimension"] = datacatalog_v1.types.TagField()
      tag.fields["dimension"].string_value = row.dimension

      tag.fields["rows_validated"] = datacatalog_v1.types.TagField()
      tag.fields["rows_validated"].double_value = row.rows_validated

      tag.fields["success_count"] = datacatalog_v1.types.TagField()
      tag.fields["success_count"].double_value = row.success_count

      tag.fields["success_pct"] = datacatalog_v1.types.TagField()
      tag.fields["success_pct"].double_value = row.success_percentage

      tag.fields["failed_count"] = datacatalog_v1.types.TagField()
      tag.fields["failed_count"].double_value = row.failed_count

      tag.fields["failed_pct"] = datacatalog_v1.types.TagField()
      tag.fields["failed_pct"].double_value = row.failed_percentage

      tag.fields["null_count"] = datacatalog_v1.types.TagField()
      tag.fields["null_count"].double_value = row.null_count

      tag.fields["null_pct"] = datacatalog_v1.types.TagField()
      tag.fields["null_pct"].double_value = row.null_percentage

      # Get the existing tempates (we need to remove the existing one if it exists (we cannot have dups))
      print ("attach_tag_template_to_columns table_entry.name: ", table_entry.name)
      page_result = datacatalog_client.list_tags(parent=table_entry.name)

      existing_name = ""
      # template: "projects/data-analytics-demo-ra5migwp3l/locations/REPLACE-REGION/tagTemplates/column_dq_tag_template"
      """ Sample Response
      name: "projects/data-analytics-demo-ra5migwp3l/locations/us/entryGroups/@bigquery/entries/cHJvamVjdHMvZGF0YS1hbmFseXRpY3MtZGVtby1yYTVtaWd3cDNsL2RhdGFzZXRzL3RheGlfZGF0YXNldC90YWJsZXMvdGF4aV90cmlwcw/tags/CVg1OS7dOJhY"
      template: "projects/data-analytics-demo-ra5migwp3l/locations/REPLACE-REGION/tagTemplates/column_dq_tag_template"
      fields {
        key: "column_id"
        value {
          display_name: "Column Name"
          string_value: "DOLocationID"
        }
      }
      fields {
        key: "dimension"
        value {
          display_name: "Dimension"
          string_value: "INTEGRITY"
        }
      }      
      """
      # Handle the response
      for response in page_result:
        print("response: ", response)
        # print("response.fields[column_id]: ", response.fields["column_id"])
        if (response.template  == tag.template and 
            "column_id" in response.fields and
            response.fields["column_id"].string_value == tag.column):
            existing_name = response.name
            print(f"existing_name: {existing_name}")
            break

      # This technically will rermove the same template if we are in a loop
      # We should ideally have more than 1 template for different reasons since a specific template cannot be assigned more than once to a column,
      # but you can assign different templates.
      # One odd thing is that if you call create_tag and the template exists, it will overwrite. It errors when doing this for a table though.
      if (existing_name != ""):
        print(f"Delete tag: {existing_name}")
        datacatalog_client.delete_tag(name=existing_name)

      # https://cloud.google.com/python/docs/reference/datacatalog/latest/google.cloud.datacatalog_v1.services.data_catalog.DataCatalogClient#google_cloud_datacatalog_v1_services_data_catalog_DataCatalogClient_create_tag
      tag = datacatalog_client.create_tag(parent=table_entry.name, tag=tag)
      print(f"Created tag: {tag.name} on {tag.column}")  



with airflow.DAG('sample-dataplex-run-data-quality',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Add the Composer "Data" directory which will hold the SQL/Bash scripts for deployment
                 template_searchpath=['/home/airflow/gcs/data'],
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # NOTE: The service account of the Composer worker node must have access to run these commands

    # Create the dataset for holding dataplex data quality results
    # NOTE: This has to be in the same region as the BigQuery dataset we are performing our data quality checks
    create_data_quality_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="create_dataset", 
        location=bigquery_region,
        project_id=project_id,
        dataset_id=data_quality_dataset_id,
        exists_ok=True
    )

    # https://airflow.apache.org/docs/apache-airflow-providers-google/stable/_api/airflow/providers/google/cloud/operators/dataplex/index.html#airflow.providers.google.cloud.operators.dataplex.DataplexCreateTaskOperator
    create_dataplex_task = DataplexCreateTaskOperator(
        project_id=project_id,
        region=dataplex_region,
        lake_id=taxi_dataplex_lake_name,
        body=data_quality_config,
        dataplex_task_id="cloud-dq-{{ ts_nodash.lower() }}",
        task_id="create_dataplex_task",
    )

    get_clouddq_task_status = PythonOperator(
        task_id='get_clouddq_task_status',
        python_callable= get_clouddq_task_status,
        op_kwargs = { "task_id" : "cloud-dq-{{ ts_nodash.lower() }}" },
        execution_timeout=timedelta(minutes=300),
        dag=dag,
        ) 

    attach_tag_template_to_table = PythonOperator(
        task_id='attach_tag_template_to_table',
        python_callable= attach_tag_template_to_table,
        execution_timeout=timedelta(minutes=5),
        dag=dag,
        ) 

    attach_tag_template_to_columns = PythonOperator(
        task_id='attach_tag_template_to_columns',
        python_callable= attach_tag_template_to_columns,
        execution_timeout=timedelta(minutes=5),
        dag=dag,
        ) 

    create_data_quality_dataset >> \
      create_dataplex_task >> get_clouddq_task_status >> \
      attach_tag_template_to_table >> attach_tag_template_to_columns


"""
Sample dataplex output from REST API call
{
  "jobs": [
    {
      "name": "projects/781192597639/locations/REPLACE-REGION/lakes/taxi-data-lake-r8immkwx8o/tasks/cloud-dq-20221031t182959/jobs/de934178-cde0-489d-b16f-ac6c1e919431",
      "uid": "de934178-cde0-489d-b16f-ac6c1e919431",
      "startTime": "2022-10-31T18:30:40.959187Z",
      "service": "DATAPROC",
      "serviceJob": "projects/paternostro-9033-2022102613235/locations/REPLACE-REGION/batches/de934178-cde0-489d-b16f-ac6c1e919431-0"
    }
  ],
  "nextPageToken": "Cg5iDAiyqICbBhCQsqf7Ag"
}
"""

"""
Sample dataproc output from REST API call

   curl \
  'https://dataproc.googleapis.com/v1/projects/paternostro-9033-2022102613235/locations/REPLACE-REGION/batches/de934178-cde0-489d-b16f-ac6c1e919431-0?key=[YOUR_API_KEY]' \
  --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
  --header 'Accept: application/json' \
  --compressed 

{
  "name": "projects/paternostro-9033-2022102613235/locations/REPLACE-REGION/batches/de934178-cde0-489d-b16f-ac6c1e919431-0",
  "uuid": "af6fd3a5-9ed3-4459-a13b-28d254732704",
  "createTime": "2022-10-31T18:30:40.959187Z",
  "pysparkBatch": {
    "mainPythonFileUri": "gs://dataplex-clouddq-artifacts-REPLACE-REGION/clouddq_pyspark_driver.py",
    "args": [
      "clouddq-executable.zip",
      "ALL",
      "gs://processed-paternostro-9033-2022102613235-r8immkwx8o/dataplex/dataplex_data_quality_taxi.yaml",
      "--gcp_project_id=paternostro-9033-2022102613235",
      "--gcp_region_id=US",
      "--gcp_bq_dataset_id=dataplex_data_quality",
      "--target_bigquery_summary_table=paternostro-9033-2022102613235.dataplex_data_quality.data_quality_results"
    ],
    "fileUris": [
      "gs://dataplex-clouddq-artifacts-REPLACE-REGION/clouddq-executable.zip",
      "gs://dataplex-clouddq-artifacts-REPLACE-REGION/clouddq-executable.zip.hashsum",
      "gs://processed-paternostro-9033-2022102613235-r8immkwx8o/dataplex/dataplex_data_quality_taxi.yaml"
    ]
  },
  "runtimeInfo": {
    "outputUri": "gs://dataproc-staging-REPLACE-REGION-781192597639-yjb84s0j/google-cloud-dataproc-metainfo/81e34cf5-9c71-41cc-98dd-751e70a0e1e5/jobs/srvls-batch-af6fd3a5-9ed3-4459-a13b-28d254732704/driveroutput",
    "approximateUsage": {
      "milliDcuSeconds": "3608000",
      "shuffleStorageGbSeconds": "360800"
    }
  },
  "state": "SUCCEEDED",
  "stateTime": "2022-10-31T18:36:46.829934Z",
  "creator": "service-781192597639@gcp-sa-dataplex.iam.gserviceaccount.com",
  "labels": {
    "goog-dataplex-task": "cloud-dq-20221031t182959",
    "goog-dataplex-task-job": "de934178-cde0-489d-b16f-ac6c1e919431",
    "goog-dataplex-workload": "task",
    "goog-dataplex-project": "paternostro-9033-2022102613235",
    "goog-dataplex-location": "REPLACE-REGION",
    "goog-dataplex-lake": "taxi-data-lake-r8immkwx8o"
  },
  "runtimeConfig": {
    "version": "1.0",
    "properties": {
      "spark:spark.executor.instances": "2",
      "spark:spark.driver.cores": "4",
      "spark:spark.executor.cores": "4",
      "spark:spark.dynamicAllocation.executorAllocationRatio": "0.3",
      "spark:spark.app.name": "projects/paternostro-9033-2022102613235/locations/REPLACE-REGION/batches/de934178-cde0-489d-b16f-ac6c1e919431-0"
    }
  },
  "environmentConfig": {
    "executionConfig": {
      "serviceAccount": "dataproc-service-account@paternostro-9033-2022102613235.iam.gserviceaccount.com",
      "subnetworkUri": "dataproc-serverless-subnet"
    },
    "peripheralsConfig": {
      "sparkHistoryServerConfig": {}
    }
  },
  "operation": "projects/paternostro-9033-2022102613235/regions/REPLACE-REGION/operations/d209b731-7cdd-3db2-ba59-10c95ede9e75",
  "stateHistory": [
    {
      "state": "PENDING",
      "stateStartTime": "2022-10-31T18:30:40.959187Z"
    },
    {
      "state": "RUNNING",
      "stateStartTime": "2022-10-31T18:31:41.245940Z"
    }
  ]
}
"""
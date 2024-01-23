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
# Summary: Download 2019, 2020, 2021 taxi data for NYC and upload to Google Cloud Storage

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
#from airflow.contrib.operators import bigquery_operator
from airflow.operators.python_operator import PythonOperator


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
raw_bucket_name       = os.environ['ENV_RAW_BUCKET'] 


# Download Taxi data from the internet
def DownloadFile(url):
    print ("Begin: DownloadFile")
    print ("url: ", url)
    r = requests.get(url, allow_redirects=True)
    fileName = url[url.rindex('/')+1:]
    print ("fileName: ", fileName)
    if r.status_code == requests.codes.ok:
        open(fileName, 'wb').write(r.content)
    else:
        raise ValueError("Could not download file: ", fileName)        
    print ("End: DownloadFile")
    return fileName


# https://cloud.google.com/storage/docs/uploading-objects#prereq-code-samples
def upload_blob(project, raw_bucket_name, source_file_name, destination_blob_name):
    """Uploads a file to the bucket."""
    # The ID of your GCS bucket
    # project = your GCP projec id
    # raw_bucket_name = "your-bucket-name" 
    # The path to your file to upload
    # source_file_name = "local/path/to/file"
    # The ID of your GCS object
    # destination_blob_name = "storage-object-name"

    print ("Begin: upload_blob")
    print ("project: ", project)
    print ("raw_bucket_name: ", raw_bucket_name)
    print ("source_file_name: ", source_file_name)
    print ("destination_blob_name: ", destination_blob_name)

    storage_client = storage.Client(project=project)
    bucket = storage_client.bucket(raw_bucket_name)
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_filename(filename=source_file_name)

    print("File {} uploaded to {}.".format(source_file_name, destination_blob_name))
    print("Begin: upload_blob")



# python3 download-taxi-data.py "big-query-demo-09" "big-query-demo-09" "yellow" "2021" "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2021-01.parquet"
def download_and_upload_to_gcs(project, raw_bucket_name, color, year, url, max_month):
    print ("Begin: download_and_upload_to_gcs")
    for month_index in range(max_month):
        downloadURL = url.replace("{COLOR}",color).replace("{YEAR}",year).replace("{MONTH}",str.format("%02d" % (month_index+1,)))
        print("downloadURL:", downloadURL)    
        try:
            source_file_name = DownloadFile(downloadURL)
            destination_blob_name = "raw/taxi-data/" + color + "/" + year + "/" + source_file_name
            upload_blob(project, raw_bucket_name, source_file_name, destination_blob_name)
            os.remove(source_file_name)
        except Exception as e: 
            print(e)
            print("Skipping file: ", downloadURL)
    print ("End: download_and_upload_to_gcs")


with airflow.DAG('step-01-taxi-data-download',
                 default_args=default_args,
                 start_date=datetime(2021, 1, 1),
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    download_yellow_2023 = PythonOperator(
        task_id='download_yellow_2023',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "yellow", 
                        "year" : "2023", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 9
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_green_2023 = PythonOperator(
        task_id='download_green_2023',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "green", 
                        "year" : "2023", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 9
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_yellow_2022 = PythonOperator(
        task_id='download_yellow_2022',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "yellow", 
                        "year" : "2022", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_green_2022 = PythonOperator(
        task_id='download_green_2022',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "green", 
                        "year" : "2022", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_yellow_2021 = PythonOperator(
        task_id='download_yellow_2021',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "yellow", 
                        "year" : "2021", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_green_2021 = PythonOperator(
        task_id='download_green_2021',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "green", 
                        "year" : "2021", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_yellow_2020 = PythonOperator(
        task_id='download_yellow_2020',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "yellow", 
                        "year" : "2020", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_green_2020 = PythonOperator(
        task_id='download_green_2020',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "green", 
                        "year" : "2020", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_yellow_2019 = PythonOperator(
        task_id='download_yellow_2019',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "yellow", 
                        "year" : "2019", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    download_green_2019 = PythonOperator(
        task_id='download_green_2019',
        python_callable= download_and_upload_to_gcs,
        op_kwargs = { "project" : project_id, 
                        "raw_bucket_name" : raw_bucket_name, 
                        "color" : "green", 
                        "year" : "2019", 
                        "url" : "https://d37ci6vzurychx.cloudfront.net/trip-data/{COLOR}_tripdata_{YEAR}-{MONTH}.parquet",
                        "max_month" : 12
                         },
        execution_timeout=timedelta(minutes=30),
        dag=dag,
        )

    # Do not do in parallel since the worker node will run out of disk space
    # If you had more workers then yes, run in parallel
    download_green_2023 >> download_yellow_2023 >> \
        download_green_2022 >> download_yellow_2022 >> \
        download_green_2021 >> download_yellow_2021 >> \
        download_green_2020 >> download_yellow_2020 >> \
        download_green_2019 >> download_yellow_2019

# [END dag]
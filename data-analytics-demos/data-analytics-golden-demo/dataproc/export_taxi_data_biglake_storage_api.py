#!/usr/bin/env python
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
# Summary: Read the BigQuery "taxi_dataset.taxi_trips" table and exports to parquet format
#          This uses dataproc serverless spark
#          The data is exported partitioned by each minute (inefficient on purpose)
#          The goal is to generate a lot of small files (antipattern) to demo BQ performance on small files

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, dayofmonth, hour, minute
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys


def ExportTaxiData(project_id, taxi_dataset_id, temporaryGcsBucket, destination):
    spark = SparkSession \
        .builder \
        .appName("export_taxi_data_biglake_storage_api") \
        .getOrCreate()

    # Use the Cloud Storage bucket for temporary BigQuery export data used by the connector.
    bucket = "[bucket]"
    spark.conf.set('temporaryGcsBucket', temporaryGcsBucket)
 
    # SQL STATEMENT

    # Sample Code: https://cloud.google.com/dataproc/docs/tutorials/bigquery-connector-spark-example#pyspark
    # To use SQL to BQ
    spark.conf.set("viewsEnabled","true")
    spark.conf.set("materializationProject",project_id)
    spark.conf.set("materializationDataset",taxi_dataset_id)
    print ("BEGIN: Querying Table (SQL STATEMENT)")
    sql = "SELECT * " + \
            "FROM `" + project_id + "." + taxi_dataset_id + ".biglake_green_trips` " + \
           "WHERE PULocationID = 168;"
    print ("SQL: ", sql)
    df_sql = spark.read.format("bigquery").option("query", sql).load()
    print ("END: Querying Table (SQL STATEMENT)")

    print ("BEGIN: Writing Data to GCS (SQL STATEMENT)")
    outputPath = destination + "/processed/df_sql/"
    df_sql \
        .write \
        .mode("overwrite") \
        .parquet(outputPath)
    print ("END: Writing Data to GCS (SQL STATEMENT)")

    # Storage API
    # Returns too much data to process with our limited demo core CPU quota
    # Load data from BigQuery taxi_trips table
    print ("BEGIN: Querying Table TABLE LOAD)")
    df_table = spark.read.format('bigquery') \
        .option('table', project_id + ':' + taxi_dataset_id + '.biglake_green_trips') \
        .load()  
    print ("END: Querying Table (TABLE LOAD)")

    # Write as Parquet
    print ("BEGIN: Writing Data to GCS (TABLE LOAD)")
    outputPath = destination + "/processed/df_table/"
    df_table \
        .write \
        .mode("overwrite") \
        .parquet(outputPath)
    print ("END: Writing Data to GCS (STORAGE API)")
                
    spark.stop()


# Main entry point
if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: export_taxi_data_biglake_storage_api project_id taxi_dataset_id temporaryGcsBucket destination")
        sys.exit(-1)

    project_id         = sys.argv[1]
    taxi_dataset_id    = sys.argv[2]
    temporaryGcsBucket = sys.argv[3]
    destination        = sys.argv[4]

    print ("project_id: ", project_id)
    print ("taxi_dataset_id: ", taxi_dataset_id)
    print ("temporaryGcsBucket: ", temporaryGcsBucket)
    print ("destination: ", destination)

    print ("BEGIN: Main")
    ExportTaxiData(project_id, taxi_dataset_id, temporaryGcsBucket, destination)
    print ("END: Main")



# Sample run via command line using Dataproc Serverless
# You must delete a lot of data from the taxi_trips table in order to test this.
# The amount of files can overwhelm most Spark clusters
"""
project_string="ag66cqmpvd"
project="paternostro-477-20221014175629"

serviceAccount="dataproc-service-account@${project}.iam.gserviceaccount.com"
rawBucket="raw-${project}-${project_string}"
processedBucket="processed-${project}-${project_string}"

gsutil cp ./dataproc/export_taxi_data_biglake_storage_api.py gs://${rawBucket}/pyspark-code

batch=`date +%Y-%m-%d-%H-%M-%S`
echo "batch: ${batch}"

gcloud beta dataproc batches submit pyspark \
    --project="${project}" \
    --region="REPLACE-REGION" \
    --batch="${batch}"  \
    gs://${rawBucket}/pyspark-code/export_taxi_data_biglake_storage_api.py \
    --jars gs://${rawBucket}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
    --subnet="dataproc-serverless-subnet" \
    --deps-bucket="gs://${project}-${project_string}" \
    --service-account="${serviceAccount}" \
    -- ${project} taxi_dataset bigspark-${project}-${project_string} gs://${processedBucket}

# to cancel
gcloud dataproc batches cancel ${batch} --project ${project} --region REPLACE-REGION

"""
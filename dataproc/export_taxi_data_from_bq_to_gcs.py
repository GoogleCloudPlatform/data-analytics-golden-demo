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
        .appName("export_taxi_data_from_bq_to_gcs") \
        .getOrCreate()

    # Use the Cloud Storage bucket for temporary BigQuery export data used by the connector.
    bucket = "[bucket]"
    spark.conf.set('temporaryGcsBucket', temporaryGcsBucket)
 
    # Sample Code: https://cloud.google.com/dataproc/docs/tutorials/bigquery-connector-spark-example#pyspark
    # To use SQL to BQ
    """
    spark.conf.set("viewsEnabled","true")
    spark.conf.set("materializationProject",project_id)
    spark.conf.set("materializationDataset",taxi_dataset_id)
    print ("BEGIN: Querying Table")
    sql = "SELECT * " + \
            "FROM `" + project_id + "." + taxi_dataset_id + ".taxi_trips` " 
    #            + \
    #      "WHERE EXTRACT(YEAR  FROM Pickup_DateTime) = " + str(data_year) + " " + \
    #        "AND EXTRACT(MONTH FROM Pickup_DateTime) = " + str(data_month) + ";"
    print ("SQL: ", sql)
    df_taxi_trips = spark.read.format("bigquery").option("query", sql).load()
    print ("END: Querying Table")
    """

 
    # Returns too much data to process with our limited demo core CPU quota
    # Load data from BigQuery taxi_trips table
    print ("BEGIN: Querying Table")
    df_taxi_trips = spark.read.format('bigquery') \
        .option('table', project_id + ':' + taxi_dataset_id + '.taxi_trips') \
        .load()
    print ("END: Querying Table")

 
    print ("BEGIN: Adding partition columns to dataframe")
    df_taxi_trips_partitioned = df_taxi_trips \
        .withColumn("year",   year       (col("Pickup_DateTime"))) \
        .withColumn("month",  month      (col("Pickup_DateTime"))) \
        .withColumn("day",    dayofmonth (col("Pickup_DateTime"))) \
        .withColumn("hour",   hour       (col("Pickup_DateTime"))) \
        .withColumn("minute", minute     (col("Pickup_DateTime"))) 
    print ("END: Adding partition columns to dataframe")

    # Write as Parquet
    print ("BEGIN: Writing Data to GCS")
    outputPath = destination + "/processed/taxi-trips-query-acceleration/"
    df_taxi_trips_partitioned \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month","day","hour","minute") \
        .parquet(outputPath)
    print ("END: Writing Data to GCS")
        
    spark.stop()


# Main entry point
if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: export_taxi_data_from_bq_to_gcs project_id taxi_dataset_id temporaryGcsBucket destination")
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



# Sample run using static Cluster 
"""
project="data-analytics-demo-4hrpc5l4yg"
dataproceTempBucketName="dataproc-data-analytics-demo-4hrpc5l4yg"

serviceAccount="dataproc-service-account@${project}.iam.gserviceaccount.com"
rawBucket="raw-${project}"
processedBucket="processed-${project}"

gcloud dataproc clusters create dataproc-cluster \
    --bucket "${dataproceTempBucketName}" \
    --region us-west2 \
    --subnet dataproc-subnet \
    --zone us-west2-c \
    --master-machine-type n1-standard-8 \
    --master-boot-disk-size 500 \
    --num-workers 3 \
    --service-account="${serviceAccount}" \
    --worker-machine-type n1-standard-16 \
    --worker-boot-disk-size 500 \
    --image-version 2.0-debian10 \
    --num-worker-local-ssds=4 \
    --project "${project}"

gsutil cp ./dataproc/export_taxi_data_from_bq_to_gcs.py gs://${rawBucket}/pyspark-code

# Write to bucket (regional)
gcloud dataproc jobs submit pyspark  \
   --cluster "dataproc-cluster" \
   --region="us-west2" \
   --project="${project}" \
   --jars gs://${rawBucket}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
   gs://${rawBucket}/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
   -- ${project} taxi_dataset ${dataproceTempBucketName} /tmp/taxi-export

# Write to local HDFS "/tmp/taxi-export" (you have to SSH to the machine and then distcp the files to a bucket)
# To SSH you need a firewall rule to open traffic
gcloud dataproc jobs submit pyspark  \
   --cluster "dataproc-cluster" \
   --region="us-west2" \
   --project="${project}" \
   --jars gs://${rawBucket}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
   gs://${rawBucket}/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
   -- ${project} taxi_dataset ${dataproceTempBucketName} /tmp/taxi-export

hdfs dfs -cp -f /tmp/taxi-export/processed/taxi-trips-query-acceleration gs://processed-data-analytics-demo-4hrpc5l4yg/taxi-export/processed/taxi-trips-query-acceleration
hadoop distcp /tmp/taxi-export/processed/taxi-trips-query-acceleration gs://processed-data-analytics-demo-4hrpc5l4yg/taxi-export/processed/taxi-trips-query-acceleration

# Delete the cluster
gcloud dataproc clusters delete dataproc-cluster --region us-west2 --project="${project}"
"""



# Sample run via command line using Dataproc Serverless
# You must delete a lot of data from the taxi_trips table in order to test this.
# The amount of files can overwhelm most Spark clusters
"""
REPLACE "4s42tmb9uw" with your unique Id

gsutil cp ./dataproc/export_taxi_data_from_bq_to_gcs.py gs://raw-data-analytics-demo-4s42tmb9uw/pyspark-code

gcloud beta dataproc batches submit pyspark \
    --project="data-analytics-demo-4s42tmb9uw" \
    --region="us-central1" \
    --batch="batch-015"  \
    gs://raw-data-analytics-demo-4s42tmb9uw/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
    --jars gs://raw-data-analytics-demo-4s42tmb9uw/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
    --subnet="bigspark-subnet" \
    --deps-bucket="gs://dataproc-data-analytics-demo-4s42tmb9uw" \
    --service-account="dataproc-service-account@data-analytics-demo-4s42tmb9uw.iam.gserviceaccount.com" \
    -- data-analytics-demo-4s42tmb9uw taxi_dataset bigspark-data-analytics-demo-4s42tmb9uw gs://processed-data-analytics-demo-4s42tmb9uw

# to cancel
gcloud dataproc batches cancel batch-000 --project data-analytics-demo-4s42tmb9uw --region us-central1

"""
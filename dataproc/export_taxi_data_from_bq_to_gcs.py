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
 
    years = [2019]
    #years = [2021]
    for data_year in years:
        print("data_year: ", data_year)
        for data_month in range(12, 13):
        #for data_month in range(1, 3):
            print("data_month: ", data_month)

            # Sample Code: https://cloud.google.com/dataproc/docs/tutorials/bigquery-connector-spark-example#pyspark
            # To use SQL to BQ
            spark.conf.set("viewsEnabled","true")
            spark.conf.set("materializationProject",project_id)
            spark.conf.set("materializationDataset",taxi_dataset_id)
            print ("BEGIN: Querying Table")
            sql = "SELECT * " + \
                    "FROM `" + project_id + "." + taxi_dataset_id + ".taxi_trips` " + \
                   "WHERE EXTRACT(YEAR  FROM Pickup_DateTime) = " + str(data_year)  + " " + \
                     "AND EXTRACT(MONTH FROM Pickup_DateTime) = " + str(data_month) + ";"
            print ("SQL: ", sql)
            df_taxi_trips = spark.read.format("bigquery").option("query", sql).load()
            print ("END: Querying Table")
     
            # Returns too much data to process with our limited demo core CPU quota
            # Load data from BigQuery taxi_trips table
            """
            print ("BEGIN: Querying Table")
            df_taxi_trips = spark.read.format('bigquery') \
                .option('table', project_id + ':' + taxi_dataset_id + '.taxi_trips') \
                .load()
            print ("END: Querying Table")
            """

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
                .mode("append") \
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



# Sample run using static Dataproc Cluster 
"""

project_string="s3epuwhxbf"
project="data-analytics-demo-${project_string}"
dataproceTempBucketName="dataproc-query-acceleration-temp"

serviceAccount="dataproc-service-account@${project}.iam.gserviceaccount.com"
rawBucket="raw-${project}"
processedBucket="processed-${project}"

# Create cluster (in central region)
# NOTE: You have to createa subnet in central called "dataproc-subnet-central"
#       You have to also create a firewall rule (like the existing one for this subnet)
gcloud dataproc clusters create dataproc-cluster \
    --bucket "${dataproceTempBucketName}" \
    --region REPLACE-REGION \
    --subnet dataproc-subnet-central \
    --zone REPLACE-REGION-a \
    --master-machine-type n1-standard-8 \
    --master-boot-disk-size 500 \
    --num-workers 3 \
    --service-account="${serviceAccount}" \
    --worker-machine-type n1-standard-16 \
    --worker-boot-disk-size 500 \
    --image-version 2.0-debian10 \
    --num-worker-local-ssds=4 \
    --project "${project}"

# Copy script to storage
gsutil cp ./dataproc/export_taxi_data_from_bq_to_gcs.py gs://${rawBucket}/pyspark-code

# Write to bucket (regional)
gcloud dataproc jobs submit pyspark  \
   --cluster "dataproc-cluster" \
   --region="REPLACE-REGION" \
   --project="${project}" \
   --jars gs://${rawBucket}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
   gs://${rawBucket}/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
   -- ${project} taxi_dataset ${dataproceTempBucketName} "gs://dataproc-query-acceleration/taxi-export"

# Write to local HDFS "/tmp/taxi-export" (you have to SSH to the machine and then distcp the files to a bucket)
# To SSH you need a firewall rule to open traffic
# This is FAST! But copying the data after the job is hard since we need this automated.
gcloud dataproc jobs submit pyspark  \
   --cluster "dataproc-cluster" \
   --region="REPLACE-REGION" \
   --project="${project}" \
   --jars gs://${rawBucket}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
   gs://${rawBucket}/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
   -- ${project} taxi_dataset ${dataproceTempBucketName} /tmp/taxi-export2

##################################################################
# SSH
##################################################################
myIPAddress=$(curl --silent ifconfig.me/ip)
gcloud compute firewall-rules create home-computer \
    --project="${project}" \
    --direction=INGRESS \
    --priority=1000 \
    --network=vpc-main \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=${myIPAddress} \
    --target-service-accounts="${serviceAccount}"

# Create firewall rule for:
# Type: Ingress
# Target: Service Account: dataproc-service-account@data-analytics-demo-${project_string}.iam.gserviceaccount.com
# Port: TCP port 22 Ingress 
# Source IP address of your home network
gcloud compute ssh --zone "REPLACE-REGION-a" "dataproc-cluster-m"  --project "data-analytics-demo-${project_string}"

# Run via SSH
hdfs dfs -ls /tmp/taxi-export/processed
hdfs dfs -count /tmp/taxi-export/processed
# grant access to dataproc-service-account@${project}.iam.gserviceaccount.com to your storage account
# 2022-09-17 00:43:15,803 INFO tools.SimpleCopyListing: Paths (files+dirs) cnt = 5069012; dirCnt = 1588356
# https://docs.cloudera.com/HDPDocuments/HDP3/HDP-3.1.0/administration/content/distcp_faq.html
export HADOOP_CLIENT_OPTS="-Xms64m -Xmx1024m"
hdfs dfs -ls /tmp/taxi-export/processed/taxi-trips-query-acceleration
hadoop distcp /tmp/taxi-export/processed/taxi-trips-query-acceleration gs://dataproc-data-analytics-demo-${project_string}/taxi-data/

FINAL:
2022-09-20 19:51:43,608 INFO tools.SimpleCopyListing: Paths (files+dirs) cnt = 5068912; dirCnt = 1588355
hadoop distcp /tmp/taxi-export/processed/taxi-trips-query-acceleration gs://data-query-acceleration/

# slower than distcp
hdfs dfs -cp -f /tmp/taxi-export/processed/taxi-trips-query-acceleration gs://processed-data-analytics-demo-${project_string}/copytest/

# Delete the cluster
gcloud dataproc clusters delete dataproc-cluster --region REPLACE-REGION --project="${project}"

"""



# Sample run via command line using Dataproc Serverless
# You must delete a lot of data from the taxi_trips table in order to test this.
# The amount of files can overwhelm most Spark clusters
"""
project_string="s3epuwhxbf"

gsutil cp ./dataproc/export_taxi_data_from_bq_to_gcs.py gs://raw-data-analytics-demo-${project_string}/pyspark-code

gcloud beta dataproc batches submit pyspark \
    --project="data-analytics-demo-${project_string}" \
    --region="REPLACE-REGION" \
    --batch="batch-015"  \
    gs://raw-data-analytics-demo-${project_string}/pyspark-code/export_taxi_data_from_bq_to_gcs.py \
    --jars gs://raw-data-analytics-demo-${project_string}/pyspark-code/spark-bigquery-with-dependencies_2.12-0.26.0.jar \
    --subnet="datatproc-serverless-subnet" \
    --deps-bucket="gs://dataproc-data-analytics-demo-${project_string}" \
    --service-account="dataproc-service-account@data-analytics-demo-${project_string}.iam.gserviceaccount.com" \
    -- data-analytics-demo-${project_string} taxi_dataset bigspark-data-analytics-demo-${project_string} gs://processed-data-analytics-demo-${project_string}

# to cancel
gcloud dataproc batches cancel batch-000 --project data-analytics-demo-${project_string} --region REPLACE-REGION

"""
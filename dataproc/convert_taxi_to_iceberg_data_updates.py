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
# Summary: Opens the Iceberg tables and performs SQL updates to update the data so we 
#          will have many metadata files as the data changes.

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys


def UpdateIcebergTaxiData(icebergWarehouse):
    print("UpdateIcebergTaxiData: icebergWarehouse:  ",icebergWarehouse)

    # ICEBERG SPECIFIC!
    # We need the ".config" options set for the default Iceberg catalog
    spark = SparkSession \
        .builder \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkSessionCatalog") \
        .config("spark.sql.catalog.spark_catalog.type", "hive") \
        .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.local.type", "hadoop") \
        .config("spark.sql.catalog.local.warehouse", icebergWarehouse) \
        .config("spark.network.timeout", 50000) \
        .appName("IcebergDataUpdates") \
        .getOrCreate()

    ##############################################################################################################
    # Do some data updates
    # https://iceberg.apache.org/docs/latest/spark-writes/#delete-from
    ##############################################################################################################
    
    # Delete some data
    query = "DELETE FROM local.default.green_taxi_trips WHERE Vendor_Id != 1"
    spark.sql(query)

    # Do an update on some data
    query = "UPDATE local.default.yellow_taxi_trips SET Surcharge = 100 WHERE Passenger_Count > 6"
    spark.sql(query)

    # Add a column "iceberg_data" to the Green table
    query = "ALTER TABLE local.default.green_taxi_trips ADD COLUMNS (iceberg_data string comment 'Iceberg new column')"
    spark.sql(query)

     # Update the "iceberg_data"" column with data 'Iceberg was here!'
    query = "UPDATE local.default.green_taxi_trips SET iceberg_data = 'Iceberg was here!'"
    spark.sql(query)

    spark.stop()


# Main entry point
# convert_taxi_to_iceberg_data_updates gs://${processedBucket}/iceberg-warehouse
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: convert_taxi_to_parquet icebergWarehouse")
        sys.exit(-1)

    icebergWarehouse = sys.argv[1]

    print ("BEGIN: Main")
    UpdateIcebergTaxiData(icebergWarehouse)
    print ("END: Main")


# Sample run: Using a full dataproc cluster
"""
project="data-analytics-demo-s3epuwhxbf"
dataproceTempBucketName="dataproc-temp-REPLACE-REGION-460335302435-2cla8wa3"

serviceAccount="dataproc-service-account@${project}.iam.gserviceaccount.com"
rawBucket="raw-${project}"
processedBucket="processed-${project}"

gcloud dataproc clusters create iceberg-cluster \
    --bucket "${dataproceTempBucketName}" \
    --region REPLACE-REGION \
    --subnet dataproc-subnet \
    --zone REPLACE-REGION-c \
    --master-machine-type n1-standard-4 \
    --master-boot-disk-size 500 \
    --num-workers 2 \
    --service-account="${serviceAccount}" \
    --worker-machine-type n1-standard-4 \
    --worker-boot-disk-size 500 \
    --image-version 2.0-debian10 \
    --project "${project}"

# pyspark.sql.utils.AnalysisException: Table gs://${rawBucket}/test-taxi/dest/green/trips_table.iceberg not found
# Download Iceberg JAR: https://iceberg.apache.org/releases/
# https://iceberg.apache.org/spark-quickstart/ (pyspark samples)

gsutil cp ./dataproc/convert_taxi_to_iceberg_data_updates.py gs://${rawBucket}/pyspark-code/convert_taxi_to_iceberg_data_updates.py

gcloud dataproc jobs submit pyspark  \
   --cluster "iceberg-cluster" \
   --region="REPLACE-REGION" \
   --project="${project}" \
   --jars ./dataproc/iceberg-spark-runtime-3.1_2.12-0.14.0.jar \
   gs://${rawBucket}/pyspark-code/convert_taxi_to_iceberg_data_updates.py \
   -- gs://${processedBucket}/iceberg-warehouse

gcloud dataproc clusters delete iceberg-cluster --region REPLACE-REGION --project="${project}"
"""


# Sample run: Using a full dataproc serverless (CURRENTLY THIS DOES NOT WORK since serverless is Spark 3.2 and Iceberg only supports Spark 3.1)
"""
REPLACE "s3epuwhxbf" with your unique Id

gsutil cp ./dataproc/convert_taxi_to_iceberg_data_updates.py gs://raw-data-analytics-demo-s3epuwhxbf/pyspark-code

gcloud beta dataproc batches submit pyspark \
    --project="data-analytics-demo-s3epuwhxbf" \
    --region="REPLACE-REGION" \
    --batch="batch-002"  \
    gs://raw-data-analytics-demo-s3epuwhxbf/pyspark-code/convert_taxi_to_iceberg_data_updates.py \
    --jars gs://raw-data-analytics-demo-s3epuwhxbf/pyspark-code/iceberg-spark-runtime-3.1_2.12-0.14.0.jar \
    --subnet="dataproc-serverless-subnet" \
    --deps-bucket="gs://dataproc-data-analytics-demo-s3epuwhxbf" \
    --service-account="dataproc-service-account@data-analytics-demo-s3epuwhxbf.iam.gserviceaccount.com" \
    -- gs://processed-data-analytics-demo-s3epuwhxbf/iceberg-warehouse

# to cancel
gcloud dataproc batches cancel batch-000 --project data-analytics-demo-s3epuwhxbf --region REPLACE-REGION

"""

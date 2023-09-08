CREATE OR REPLACE PROCEDURE
	`bigquery_preview_features.sp_demo_bigspark_read_bq_save_hive_on_data_lake`(test_parameter STRING)
WITH CONNECTION `us.bigspark-connection` OPTIONS (engine='SPARK', runtime_version='2.0',
		jar_uris=["gs://spark-lib/bigquery/spark-3.3-bigquery-0.32.0.jar"])
	LANGUAGE python AS R"""
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


# Use Cases:
#    - Export data from BigQuery to GCS and use a custom partitioning that cannot be performed with BQ EXTRACT command
#
# Description: 
#     - Reads data from BQ using dataproc connector (spark-bigquery-with-dependencies_2.12-0.26.0.jar) and does a custom SQL statement
#     - Partitions the data by year | month | day
#     - Saves the data in parquet format
# 
# Show:
#     - BQ support for Spark
#     - Running spark directly in the interface
# 
# References:
#     - pending
# 
# Clean up / Reset script:
#   n/a

# To invoke:
#   CALL `bigquery_preview_features.sp_demo_bigspark_read_bq_save_hive_on_data_lake`('testval');

# To create the External Connection (you can use the BQ UI for this under "+ Add Data | External Data Source")
# bq mk --connection \
#       --connection_type='SPARK' \
#       --project_id="REPLACE-ME" \
#       --location="us" \
#       "bigspark-connection"

# NOTE: You must enable Dataproc API in the project for BigSpark (this has been done)

# NOTE: The storage buckets must be accessible via the service account on the external connection
#       View the connection to see the service account
#       e.g. bqcx-312090430116-oi5j@gcp-sa-bigquery-consp.iam.gserviceaccount.com 
#       This account was granted Editor role at the Project level due to Preview Requirements

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, dayofmonth, hour, minute
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys

# Read input parameters
import os
import json
test_parameter_value = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.test_parameter"]))
print("test_parameter_value", test_parameter_value)

temporaryGcsBucket = "sample-shared-data-temp"
project_id = "REPLACE-ME"
taxi_dataset_id = "bigquery_preview_features"
destination = "gs://sample-shared-data/customer-extract/taxi-data/"

print("Create session")
spark = SparkSession \
     .builder \
     .appName("read_bq_save_hive_on_data_lake") \
     .config("spark.network.timeout", 50000) \
     .getOrCreate()
     

spark.conf.set("temporaryGcsBucket",temporaryGcsBucket)
spark.conf.set("viewsEnabled","true")
spark.conf.set("materializationProject",project_id)
spark.conf.set("materializationDataset",taxi_dataset_id)
spark.conf.set("readDataFormat", "AVRO")


print ("BEGIN: Querying Table")
sql = "SELECT * " + \
        "FROM `" + project_id + "." + taxi_dataset_id + ".taxi_trips` " + \
        "WHERE EXTRACT(YEAR  FROM Pickup_DateTime) = 2022 " + \
          "AND EXTRACT(MONTH FROM Pickup_DateTime) = 1;"
print ("SQL: ", sql)
df_taxi_trips = spark.read.format("bigquery").option("query", sql).load()
print ("END: Querying Table")


print ("BEGIN: Adding partition columns to dataframe")
df_taxi_trips_partitioned = df_taxi_trips \
    .withColumn("year",   year       (col("Pickup_DateTime"))) \
    .withColumn("month",  month      (col("Pickup_DateTime"))) \
    .withColumn("day",    dayofmonth (col("Pickup_DateTime"))) 
print ("END: Adding partition columns to dataframe")


# Write as Parquet
# Open Cloud Storage and view the data at: gs://sample-shared-data/customer-extract/taxi-data/
print ("BEGIN: Writing Data to GCS")
df_taxi_trips_partitioned \
    .write \
    .mode("overwrite") \
    .partitionBy("year","month","day") \
    .parquet(destination)
print ("END: Writing Data to GCS")
""";
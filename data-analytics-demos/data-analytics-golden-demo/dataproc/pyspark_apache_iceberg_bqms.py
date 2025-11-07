####################################################################################
# Copyright 2024 Google LLC
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

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, dayofmonth, hour, minute
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys
import os
import json

# https://cloud.google.com/bigquery/docs/iceberg-tables
# Dataproc Serverless Runtime Versions: https://cloud.google.com/dataproc-serverless/docs/concepts/versions/dataproc-serverless-versions

# We need the ".config" options set for the default Iceberg catalog
spark = SparkSession \
     .builder \
     .appName("BigLake Iceberg") \
     .config("spark.network.timeout", 50000) \
     .getOrCreate()


#####################################################################################
# Sample Parameters
#####################################################################################
# Iceberg configuration
# iceberg_catalog = "iceberg_catalog" # MUST MATCH the spark.sql.catalog.iceberg_catalog.XXX in the above Spark Properties
# iceberg_warehouse = "iceberg_warehouse"
# iceberg_table = "driver_iceberg"

# BigQuery configuration
# bq_dataset = "biglake_dataset" 
# bq_region = "us"
# biglake_connection = "biglake-notebook-connection"
# source_parquet_file = "gs://biglake-notebook-test-421220/biglake-tables/driver_parquet/driver.snappy.parquet"


#####################################################################################
# Use parameters
#####################################################################################
# Iceberg configuration
iceberg_catalog = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.iceberg_catalog"]))
iceberg_warehouse = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.iceberg_warehouse"]))
iceberg_table = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.iceberg_table"]))

# BigQuery configuration
bq_dataset = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.bq_dataset"]))
bq_region = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.bq_region"]))
biglake_connection = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.biglake_connection"]))
source_parquet_file = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.source_parquet_file"]))

project_id = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.project_id"]))


#####################################################################################
# Iceberg Initialization
#####################################################################################
spark.sql(f"USE {iceberg_catalog};")
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {iceberg_warehouse};")
spark.sql(f"USE {iceberg_warehouse};")

#####################################################################################
# Create the Iceberg tables
#####################################################################################
sql = f"CREATE TABLE IF NOT EXISTS {iceberg_catalog}.{iceberg_warehouse}.{iceberg_table} " + \
               "(driver_id int, driver_name string, driver_mobile_number string, driver_license_number string, " + \
               "driver_email_address string, driver_dob date, driver_ach_routing_number string, driver_ach_account_number string) " + \
       "USING iceberg " + \
       f"TBLPROPERTIES('bq_connection'='projects/{project_id}/locations/{bq_region}/connections/{biglake_connection}');"

print(f"sql: {sql}")
spark.sql(sql)

# Read parquet source data to convert to iceberg
print (f"source_parquet_file: {source_parquet_file}")
df = spark.read.parquet(source_parquet_file)

# Save as temp view to do INSERT..INTO iceberg
df.createOrReplaceTempView(f"temp_view_{iceberg_table}")

sql = f"INSERT INTO {iceberg_catalog}.{iceberg_warehouse}.{iceberg_table} " + \
              "(driver_id, driver_name, driver_mobile_number, driver_license_number, " + \
              "driver_email_address, driver_dob, driver_ach_routing_number, driver_ach_account_number)" + \
       "SELECT cast(driver_id as int), cast(driver_name as string), cast(driver_mobile_number as string), " + \
              "cast(driver_license_number as string), cast(driver_email_address as string), cast(driver_dob as date), " + \
              "cast(driver_ach_routing_number as string), cast(driver_ach_account_number as string) " + \
        f"FROM temp_view_{iceberg_table}"

print(f"sql: {sql}")
spark.sql(sql)
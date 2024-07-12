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


# Use Cases:
#    - Be able to directly run Spark in BigQuery
#    - Supplement BigQuery functionality with Spark
#
# Description: 
#     - First View and Explore the Cloud Storage Account in this Project
# 
# Show:
#     - BQ support for Spark
#     - Running spark directly in the interface
# 
# References:
#     - https://cloud.google.com/bigquery/docs/spark-procedures
# 
# Clean up / Reset script:
#   DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.product_discounts`;


# NOTE: The storage buckets must be accessible via the service account on the external connection
#       View the connection to see the service account
#       e.g. bqcx-312090430116-oi5j@gcp-sa-bigquery-consp.iam.gserviceaccount.com 
#       This account was granted Editor role at the Project level due to Preview Requirements

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField,  IntegerType, DoubleType, StringType
import os
import json
test_parameter_value = str(json.loads(os.environ["BIGQUERY_PROC_PARAM.test_parameter"]))
print("test_parameter_value", test_parameter_value)

temporaryGcsBucket = "dataproc-data-analytics-demo-${random_extension}"
project_id = "${project_id}"
taxi_dataset_id = "${bigquery_taxi_dataset}"
source = "gs://${storage_bucket}/bigspark/sample-bigspark-discount-data.csv"

print("Create session")
spark = SparkSession.builder \
    .config("spark.jars.packages","com.google.cloud.spark:spark-bigquery-with-dependencies_2.12-0.26.0") \
    .appName('bq_spark_sp_demo_bigspark_read_csv_load_bq_table') \
    .getOrCreate()

spark.conf.set("temporaryGcsBucket",temporaryGcsBucket)

print("Declare schema of file to load")
# SKU,brand,department,discount,discount_code
discountSchema = StructType([
    StructField('SKU', StringType(), False),
    StructField('brand', StringType(), False),
    StructField('department', StringType(), False),
    StructField('discount', IntegerType(), False),
    StructField('discount_code', StringType(), False)])
    
print("Load the discount")
dfDiscount = spark.read.format("csv") \
    .option("header", True) \
    .option("delimiter", ",") \
    .schema(discountSchema) \
    .load(source)
 
print("Determine if discount is High, Medium or Low")
dfDiscount = dfDiscount.withColumn("discount_rate", F.expr("CASE WHEN discount < 10 THEN 'Low' WHEN discount < 20 THEN 'Medium' ELSE 'High' END"))

print("Display dataframe")
dfDiscount.show(5)

print("Saving results to BigQuery")
dfDiscount.write.format("bigquery") \
    .option("table", f"{taxi_dataset_id}.product_discounts") \
    .mode("overwrite") \
    .save()
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
# Summary: Read the data from the Raw zone and creates Iceberg tables in the Enriched Zone
#          Uses the BigLake Metastore service to create BigLake tables

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, dayofmonth, hour, minute
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys
import os
import json


def CreateIcebergWarehouse(project_id,iceberg_catalog,iceberg_warehouse,bq_rideshare_enriched_dataset,bq_rideshare_raw_dataset,rideshare_raw_bucket,rideshare_enriched_bucket,bigquery_region):
    print("BEGIN: CreateIcebergWarehouse")

    # We need the ".config" options set for the default Iceberg catalog
    spark = SparkSession \
        .builder \
        .appName("BigLake Iceberg") \
        .config("spark.network.timeout", 50000) \
        .getOrCreate()

    # .enableHiveSupport() \

    #project_id = "data-analytics-demo-rexm45tpvr"
    #iceberg_catalog = "iceberg_catalog_1"
    #iceberg_warehouse = "iceberg_warehouse"
    #bq_rideshare_enriched_dataset = "iceberg_test"
    #bq_rideshare_raw_dataset = "rideshare_lakehouse_raw"
    #rideshare_raw_bucket = "rideshare-lakehouse-raw-rexm45tpvr"

    #####################################################################################
    # Iceberg Initialization
    #####################################################################################
    spark.sql("CREATE NAMESPACE IF NOT EXISTS {};".format(iceberg_catalog))
    spark.sql("CREATE NAMESPACE IF NOT EXISTS {}.{};".format(iceberg_catalog,iceberg_warehouse))
    spark.sql("DROP TABLE IF EXISTS {}.{}.biglake_rideshare_payment_type_iceberg".format(iceberg_catalog,iceberg_warehouse))


    #####################################################################################
    # Create the Iceberg tables
    #####################################################################################
    spark.sql("CREATE TABLE IF NOT EXISTS {}.{}.biglake_rideshare_payment_type_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(payment_type_id int, payment_type_description string) " + \
            "USING iceberg " + \
            "TBLPROPERTIES(bq_table='{}.biglake_rideshare_payment_type_iceberg', bq_connection='{}.biglake-connection');".format(bq_rideshare_enriched_dataset,bigquery_region))

    spark.sql("CREATE TABLE IF NOT EXISTS {}.{}.biglake_rideshare_zone_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(location_id int, borough string, zone string, service_zone string) " + \
            "USING iceberg " + \
            "TBLPROPERTIES(bq_table='{}.biglake_rideshare_zone_iceberg', bq_connection='{}.biglake-connection');".format(bq_rideshare_enriched_dataset,bigquery_region))

    spark.sql("CREATE TABLE IF NOT EXISTS {}.{}.biglake_rideshare_trip_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(rideshare_trip_id string, pickup_location_id int, pickup_datetime timestamp, " + \
                    "dropoff_location_id int, dropoff_datetime timestamp, ride_distance float, " + \
                    "is_airport boolean, payment_type_id int, fare_amount float, tip_amount float, " + \
                    "taxes_amount float, total_amount float, " + \
                    "credit_card_number string, credit_card_expire_date date, credit_card_cvv_code string, " + \
                    "partition_date date)" + \
            "USING iceberg " + \
            "PARTITIONED BY (partition_date) " + \
            "TBLPROPERTIES(bq_table='{}.biglake_rideshare_trip_iceberg', bq_connection='{}.biglake-connection');".format(bq_rideshare_enriched_dataset,bigquery_region))
        
    #####################################################################################
    # Load the Payment Type Table in the Enriched Zone
    #####################################################################################
    # Option 1: Use BigQuery Spark Adaptor to load the whole table
    # Read from the RAW zone
    #df_biglake_rideshare_payment_type_json = spark.read.format('bigquery') \
    #    .option("table", "{}:{}.biglake_rideshare_payment_type_json".format(project_id,bq_rideshare_raw_dataset)) \
    #    .load()

    # Option 2: Use BigQuery Spark Adaptor to run a SQL statement
    #df_biglake_rideshare_payment_type_json = spark.read.format("bigquery") \
    #  .load("select * from `{}.{}.biglake_rideshare_payment_type_json`"".format(project_id,bq_rideshare_raw_dataset))

    # Option 3: Read from raw files
    df_biglake_rideshare_payment_type_json = spark.read.json("gs://{}/rideshare_payment_type/*.json".format(rideshare_raw_bucket))

    # Create Spark View and Show the data
    df_biglake_rideshare_payment_type_json.createOrReplaceTempView("temp_view_rideshare_payment_type")
    spark.sql("select * from temp_view_rideshare_payment_type").show(10)

    # Insert into Iceberg table (perform typecasting)
    spark.sql("INSERT INTO {}.{}.biglake_rideshare_payment_type_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(payment_type_id, payment_type_description) " + \
            "SELECT cast(payment_type_id as int), cast(payment_type_description as string) " + \
            "FROM temp_view_rideshare_payment_type;")
        

    #####################################################################################
    # Load the Zone Table in the Enriched Zone
    #####################################################################################
    df_biglake_rideshare_zone_csv = spark.read \
        .option("delimiter", "|") \
        .option("header", "true") \
        .csv("gs://{}/rideshare_zone/*.csv".format(rideshare_raw_bucket))

    # Create Spark View and Show the data
    df_biglake_rideshare_zone_csv.createOrReplaceTempView("temp_view_rideshare_zone")
    spark.sql("select * from temp_view_rideshare_zone").show(10)

    # Insert into Iceberg table (perform typecasting)
    spark.sql("INSERT INTO {}.{}.biglake_rideshare_zone_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(location_id, borough, zone, service_zone) " + \
            "SELECT cast(location_id as int), cast(borough as string), cast(zone as string), cast(service_zone as string) " + \
            "FROM temp_view_rideshare_zone;")


    #####################################################################################
    # Load the Rideshare Trips Table in the Enriched Zone (3 different formats)
    #####################################################################################
    # AVRO data
    df_biglake_rideshare_trip_avro = spark.read.format("avro").load("gs://{}/rideshare_trip/avro/*.avro".format(rideshare_raw_bucket))

    # Create Spark View and Show the data
    df_biglake_rideshare_trip_avro.createOrReplaceTempView("temp_view_rideshare_trip_avro")
    spark.sql("select * from temp_view_rideshare_trip_avro").show(10)

    # Insert into Iceberg table (perform typecasting)
    spark.sql("INSERT INTO {}.{}.biglake_rideshare_trip_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(rideshare_trip_id, pickup_location_id, pickup_datetime, " + \
                    "dropoff_location_id, dropoff_datetime, ride_distance, " + \
                    "is_airport, payment_type_id, fare_amount, tip_amount, " + \
                    "taxes_amount, total_amount, credit_card_number, credit_card_expire_date, credit_card_cvv_code, partition_date)" + \
            "SELECT cast(rideshare_trip_id as string), cast(pickup_location_id as int), cast(pickup_datetime as timestamp), " + \
                    "cast(dropoff_location_id as int), cast(dropoff_datetime as timestamp), cast(ride_distance as float), " + \
                    "cast(is_airport as boolean), cast(payment_type_id as int), cast(fare_amount as float), cast(tip_amount as float), " + \
                    "cast(taxes_amount as float), cast(total_amount as float), " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CONCAT(CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CAST( " + \
                            "  CONCAT(CAST(CAST(ROUND(2022 + RAND() * (2025 - 2022)) AS INT) AS STRING),'-', " + \
                            "         CAST(CAST(ROUND(   1 + RAND() * (12   - 1)) AS INT) AS STRING),'-', " + \
                            "         CAST(CAST(ROUND(   1 + RAND() * (28   - 1)) AS INT) AS STRING)) " + \
                            "AS DATE) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "cast(partition_date as date) " + \
            "FROM temp_view_rideshare_trip_avro;")

            
    # Parquet data
    df_biglake_rideshare_trip_parquet = spark.read.parquet("gs://{}/rideshare_trip/parquet/*.parquet".format(rideshare_raw_bucket))

    # Create Spark View and Show the data
    df_biglake_rideshare_trip_parquet.createOrReplaceTempView("temp_view_rideshare_trip_parquet")
    spark.sql("select * from temp_view_rideshare_trip_parquet").show(10)

    # Insert into Iceberg table (perform typecasting)
    spark.sql("INSERT INTO {}.{}.biglake_rideshare_trip_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(rideshare_trip_id, pickup_location_id, pickup_datetime, " + \
                    "dropoff_location_id, dropoff_datetime, ride_distance, " + \
                    "is_airport, payment_type_id, fare_amount, tip_amount, " + \
                    "taxes_amount, total_amount, credit_card_number, credit_card_expire_date, credit_card_cvv_code, partition_date)" + \
            "SELECT cast(rideshare_trip_id as string), cast(pickup_location_id as int), cast(pickup_datetime as timestamp), " + \
                    "cast(dropoff_location_id as int), cast(dropoff_datetime as timestamp), cast(ride_distance as float), " + \
                    "cast(is_airport as boolean), cast(payment_type_id as int), cast(fare_amount as float), cast(tip_amount as float), " + \
                    "cast(taxes_amount as float), cast(total_amount as float), " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CONCAT(CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CAST( " + \
                            "  CONCAT(CAST(CAST(ROUND(2022 + RAND() * (2025 - 2022)) AS INT) AS STRING),'-', " + \
                            "         CAST(CAST(ROUND(   1 + RAND() * (12   - 1)) AS INT) AS STRING),'-', " + \
                            "         CAST(CAST(ROUND(   1 + RAND() * (28   - 1)) AS INT) AS STRING)) " + \
                            "AS DATE) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "cast(partition_date as date) " + \
            "FROM temp_view_rideshare_trip_parquet;")


    # JSON data
    df_biglake_rideshare_trip_json = spark.read.json("gs://{}/rideshare_trip/json/*.json".format(rideshare_raw_bucket))

    # Create Spark View and Show the data
    df_biglake_rideshare_trip_json.createOrReplaceTempView("temp_view_rideshare_trip_json")
    spark.sql("select * from temp_view_rideshare_trip_json").show(10)

    # Insert into Iceberg table (perform typecasting)
    spark.sql("INSERT INTO {}.{}.biglake_rideshare_trip_iceberg ".format(iceberg_catalog, iceberg_warehouse) + \
                    "(rideshare_trip_id, pickup_location_id, pickup_datetime, " + \
                    "dropoff_location_id, dropoff_datetime, ride_distance, " + \
                    "is_airport, payment_type_id, fare_amount, tip_amount, " + \
                    "taxes_amount, total_amount, credit_card_number, credit_card_expire_date, credit_card_cvv_code, partition_date)" + \
            "SELECT cast(rideshare_trip_id as string), cast(pickup_location_id as int), cast(pickup_datetime as timestamp), " + \
                    "cast(dropoff_location_id as int), cast(dropoff_datetime as timestamp), cast(ride_distance as float), " + \
                    "cast(is_airport as boolean), cast(payment_type_id as int), cast(fare_amount as float), cast(tip_amount as float), " + \
                    "cast(taxes_amount as float), cast(total_amount as float), " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CONCAT(CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-', " + \
                            "CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CAST( " + \
                            "  CONCAT(CAST(CAST(ROUND(2022 + RAND() * (2025 - 2022)) AS INT) AS STRING),'-', " + \
                            "         CAST(CAST(ROUND(   1 + RAND() * (12   - 1)) AS INT) AS STRING),'-', " + \
                            "         CAST(CAST(ROUND(   1 + RAND() * (28   - 1)) AS INT) AS STRING)) " + \
                            "AS DATE) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "CASE WHEN cast(payment_type_id as int) = 1 " + \
                        "THEN CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING) " + \
                        "ELSE NULL " + \
                    "END, " + \
                    "cast(partition_date as date) " + \
            "FROM temp_view_rideshare_trip_json;")


    spark.stop()


# Main entry point
# rideshare_iceberg_serverless gs://${processedBucket}/iceberg-warehouse
if __name__ == "__main__":
    if len(sys.argv) != 9:
        print("Usage: rideshare_iceberg_serverless project_id,iceberg_catalog,iceberg_warehouse,bq_rideshare_enriched_dataset,bq_rideshare_raw_dataset,rideshare_raw_bucket,rideshare_enriched_bucket,bigquery_region")
        sys.exit(-1)

    project_id=sys.argv[1]
    iceberg_catalog=sys.argv[2]
    iceberg_warehouse=sys.argv[3]
    bq_rideshare_enriched_dataset=sys.argv[4]
    bq_rideshare_raw_dataset=sys.argv[5]
    rideshare_raw_bucket=sys.argv[6]
    rideshare_enriched_bucket=sys.argv[7]
    bigquery_region=sys.argv[8]

    print ("BEGIN: Main")
    CreateIcebergWarehouse(project_id,iceberg_catalog,iceberg_warehouse,bq_rideshare_enriched_dataset,bq_rideshare_raw_dataset,rideshare_raw_bucket,rideshare_enriched_bucket,bigquery_region)
    print ("END: Main")



# Sample run: Using a full dataproc serverless
"""
project_id="data-analytics-demo-rexm45tpvr"
iceberg_catalog="iceberg_catalog_1"
iceberg_warehouse="iceberg_warehouse"
bq_rideshare_enriched_dataset="iceberg_test"
bq_rideshare_raw_dataset="rideshare_lakehouse_raw"
rideshare_raw_bucket="rideshare-lakehouse-raw-rexm45tpvr"
rideshare_enriched_bucket="rideshare-lakehouse-enriched-rexm45tpvr"

gsutil cp ./dataproc/rideshare_iceberg_serverless.py gs://raw-${project_id}/pyspark-code
# This needs to escape (gcloud topic escaping) org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:0.14.1,org.apache.spark:spark-avro_2.12:3.3.1

gcloud beta dataproc batches submit pyspark \
    --project="${project_id}" \
    --region="REPLACE-REGION" \
    --batch="batch-015"  \
    gs://raw-${project_id}/pyspark-code/rideshare_iceberg_serverless.py \
    --jars gs://spark-lib/biglake/biglake-catalog-iceberg1.2.0-0.1.0-with-dependencies.jar \
    --subnet="dataproc-serverless-subnet" \
    --deps-bucket="gs://dataproc-${project_id}" \
    --service-account="dataproc-service-account@${project_id}.iam.gserviceaccount.com" \
    --properties="spark.sql.catalog.${iceberg_catalog}.blms_catalog=${iceberg_catalog}, \
     spark.sql.catalog.${iceberg_catalog}.gcp_project=${project_id}, \
     spark.jars.packages=org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:0.14.1,org.apache.spark:spark-avro_2.12:3.3.1, \
     spark.sql.catalog.${iceberg_catalog}.catalog-impl=org.apache.iceberg.gcp.biglake.BigLakeCatalog, \
     spark.sql.catalog.${iceberg_catalog}.gcp_location=us, \
     spark.sql.catalog.${iceberg_catalog}=org.apache.iceberg.spark.SparkCatalog, \
     spark.sql.catalog.${iceberg_catalog}.warehouse=gs://${rideshare_enriched_bucket}/${iceberg_catalog}" \
    --version="1.0" \
    -- ${project_id} ${iceberg_catalog} ${iceberg_warehouse} ${bq_rideshare_enriched_dataset} ${bq_rideshare_raw_dataset} ${rideshare_raw_bucket} ${rideshare_enriched_bucket}

 
# to cancel
gcloud dataproc batches cancel batch-000 --project ${project_id} --region REPLACE-REGION

"""

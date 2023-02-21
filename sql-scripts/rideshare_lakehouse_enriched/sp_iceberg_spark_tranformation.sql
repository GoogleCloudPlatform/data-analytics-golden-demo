/*
NOTE: 1. You need to be allowlisted to run BigSpark
      2. You also need to be allowlisted for Iceberg
      3. Remove this NOTE down to the line WITH CONNECTION `${project_id}.us.bigspark-connection`
      4. Remove "-- REMOVE EVERYTHING BELOW THIS LINE TO USE BigSpark" at the bottom
      5. You need to create a a connection named "us-bigspark"
      6. For the service principal for the connection:
         a. Grant the service principal an Editor role at the project level (this is being worked on to have less permissions)
         b. Grant the service principal the custom role "CustomConnectionDelegate" 

WITH CONNECTION `${project_id}.us.bigspark-connection`
OPTIONS (engine='SPARK',
     runtime_version="1.0",
     properties=[("spark.sql.catalog.rideshare_iceberg_catalog.blms_catalog","rideshare_iceberg_catalog"),
     ("spark.sql.catalog.rideshare_iceberg_catalog.gcp_project","${project_id}"),
     ("spark.jars.packages","org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:0.14.1,org.apache.spark:spark-avro_2.12:3.3.1"),
     ("spark.sql.catalog.rideshare_iceberg_catalog.catalog-impl","org.apache.iceberg.gcp.biglake.BigLakeCatalog"),
     ("spark.sql.catalog.rideshare_iceberg_catalog.gcp_location","us"),
     ("spark.sql.catalog.rideshare_iceberg_catalog","org.apache.iceberg.spark.SparkCatalog"),
     ("spark.sql.catalog.rideshare_iceberg_catalog.warehouse","gs://rideshare-lakehouse-enriched-rexm45tpvr/biglake-iceberg-warehouse")],
     jar_uris=["gs://spark-lib/biglake/iceberg-biglake-catalog-0.0.1-with-dependencies.jar"])
	LANGUAGE python AS R"""

 ##################################################################################
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
 ###################################################################################
 #
 # Use Cases:
 #     - Runs a BigSpark job that read the raw zone data and saves in Iceberg format
 # 
 # Description: 
 #     - Support for open source formats 
 #     
 # Show:
 #     - Storage account with Iceberg warehouse
 # 
 # References:
 #      - https://cloud.google.com/bigquery/docs/iceberg-tables#create-using-biglake-metastore
 #  
 #  Clean up / Reset script:

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, dayofmonth, hour, minute
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys
import os
import json

spark = SparkSession \
  .builder \
  .appName("BigLake Iceberg") \
  .enableHiveSupport() \
  .config("spark.network.timeout", 50000) \
  .getOrCreate()


temporaryGcsBucket = "bigspark-${project_id}"
materializationProject = "${bigquery_rideshare_lakehouse_enriched_dataset}"
materializationDataset = "${project_id}"

spark.conf.set("temporaryGcsBucket",temporaryGcsBucket)
spark.conf.set("viewsEnabled","true")
spark.conf.set("materializationProject",materializationProject)
spark.conf.set("materializationDataset",materializationDataset)


#####################################################################################
# Iceberg Initialization
#####################################################################################
spark.sql("CREATE NAMESPACE IF NOT EXISTS rideshare_iceberg_catalog;")
spark.sql("CREATE NAMESPACE IF NOT EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset};")
spark.sql("DROP TABLE IF EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg")
spark.sql("DROP TABLE IF EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg")
spark.sql("DROP TABLE IF EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg")


#####################################################################################
# Create the Iceberg tables
#####################################################################################
spark.sql("CREATE TABLE IF NOT EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg " + \
                 "(payment_type_id int, payment_type_description string) " + \
         "USING iceberg " + \
         "TBLPROPERTIES(bq_table='${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg', bq_connection='us.biglake-connection');")

spark.sql("CREATE TABLE IF NOT EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg " + \
                 "(location_id int, borough string, zone string, service_zone string) " + \
         "USING iceberg " + \
         "TBLPROPERTIES(bq_table='${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg', bq_connection='us.biglake-connection');")

spark.sql("CREATE TABLE IF NOT EXISTS rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg " + \
                 "(rideshare_trip_id string, pickup_location_id int, pickup_datetime timestamp, " + \
                 "dropoff_location_id int, dropoff_datetime timestamp, ride_distance float, " + \
                 "is_airport boolean, payment_type_id int, fare_amount float, tip_amount float, " + \
                 "taxes_amount float, total_amount float, " + \
                 "credit_card_number string, credit_card_expire_date date, credit_card_cvv_code string, " + \
                 "partition_date date)" + \
         "USING iceberg " + \
         "PARTITIONED BY (partition_date) " + \
         "TBLPROPERTIES(bq_table='${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg', bq_connection='us.biglake-connection');")
	
	
#####################################################################################
# Load the Payment Type Table in the Enriched Zone
#####################################################################################
# Option 1: Use BigQuery Spark Adaptor to load the whole table
# Read from the RAW zone
#df_biglake_rideshare_payment_type_json = spark.read.format('bigquery') \
#    .option('table', '${project_id}:rideshare_lakehouse_raw.biglake_rideshare_payment_type_json') \
#    .load()

# Option 2: Use BigQuery Spark Adaptor to run a SQL statement
#df_biglake_rideshare_payment_type_json = spark.read.format("bigquery") \
#  .load("select * from `${project_id}.rideshare_lakehouse_raw.biglake_rideshare_payment_type_json`")

# Option 3: Read from raw files
df_biglake_rideshare_payment_type_json = spark.read.json("gs://rideshare-lakehouse-raw-rexm45tpvr/rideshare_payment_type/*.json")

# Create Spark View and Show the data
df_biglake_rideshare_payment_type_json.createOrReplaceTempView("temp_view_rideshare_payment_type")
spark.sql("select * from temp_view_rideshare_payment_type").show(10)

# Insert into Iceberg table (perform typecasting)
spark.sql("INSERT INTO rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg " + \
                 "(payment_type_id, payment_type_description) " + \
         "SELECT cast(payment_type_id as int), cast(payment_type_description as string) " + \
         "FROM temp_view_rideshare_payment_type;")

#####################################################################################
# Load the Zone Table in the Enriched Zone
#####################################################################################
df_biglake_rideshare_zone_csv = spark.read \
  .option("delimiter", "|") \
  .option("header", "true") \
  .csv("gs://rideshare-lakehouse-raw-rexm45tpvr/rideshare_zone/*.csv")

# Create Spark View and Show the data
df_biglake_rideshare_zone_csv.createOrReplaceTempView("temp_view_rideshare_zone")
spark.sql("select * from temp_view_rideshare_zone").show(10)

# Insert into Iceberg table (perform typecasting)
spark.sql("INSERT INTO rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg " + \
                 "(location_id, borough, zone, service_zone) " + \
         "SELECT cast(location_id as int), cast(borough as string), cast(zone as string), cast(service_zone as string) " + \
         "FROM temp_view_rideshare_zone;")


#####################################################################################
# Load the Rideshare Trips Table in the Enriched Zone (3 different formats)
#####################################################################################
# AVRO data
df_biglake_rideshare_trip_avro = spark.read.format("avro").load("gs://rideshare-lakehouse-raw-rexm45tpvr/rideshare_trip/avro/*.avro")

# Create Spark View and Show the data
df_biglake_rideshare_trip_avro.createOrReplaceTempView("temp_view_rideshare_trip_avro")
spark.sql("select * from temp_view_rideshare_trip_avro").show(10)

# Insert into Iceberg table (perform typecasting)
spark.sql("INSERT INTO rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg " + \
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
df_biglake_rideshare_trip_parquet = spark.read.parquet("gs://rideshare-lakehouse-raw-rexm45tpvr/rideshare_trip/parquet/*.parquet")

# Create Spark View and Show the data
df_biglake_rideshare_trip_parquet.createOrReplaceTempView("temp_view_rideshare_trip_parquet")
spark.sql("select * from temp_view_rideshare_trip_parquet").show(10)

# Insert into Iceberg table (perform typecasting)
spark.sql("INSERT INTO rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg " + \
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
df_biglake_rideshare_trip_json = spark.read.json("gs://rideshare-lakehouse-raw-rexm45tpvr/rideshare_trip/json/*.json")

# Create Spark View and Show the data
df_biglake_rideshare_trip_json.createOrReplaceTempView("temp_view_rideshare_trip_json")
spark.sql("select * from temp_view_rideshare_trip_json").show(10)

# Insert into Iceberg table (perform typecasting)
spark.sql("INSERT INTO rideshare_iceberg_catalog.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg " + \
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
""";
*/
-- REMOVE EVERYTHING BELOW THIS LINE TO USE BigSpark
-- These tables ARE NOT Iceberg, they are here so the demo works in case you are NOT Allowlisted for Iceberg
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg` AS
SELECT payment_type_id,	
       payment_type_description	
 FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_payment_type_json`;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg` AS
SELECT location_id,	
       borough,
       zone,
       service_zone
 FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_zone_csv`;

	
-- https://cloud.google.com/bigquery/docs/loading-data-cloud-storage-avro#logical_types (for Avro)
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg` AS
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       CAST(TIMESTAMP_MICROS(pickup_datetime) AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       CAST(TIMESTAMP_MICROS(dropoff_datetime) AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       CAST(payment_type_id AS FLOAT64) AS payment_type_id,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount,
       CAST(NULL AS STRING) AS credit_card_number,
       CAST(NULL AS DATE) AS credit_card_expire_date,
       CAST(NULL AS STRING) AS credit_card_cvv_code,
       CAST(FORMAT_DATE('%Y-%m-01',cast(timestamp_micros(pickup_datetime) AS date)) AS DATE) AS partition_date
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_avro`
UNION ALL
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       CAST(payment_type_id AS FLOAT64) AS payment_type_id,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount,
       CAST(NULL AS STRING) AS credit_card_number,
       CAST(NULL AS DATE) AS credit_card_expire_date,
       CAST(NULL AS STRING) AS credit_card_cvv_code,
       CAST(partition_date AS DATE) AS partition_date
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_json`
UNION ALL
SELECT CAST(rideshare_trip_id AS STRING) AS rideshare_trip_id,
       CAST(pickup_location_id AS INTEGER) AS pickup_location_id,
       CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
       CAST(dropoff_location_id AS INTEGER) AS dropoff_location_id,
       CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
       CAST(ride_distance AS FLOAT64) AS ride_distance,
       CAST(is_airport AS BOOLEAN) AS is_airport,
       CAST(payment_type_id AS FLOAT64) AS payment_type_id,
       CAST(fare_amount AS FLOAT64) AS fare_amount,
       CAST(tip_amount AS FLOAT64) AS tip_amount,
       CAST(taxes_amount AS FLOAT64) AS taxes_amount,
       CAST(total_amount AS FLOAT64) AS total_amount,
       CAST(NULL AS STRING) AS credit_card_number,
       CAST(NULL AS DATE) AS credit_card_expire_date,
       CAST(NULL AS STRING) AS credit_card_cvv_code,
       CAST(partition_date AS DATE) AS partition_date
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_trip_parquet`;
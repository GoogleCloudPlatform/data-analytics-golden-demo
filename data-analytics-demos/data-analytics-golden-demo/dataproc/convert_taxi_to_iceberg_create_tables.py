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
# Summary: Opens the taxi parquet files and renames the fields as well as partitions the data.
#          The data is saved as Apache Iceberg format

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys


def ConvertTaxiData(sourceYellow, sourceGreen, icebergWarehouse):
    print("ConvertTaxiData: sourceYellow: ",sourceYellow)
    print("ConvertTaxiData: sourceGreen:  ",sourceGreen)
    print("ConvertTaxiData: icebergWarehouse:  ",icebergWarehouse)

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
        .appName("ConvertTaxiData") \
        .getOrCreate()

    ##############################################################################################################
    # Green
    ##############################################################################################################
    df_source = spark.read.parquet(sourceGreen)
    
    # Change datatypes (FLOAT to INT)
    df_source = df_source \
        .withColumn("NEW_Passenger_Count",col("passenger_count").cast(IntegerType())) \
        .withColumn("NEW_Rate_Code_Id",col("RatecodeID").cast(IntegerType())) \
        .withColumn("NEW_Payment_Type_Id",col("payment_type").cast(IntegerType()))
            
    # Drop columns
    df_source = df_source \
        .drop("passenger_count") \
        .drop("RatecodeID")
     
    df_rename = df_source.withColumnRenamed("VendorID", "Vendor_Id") \
        .withColumnRenamed("lpep_pickup_datetime", "Pickup_DateTime") \
        .withColumnRenamed("lpep_dropoff_datetime", "Dropoff_DateTime") \
        .withColumnRenamed("store_and_fwd_flag", "Store_And_Forward") \
        .withColumnRenamed("NEW_Passenger_Count", "Passenger_Count") \
        .withColumnRenamed("trip_distance", "Trip_Distance") \
        .withColumnRenamed("NEW_Rate_Code_Id", "Rate_Code_Id") \
        .withColumnRenamed("fare_amount", "Fare_Amount") \
        .withColumnRenamed("extra", "Surcharge") \
        .withColumnRenamed( "mta_tax", "MTA_Tax") \
        .withColumnRenamed("tip_amount", "Tip_Amount") \
        .withColumnRenamed("tolls_amount", "Tolls_Amount") \
        .withColumnRenamed("ehail_fee", "Ehail_Fee") \
        .withColumnRenamed("improvement_surcharge", "Improvement_Surcharge") \
        .withColumnRenamed("total_amount", "Total_Amount") \
        .withColumnRenamed("NEW_Payment_Type_Id", "Payment_Type_Id") \
        .withColumnRenamed("trip_type", "Trip_Type") \
        .withColumnRenamed("congestion_surcharge", "Congestion_Surcharge")

    df_new_column_order = df_rename.select( \
        'Vendor_Id', \
        'Pickup_DateTime', \
        'Dropoff_DateTime', \
        'Store_And_Forward', \
        'Rate_Code_Id', \
        'PULocationID', \
        'DOLocationID', \
        'Passenger_Count', \
        'Trip_Distance', \
        'Fare_Amount', \
        'Surcharge', \
        'MTA_Tax', \
        'Tip_Amount', \
        'Tolls_Amount', \
        'Ehail_Fee', \
        'Improvement_Surcharge', \
        'Total_Amount', \
        'Payment_Type_Id', \
        'Trip_Type', \
        'Congestion_Surcharge' \
    )

    # Note the IsIn is used since future dates can be in the files???
    df_with_partition_cols = df_new_column_order \
        .withColumn("year",  year      (col("Pickup_DateTime"))) \
        .withColumn("month", month     (col("Pickup_DateTime"))) \
        .filter(year(col("Pickup_DateTime")).isin (2019,2020,2021,2022))

    # Tests
    # query = "CREATE TABLE local.default.mytable (id bigint, data string) USING iceberg"
    # spark.sql(query)
    # query = "INSERT INTO local.default.mytable VALUES (1, 'a'), (2, 'b')"
    # spark.sql(query)

    # Used during testing to clean up an existing table
    # sql = "DROP TABLE local.default.taxi_trips"
    # spark.sql(sql)

    # Write as Iceberg
    create_green_taxi_trips = \
        """CREATE OR REPLACE TABLE local.default.green_taxi_trips (
                Vendor_Id INT,
                Pickup_DateTime TIMESTAMP,
                Dropoff_DateTime TIMESTAMP,
                Store_And_Forward STRING,
                Rate_Code_Id INT,
                PULocationID INT,
                DOLocationID INT,
                Passenger_Count INT,
                Trip_Distance FLOAT,
                Fare_Amount FLOAT,
                Surcharge FLOAT,
                MTA_Tax FLOAT,
                Tip_Amount FLOAT,
                Tolls_Amount FLOAT,
                Ehail_Fee FLOAT,
                Improvement_Surcharge FLOAT,
                Total_Amount FLOAT,
                Payment_Type_Id INT,
                Trip_Type FLOAT,
                Congestion_Surcharge FLOAT,
                year INT,
                month INT)
            USING iceberg
            PARTITIONED BY (year, month)"""

    spark.sql(create_green_taxi_trips)

    # Partition names are case sensative
    # The data must be sorted or you get the error:
    # java.lang.IllegalStateException: Incoming records violate the writer assumption that records are clustered by spec and by partition within each spec. Either cluster the incoming records or switch to fanout writers.
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .sortWithinPartitions("year", "month") \
        .write \
        .format("iceberg") \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .save("local.default.green_taxi_trips")


    ##############################################################################################################
    # Yellow
    ##############################################################################################################
    df_source = spark.read.parquet(sourceYellow)

    # Change datatypes (FLOAT to INT)
    df_source = df_source \
        .withColumn("NEW_Passenger_Count",col("passenger_count").cast(IntegerType())) \
        .withColumn("NEW_Rate_Code_Id",col("RatecodeID").cast(IntegerType()))

    # Drop columns
    # airport_fee: causes issues since the datatype id INT for 2019 and FLOAT for 2020+
    df_source = df_source \
        .drop("airport_fee") \
        .drop("passenger_count") \
        .drop("RatecodeID")  

    df_rename = df_source.withColumnRenamed("VendorID", "Vendor_Id") \
        .withColumnRenamed("tpep_pickup_datetime", "Pickup_DateTime") \
        .withColumnRenamed("tpep_dropoff_datetime", "Dropoff_DateTime") \
        .withColumnRenamed("NEW_Passenger_Count", "Passenger_Count") \
        .withColumnRenamed("trip_distance", "Trip_Distance") \
        .withColumnRenamed("NEW_Rate_Code_Id", "Rate_Code_Id") \
        .withColumnRenamed("store_and_fwd_flag", "Store_And_Forward") \
        .withColumnRenamed("payment_type", "Payment_Type_Id") \
        .withColumnRenamed("fare_amount", "Fare_Amount") \
        .withColumnRenamed("extra", "Surcharge") \
        .withColumnRenamed("mta_tax", "MTA_Tax") \
        .withColumnRenamed("tip_amount", "Tip_Amount") \
        .withColumnRenamed("tolls_amount", "Tolls_Amount") \
        .withColumnRenamed("improvement_surcharge", "Improvement_Surcharge") \
        .withColumnRenamed("total_amount", "Total_Amount") \
        .withColumnRenamed("congestion_surcharge", "Congestion_Surcharge")

    df_new_column_order = df_rename.select( \
        'Vendor_Id', \
        'Pickup_DateTime', \
        'Dropoff_DateTime', \
        'Passenger_Count', \
        'Trip_Distance', \
        'Rate_Code_Id', \
        'Store_And_Forward', \
        'PULocationID', \
        'DOLocationID', \
        'Payment_Type_Id', \
        'Fare_Amount', \
        'Surcharge', \
        'MTA_Tax', \
        'Tip_Amount', \
        'Tolls_Amount', \
        'Improvement_Surcharge', \
        'Total_Amount', \
        'Congestion_Surcharge' \
        )

    df_with_partition_cols = df_new_column_order \
        .withColumn("year",  year      (col("Pickup_DateTime"))) \
        .withColumn("month", month     (col("Pickup_DateTime"))) \
        .filter(year(col("Pickup_DateTime")).isin (2019,2020,2021,2022))    

    # Write as Iceberg
    create_yellow_taxi_trips = \
        """CREATE OR REPLACE TABLE local.default.yellow_taxi_trips (
                Vendor_Id INTEGER,
                Pickup_DateTime TIMESTAMP,
                Dropoff_DateTime TIMESTAMP,
                Passenger_Count INTEGER,
                Trip_Distance FLOAT,
                Rate_Code_Id INTEGER,
                Store_And_Forward STRING,
                PULocationID INTEGER,
                DOLocationID INTEGER,
                Payment_Type_Id INTEGER,
                Fare_Amount FLOAT,
                Surcharge FLOAT,
                MTA_Tax FLOAT,
                Tip_Amount FLOAT,
                Tolls_Amount FLOAT,
                Improvement_Surcharge FLOAT,
                Total_Amount FLOAT,
                Congestion_Surcharge FLOAT,
                year INTEGER,
                month INTEGER)
            USING iceberg
            PARTITIONED BY (year, month)"""

    spark.sql(create_yellow_taxi_trips)

    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .sortWithinPartitions("year", "month") \
        .write \
        .format("iceberg") \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .save("local.default.yellow_taxi_trips")

    spark.stop()


# Main entry point
# convert_taxi_to_iceberg_create_tables gs://${rawBucket}/raw/taxi-data/yellow/*/*.parquet gs://${rawBucket}/raw/taxi-data/green/*/*.parquet gs://${processedBucket}/iceberg-warehouse
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: convert_taxi_to_iceberg_create_tables sourceYellow sourceGreen icebergWarehouse")
        sys.exit(-1)

    sourceYellow     = sys.argv[1]
    sourceGreen      = sys.argv[2]
    icebergWarehouse = sys.argv[3]

    print ("BEGIN: Main")
    ConvertTaxiData(sourceYellow, sourceGreen, icebergWarehouse)
    print ("END: Main")


# Sample run 
"""
project="REPLACE-ME"
dataproceTempBucketName="REPLACE-ME"

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

gsutil cp ./dataproc/convert_taxi_to_iceberg_create_tables.py gs://${rawBucket}/pyspark-code/convert_taxi_to_iceberg_create_tables.py

gcloud dataproc jobs submit pyspark  \
   --cluster "iceberg-cluster" \
   --region="REPLACE-REGION" \
   --project="${project}" \
   --jars ./dataproc/iceberg-spark-runtime-3.1_2.12-0.14.0.jar \
   gs://${rawBucket}/pyspark-code/convert_taxi_to_iceberg_create_tables.py \
   -- gs://${rawBucket}/raw/taxi-data/yellow/*/*.parquet \
      gs://${rawBucket}/raw/taxi-data/green/*/*.parquet \
      gs://${processedBucket}/iceberg-warehouse

gcloud dataproc clusters delete iceberg-cluster --region REPLACE-REGION --project="${project}"
"""
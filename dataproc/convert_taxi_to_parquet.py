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
# Summary: Convert the download CSV Taxi data to Parquet, CSV and JSON formats in a partitioned structure

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys


def ConvertTaxiData(sourceYellowCSV, sourceGreenCSV, destination):
    print("ConvertTaxiData: sourceYellowCSV: ",sourceYellowCSV)
    print("ConvertTaxiData: sourceGreenCSV:  ",sourceGreenCSV)
    print("ConvertTaxiData: destination:     ",destination)

    spark = SparkSession \
        .builder \
        .appName("ConvertTaxiData") \
        .getOrCreate()


    ################################################################################################
    # Yellow
    ################################################################################################
    # Yellow Schema for 2019 / 2020 / 2021
    # 2021 VendorID,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,RatecodeID,store_and_fwd_flag,PULocationID,DOLocationID,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge
    # 2020 VendorID,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,RatecodeID,store_and_fwd_flag,PULocationID,DOLocationID,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge
    # 2019 VendorID,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,RatecodeID,store_and_fwd_flag,PULocationID,DOLocationID,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge
    yellowSchema = StructType([
        StructField('Vendor_Id', IntegerType(), True),
        StructField('Pickup_DateTime', TimestampType(), True),
        StructField('Dropoff_DateTime', TimestampType(), True),
        StructField('Passenger_Count', IntegerType(), True),
        StructField('Trip_Distance', DoubleType(), True),
        StructField('Rate_Code_Id', IntegerType(), True),
        StructField('Store_And_Forward', StringType(), True),
        StructField('PULocationID', IntegerType(), True),
        StructField('DOLocationID', IntegerType(), True),
        StructField('Payment_Type_Id', IntegerType(), True),
        StructField('Fare_Amount', DoubleType(), True),
        StructField('Surcharge', DoubleType(), True),
        StructField('MTA_Tax', DoubleType(), True),
        StructField('Tip_Amount', DoubleType(), True),
        StructField('Tolls_Amount', DoubleType(), True),
        StructField('Improvement_Surcharge', DoubleType(), True),
        StructField('Total_Amount', DoubleType(), True),
        StructField('Congestion_Surcharge', DoubleType(), True)
        ])

    df = spark.read.format("csv") \
        .option("header", True) \
        .schema(yellowSchema) \
        .load(sourceYellowCSV)

    df_with_partition_cols = df \
        .withColumn("year",  year      (col("Pickup_DateTime"))) \
        .withColumn("month", month     (col("Pickup_DateTime"))) \
        .filter(year(col("Pickup_DateTime")).isin (2019,2020,2021))

    # Write as Parquet
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .parquet(destination + "yellow/trips_table/parquet")

    # Write as CSV
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .format("csv") \
        .option('header',True) \
        .save(destination + "yellow/trips_table/csv")

    # Write as JSON
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .format("json") \
        .save(destination + "yellow/trips_table/json")


    ################################################################################################
    # Green
    ################################################################################################
    # 2021 VendorID,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,RatecodeID,PULocationID,DOLocationID,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type,congestion_surcharge
    # 2020 VendorID,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,RatecodeID,PULocationID,DOLocationID,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type,congestion_surcharge
    # 2019 VendorID,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,RatecodeID,PULocationID,DOLocationID,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type,congestion_surcharge
    greenSchema = StructType([
        StructField('Vendor_Id', IntegerType(), True),
        StructField('Pickup_DateTime', TimestampType(), True),
        StructField('Dropoff_DateTime', TimestampType(), True),
        StructField('Store_And_Forward', StringType(), True),
        StructField('Rate_Code_Id', IntegerType(), True),
        StructField('PULocationID', IntegerType(), True),
        StructField('DOLocationID', IntegerType(), True),
        StructField('Passenger_Count', IntegerType(), True),
        StructField('Trip_Distance', DoubleType(), True),
        StructField('Fare_Amount', DoubleType(), True),
        StructField('Surcharge', DoubleType(), True),
        StructField('MTA_Tax', DoubleType(), True),
        StructField('Tip_Amount', DoubleType(), True),
        StructField('Tolls_Amount', DoubleType(), True),
        StructField('Ehail_Fee', DoubleType(), True),
        StructField('Improvement_Surcharge', DoubleType(), True),
        StructField('Total_Amount', DoubleType(), True),
        StructField('Payment_Type_Id', IntegerType(), True),
        StructField('Trip_Type', StringType(), True),
        StructField('Congestion_Surcharge', DoubleType(), True)
        ])

    df = spark.read.format("csv") \
        .option("header", True) \
        .schema(greenSchema) \
        .load(sourceGreenCSV)

    df_with_partition_cols = df \
        .withColumn("year",  year      (col("Pickup_DateTime"))) \
        .withColumn("month", month     (col("Pickup_DateTime"))) \
        .filter(year(col("Pickup_DateTime")).isin (2019,2020,2021))

    # Write as Parquet
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .parquet(destination + "green/trips_table/parquet")

    # Write as CSV
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .format("csv") \
        .option('header',True) \
        .save(destination + "green/trips_table/csv")

    # Write as JSON
    df_with_partition_cols \
        .repartition(5) \
        .coalesce(5) \
        .write \
        .mode("overwrite") \
        .partitionBy("year","month") \
        .format("json") \
        .save(destination + "green/trips_table/json")


    ################################################################################################
    # Create Common Tables 
    ################################################################################################
    # Vendor Table
    vendor_df = spark.createDataFrame(
        [
            (1, "Creative Mobile Technologies"), 
            (2, "VeriFone")
        ],
        ["Vendor_Id", "Vendor_Description"] 
    )        

    vendor_df \
        .repartition(1) \
        .coalesce(1) \
        .write \
        .mode("overwrite") \
        .parquet(destination + "vendor_table/")

    # Rate Code Table
    rate_code_df = spark.createDataFrame(
        [
            (1, "Standard rate"), 
            (2, "JFK"),
            (3, "Newark"),
            (4, "Nassau or Westchester"),
            (5, "Negotiated fare"),
            (6, "Group ride"),
        ],
        ["Rate_Code_Id", "Rate_Code_Description"] 
    )        

    rate_code_df \
        .repartition(1) \
        .coalesce(1) \
        .write \
        .mode("overwrite") \
        .parquet(destination + "rate_code_table/")

    # Payment Type Table
    payment_type_df = spark.createDataFrame(
        [
            (1, "Credit card"), 
            (2, "Cash"),
            (3, "No charge"),
            (4, "Dispute"),
            (5, "Unknown"),
            (6, "Voided trip"),
        ],
        ["Payment_Type_Id", "Payment_Type_Description"] 
    )        

    payment_type_df \
        .repartition(1) \
        .coalesce(1) \
        .write \
        .mode("overwrite") \
        .parquet(destination + "payment_type_table/")

    # Trip Type Table
    trip_type_df = spark.createDataFrame(
        [
            (1, "Street-hail"),
            (2, "Dispatch")
        ],
        ["Trip_Type_Id", "Trip_Type_Description"] 
    )        

    trip_type_df \
        .repartition(1) \
        .coalesce(1) \
        .write \
        .mode("overwrite") \
        .parquet(destination + "trip_type_table/")

    spark.stop()


# Main entry point
# convert_taxi_to_parquet gs://big-query-demo-09/test-taxi/yellow gs://big-query-demo-09/test-taxi/green gs://big-query-demo-09/test-taxi-output
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: convert_taxi_to_parquet sourceYellowCSV sourceGreenCSV destination")
        sys.exit(-1)

    sourceYellowCSV = sys.argv[1]
    sourceGreenCSV  = sys.argv[2]
    destination     = sys.argv[3]

    print ("BEGIN: Main")
    ConvertTaxiData(sourceYellowCSV, sourceGreenCSV, destination)
    print ("END: Main")

# Sample run 
# gcloud dataproc jobs submit pyspark  \
#    --cluster "testcluster" \
#    --region="us-west2" \
#    gs://big-query-demo-09/pyspark-code/convert_taxi_to_parquet.py \
#    -- gs://big-query-demo-09/test-taxi/yellow/*/*.csv \
#       gs://big-query-demo-09/test-taxi/green/*/*.csv \
#       gs://big-query-demo-09/test-taxi/dest/
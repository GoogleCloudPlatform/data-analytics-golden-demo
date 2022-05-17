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

# Note: NYC changes from CSV to Parquet format, this file has been updated on 05/16/2022

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys


def ConvertTaxiData(sourceYellow, sourceGreen, destination):
    print("ConvertTaxiData: sourceYellow: ",sourceYellow)
    print("ConvertTaxiData: sourceGreen:  ",sourceGreen)
    print("ConvertTaxiData: destination:  ",destination)

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

    """
    RENAME: VendorID	INTEGER	NULLABLE		
    RENAME: tpep_pickup_datetime	TIMESTAMP	NULLABLE		
    RENAME: tpep_dropoff_datetime	TIMESTAMP	NULLABLE		
    RENAME: passenger_count	FLOAT	NULLABLE		
    RENAME: trip_distance	FLOAT	NULLABLE		
    RENAME: RatecodeID	FLOAT	NULLABLE		
    RENAME: store_and_fwd_flag	STRING	NULLABLE		
    PULocationID	INTEGER	NULLABLE		
    DOLocationID	INTEGER	NULLABLE		
    RENAME: payment_type	INTEGER	NULLABLE		
    RENAME: fare_amount	FLOAT	NULLABLE		
    RENAME: (Surcharge) extra	FLOAT	NULLABLE		
    RENAME: mta_tax	FLOAT	NULLABLE		
    RENAME: tip_amount	FLOAT	NULLABLE		
    RENAME: tolls_amount	FLOAT	NULLABLE		
    RENAME: improvement_surcharge	FLOAT	NULLABLE		
    RENAME: total_amount	FLOAT	NULLABLE		
    RENAME: congestion_surcharge	FLOAT	NULLABLE		
    NEW: airport_fee	INTEGER	NULLABLE		
    """

    """
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
    """

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
    """
    df_new_column_order = df_rename \
        .withColumn("Vendor_Id",col("Vendor_Id")) \
        .withColumn("Pickup_DateTime",col("Pickup_DateTime")) \
        .withColumn("Dropoff_DateTime",col("Dropoff_DateTime")) \
        .withColumn("Passenger_Count",col("Passenger_Count")) \
        .withColumn("Trip_Distance",col("Trip_Distance")) \
        .withColumn("Rate_Code_Id",col("Rate_Code_Id")) \
        .withColumn("Store_And_Forward",col("Store_And_Forward")) \
        .withColumn("PULocationID",col("PULocationID")) \
        .withColumn("DOLocationID",col("DOLocationID")) \
        .withColumn("Payment_Type_Id",col("Payment_Type_Id")) \
        .withColumn("Fare_Amount",col("Fare_Amount")) \
        .withColumn("Surcharge",col("Surcharge")) \
        .withColumn("MTA_Tax",col("MTA_Tax")) \
        .withColumn("Tip_Amount",col("Tip_Amount")) \
        .withColumn("Tolls_Amount",col("Tolls_Amount")) \
        .withColumn("Improvement_Surcharge",col("Improvement_Surcharge")) \
        .withColumn("Total_Amount",col("Total_Amount")) \
        .withColumn("Congestion_Surcharge",col("Congestion_Surcharge"))
    """

    df_with_partition_cols = df_new_column_order \
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
    
    """
    VendorID	INTEGER	NULLABLE		
    lpep_pickup_datetime	TIMESTAMP	NULLABLE		
    lpep_dropoff_datetime	TIMESTAMP	NULLABLE		
    store_and_fwd_flag	STRING	NULLABLE		
    RatecodeID	FLOAT	NULLABLE		
    PULocationID	INTEGER	NULLABLE		
    DOLocationID	INTEGER	NULLABLE		
    passenger_count	FLOAT	NULLABLE		
    trip_distance	FLOAT	NULLABLE		
    fare_amount	FLOAT	NULLABLE		
    extra	FLOAT	NULLABLE		
    mta_tax	FLOAT	NULLABLE		
    tip_amount	FLOAT	NULLABLE		
    tolls_amount	FLOAT	NULLABLE		
    ehail_fee	FLOAT	NULLABLE		
    improvement_surcharge	FLOAT	NULLABLE		
    total_amount	FLOAT	NULLABLE		
    payment_type	FLOAT	NULLABLE		
    trip_type	FLOAT	NULLABLE		
    congestion_surcharge	FLOAT	NULLABLE
    """

    """
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
    """

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

    """
    df_new_column_order = df_rename \
        .withColumn("Vendor_Id",col("Vendor_Id")) \
        .withColumn("Pickup_DateTime",col("Pickup_DateTime")) \
        .withColumn("Dropoff_DateTime",col("Dropoff_DateTime")) \
        .withColumn("Store_And_Forward",col("Store_And_Forward")) \
        .withColumn("Rate_Code_Id",col("Rate_Code_Id")) \
        .withColumn("PULocationID",col("PULocationID")) \
        .withColumn("DOLocationID",col("DOLocationID")) \
        .withColumn("Passenger_Count",col("Passenger_Count")) \
        .withColumn("Trip_Distance",col("Trip_Distance")) \
        .withColumn("Fare_Amount",col("Fare_Amount")) \
        .withColumn("Surcharge",col("Surcharge")) \
        .withColumn("MTA_Tax",col("MTA_Tax")) \
        .withColumn("Tip_Amount",col("Tip_Amount")) \
        .withColumn("Tolls_Amount",col("Tolls_Amount")) \
        .withColumn("Ehail_Fee",col("Ehail_Fee")) \
        .withColumn("Improvement_Surcharge",col("Improvement_Surcharge")) \
        .withColumn("Total_Amount",col("Total_Amount")) \
        .withColumn("Payment_Type_Id",col("Payment_Type_Id")) \
        .withColumn("Trip_Type",col("Trip_Type")) \
        .withColumn("Congestion_Surcharge",col("Congestion_Surcharge")) 
    """

    df_with_partition_cols = df_new_column_order \
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
        print("Usage: convert_taxi_to_parquet sourceYellow sourceGreen destination")
        sys.exit(-1)

    sourceYellow = sys.argv[1]
    sourceGreen  = sys.argv[2]
    destination  = sys.argv[3]

    print ("BEGIN: Main")
    ConvertTaxiData(sourceYellow, sourceGreen, destination)
    print ("END: Main")

# Sample run 
# gcloud dataproc jobs submit pyspark  \
#    --cluster "testcluster" \
#    --region="us-west2" \
#    gs://big-query-demo-09/pyspark-code/convert_taxi_to_parquet.py \
#    -- gs://big-query-demo-09/test-taxi/yellow/*/*.parquet \
#       gs://big-query-demo-09/test-taxi/green/*/*.parquet \
#       gs://big-query-demo-09/test-taxi/dest/
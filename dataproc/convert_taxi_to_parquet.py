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


# All the data cannot be read at once since MergeSchema does not work for the NYC data
def ProcessGreenFile(spark, filenameAndPath):
    df_source = spark.read.option("mergeSchema", "true").parquet(filenameAndPath)

    print("ProcessGreenFile: filenameAndPath: ",filenameAndPath)

    df_TypeCast = df_source \
        .withColumn("Vendor_ID",col("VendorID").cast(IntegerType())) \
        .withColumn("Pickup_DateTime",col("lpep_pickup_datetime").cast(TimestampType())) \
        .withColumn("Dropoff_DateTime",col("lpep_dropoff_datetime").cast(TimestampType())) \
        .withColumn("Store_And_Forward",col("store_and_fwd_flag").cast(StringType())) \
        .withColumn("Rate_Code_Id",col("RatecodeID").cast(IntegerType())) \
        .withColumn("PULocationID",col("PULocationID").cast(IntegerType())) \
        .withColumn("DOLocationID",col("DOLocationID").cast(IntegerType())) \
        .withColumn("Passenger_Count",col("passenger_count").cast(IntegerType())) \
        .withColumn("Trip_Distance",col("trip_distance").cast(DoubleType())) \
        .withColumn("Fare_Amount",col("fare_amount").cast(DoubleType())) \
        .withColumn("Surcharge",col("extra").cast(DoubleType())) \
        .withColumn("MTA_Tax",col("mta_tax").cast(DoubleType())) \
        .withColumn("Tip_Amount",col("tip_amount").cast(DoubleType())) \
        .withColumn("Tolls_Amount",col("tolls_amount").cast(DoubleType())) \
        .withColumn("Ehail_Fee",col("ehail_fee").cast(DoubleType())) \
        .withColumn("Improvement_Surcharge",col("improvement_surcharge").cast(DoubleType())) \
        .withColumn("Total_Amount",col("total_amount").cast(DoubleType())) \
        .withColumn("Payment_Type_Id",col("payment_type").cast(IntegerType())) \
        .withColumn("Trip_Type",col("trip_type").cast(IntegerType())) \
        .withColumn("Congestion_Surcharge",col("congestion_surcharge").cast(DoubleType()))

    df_result = df_TypeCast.select( \
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
   
    return df_result


# All the data cannot be read at once since MergeSchema does not work for the NYC data
def ProcessYellowFile(spark, filenameAndPath):
    df_source = spark.read.parquet(filenameAndPath)

    print("ProcessYellowFile: filenameAndPath: ",filenameAndPath)

    df_TypeCast = df_source \
        .withColumn("Vendor_ID",col("VendorID").cast(IntegerType())) \
        .withColumn("Pickup_DateTime",col("tpep_pickup_datetime").cast(TimestampType())) \
        .withColumn("Dropoff_DateTime",col("tpep_dropoff_datetime").cast(TimestampType())) \
        .withColumn("Passenger_Count",col("passenger_count").cast(IntegerType())) \
        .withColumn("Trip_Distance",col("trip_distance").cast(DoubleType())) \
        .withColumn("Rate_Code_Id",col("RatecodeID").cast(IntegerType())) \
        .withColumn("Store_And_Forward",col("store_and_fwd_flag").cast(StringType())) \
        .withColumn("PULocationID",col("PULocationID").cast(IntegerType())) \
        .withColumn("DOLocationID",col("DOLocationID").cast(IntegerType())) \
        .withColumn("Payment_Type_Id",col("payment_type").cast(IntegerType())) \
        .withColumn("Fare_Amount",col("fare_amount").cast(DoubleType())) \
        .withColumn("Surcharge",col("extra").cast(DoubleType())) \
        .withColumn("MTA_Tax",col("mta_tax").cast(DoubleType())) \
        .withColumn("Tip_Amount",col("tip_amount").cast(DoubleType())) \
        .withColumn("Tolls_Amount",col("tolls_amount").cast(DoubleType())) \
        .withColumn("Improvement_Surcharge",col("improvement_surcharge").cast(DoubleType())) \
        .withColumn("Total_Amount",col("total_amount").cast(DoubleType())) \
        .withColumn("Congestion_Surcharge",col("congestion_surcharge").cast(DoubleType()))
        #.withColumn("Airport_Fee",col("airport_fee").cast(DoubleType()))

    df_result = df_TypeCast.select( \
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
    
    return df_result


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
    yellow_path = sourceYellow.replace("/*/*.parquet","")

    # The NYC taxi data has fields that change data types and some are incompatible with mergeScheme   
    # 2019
    yellow_tripdata_2019_01 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-01.parquet")
    yellow_tripdata_2019_02 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-02.parquet")
    yellow_tripdata_2019_03 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-03.parquet")
    yellow_tripdata_2019_04 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-04.parquet")
    yellow_tripdata_2019_05 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-05.parquet")
    yellow_tripdata_2019_06 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-06.parquet")
    yellow_tripdata_2019_07 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-07.parquet")
    yellow_tripdata_2019_08 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-08.parquet")
    yellow_tripdata_2019_09 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-09.parquet")
    yellow_tripdata_2019_10 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-10.parquet")
    yellow_tripdata_2019_11 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-11.parquet")
    yellow_tripdata_2019_12 = ProcessYellowFile(spark,f"{yellow_path}/2019/yellow_tripdata_2019-12.parquet")

    # 2020
    yellow_tripdata_2020_01 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-01.parquet")
    yellow_tripdata_2020_02 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-02.parquet")
    yellow_tripdata_2020_03 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-03.parquet")
    yellow_tripdata_2020_04 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-04.parquet")
    yellow_tripdata_2020_05 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-05.parquet")
    yellow_tripdata_2020_06 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-06.parquet")
    yellow_tripdata_2020_07 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-07.parquet")
    yellow_tripdata_2020_08 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-08.parquet")
    yellow_tripdata_2020_09 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-09.parquet")
    yellow_tripdata_2020_10 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-10.parquet")
    yellow_tripdata_2020_11 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-11.parquet")
    yellow_tripdata_2020_12 = ProcessYellowFile(spark,f"{yellow_path}/2020/yellow_tripdata_2020-12.parquet")

    # 2021
    yellow_tripdata_2021_01 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-01.parquet")
    yellow_tripdata_2021_02 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-02.parquet")
    yellow_tripdata_2021_03 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-03.parquet")
    yellow_tripdata_2021_04 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-04.parquet")
    yellow_tripdata_2021_05 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-05.parquet")
    yellow_tripdata_2021_06 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-06.parquet")
    yellow_tripdata_2021_07 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-07.parquet")
    yellow_tripdata_2021_08 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-08.parquet")
    yellow_tripdata_2021_09 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-09.parquet")
    yellow_tripdata_2021_10 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-10.parquet")
    yellow_tripdata_2021_11 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-11.parquet")
    yellow_tripdata_2021_12 = ProcessYellowFile(spark,f"{yellow_path}/2021/yellow_tripdata_2021-12.parquet")

    # 2022
    yellow_tripdata_2022_01 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-01.parquet")
    yellow_tripdata_2022_02 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-02.parquet")
    yellow_tripdata_2022_03 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-03.parquet")
    yellow_tripdata_2022_04 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-04.parquet")
    yellow_tripdata_2022_05 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-05.parquet")
    yellow_tripdata_2022_06 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-06.parquet")
    yellow_tripdata_2022_07 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-07.parquet")
    yellow_tripdata_2022_08 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-08.parquet")
    yellow_tripdata_2022_09 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-09.parquet")
    yellow_tripdata_2022_10 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-10.parquet")
    yellow_tripdata_2022_11 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-11.parquet")
    yellow_tripdata_2022_12 = ProcessYellowFile(spark,f"{yellow_path}/2022/yellow_tripdata_2022-12.parquet")

    # 2023
    yellow_tripdata_2023_01 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-01.parquet")
    yellow_tripdata_2023_02 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-02.parquet")
    yellow_tripdata_2023_03 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-03.parquet")
    yellow_tripdata_2023_04 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-04.parquet")
    yellow_tripdata_2023_05 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-05.parquet")
    yellow_tripdata_2023_06 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-06.parquet")
    yellow_tripdata_2023_07 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-07.parquet")
    yellow_tripdata_2023_08 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-08.parquet")
    yellow_tripdata_2023_09 = ProcessYellowFile(spark,f"{yellow_path}/2023/yellow_tripdata_2023-09.parquet")

    # Merge everything together (we should have all the same schema now)
    df_yellow_final = yellow_tripdata_2019_01 \
        .union(yellow_tripdata_2019_02) \
        .union(yellow_tripdata_2019_03) \
        .union(yellow_tripdata_2019_04) \
        .union(yellow_tripdata_2019_05) \
        .union(yellow_tripdata_2019_06) \
        .union(yellow_tripdata_2019_07) \
        .union(yellow_tripdata_2019_08) \
        .union(yellow_tripdata_2019_09) \
        .union(yellow_tripdata_2019_10) \
        .union(yellow_tripdata_2019_11) \
        .union(yellow_tripdata_2019_12) \
        .union(yellow_tripdata_2020_01) \
        .union(yellow_tripdata_2020_02) \
        .union(yellow_tripdata_2020_03) \
        .union(yellow_tripdata_2020_04) \
        .union(yellow_tripdata_2020_05) \
        .union(yellow_tripdata_2020_06) \
        .union(yellow_tripdata_2020_07) \
        .union(yellow_tripdata_2020_08) \
        .union(yellow_tripdata_2020_09) \
        .union(yellow_tripdata_2020_10) \
        .union(yellow_tripdata_2020_11) \
        .union(yellow_tripdata_2020_12) \
        .union(yellow_tripdata_2021_01) \
        .union(yellow_tripdata_2021_02) \
        .union(yellow_tripdata_2021_03) \
        .union(yellow_tripdata_2021_04) \
        .union(yellow_tripdata_2021_05) \
        .union(yellow_tripdata_2021_06) \
        .union(yellow_tripdata_2021_07) \
        .union(yellow_tripdata_2021_08) \
        .union(yellow_tripdata_2021_09) \
        .union(yellow_tripdata_2021_10) \
        .union(yellow_tripdata_2021_11) \
        .union(yellow_tripdata_2021_12) \
        .union(yellow_tripdata_2022_01) \
        .union(yellow_tripdata_2022_02) \
        .union(yellow_tripdata_2022_03) \
        .union(yellow_tripdata_2022_04) \
        .union(yellow_tripdata_2022_05) \
        .union(yellow_tripdata_2022_06) \
        .union(yellow_tripdata_2022_07) \
        .union(yellow_tripdata_2022_08) \
        .union(yellow_tripdata_2022_09) \
        .union(yellow_tripdata_2022_10) \
        .union(yellow_tripdata_2022_11) \
        .union(yellow_tripdata_2022_12) \
        .union(yellow_tripdata_2023_01) \
        .union(yellow_tripdata_2023_02) \
        .union(yellow_tripdata_2023_03) \
        .union(yellow_tripdata_2023_04) \
        .union(yellow_tripdata_2023_05) \
        .union(yellow_tripdata_2023_06) \
        .union(yellow_tripdata_2023_07) \
        .union(yellow_tripdata_2023_08) \
        .union(yellow_tripdata_2023_09)

    df_with_partition_cols = df_yellow_final \
        .withColumn("year",  year      (col("Pickup_DateTime"))) \
        .withColumn("month", month     (col("Pickup_DateTime"))) \
        .filter("Pickup_DateTime >= '2019-01-01' AND Pickup_DateTime <= '2023-09-30'")

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
    green_path = sourceGreen.replace("/*/*.parquet","")
    
   # The NYC taxi data has fields that change data types and some are incompatible with mergeScheme   
    # 2019
    green_tripdata_2019_01 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-01.parquet")
    green_tripdata_2019_02 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-02.parquet")
    green_tripdata_2019_03 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-03.parquet")
    green_tripdata_2019_04 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-04.parquet")
    green_tripdata_2019_05 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-05.parquet")
    green_tripdata_2019_06 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-06.parquet")
    green_tripdata_2019_07 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-07.parquet")
    green_tripdata_2019_08 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-08.parquet")
    green_tripdata_2019_09 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-09.parquet")
    green_tripdata_2019_10 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-10.parquet")
    green_tripdata_2019_11 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-11.parquet")
    green_tripdata_2019_12 = ProcessGreenFile(spark,f"{green_path}/2019/green_tripdata_2019-12.parquet")

    # 2020
    green_tripdata_2020_01 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-01.parquet")
    green_tripdata_2020_02 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-02.parquet")
    green_tripdata_2020_03 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-03.parquet")
    green_tripdata_2020_04 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-04.parquet")
    green_tripdata_2020_05 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-05.parquet")
    green_tripdata_2020_06 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-06.parquet")
    green_tripdata_2020_07 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-07.parquet")
    green_tripdata_2020_08 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-08.parquet")
    green_tripdata_2020_09 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-09.parquet")
    green_tripdata_2020_10 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-10.parquet")
    green_tripdata_2020_11 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-11.parquet")
    green_tripdata_2020_12 = ProcessGreenFile(spark,f"{green_path}/2020/green_tripdata_2020-12.parquet")

    # 2021
    green_tripdata_2021_01 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-01.parquet")
    green_tripdata_2021_02 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-02.parquet")
    green_tripdata_2021_03 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-03.parquet")
    green_tripdata_2021_04 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-04.parquet")
    green_tripdata_2021_05 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-05.parquet")
    green_tripdata_2021_06 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-06.parquet")
    green_tripdata_2021_07 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-07.parquet")
    green_tripdata_2021_08 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-08.parquet")
    green_tripdata_2021_09 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-09.parquet")
    green_tripdata_2021_10 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-10.parquet")
    green_tripdata_2021_11 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-11.parquet")
    green_tripdata_2021_12 = ProcessGreenFile(spark,f"{green_path}/2021/green_tripdata_2021-12.parquet")

    # 2022
    green_tripdata_2022_01 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-01.parquet")
    green_tripdata_2022_02 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-02.parquet")
    green_tripdata_2022_03 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-03.parquet")
    green_tripdata_2022_04 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-04.parquet")
    green_tripdata_2022_05 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-05.parquet")
    green_tripdata_2022_06 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-06.parquet")
    green_tripdata_2022_07 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-07.parquet")
    green_tripdata_2022_08 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-08.parquet")
    green_tripdata_2022_09 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-09.parquet")
    green_tripdata_2022_10 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-10.parquet")
    green_tripdata_2022_11 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-11.parquet")
    green_tripdata_2022_12 = ProcessGreenFile(spark,f"{green_path}/2022/green_tripdata_2022-12.parquet")

    # 2023
    green_tripdata_2023_01 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-01.parquet")
    green_tripdata_2023_02 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-02.parquet")
    green_tripdata_2023_03 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-03.parquet")
    green_tripdata_2023_04 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-04.parquet")
    green_tripdata_2023_05 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-05.parquet")
    green_tripdata_2023_06 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-06.parquet")
    green_tripdata_2023_07 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-07.parquet")
    green_tripdata_2023_08 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-08.parquet")
    green_tripdata_2023_09 = ProcessGreenFile(spark,f"{green_path}/2023/green_tripdata_2023-09.parquet")

    # Merge everything together (we should have all the same schema now)
    df_green_final = green_tripdata_2019_01 \
        .union(green_tripdata_2019_02) \
        .union(green_tripdata_2019_03) \
        .union(green_tripdata_2019_04) \
        .union(green_tripdata_2019_05) \
        .union(green_tripdata_2019_06) \
        .union(green_tripdata_2019_07) \
        .union(green_tripdata_2019_08) \
        .union(green_tripdata_2019_09) \
        .union(green_tripdata_2019_10) \
        .union(green_tripdata_2019_11) \
        .union(green_tripdata_2019_12) \
        .union(green_tripdata_2020_01) \
        .union(green_tripdata_2020_02) \
        .union(green_tripdata_2020_03) \
        .union(green_tripdata_2020_04) \
        .union(green_tripdata_2020_05) \
        .union(green_tripdata_2020_06) \
        .union(green_tripdata_2020_07) \
        .union(green_tripdata_2020_08) \
        .union(green_tripdata_2020_09) \
        .union(green_tripdata_2020_10) \
        .union(green_tripdata_2020_11) \
        .union(green_tripdata_2020_12) \
        .union(green_tripdata_2021_01) \
        .union(green_tripdata_2021_02) \
        .union(green_tripdata_2021_03) \
        .union(green_tripdata_2021_04) \
        .union(green_tripdata_2021_05) \
        .union(green_tripdata_2021_06) \
        .union(green_tripdata_2021_07) \
        .union(green_tripdata_2021_08) \
        .union(green_tripdata_2021_09) \
        .union(green_tripdata_2021_10) \
        .union(green_tripdata_2021_11) \
        .union(green_tripdata_2021_12) \
        .union(green_tripdata_2022_01) \
        .union(green_tripdata_2022_02) \
        .union(green_tripdata_2022_03) \
        .union(green_tripdata_2022_04) \
        .union(green_tripdata_2022_05) \
        .union(green_tripdata_2022_06) \
        .union(green_tripdata_2022_07) \
        .union(green_tripdata_2022_08) \
        .union(green_tripdata_2022_09) \
        .union(green_tripdata_2022_10) \
        .union(green_tripdata_2022_11) \
        .union(green_tripdata_2022_12) \
        .union(green_tripdata_2023_01) \
        .union(green_tripdata_2023_02) \
        .union(green_tripdata_2023_03) \
        .union(green_tripdata_2023_04) \
        .union(green_tripdata_2023_05) \
        .union(green_tripdata_2023_06) \
        .union(green_tripdata_2023_07) \
        .union(green_tripdata_2023_08) \
        .union(green_tripdata_2023_09)

    df_with_partition_cols = df_green_final \
        .withColumn("year",  year      (col("Pickup_DateTime"))) \
        .withColumn("month", month     (col("Pickup_DateTime"))) \
        .filter("Pickup_DateTime >= '2019-01-01' AND Pickup_DateTime <= '2023-09-30'")

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
#    --region="REPLACE-REGION" \
#    gs://big-query-demo-09/pyspark-code/convert_taxi_to_parquet.py \
#    -- gs://big-query-demo-09/test-taxi/yellow/*/*.parquet \
#       gs://big-query-demo-09/test-taxi/green/*/*.parquet \
#       gs://big-query-demo-09/test-taxi/dest/
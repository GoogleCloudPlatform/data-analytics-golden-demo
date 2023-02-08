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


###################################################################################
# NOTE: This is a public preview feature and requires Allowlisting
#       Please contact your Google Account Team
###################################################################################

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField,  IntegerType, DoubleType, StringType

print("Create session")
spark = SparkSession.builder.appName('Load-Discount-Data').getOrCreate()

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
    .load('gs://${bucket_name}/bigspark/sample-bigspark-discount-data.csv')
 
print("Determine if discount is High, Medium or Low")
dfDiscount = dfDiscount.withColumn("discount_rate", F.expr("CASE WHEN discount < 10 THEN 'Low' WHEN discount < 20 THEN 'Medium' ELSE 'High' END"))

print("Display dataframe")
dfDiscount.show(5)

print("Saving results to BigQuery")
dfDiscount.write.format("bigquery") \
    .option("temporaryGcsBucket","${bucket_name}") \
    .option("table", "thelook_ecommerce.product_discounts") \
    .mode("overwrite") \
    .save()
    
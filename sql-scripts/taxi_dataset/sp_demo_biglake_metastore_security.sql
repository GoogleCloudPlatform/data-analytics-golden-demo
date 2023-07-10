/*
# NOTE: You need to delete the CREATE PROCEDURE above and comment this one out
#       You need to delete the two lines at the bottom
#           -- So this deploys via Terraform
#           SELECT 1;
#       You should also make sure the stored procedure has proper Python Indenting (it might get messed up from Terraform)
#       Edit the Stored Procedure and then replace Two Spaces with Zero spaces and then run to compile it
CREATE OR REPLACE PROCEDURE `${project_id}.${bigquery_taxi_dataset}.sp_demo_biglake_metastore_security`()
WITH CONNECTION `${project_id}.${bigquery_region}.bigspark-connection`
OPTIONS (engine='SPARK',
   runtime_version='1.0',
   properties=[("spark.sql.catalog.iceberg_catalog.gcp_project","${project_id}"),
   ("spark.sql.catalog.iceberg_catalog.catalog-impl","org.apache.iceberg.gcp.biglake.BigLakeCatalog"),
   ("spark.sql.catalog.iceberg_catalog.blms_catalog","iceberg_catalog"),
   ("spark.sql.catalog.iceberg_catalog","org.apache.iceberg.spark.SparkCatalog"),
   ("spark.sql.catalog.iceberg_catalog.gcp_location","${bigquery_region}"),
   ("spark.sql.catalog.iceberg_catalog.warehouse","gs://iceberg-catalog-${random_extension}/iceberg-warehouse"),
   ("spark.jars.packages","org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:0.14.1")],
   jar_uris=["gs://spark-lib/biglake/biglake-catalog-iceberg1.2.0-0.1.0-with-dependencies.jar"]
)
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
# YouTube:
#    - https://youtu.be/IQR9gJuLXbQ
#
# Use Cases:
#     - Runs a BigSpark job that will create an Iceberg table using the BigLake Metastore
# 
# Description: 
#     - Shows how to setup security with BigLake Metastore on each connection, storage account and dataset
#     
# Show:
#     - Creating an Iceberg Warehouse with BigLake Metastore
# 
# References:
#      - https://cloud.google.com/bigquery/docs/iceberg-tables#create-using-biglake-metastore
#  
#  Clean up / Reset script:
#      DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.iceberg_payment_type`;
#      * If you need to list and/or delete any catalogs (in case you mess things up and need to restart) *
#      https://cloud.google.com/bigquery/docs/reference/biglake/rest/v1alpha1/projects.locations.catalogs/list
#      List Catalogs BLMS
#      curl "https://biglake.googleapis.com/v1alpha1/projects/${project_id}/locations/${bigquery_region}/catalogs" --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" --header "Accept: application/json"
#      Delete a Catalog 
#      curl -X DELETE "https://biglake.googleapis.com/v1alpha1/[REPLACE-FROM-RESULTS-ABOVE -> the Name Field (e.g. projects/xxxxxx/locations/${bigquery_region}/catalogs/iceberg_catalog) END-REPLACE]" --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" --header "Accept: application/json"
#
# Objects:
# BigQuery Connection: This is a Spark Connection | ${bigquery_region}.bigspark-connection | The service account of this connection will execute the BigSpark code.  
#                      The service account for this connection needs to be able to run a dataproc serverless cluster.  
#                      This connection will call the ${bigquery_region}.biglake-connection to create the BigLake tables.
#                      * If using Dataproc (vs BigSpark) add the "${bigquery_region}".bigspark-connection" permission's the dataproc service account permissions.
# BigQuery Connection: This is a BigLake Connection | ${bigquery_region}.biglake-connection | The service account of this connection will be used for creating the BigLake tables in your dataset.  
# BigQuery Dataset: ${bigquery_taxi_dataset} | This is the dataset the BigLake tables will get created by the ${bigquery_region}.biglake-connection.  The BigLake tables will point to Iceberg tables.
# BigQuery Stored Proc: sp_demo_biglake_metastore_security | This is your BigSpark stored procedure. | 
# Storage Account: iceberg-catalog-${random_extension} | This is where your Iceberg catalog, warehouse and files will get created by the ${bigquery_region}.bigspark-connection’s service account.
# Storage Account: iceberg-source-data-${random_extension} | These are any buckets that you will read from by your spark code.
#
# Custom Role (create this):
# Custom Role: Permissions | CustomDelegate | Add permission "bigquery.connections.delegate"
#
# BigQuery Connection: ${bigquery_region}.bigspark-connection
# On iceberg-catalog-${random_extension} grant Storage Object Admin to the ${bigquery_region}.bigspark-connection service account | Access to write out the Iceberg files to storage
# On iceberg-source-data-${random_extension} grant Storage Object Viewer to the ${bigquery_region}.bigspark-connection service account | For Spark to read source data
# On the ${bigquery_region}.biglake-connection (press sharing) add CustomDelegate for the ${bigquery_region}.bigspark-connection service account | So the BigSpark connection can access the BigLake connection so the BigLake tables get created in BigQuery
# On the ${bigquery_taxi_dataset} add BigQuery Data Owner to the ${bigquery_region}.bigspark-connection service account | To drop the Iceberg table via Spark.  This triggers a drop in the BLMS so access to the dataset is needed.
# In IAM add BigLake Admin to the ${bigquery_region}.bigspark-connection service account | To create the Iceberg Catalog in BLMS
# In IAM add BigQuery User to the ${bigquery_region}.bigspark-connection service account | To create BigQuery jobs
#
# BigQuery Connection: ${bigquery_region}.biglake-connection
# In IAM add BigLake Admin to the ${bigquery_region}.biglake-connection service account | To create the tables in BigQuery linked to BLMS
# On iceberg-catalog-${random_extension}  grant Storage Object Admin to the ${bigquery_region}.biglake-connection service account | For BigLake to read the files when querying the data on storage
# On the ${bigquery_taxi_dataset} add BigQuery Data Owner to the ${bigquery_region}.biglake-connection service account | To create the tables in the dataset


from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, dayofmonth, hour, minute
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import time
import sys
import os
import json

# We need the ".config" options set for the default Iceberg catalog
spark = SparkSession \
     .builder \
     .appName("BigLake Iceberg") \
     .config("spark.network.timeout", 50000) \
     .getOrCreate()

# .enableHiveSupport() \

project_id = "${project_id}"
iceberg_catalog = "iceberg_catalog"  # NOTE: This is the same name in the Spark.Properties
iceberg_warehouse = "iceberg_warehouse"
bq_dataset = "${bigquery_taxi_dataset}"
source_data_parquet = "gs://iceberg-source-data-${random_extension}/payment_type_table/*.parquet"


#####################################################################################
# Iceberg Initialization
#####################################################################################
spark.sql("CREATE NAMESPACE IF NOT EXISTS {};".format(iceberg_catalog))
spark.sql("CREATE NAMESPACE IF NOT EXISTS {}.{};".format(iceberg_catalog,iceberg_warehouse))
spark.sql("DROP TABLE IF EXISTS {}.{}.iceberg_payment_type".format(iceberg_catalog,iceberg_warehouse))


#####################################################################################
# Create the Iceberg tables
#####################################################################################
spark.sql("CREATE TABLE IF NOT EXISTS {}.{}.iceberg_payment_type ".format(iceberg_catalog, iceberg_warehouse) + \
        "(payment_type_id int, payment_type_description string) " + \
   "USING iceberg " + \
   "TBLPROPERTIES(bq_table='{}.iceberg_payment_type', bq_connection='${bigquery_region}.biglake-connection');".format(bq_dataset))


#####################################################################################
# Load the Payment Type Table in the Enriched Zone
#####################################################################################
# Option 3: Read from raw files
df_biglake_rideshare_payment_type_json = spark.read.parquet("{}".format(source_data_parquet))

# Create Spark View and Show the data
df_biglake_rideshare_payment_type_json.createOrReplaceTempView("temp_view_rideshare_payment_type")
spark.sql("select * from temp_view_rideshare_payment_type").show(10)

# Insert into Iceberg table (perform typecasting)
spark.sql("INSERT INTO {}.{}.iceberg_payment_type ".format(iceberg_catalog, iceberg_warehouse) + \
        "(payment_type_id, payment_type_description) " + \
   "SELECT cast(payment_type_id as int), cast(payment_type_description as string) " + \
   "FROM temp_view_rideshare_payment_type;")
""";
*/

-- So this deploys via Terraform
SELECT 1;
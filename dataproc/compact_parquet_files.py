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
# Summary: Compact parquet files to 10000 (upper BigQuery external table URI limit)

from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from datetime import datetime
import time
import sys


def CompactParquetFiles(source, destination, numberOfPartitions):
    print("CompactParquetFiles: source:             ",source)
    print("CompactParquetFiles: destination:        ",destination)
    print("CompactParquetFiles: numberOfPartitions: ",str(numberOfPartitions))

    spark = SparkSession \
        .builder \
        .appName("CompactParquetFiles") \
        .getOrCreate()

    df = spark.read.parquet(source)

    # Write as Parquet
    df \
        .repartition(numberOfPartitions) \
        .coalesce(numberOfPartitions) \
        .write \
        .mode("overwrite") \
        .parquet(destination)

    spark.stop()


# Main entry point
# compact_parquet_files gs://big-query-demo-09/test-taxi/source/*.parquet gs://big-query-demo-09/test-taxi/dest/ 10000
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: compact_parquet_files source destination numberOfPartitions")
        sys.exit(-1)

    source = sys.argv[1]
    destination  = sys.argv[2]
    numberOfPartitions = int(sys.argv[3])

    print ("BEGIN: Main")
    numberOfPartitions = int(sys.argv[3])
    CompactParquetFiles(source, destination, numberOfPartitions)
    print ("END: Main")

"""
gcloud dataproc clusters create "compactcluster" \
    --project="big-query-demo-09" \
    --region="REPLACE-REGION" \
    --zone="REPLACE-REGION-a" \
    --num-masters=1 \
    --bucket=dataproc-big-query-demo-09 \
    --temp-bucket=dataproc-big-query-demo-09 \
    --master-machine-type="n1-standard-8" \
    --worker-machine-type="n1-standard-8" \
    --num-workers=4 \
    --image-version="2.0.28-debian10" \
    --subnet="dataproc-subnet" \
    --service-account="dataproc-service-account@big-query-demo-09.iam.gserviceaccount.com" \
    --scopes="cloud-platform"
    
# Sample run (flat source directory)
gcloud dataproc jobs submit pyspark  \
   --project="big-query-demo-09" \
   --cluster="compactcluster" \
   --region="REPLACE-REGION" \
   gs://big-query-demo-09/pyspark-code/compact_parquet_files.py \
   -- gs://big-query-demo-09/test-taxi/source/*.parquet \
      gs://big-query-demo-09/test-taxi/dest/ \
      10000

# Sample run (partitioned source directory)
gcloud dataproc jobs submit pyspark  \
   --project="big-query-demo-09" \
   --cluster="compactcluster" \
   --region="REPLACE-REGION" \
   gs://big-query-demo-09/pyspark-code/compact_parquet_files.py \
   -- gs://big-query-demo-09/processed/taxi-data/green/trips_table/parquet/*/*/*.parquet \
      gs://big-query-demo-09/compacted/dest/ \
      50


# Delete the cluster (clean up)
gcloud dataproc clusters delete "compactcluster" \
   --project="big-query-demo-09" \
   --region="REPLACE-REGION"

"""

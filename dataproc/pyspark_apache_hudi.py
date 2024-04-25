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

"""
# https://cloud.google.com/dataproc/docs/concepts/components/hudi

# Create Cluster 
# The dataproc-service-account service account needs access to BigQuery (made a project editor for now)
project_id="data-analytics-preview"
hudi_bucket="biglake-{project_id}"

# You must create this
dataproc_bucket="${project_id}-4prl0sgfm7"
service_account="dataproc-service-account@${project_id}.iam.gserviceaccount.com"
dataproc_subnet="dataproc-subnet"

gcloud dataproc clusters create "hudi_cluster" \
    --project="${project_id}" \
    --region="us-central1" \
    --num-masters=1 \
    --bucket=${dataproc_bucket} \
    --temp-bucket=${dataproc_bucket} \
    --master-machine-type="n1-standard-8" \
    --worker-machine-type="n1-standard-8" \
    --num-workers=2 \
    --subnet="${dataproc_subnet}" \
    --service-account="${service_account}" \
    --optional-components=HUDI \
    ${hudi_bucket}

# Run the job to create the Hudi table
gcloud dataproc jobs submit pyspark \
    --cluster="hudi_cluster" \
    --region="us-central1" \
    hudi.py

-- SSH to cluster
spark-submit \
   --master yarn \
   --packages com.google.cloud:google-cloud-bigquery:2.10.4 \
   --conf spark.driver.userClassPathFirst=true \
   --conf spark.executor.userClassPathFirst=true \
   --class org.apache.hudi.gcp.bigquery.BigQuerySyncTool  \
   /usr/lib/hudi/tools/bq-sync-tool/hudi-gcp-bundle-0.12.3.jar \
   --project-id ${project_id} \
   --dataset-name biglake_dataset \
   --dataset-location us \
   --table location_hudi \
   --source-uri gs://${hudi_bucket}/biglake-tables/location_hudi/borough=* \
   --source-uri-prefix gs://${hudi_bucket}/biglake-tables/location_hudi/ \
   --base-path gs://${hudi_bucket}/biglake-tables/location_hudi \
   --partitioned-by borough \
   --use-bq-manifest-file    
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp

def write_hudi_table(table_name, table_uri, df):
  """Writes Hudi table."""
  hudi_options = {
      'hoodie.table.name': table_name,
      'hoodie.datasource.write.recordkey.field': 'location_id',
      'hoodie.datasource.write.partitionpath.field': 'borough',
      'hoodie.datasource.write.table.name': table_name,
      'hoodie.datasource.write.operation': 'insert',
      'hoodie.datasource.write.precombine.field': 'ts',
      'hoodie.upsert.shuffle.parallelism': 2,
      'hoodie.insert.shuffle.parallelism': 2,
      # BQ Support
      'hoodie-conf hoodie.partition.metafile.use.base.format' : 'true',
      'hoodie-conf hoodie.metadata.enable' : 'true',
      'hoodie.datasource.write.hive_style_partitioning' :'true',
      'hoodie.datasource.write.drop.partition.columns': 'true',
  }
  df.write.format('hudi').options(**hudi_options).mode('append').save(table_uri)


def main(hudi_bucket):
  table_name = "location_hudi"
  table_uri= f"gs://{hudi_bucket}/biglake-tables/location_hudi"
  app_name = f'pyspark-hudi-test_{table_name}'

  print(f'Creating Spark session {app_name} ...')
  spark = SparkSession.builder.appName(app_name).getOrCreate()
  spark.sparkContext.setLogLevel('WARN')

  file_location = f"gs://{hudi_bucket}/biglake-tables/location_parquet/location.snappy.parquet"
  df = spark.read.parquet(file_location)

  df_with_ts = df.withColumn("ts", current_timestamp())
  df_with_ts_converted = df_with_ts.withColumn("ts", df_with_ts["ts"].cast("string"))

  print('Writing Hudi table ...')
  write_hudi_table(table_name, table_uri, df_with_ts)

  print('Stopping Spark session ...')
  spark.stop()

  print('Hudi table created.  Please run Sync process.')


main(sys.argv[1])
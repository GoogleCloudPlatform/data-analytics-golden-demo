####################################################################################
# Copyright 2023 Google LLC
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

####################################################################################
# Create the GCP resources
#
# Author: Adam Paternostro
####################################################################################

# Need this version to implement
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = ">= 4.52, < 6"
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "dataplex_region" {}
variable "storage_bucket" {}
variable "random_extension" {}
variable "deployment_service_account_name" {}
variable "composer_name" {}
variable "composer_dag_bucket" {}
variable "demo_rest_api_service_uri" {}
variable "code_bucket_name" {}

variable "bigquery_rideshare_llm_raw_dataset" {}
variable "bigquery_rideshare_llm_enriched_dataset" {}
variable "bigquery_rideshare_llm_curated_dataset" {}
variable "bigquery_region" {}
variable "gcs_rideshare_lakehouse_raw_bucket" {}
variable "cloud_run_service_rideshare_plus_website_url" {}

variable "bigquery_taxi_dataset" {
  type        = string
  default     = "taxi_dataset"
}  

locals {
  # Replace gs://composer-generated-name/dags to composer-generated-name
  local_composer_bucket_name = replace(replace(replace(var.composer_dag_bucket, "gs://", ""),"/dags",""),"/","")

  local_composer_dag_path = "dags"
  local_composer_data_path = "data"
  local_dataproc_pyspark_path = "pyspark-code"
  local_dataflow_source_path = "dataflow"
  local_bigspark_path = "bigspark"
}


####################################################################################
# Deploy Composer DAGs and Data
###################################################################################
# Upload the Airflow initial DAGs needed to run the system (dependencies of run-all-dags)
# Upload all the DAGs can cause issues since the Airflow instance is so small they call cannot sync
# before run-all-dags is launched


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_step-01-taxi-data-download" {
  name   = "${local.local_composer_dag_path}/step-01-taxi-data-download.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/step-01-taxi-data-download.py"

  depends_on = [ 
    ]  
}
resource "google_storage_bucket_object" "deploy_airflow_dag_step-01-taxi-data-download-quick-copy" {
  name   = "${local.local_composer_dag_path}/step-01-taxi-data-download-quick-copy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/step-01-taxi-data-download-quick-copy.py"

  depends_on = [ 
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_step-02-taxi-data-processing" {
  name   = "${local.local_composer_dag_path}/step-02-taxi-data-processing.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/step-02-taxi-data-processing.py"

  depends_on = [ 
    ]  
}
resource "google_storage_bucket_object" "deploy_airflow_dag_step-02-taxi-data-processing-quick-copy" {
  name   = "${local.local_composer_dag_path}/step-02-taxi-data-processing-quick-copy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/step-02-taxi-data-processing-quick-copy.py"

  depends_on = [ 
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_step-03-hydrate-tables" {
  name   = "${local.local_composer_dag_path}/step-03-hydrate-tables.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/step-03-hydrate-tables.py"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataflow-start-streaming-job" {
  name   = "${local.local_composer_dag_path}/sample-dataflow-start-streaming-job.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataflow-start-streaming-job.py"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-dataprofile-ridehshare-llm" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-dataprofile-ridehshare-llm.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-dataprofile-ridehshare-llm.py"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_dataplex_dataprofile_ridehshare_llm" {
  name   = "${local.local_composer_data_path}/bash_dataplex_dataprofile_ridehshare_llm.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_dataplex_dataprofile_ridehshare_llm.sh"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-dataprofile-taxi" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-dataprofile-taxi.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-dataprofile-taxi.py"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_dataplex_dataprofile_taxi" {
  name   = "${local.local_composer_data_path}/bash_dataplex_dataprofile_taxi.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_dataplex_dataprofile_taxi.sh"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-dataprofile-thelook" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-dataprofile-thelook.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-dataprofile-thelook.py"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_dataplex_dataprofile_thelook" {
  name   = "${local.local_composer_data_path}/bash_dataplex_dataprofile_thelook.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_dataplex_dataprofile_thelook.sh"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-dataprofile-rideshare-lakehouse" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-dataprofile-rideshare-lakehouse.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-dataprofile-rideshare-lakehouse.py"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_dataplex_dataprofile_ridehshare_lakehouse" {
  name   = "${local.local_composer_data_path}/bash_dataplex_dataprofile_ridehshare_lakehouse.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_dataplex_dataprofile_ridehshare_lakehouse.sh"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_sample_datastream_public_ip_deploy_postgres" {
  name   = "${local.local_composer_data_path}/sample_datastream_public_ip_deploy_postgres.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_datastream_public_ip_deploy_postgres.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_sample_datastream_public_ip_deploy_datastream" {
  name   = "${local.local_composer_data_path}/sample_datastream_public_ip_deploy_datastream.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_datastream_public_ip_deploy_datastream.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_sample_datastream_public_ip_destroy" {
  name   = "${local.local_composer_data_path}/sample_datastream_public_ip_destroy.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_datastream_public_ip_destroy.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_sample_datastream_private_ip_deploy_postgres" {
  name   = "${local.local_composer_data_path}/sample_datastream_private_ip_deploy_postgres.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_datastream_private_ip_deploy_postgres.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_sample_datastream_private_ip_deploy_datastream" {
  name   = "${local.local_composer_data_path}/sample_datastream_private_ip_deploy_datastream.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_datastream_private_ip_deploy_datastream.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_sample_datastream_private_ip_destroy" {
  name   = "${local.local_composer_data_path}/sample_datastream_private_ip_destroy.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_datastream_private_ip_destroy.sh"

  depends_on = [ 
    ]  
}



# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_create_spanner_connection" {
  name   = "${local.local_composer_data_path}/bash_create_spanner_connection.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_create_spanner_connection.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_deploy_dataplex" {
  name   = "${local.local_composer_data_path}/bash_deploy_dataplex.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_deploy_dataplex.sh"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_deploy_rideshare_website" {
  name   = "${local.local_composer_data_path}/bash_deploy_rideshare_website.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_deploy_rideshare_website.sh"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_download_rideshare_images" {
  name   = "${local.local_composer_data_path}/bash_download_rideshare_images.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_download_rideshare_images.sh"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_bash_seed_unstructured_data" {
  name   = "${local.local_composer_data_path}/bash_seed_unstructured_data.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/bash_seed_unstructured_data.sh"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_cloud_sql_reverse_proxy_template" {
  name   = "${local.local_composer_data_path}/cloud_sql_reverse_proxy_template.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/cloud_sql_reverse_proxy_template.sh"

  depends_on = [ 
    ]  
}

# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_postgres_create_datastream_replication" {
  name   = "${local.local_composer_data_path}/postgres_create_datastream_replication.sql"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/postgres_create_datastream_replication.sql"

  depends_on = [ 
    ]  
}


# Upload the Airflow "data/template" files
resource "google_storage_bucket_object" "deploy_airflow_data_postgres_create_schema" {
  name   = "${local.local_composer_data_path}/postgres_create_schema.sql"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/postgres_create_schema.sql"

  depends_on = [ 
    ]  
}


####################################################################################
# Dataplex Terraform
####################################################################################
# Upload Deploy DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-deploy" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-deploy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Upload Destroy DAG (Copy the Deploy AS THE Destroy)
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-destroy" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-destroy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Backend State file
# The bucket for the state must be substituted.  We do not want to do this for the other files since we
# would need to escape all the ${var} with $${var}.
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_dataplex_backend" {
  name   = "${local.local_composer_data_path}/terraform/dataplex/backend.tf"
  bucket = local.local_composer_bucket_name

  content = templatefile("../cloud-composer/data/terraform/dataplex/backend.tf", 
  { 
    code_bucket_name = var.code_bucket_name
  })

  depends_on = [ 
    ]  
}

# Variables file
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_dataplex_variables" {
  name   = "${local.local_composer_data_path}/terraform/dataplex/variables.tf"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/terraform/dataplex/variables.tf"

  depends_on = [ 
    ]  
}

# Main Resources file
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_dataplex" {
  name   = "${local.local_composer_data_path}/terraform/dataplex/terraform.tf"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/terraform/dataplex/terraform.tf"

  depends_on = [ 
    ]  
}

# Bash script to run and install Terraform
resource "google_storage_bucket_object" "deploy_airflow_data_sample_terraform_dataplex" {
  name   = "${local.local_composer_data_path}/sample_terraform_dataplex.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_terraform_dataplex.sh"

  depends_on = [ 
    ]  
}


####################################################################################
# Dataplex Terraform WITH Hive Metastore Service
####################################################################################
# Upload Deploy DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-with-hms-deploy" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-with-hms-deploy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-with-hms-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Upload Destroy DAG (Copy the Deploy AS THE Destroy)
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-with-hms-destroy" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-with-hms-destroy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-with-hms-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Backend State file
# The bucket for the state must be substituted.  We do not want to do this for the other files since we
# would need to escape all the ${var} with $${var}.
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_dataplex_backend_with_hms" {
  name   = "${local.local_composer_data_path}/terraform/dataplex-with-hms/backend.tf"
  bucket = local.local_composer_bucket_name

  content = templatefile("../cloud-composer/data/terraform/dataplex-with-hms/backend.tf", 
  { 
    code_bucket_name = var.code_bucket_name
  })

  depends_on = [ 
    ]  
}

# Variables file
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_dataplex_variables_with_hms" {
  name   = "${local.local_composer_data_path}/terraform/dataplex-with-hms/variables.tf"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/terraform/dataplex-with-hms/variables.tf"

  depends_on = [ 
    ]  
}

# Main Resources file
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_dataplex_with_hms" {
  name   = "${local.local_composer_data_path}/terraform/dataplex-with-hms/terraform.tf"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/terraform/dataplex-with-hms/terraform.tf"

  depends_on = [ 
    ]  
}

# Bash script to run and install Terraform
resource "google_storage_bucket_object" "deploy_airflow_data_sample_terraform_dataplex_with_hms" {
  name   = "${local.local_composer_data_path}/sample_terraform_dataplex_with_hms.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_terraform_dataplex_with_hms.sh"

  depends_on = [ 
    ]  
}


####################################################################################
# Bucket Demo Terraform
####################################################################################
# Upload Deploy DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-terraform-bucket-demo-deploy" {
  name   = "${local.local_composer_dag_path}/sample-terraform-bucket-demo-deploy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-terraform-bucket-demo-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Upload Destroy DAG (Copy the Deploy AS THE Destroy)
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-terraform-bucket-demo-destroy" {
  name   = "${local.local_composer_dag_path}/sample-terraform-bucket-demo-destroy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-terraform-bucket-demo-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Backend State file
# The bucket for the state must be substituted.  We do not want to do this for the other files since we
# would need to escape all the ${var} with $${var}.
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_bucket-demo_backend" {
  name   = "${local.local_composer_data_path}/terraform/bucket-demo/backend.tf"
  bucket = local.local_composer_bucket_name

  content = templatefile("../cloud-composer/data/terraform/bucket-demo/backend.tf", 
  { 
    code_bucket_name = var.code_bucket_name
  })

  depends_on = [ 
    ]  
}

# Variables file
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_bucket-demo_variables" {
  name   = "${local.local_composer_data_path}/terraform/bucket-demo/variables.tf"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/terraform/bucket-demo/variables.tf"

  depends_on = [ 
    ]  
}

# Main Resources file
resource "google_storage_bucket_object" "deploy_airflow_data_terraform_bucket-demo" {
  name   = "${local.local_composer_data_path}/terraform/bucket-demo/terraform.tf"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/terraform/bucket-demo/terraform.tf"

  depends_on = [ 
    ]  
}

# Bash script to run and install Terraform
resource "google_storage_bucket_object" "deploy_airflow_data_sample_terraform_bucket_demo" {
  name   = "${local.local_composer_data_path}/sample_terraform_bucket_demo.sh"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/data/sample_terraform_bucket_demo.sh"

  depends_on = [ 
    ]  
}




####################################################################################
# Upload the PySpark scripts
###################################################################################
# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_compact_parquet_files" {
  name   = "${local.local_dataproc_pyspark_path}/compact_parquet_files.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/compact_parquet_files.py"

  depends_on = [ 
    ]  
}


# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_convert_taxi_to_iceberg_create_tables" {
  name   = "${local.local_dataproc_pyspark_path}/convert_taxi_to_iceberg_create_tables.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/convert_taxi_to_iceberg_create_tables.py"

  depends_on = [ 
    ]  
}


# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_convert_taxi_to_iceberg_data_updates" {
  name   = "${local.local_dataproc_pyspark_path}/convert_taxi_to_iceberg_data_updates.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/convert_taxi_to_iceberg_data_updates.py"

  depends_on = [ 
    ]  
}


# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_convert_taxi_to_parquet" {
  name   = "${local.local_dataproc_pyspark_path}/convert_taxi_to_parquet.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/convert_taxi_to_parquet.py"

  depends_on = [ 
    ]  
}


# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_export_taxi_data_biglake_storage_api" {
  name   = "${local.local_dataproc_pyspark_path}/export_taxi_data_biglake_storage_api.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/export_taxi_data_biglake_storage_api.py"

  depends_on = [ 
    ]  
}


# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_export_taxi_data_from_bq_to_gcs" {
  name   = "${local.local_dataproc_pyspark_path}/export_taxi_data_from_bq_to_gcs.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/export_taxi_data_from_bq_to_gcs.py"

  depends_on = [ 
    ]  
}


# Upload PySpark
resource "google_storage_bucket_object" "deploy_pyspark_rideshare_iceberg_serverless" {
  name   = "${local.local_dataproc_pyspark_path}/rideshare_iceberg_serverless.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataproc/rideshare_iceberg_serverless.py"

  depends_on = [ 
    ]  
}


####################################################################################
# Upload the PySpark scripts
###################################################################################
# Download the BigQuery Spark JAR file
# Download the Iceberg JAR File
resource "null_resource" "download_dataproc_jars" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
if [ -z "$${GOOGLE_APPLICATION_CREDENTIALS}" ]
then
    echo "We are not running in a local docker container.  No need to login."
else
    echo "We are running in local docker container. Logging in."
    gcloud auth activate-service-account "${var.deployment_service_account_name}" --key-file="$${GOOGLE_APPLICATION_CREDENTIALS}" --project="${var.project_id}"
    gcloud config set account "${var.deployment_service_account_name}"
fi  
curl -L https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.1_2.12/0.14.0/iceberg-spark-runtime-3.1_2.12-0.14.0.jar   --output iceberg-spark-runtime-3.1_2.12-0.14.0.jar
curl -L https://github.com/GoogleCloudDataproc/spark-bigquery-connector/releases/download/0.26.0/spark-bigquery-with-dependencies_2.12-0.26.0.jar --output spark-bigquery-with-dependencies_2.12-0.26.0.jar
EOF
  }
}


# Upload PySpark JAR Files
resource "google_storage_bucket_object" "deploy_pyspark_iceberg-spark-runtime" {
  name   = "${local.local_dataproc_pyspark_path}/iceberg-spark-runtime-3.1_2.12-0.14.0.jar"
  bucket = "raw-${var.storage_bucket}"
  source = "iceberg-spark-runtime-3.1_2.12-0.14.0.jar"

  depends_on = [ 
    null_resource.download_dataproc_jars
    ]  
}


# Upload PySpark JAR Files
resource "google_storage_bucket_object" "deploy_pyspark_spark-bigquery-with-dependencies" {
  name   = "${local.local_dataproc_pyspark_path}/spark-bigquery-with-dependencies_2.12-0.26.0.jar"
  bucket = "raw-${var.storage_bucket}"
  source = "spark-bigquery-with-dependencies_2.12-0.26.0.jar"

  depends_on = [ 
    null_resource.download_dataproc_jars
    ]  
}



####################################################################################
# Upload the Dataflow scripts
###################################################################################
resource "google_storage_bucket_object" "deploy_dataflow_script_streaming-taxi-data" {
  name   = "${local.local_dataflow_source_path}/streaming-taxi-data.py"
  bucket = "raw-${var.storage_bucket}"
  source = "../dataflow/streaming-taxi-data.py"

  depends_on = [ 
    ]  
}


####################################################################################
# Upload the Dataplex scripts
####################################################################################
resource "google_storage_bucket_object" "dataplex_data_quality_yaml" {
  name        = "dataplex/data-quality/dataplex_data_quality_taxi.yaml"
  content = templatefile("../dataplex/data-quality/dataplex_data_quality_taxi.yaml", 
  { 
    project_id = var.project_id
    dataplex_region = var.dataplex_region
    random_extension = var.random_extension
  })
  bucket      = "code-${var.storage_bucket}"
}

resource "google_storage_bucket_object" "dataplex_data_quality_rideshare_yaml" {
  name        = "dataplex/data-quality/dataplex_data_quality_rideshare.yaml"
  content = templatefile("../dataplex/data-quality/dataplex_data_quality_rideshare.yaml", 
  { 
    project_id = var.project_id
    dataplex_region = var.dataplex_region
    random_extension = var.random_extension
  })
  bucket      = "code-${var.storage_bucket}"
}


resource "google_storage_bucket_object" "dataplex_data-explore-dataplex-explore-notebook" {
  name        = "dataplex/data-explore/dataplex-explore-notebook.ipynb"
  content     = templatefile("../dataplex/data-explore/dataplex-explore-notebook.ipynb", 
  { 
    project_id            = var.project_id
    dataplex_region       = var.dataplex_region
    random_extension      = var.random_extension
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
  })
  bucket      = "code-${var.storage_bucket}"
}

resource "google_storage_bucket_object" "dataplex_data-explore-dataplex-explore-script" {
  name        = "dataplex/data-explore/dataplex-explore-script.sql"
  content     = templatefile("../dataplex/data-explore/dataplex-explore-script.sql", 
  { 
    project_id            = var.project_id
    dataplex_region       = var.dataplex_region
    random_extension      = var.random_extension
    bigquery_taxi_dataset = var.bigquery_taxi_dataset

  })
  bucket      = "code-${var.storage_bucket}"
}




####################################################################################
# Deploy BigSpark
####################################################################################
# Replace the Project and Bucket name
# Upload BigSpark script
resource "google_storage_bucket_object" "deploy_bigspark_sample-bigspark" {
  name   = "${local.local_bigspark_path}/sample-bigspark.py"
  bucket = "raw-${var.storage_bucket}"
  content = templatefile("../sample-data/bigspark/sample-bigspark.py", 
  { 
    project_id = var.project_id
    bucket_name = "raw-${var.storage_bucket}"
  })


  depends_on = [ 
    ]  
}

# Upload BigSpark sample data
resource "google_storage_bucket_object" "deploy_bigspark_sample-bigspark-discount-data" {
  name   = "${local.local_bigspark_path}/sample-bigspark-discount-data.csv"
  bucket = "raw-${var.storage_bucket}"
  source = "../sample-data/bigspark/sample-bigspark-discount-data.csv"

  depends_on = [ 
    ]  
}


# Random name file
resource "google_storage_bucket_object" "deploy_sample_data-random_names" {
  name   = "random_names/random_names.csv"
  bucket = "raw-${var.storage_bucket}"
  source = "../sample-data/random_names/random_names.csv"

  depends_on = [ 
    ]  
}

# Pickup and Dropoff location data
resource "google_storage_bucket_object" "deploy_sample_data-location" {
  name   = "processed/taxi-data/location/location.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/location/location.parquet"

  depends_on = [ 
    ]  
}


# Upload Resenet Imagenet Labels sample data
resource "google_storage_bucket_object" "deploy_resnet_imagenet_labels-data" {
  name   = "resnet_imagenet_labels/resnet_imagenet_labels.csv"
  bucket = "raw-${var.storage_bucket}"
  source = "../sample-data/resnet_imagenet_labels/resnet_imagenet_labels.csv"

  depends_on = [ 
    ]  
}


# Upload BigLake Meatastore sample data
resource "google_storage_bucket_object" "deploy_biglake-metastore-payment-type-data" {
  name   = "payment_type_table/payment_type_table.snappy.parquet"
  bucket = "iceberg-source-data-${var.random_extension}"
  source = "../sample-data/iceberg_source_data/payment_type_table.snappy.parquet"

  depends_on = [ 
    ]  
}


####################################################################################
# Delta IO Files
####################################################################################

# Upload the sample Delta.io files
# The manifest files need to have the GCS bucket name updated
# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/part-00000-3bec3377-d4a1-4e29-9e1e-b106e63929a6.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/part-00001-9dd1b37f-6e98-48c5-bb5a-613ba36b2f70.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/part-00002-6d9993de-beb3-4c54-8aa7-a1ea576c2019.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/part-00003-0c324b19-b541-4ae1-b958-7090e8192c62.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/part-00004-0c280354-a13c-4b5b-9808-666ea0bcd49e.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/part-00005-d22c4ae9-e0e6-4887-b0b6-493bf313d049.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/part-00006-0aadcdad-a3a9-4e5c-a0f8-c5cc033f5878.c000.snappy.parquet

# sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/manifest:
#   1: gs://REPLACE-BUCKET-NAME/delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/part-00007-327dd29b-6c62-4f56-963d-d7c0d2a235be.c000.snappy.parquet


#sample-data/rideshare_trips/Rideshare_Vendor_Id=1:
#Pickup_Date=2021-12-01  Pickup_Date=2021-12-02  Pickup_Date=2021-12-03  Pickup_Date=2021-12-04  Pickup_Date=2021-12-06

# sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01:
# part-00000-3bec3377-d4a1-4e29-9e1e-b106e63929a6.c000.snappy.parquet     part-00000-7dfd2262-fa70-4593-8d3a-d82efa1b94e2.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-3bec3377-d4a1-4e29-9e1e-b106e63929a6_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/part-00000-3bec3377-d4a1-4e29-9e1e-b106e63929a6.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/part-00000-3bec3377-d4a1-4e29-9e1e-b106e63929a6.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-7dfd2262-fa70-4593-8d3a-d82efa1b94e2_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/part-00000-7dfd2262-fa70-4593-8d3a-d82efa1b94e2.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/part-00000-7dfd2262-fa70-4593-8d3a-d82efa1b94e2.c000.snappy.parquet"
}

# sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02:
# part-00000-3c1d5fd2-43fe-4e9f-b51b-6089242ff338.c000.snappy.parquet     part-00001-9dd1b37f-6e98-48c5-bb5a-613ba36b2f70.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-3c1d5fd2-43fe-4e9f-b51b-6089242ff338_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/part-00000-3c1d5fd2-43fe-4e9f-b51b-6089242ff338.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/part-00000-3c1d5fd2-43fe-4e9f-b51b-6089242ff338.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00001-9dd1b37f-6e98-48c5-bb5a-613ba36b2f70_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/part-00001-9dd1b37f-6e98-48c5-bb5a-613ba36b2f70.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/part-00001-9dd1b37f-6e98-48c5-bb5a-613ba36b2f70.c000.snappy.parquet"
}

# sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03:
# part-00000-5816f690-6c3b-4d38-8266-023ce2449b70.c000.snappy.parquet     part-00002-6d9993de-beb3-4c54-8aa7-a1ea576c2019.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-5816f690-6c3b-4d38-8266-023ce2449b70_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/part-00000-5816f690-6c3b-4d38-8266-023ce2449b70.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/part-00000-5816f690-6c3b-4d38-8266-023ce2449b70.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00002-6d9993de-beb3-4c54-8aa7-a1ea576c2019_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/part-00002-6d9993de-beb3-4c54-8aa7-a1ea576c2019.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/part-00002-6d9993de-beb3-4c54-8aa7-a1ea576c2019.c000.snappy.parquet"
}


# sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04:
# part-00000-86dc7fc1-b24a-45d6-8245-b5db27040e5e.c000.snappy.parquet     part-00003-0c324b19-b541-4ae1-b958-7090e8192c62.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-86dc7fc1-b24a-45d6-8245-b5db27040e5e_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/part-00000-86dc7fc1-b24a-45d6-8245-b5db27040e5e.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/part-00000-86dc7fc1-b24a-45d6-8245-b5db27040e5e.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00003-0c324b19-b541-4ae1-b958-7090e8192c62_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/part-00003-0c324b19-b541-4ae1-b958-7090e8192c62.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/part-00003-0c324b19-b541-4ae1-b958-7090e8192c62.c000.snappy.parquet"
}


# sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-06:
# part-00000-e9d227ec-236a-4090-8a2d-41ef9eda576d.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-e9d227ec-236a-4090-8a2d-41ef9eda576d_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-06/part-00000-e9d227ec-236a-4090-8a2d-41ef9eda576d.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-06/part-00000-e9d227ec-236a-4090-8a2d-41ef9eda576d.c000.snappy.parquet"
}


# sample-data/rideshare_trips/Rideshare_Vendor_Id=2:
# Pickup_Date=2021-12-01  Pickup_Date=2021-12-02  Pickup_Date=2021-12-03  Pickup_Date=2021-12-04  Pickup_Date=2021-12-06

# sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01:
# part-00000-4c85ae57-0beb-4bcb-b12e-3d96c12ca261.c000.snappy.parquet     part-00004-0c280354-a13c-4b5b-9808-666ea0bcd49e.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-4c85ae57-0beb-4bcb-b12e-3d96c12ca261_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/part-00000-4c85ae57-0beb-4bcb-b12e-3d96c12ca261.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/part-00000-4c85ae57-0beb-4bcb-b12e-3d96c12ca261.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00004-0c280354-a13c-4b5b-9808-666ea0bcd49e_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/part-00004-0c280354-a13c-4b5b-9808-666ea0bcd49e.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/part-00004-0c280354-a13c-4b5b-9808-666ea0bcd49e.c000.snappy.parquet"
}


# sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02:
# part-00000-08363b08-e1f1-4a9a-99ee-b2dfc6a72253.c000.snappy.parquet     part-00005-d22c4ae9-e0e6-4887-b0b6-493bf313d049.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-08363b08-e1f1-4a9a-99ee-b2dfc6a72253_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/part-00000-08363b08-e1f1-4a9a-99ee-b2dfc6a72253.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/part-00000-08363b08-e1f1-4a9a-99ee-b2dfc6a72253.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00005-d22c4ae9-e0e6-4887-b0b6-493bf313d049_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/part-00005-d22c4ae9-e0e6-4887-b0b6-493bf313d049.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/part-00005-d22c4ae9-e0e6-4887-b0b6-493bf313d049.c000.snappy.parquet"
}

# sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03:
# part-00000-cb84f5c4-33ab-4298-ae0c-2cae87cedf36.c000.snappy.parquet     part-00006-0aadcdad-a3a9-4e5c-a0f8-c5cc033f5878.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-cb84f5c4-33ab-4298-ae0c-2cae87cedf36_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/part-00000-cb84f5c4-33ab-4298-ae0c-2cae87cedf36.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/part-00000-cb84f5c4-33ab-4298-ae0c-2cae87cedf36.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00006-0aadcdad-a3a9-4e5c-a0f8-c5cc033f5878_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/part-00006-0aadcdad-a3a9-4e5c-a0f8-c5cc033f5878.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/part-00006-0aadcdad-a3a9-4e5c-a0f8-c5cc033f5878.c000.snappy.parquet"
}

# sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04:
# part-00000-8ec550ea-5ced-4dc1-8555-9fbe815fef12.c000.snappy.parquet     part-00007-327dd29b-6c62-4f56-963d-d7c0d2a235be.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-8ec550ea-5ced-4dc1-8555-9fbe815fef12_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/part-00000-8ec550ea-5ced-4dc1-8555-9fbe815fef12.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/part-00000-8ec550ea-5ced-4dc1-8555-9fbe815fef12.c000.snappy.parquet"
}

resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00007-327dd29b-6c62-4f56-963d-d7c0d2a235be_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/part-00007-327dd29b-6c62-4f56-963d-d7c0d2a235be.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/part-00007-327dd29b-6c62-4f56-963d-d7c0d2a235be.c000.snappy.parquet"
}

# sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-06:
# part-00000-e8cdd40e-4587-4ac8-b511-511d1fbce5d1.c000.snappy.parquet
resource "google_storage_bucket_object" "deploy_sample_data_parquet_part-00000-e8cdd40e-4587-4ac8-b511-511d1fbce5d1_c000_snappy_parquet" {
  name   = "delta_io/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-06/part-00000-e8cdd40e-4587-4ac8-b511-511d1fbce5d1.c000.snappy.parquet"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-06/part-00000-e8cdd40e-4587-4ac8-b511-511d1fbce5d1.c000.snappy.parquet"
}


# sample-data/rideshare_trips//_delta_log:
# 00000000000000000000.crc        00000000000000000001.crc        00000000000000000002.crc
# 00000000000000000000.json       00000000000000000001.json       00000000000000000002.json

resource "google_storage_bucket_object" "deploy_sample_data_delta_io_delta_log-00000000000000000000_crc" {
  name   = "delta_io/rideshare_trips/_delta_log/00000000000000000000.crc"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/_delta_log/00000000000000000000.crc"
}

resource "google_storage_bucket_object" "deploy_sample_data_delta_io_delta_log-00000000000000000001_crc" {
  name   = "delta_io/rideshare_trips/_delta_log/00000000000000000001.crc"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/_delta_log/00000000000000000001.crc"
}

resource "google_storage_bucket_object" "deploy_sample_data_delta_io_delta_log-00000000000000000002_crc" {
  name   = "delta_io/rideshare_trips/_delta_log/00000000000000000002.crc"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/_delta_log/00000000000000000002.crc"
}

resource "google_storage_bucket_object" "deploy_sample_data_delta_io_delta_log-00000000000000000000_json" {
  name   = "delta_io/rideshare_trips/_delta_log/00000000000000000000.json"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/_delta_log/00000000000000000000.json"
}

resource "google_storage_bucket_object" "deploy_sample_data_delta_io_delta_log-00000000000000000001_json" {
  name   = "delta_io/rideshare_trips/_delta_log/00000000000000000001.json"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/_delta_log/00000000000000000001.json"
}

resource "google_storage_bucket_object" "deploy_sample_data_delta_io_delta_log-00000000000000000002_json" {
  name   = "delta_io/rideshare_trips/_delta_log/00000000000000000002.json"
  bucket = "processed-${var.storage_bucket}"
  source = "../sample-data/rideshare_trips/_delta_log/00000000000000000002.json"
}


# sample-data/rideshare_trips//_symlink_format_manifest:
# Rideshare_Vendor_Id=1   Rideshare_Vendor_Id=2

# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=1:
# Pickup_Date=2021-12-01  Pickup_Date=2021-12-02  Pickup_Date=2021-12-03  Pickup_Date=2021-12-04

# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_Rideshare_Vendor_Id_1_Pickup_Date_2021-12-01" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-01/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })
}

# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_Rideshare_Vendor_Id_1_Pickup_Date_2021-12-02" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-02/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })
}


# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_Rideshare_Vendor_Id_1_Pickup_Date_2021-12-03" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-03/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })

}


# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_manifest_Rideshare_Vendor_Id_1_Pickup_Date_2021-12-04-bigspark" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=1/Pickup_Date=2021-12-04/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })

}


# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=2:
# Pickup_Date=2021-12-01  Pickup_Date=2021-12-02  Pickup_Date=2021-12-03  Pickup_Date=2021-12-04

# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_Rideshare_Vendor_Id_2_Pickup_Date_2021-12-01" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-01/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })
}


# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_Rideshare_Vendor_Id_2_Pickup_Date_2021-12-02" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-02/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"  
  })
}


# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_Rideshare_Vendor_Id_2_Pickup_Date_2021-12-03" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-03/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })

}

# sample-data/rideshare_trips//_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04:
# manifest
# Upload Sample Delta IO file with Template substitution
resource "google_storage_bucket_object" "deploy_sample_data_delta_io_manifest_Rideshare_Vendor_Id_2_Pickup_Date_2021-12-04-bigspark" {
  name   = "delta_io/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/manifest"
  bucket = "processed-${var.storage_bucket}"
  content = templatefile("../sample-data/rideshare_trips/_symlink_format_manifest/Rideshare_Vendor_Id=2/Pickup_Date=2021-12-04/manifest", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })

}


####################################################################################
# Remaining Airflow / Composer DAGs
####################################################################################
# You need to wait for Airflow to read the DAGs just uploaded
# Only a few DAGs are uploaded so that we can sync quicker
resource "time_sleep" "wait_for_airflow_dag_sync" {
  depends_on = [
    google_storage_bucket_object.deploy_airflow_dag_step-01-taxi-data-download-quick-copy,
    google_storage_bucket_object.deploy_airflow_dag_step-02-taxi-data-processing-quick-copy,
    google_storage_bucket_object.deploy_airflow_dag_step-01-taxi-data-download,
    google_storage_bucket_object.deploy_airflow_dag_step-02-taxi-data-processing,
    google_storage_bucket_object.deploy_airflow_dag_step-03-hydrate-tables,
    google_storage_bucket_object.deploy_airflow_dag_sample-dataflow-start-streaming-job,

    google_storage_bucket_object.deploy_airflow_dag_sample-rideshare-iceberg-serverless,
    google_storage_bucket_object.deploy_airflow_dag_sample-rideshare-download-images,
    google_storage_bucket_object.deploy_airflow_dag_sample-rideshare-website,
    google_storage_bucket_object.deploy_airflow_dag_sample-rideshare-llm-hydrate-data,
    google_storage_bucket_object.deploy_airflow_dag_sample-rideshare-hydrate-data,

  ]
  # This just a "guess" and might need to be extended.  The Composer (Airflow) cluster is sized very small so it 
  # takes longer to sync the DAG files
  create_duration = "180s"
}


# Deploy all the remaining DAGs (hopefully the initial ones have synced)
# When the Run-All-Dag deploys, it should run automatically

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_run-all-dags" {
  name   = "${local.local_composer_dag_path}/run-all-dags.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/run-all-dags.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-bigquery-data-transfer-service" {
  name   = "${local.local_composer_dag_path}/sample-bigquery-data-transfer-service.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-bigquery-data-transfer-service.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-bigquery-start-spanner" {
  name   = "${local.local_composer_dag_path}/sample-bigquery-start-spanner.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-bigquery-start-spanner.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-bigquery-stop-spanner" {
  name   = "${local.local_composer_dag_path}/sample-bigquery-stop-spanner.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-bigquery-stop-spanner.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-create-data-fusion" {
  name   = "${local.local_composer_dag_path}/sample-create-data-fusion.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-create-data-fusion.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}



# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataflow-stop-streaming-job" {
  name   = "${local.local_composer_dag_path}/sample-dataflow-stop-streaming-job.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataflow-stop-streaming-job.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-datastream-public-ip-deploy" {
  name   = "${local.local_composer_dag_path}/sample-datastream-public-ip-deploy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-datastream-public-ip-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-datastream-public-ip-destroy" {
  name   = "${local.local_composer_dag_path}/sample-datastream-public-ip-destroy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-datastream-public-ip-destroy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-datastream-public-ip-generate-data" {
  name   = "${local.local_composer_dag_path}/sample-datastream-public-ip-generate-data.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-datastream-public-ip-generate-data.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-datastream-private-ip-deploy" {
  name   = "${local.local_composer_dag_path}/sample-datastream-private-ip-deploy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-datastream-private-ip-deploy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-datastream-private-ip-destroy" {
  name   = "${local.local_composer_dag_path}/sample-datastream-private-ip-destroy.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-datastream-private-ip-destroy.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-datastream-private-ip-generate-data" {
  name   = "${local.local_composer_dag_path}/sample-datastream-private-ip-generate-data.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-datastream-private-ip-generate-data.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-dataplex-run-data-quality" {
  name   = "${local.local_composer_dag_path}/sample-dataplex-run-data-quality.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-dataplex-run-data-quality.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-export-taxi-trips-from-bq-to-gcs-cluster" {
  name   = "${local.local_composer_dag_path}/sample-export-taxi-trips-from-bq-to-gcs-cluster.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-export-taxi-trips-from-bq-to-gcs-cluster.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-export-taxi-trips-from-bq-to-gcs-serverless" {
  name   = "${local.local_composer_dag_path}/sample-export-taxi-trips-from-bq-to-gcs-serverless.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-export-taxi-trips-from-bq-to-gcs-serverless.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-iceberg-create-tables-update-data" {
  name   = "${local.local_composer_dag_path}/sample-iceberg-create-tables-update-data.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-iceberg-create-tables-update-data.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-download-images" {
  name   = "${local.local_composer_dag_path}/sample-rideshare-download-images.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-rideshare-download-images.py"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-hydrate-data" {
  name   = "${local.local_composer_dag_path}/sample-rideshare-hydrate-data.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-rideshare-hydrate-data.py"

  depends_on = [ 
    ]  
}

# Upload DAG
# resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-hydrate-object-table" {
#   name   = "${local.local_composer_dag_path}/sample-rideshare-hydrate-object-table.py"
#   bucket = local.local_composer_bucket_name
#   source = "../cloud-composer/dags/sample-rideshare-hydrate-object-table.py"
# 
#   depends_on = [ 
#     ]  
# }

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-iceberg-serverless" {
  name   = "${local.local_composer_dag_path}/sample-rideshare-iceberg-serverless.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-rideshare-iceberg-serverless.py"

  depends_on = [ 
    ]  
}

# Upload DAG
# resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-object-table-delay" {
#   name   = "${local.local_composer_dag_path}/sample-rideshare-object-table-delay.py"
#   bucket = local.local_composer_bucket_name
#   source = "../cloud-composer/dags/sample-rideshare-object-table-delay.py"
#
#   depends_on = [ 
#     ]  
# }


# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-run-data-quality" {
  name   = "${local.local_composer_dag_path}/sample-rideshare-run-data-quality.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-rideshare-run-data-quality.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-website" {
  name   = "${local.local_composer_dag_path}/sample-rideshare-website.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-rideshare-website.py"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-rideshare-llm-hydrate-data" {
  name   = "${local.local_composer_dag_path}/sample-rideshare-llm-hydrate-data.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-rideshare-llm-hydrate-data.py"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-seed-unstructured-data" {
  name   = "${local.local_composer_dag_path}/sample-seed-unstructured-data.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-seed-unstructured-data.py"

  depends_on = [ 
    ]  
}

# Upload DAG
resource "google_storage_bucket_object" "deploy_airflow_dag_sample-sla-miss-task-groups" {
  name   = "${local.local_composer_dag_path}/sample-sla-miss-task-groups.py"
  bucket = local.local_composer_bucket_name
  source = "../cloud-composer/dags/sample-sla-miss-task-groups.py"

  depends_on = [ 
    time_sleep.wait_for_airflow_dag_sync
    ]  
}

####################################################################################
# Deploy App Engine files
####################################################################################
# e.g. gcloud app deploy ./app.yaml --project=data-analytics-demo-02kg6c8jm9 --quiet

# These are uploaded to the composer/data path where an Airflow job can deploy the website
resource "google_storage_bucket_object" "deploy_rideshare_website_app_yaml" {
  name    = "${local.local_composer_data_path}/rideshare-website/app.yaml"
  bucket  = local.local_composer_bucket_name
  source  = "../rideshare-website/app.yaml" 
}

resource "google_storage_bucket_object" "deploy_rideshare_website_gcloudignore" {
  name    = "${local.local_composer_data_path}/rideshare-website/.gcloudignore"
  bucket  = local.local_composer_bucket_name
  source  = "../rideshare-website/.gcloudignore" 
}

resource "google_storage_bucket_object" "deploy_rideshare_website_www_configuration" {
  name    = "${local.local_composer_data_path}/rideshare-website/www/configuration.html"
  bucket  = local.local_composer_bucket_name
  content = templatefile("../rideshare-website/www/configuration.html", { project_id =var.project_id, demo_rest_api_service_uri=var.demo_rest_api_service_uri })
}

resource "google_storage_bucket_object" "deploy_rideshare_website_www_index" {
  name    = "${local.local_composer_data_path}/rideshare-website/www/index.html"
  bucket  = local.local_composer_bucket_name
  content = templatefile("../rideshare-website/www/index.html", { project_id =var.project_id, demo_rest_api_service_uri=var.demo_rest_api_service_uri,cloud_run_service_rideshare_plus_website_url=var.cloud_run_service_rideshare_plus_website_url })
}

resource "google_storage_bucket_object" "deploy_rideshare_website_www_predict" {
  name    = "${local.local_composer_data_path}/rideshare-website/www/predict.html"
  bucket  = local.local_composer_bucket_name
  content = templatefile("../rideshare-website/www/predict.html", { project_id =var.project_id, demo_rest_api_service_uri=var.demo_rest_api_service_uri })
}

resource "google_storage_bucket_object" "deploy_rideshare_website_www_realtime" {
  name    = "${local.local_composer_data_path}/rideshare-website/www/realtime.html"
  bucket  = local.local_composer_bucket_name
  content = templatefile("../rideshare-website/www/realtime.html", { project_id =var.project_id, demo_rest_api_service_uri=var.demo_rest_api_service_uri })
}

resource "google_storage_bucket_object" "deploy_rideshare_website_www_reports" {
  name    = "${local.local_composer_data_path}/rideshare-website/www/reports.html"
  bucket  = local.local_composer_bucket_name
  content = templatefile("../rideshare-website/www/reports.html", { project_id =var.project_id, demo_rest_api_service_uri=var.demo_rest_api_service_uri })
}




####################################################################################
# Deploy Colab notebooks
####################################################################################
resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_ai_lakehouse_demo" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_ai_lakehouse_demo.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_ai_lakehouse_demo.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    bigquery_region = var.bigquery_region

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_01_customer_sentiment_analysis" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_01_customer_sentiment_analysis.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_01_customer_sentiment_analysis.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_02_driver_themes" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_02_driver_themes.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_02_driver_themes.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_03_customer_themes" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_03_customer_themes.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_03_customer_themes.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_04_driver_summary" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_04_driver_summary.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_04_driver_summary.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_05_customer_summary" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_05_customer_summary.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_05_customer_summary.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_06_driver_quantitative_analysis" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_06_driver_quantitative_analysis.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_06_driver_quantitative_analysis.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_step_07_customer_quantitative_analysis" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_step_07_customer_quantitative_analysis.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_step_07_customer_quantitative_analysis.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_ai_lakehouse_bigframes_eda" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_ai_lakehouse_bigframes_eda.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_ai_lakehouse_bigframes_eda.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}

resource "google_storage_bucket_object" "deploy_notebook_rideshare_llm_ai_lakehouse_embeddings" {
  name   = "colab-enterprise/rideshare-llm/rideshare_llm_ai_lakehouse_embeddings.ipynb"
  bucket = "code-${var.storage_bucket}"
  content = templatefile("../colab-enterprise/rideshare-llm/rideshare_llm_ai_lakehouse_embeddings.ipynb", 
  { 
    project_id = var.project_id

    bigquery_rideshare_llm_raw_dataset = var.bigquery_rideshare_llm_raw_dataset
    bigquery_rideshare_llm_enriched_dataset = var.bigquery_rideshare_llm_enriched_dataset
    bigquery_rideshare_llm_curated_dataset = var.bigquery_rideshare_llm_curated_dataset

    gcs_rideshare_lakehouse_raw_bucket = var.gcs_rideshare_lakehouse_raw_bucket    
  })
  depends_on = []  
}


####################################################################################
# Deploy Jupyter notebooks - Now for Colab
####################################################################################
resource "google_storage_bucket_object" "deploy_notebook_BigQuery-Create-TensorFlow-Model" {
  name   = "colab-enterprise/taxi-dataset-demo/BigQuery-Create-TensorFlow-Model.ipynb"
  bucket = "code-${var.storage_bucket}"

  content = templatefile("../colab-enterprise/taxi-dataset-demo/BigQuery-Create-TensorFlow-Model.ipynb", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })

  depends_on = [ 
    ]  
}


resource "google_storage_bucket_object" "deploy_notebook_BigQuery-Demo-Notebook" {
  name   = "colab-enterprise/taxi-dataset-demo/BigQuery-Demo-Notebook.ipynb"
  bucket = "code-${var.storage_bucket}"

  content = templatefile("../colab-enterprise/taxi-dataset-demo/BigQuery-Demo-Notebook.ipynb", 
  { 
    project_id = var.project_id
    bucket_name = "processed-${var.storage_bucket}"
  })


  depends_on = [ 
    ]  
}
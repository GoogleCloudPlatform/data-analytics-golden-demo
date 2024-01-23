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
variable "storage_bucket" {}
variable "random_extension" {}
variable "deployment_service_account_name" {}
variable "composer_name" {}
variable "composer_dag_bucket" {}


####################################################################################
# Deploy "data" and "scripts"
###################################################################################
# Upload the Airflow initial DAGs needed to run the system (dependencies of run-all-dags)
# Upload all the DAGs can cause issues since the Airflow instance is so small they call cannot sync
# before run-all-dags is launched
resource "null_resource" "deploy_initial_airflow_dags" {
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
gsutil cp ../cloud-composer/dags/step-*.py ${var.composer_dag_bucket}
gsutil cp ../cloud-composer/dags/sample-dataflow-start-streaming-job.py ${var.composer_dag_bucket}
EOF    
  }
}


# Upload the Airflow "data/template" files
# The data folder is the same path as the DAGs, but just has DATA as the folder name
resource "null_resource" "deploy_initial_airflow_dags_data" {
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
gsutil cp -r ../cloud-composer/data/* ${replace(var.composer_dag_bucket, "/dags", "/data")}
EOF        
  }
}


# Upload the PySpark scripts
resource "null_resource" "deploy_dataproc_scripts" {
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
gsutil cp ../dataproc/* gs://raw-${var.storage_bucket}/pyspark-code/
EOF
  }
}

# Download the BigQuery Spark JAR file
# Download the Iceberg JAR File
resource "null_resource" "deploy_dataproc_jars" {
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
gsutil cp *.jar gs://raw-${var.storage_bucket}/pyspark-code/
EOF
  }
}


# Upload the Dataflow scripts
resource "null_resource" "deploy_dataflow_scripts" {
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
gsutil cp ../dataflow/* gs://raw-${var.storage_bucket}/dataflow/
EOF
  }
}


# Upload the Dataplex scripts
data "template_file" "dataplex_data_quality_template" {
  template = "${file("../dataplex/data-quality/dataplex_data_quality_taxi.yaml")}"
  vars = {
    project_id = var.project_id
    dataplex_region = "REPLACE-REGION"
    random_extension = var.random_extension
  }  
}

resource "google_storage_bucket_object" "dataplex_data_quality_yaml" {
  name        = "dataplex/data-quality/dataplex_data_quality_taxi.yaml"
  content     = "${data.template_file.dataplex_data_quality_template.rendered}"
  bucket      = "code-${var.storage_bucket}"
}


# Replace the Bucket Name in the Jupyter notebooks
resource "null_resource" "deploy_vertex_notebooks" {
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
find ../notebooks -type f -name "*.ipynb" -print0 | while IFS= read -r -d '' file; do
    echo "Notebook Replacing: $${file}"
    searchString="../notebooks/"
    replaceString="../notebooks-with-substitution/"
    destFile=$(echo "$${file//$searchString/$replaceString}")
    echo "destFile: $${destFile}"
    sed "s/REPLACE-BUCKET-NAME/processed-${var.storage_bucket}/g" "$${file}" > "$${destFile}.tmp"
    sed "s/REPLACE-PROJECT-ID/${var.project_id}/g" "$${destFile}.tmp" > "$${destFile}"
done
gsutil cp ../notebooks-with-substitution/*.ipynb gs://processed-${var.storage_bucket}/notebooks/
EOF
  }
}


# Replace the Bucket Name in the Jupyter notebooks
resource "null_resource" "deploy_bigspark" {
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
find ../bigspark -type f -name "*.py" -print0 | while IFS= read -r -d '' file; do
    echo "BigSpark Replacing: $${file}"
    searchString="../bigspark/"
    replaceString="../bigspark-with-substitution/"
    destFile=$(echo "$${file//$searchString/$replaceString}")
    echo "destFile: $${destFile}"
    sed "s/REPLACE-BUCKET-NAME/raw-${var.storage_bucket}/g" "$${file}" > "$${destFile}.tmp"
    sed "s/REPLACE-PROJECT-ID/${var.project_id}/g" "$${destFile}.tmp" > "$${destFile}"
done
gsutil cp ../bigspark-with-substitution/*.py gs://raw-${var.storage_bucket}/bigspark/
gsutil cp ../bigspark/*.csv gs://raw-${var.storage_bucket}/bigspark/
EOF
  }
}


# Upload the sample Delta.io files
# The manifest files need to have the GCS bucket name updated
resource "null_resource" "deploy_delta_io_files" {
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
cp -rf ../sample-data/rideshare_trips/* ../sample-data/rideshare_trips-with-substitution
find ../sample-data/rideshare_trips/_symlink_format_manifest -type f -name "*" -print0 | while IFS= read -r -d '' file; do
    echo "Updating Manifest file: $${file}"
    searchString="../sample-data/rideshare_trips"
    replaceString="../sample-data/rideshare_trips-with-substitution"
    destFile=$(echo "$${file//$searchString/$replaceString}")
    echo "destFile: $${destFile}"
    sed "s/REPLACE-BUCKET-NAME/processed-${var.storage_bucket}/g" "$${file}" > "$${destFile}"
done
gsutil cp -r ../sample-data/rideshare_trips-with-substitution/* gs://processed-${var.storage_bucket}/delta_io/rideshare_trips/
gsutil rm gs://processed-${var.storage_bucket}/delta_io/rideshare_trips/README.md
EOF
  }
}



# You need to wait for Airflow to read the DAGs just uploaded
# Only a few DAGs are uploaded so that we can sync quicker
resource "time_sleep" "wait_for_airflow_dag_sync" {
  depends_on = [
    null_resource.deploy_initial_airflow_dags,
    null_resource.deploy_initial_airflow_dags_data
  ]
  # This just a "guess" and might need to be extended.  The Composer (Airflow) cluster is sized very small so it 
  # takes longer to sync the DAG files
  create_duration = "180s"
}


# Kick off Airflow DAG
# The Run-All-Dags as been scheduled for @once.  
# The below commands do not work for No External IPs
/*
resource "null_resource" "run_airflow_dag" {
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
gcloud composer environments run ${var.composer_name} --project ${var.project_id} --location ${var.composer_region} dags trigger -- run-all-dags
EOF
  }
  depends_on = [
    time_sleep.wait_for_airflow_dag_sync
  ]
}
*/

# Deploy all the remaining DAGs (hopefully the initial ones have synced)
# When the Run-All-Dag deploys, it should run automatically
resource "null_resource" "deploy_all_airflow_dags" {
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
gsutil cp -n ../cloud-composer/dags/* ${var.composer_dag_bucket}

EOF    
  }
  depends_on = [
    time_sleep.wait_for_airflow_dag_sync
  ]
}


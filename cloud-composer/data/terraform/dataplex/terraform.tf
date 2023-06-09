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
# Common Variables (typically always required)
####################################################################################
variable "project_id" {
  type        = string
  description = "The current project"
  validation {
    condition     = length(var.project_id) > 0
    error_message = "The project_id is required."
  }
}

variable "impersonate_service_account" {
  type        = string
  description = "We want to impersonate the Terraform service account"
  default     = "us-west2"
  validation {
    condition     = length(var.impersonate_service_account) > 0
    error_message = "The impersonate_service_account is required."
  }
}


####################################################################################
# Deployment Specific Variables (typically you customize this)
####################################################################################
variable "dataplex_region" {
  type        = string
  description = "The dataplex_region of the dataplex"
  validation {
    condition     = length(var.dataplex_region) > 0
    error_message = "The dataplex_region is required."
  }
}

variable "raw_bucket_name" {
  type        = string
  description = "The raw_bucket_name"
  validation {
    condition     = length(var.raw_bucket_name) > 0
    error_message = "The raw_bucket_name is required."
  }
}

variable "processed_bucket_name" {
  type        = string
  description = "The processed_bucket_name"
  validation {
    condition     = length(var.processed_bucket_name) > 0
    error_message = "The processed_bucket_name is required."
  }
}

variable "taxi_dataset_id" {
  type        = string
  description = "The taxi_dataset_id"
  validation {
    condition     = length(var.taxi_dataset_id) > 0
    error_message = "The taxi_dataset_id is required."
  }
}

variable "thelook_dataset_id" {
  type        = string
  description = "The thelook_dataset_id"
  validation {
    condition     = length(var.thelook_dataset_id) > 0
    error_message = "The thelook_dataset_id is required."
  }
}

variable "random_extension" {
  type        = string
  description = "The random_extension"
  validation {
    condition     = length(var.random_extension) > 0
    error_message = "The random_extension is required."
  }
}

variable "rideshare_raw_bucket" {
  type        = string
  description = "The rideshare_raw_bucket"
  validation {
    condition     = length(var.rideshare_raw_bucket) > 0
    error_message = "The rideshare_raw_bucket is required."
  }
}

variable "rideshare_enriched_bucket" {
  type        = string
  description = "The rideshare_enriched_bucket"
  validation {
    condition     = length(var.rideshare_enriched_bucket) > 0
    error_message = "The rideshare_enriched_bucket is required."
  }
}

variable "rideshare_curated_bucket" {
  type        = string
  description = "The rideshare_curated_bucket"
  validation {
    condition     = length(var.rideshare_curated_bucket) > 0
    error_message = "The rideshare_curated_bucket is required."
  }
}

variable "rideshare_raw_dataset" {
  type        = string
  description = "The rideshare_raw_dataset"
  validation {
    condition     = length(var.rideshare_raw_dataset) > 0
    error_message = "The rideshare_raw_dataset is required."
  }
}

variable "rideshare_enriched_dataset" {
  type        = string
  description = "The rideshare_enriched_dataset"
  validation {
    condition     = length(var.rideshare_enriched_dataset) > 0
    error_message = "The rideshare_enriched_dataset is required."
  }
}

variable "rideshare_curated_dataset" {
  type        = string
  description = "The rideshare_curated_dataset"
  validation {
    condition     = length(var.rideshare_curated_dataset) > 0
    error_message = "The rideshare_curated_dataset is required."
  }
}

####################################################################################
# Provider with service account impersonation
####################################################################################
terraform {
  required_providers {
    google = {
      source                = "hashicorp/google-beta"
      version               = "4.42.0"
      configuration_aliases = [google.service_principal_impersonation]
    }
  }
}

# Provider that uses service account impersonation (best practice - no exported secret keys to local computers)
provider "google" {
  alias                       = "service_principal_impersonation"
  impersonate_service_account = var.impersonate_service_account
  project                     = var.project_id
}


####################################################################################
# Deployment Specific Resources (typically you customize this)
####################################################################################


##########################################################################################
# Taxi Data
##########################################################################################
/*
gcloud dataplex lakes create "taxi-data-lake-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Data Lake" \
    --display-name="Taxi Data Lake"
*/
resource "google_dataplex_lake" "taxi-data-lake" {
  project      = var.project_id
  location     = var.dataplex_region
  name         = "taxi-data-lake-${var.random_extension}"
  description  = "Taxi Data Lake"
  display_name = "Taxi Data Lake"
}

/*
# Create the Zones 
gcloud dataplex zones create "taxi-raw-zone-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --type=RAW \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Raw Zone" \
    --display-name="Taxi Raw Zone" \
    --csv-delimiter="," \
    --csv-header-rows=1
*/
resource "google_dataplex_zone" "taxi-raw-zone" {
  project      = var.project_id
  location     = var.dataplex_region
  lake         = google_dataplex_lake.taxi-data-lake.name
  name         = "taxi-raw-zone-${var.random_extension}"
  type         = "RAW"
  description  = "Taxi Raw Zone"
  display_name = "Taxi Raw Zone"

  resource_spec {
    location_type = "MULTI_REGION"
  }

  discovery_spec {
    enabled = true
    # every 12 hours
    schedule = "0 */12 * * *" 
    csv_options {
        delimiter = ","
        header_rows = 1
    }
  }

  depends_on = [
    google_dataplex_lake.taxi-data-lake
  ]    
}

/*
gcloud dataplex zones create "taxi-curated-zone-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Curated Zone" \
    --display-name="Taxi Curated Zone" \
    --csv-delimiter="," \
    --csv-header-rows=1
*/
resource "google_dataplex_zone" "taxi-curated-zone" {
  project      = var.project_id
  location     = var.dataplex_region
  lake         = google_dataplex_lake.taxi-data-lake.name
  name         = "taxi-curated-zone-${var.random_extension}"
  type         = "CURATED"
  description  = "Taxi Curated Zone"
  display_name = "Taxi Curated Zone"

  resource_spec {
    location_type = "MULTI_REGION"
  }

  discovery_spec {
    enabled = true
    # every 12 hours
    schedule = "0 */12 * * *" 
    csv_options {
        delimiter = ","
        header_rows = 1
    }
  }

  depends_on = [
    google_dataplex_lake.taxi-data-lake
  ]  
}


/*
gcloud dataplex assets create "taxi-raw-bucket-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --zone="taxi-raw-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Raw Bucket" \
    --display-name="Taxi Raw Bucket" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${raw_bucket_name}" \
    --discovery-enabled \
    --csv-delimiter="," \
    --csv-header-rows=1
*/
resource "google_dataplex_asset" "taxi-raw-bucket-asset" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.taxi-data-lake.name
  dataplex_zone = google_dataplex_zone.taxi-raw-zone.name
  name          = "taxi-raw-bucket-${var.random_extension}"
  description   = "Taxi Raw Bucket"
  display_name  = "Taxi Raw Bucket"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/buckets/${var.raw_bucket_name}"
    type = "STORAGE_BUCKET"
  }

  depends_on = [
    google_dataplex_lake.taxi-data-lake,
    google_dataplex_zone.taxi-raw-zone
  ]
}

/*
gcloud dataplex assets create "taxi-processed-bucket-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --zone="taxi-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi Processed Bucket" \
    --display-name="Taxi Processed Bucket" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${PROCESSED_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="," \
    --csv-header-rows=1 
*/
resource "google_dataplex_asset" "taxi-processed-bucket-asset" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.taxi-data-lake.name
  dataplex_zone = google_dataplex_zone.taxi-curated-zone.name
  name          = "taxi-processed-bucket-${var.random_extension}"
  description   = "Taxi Processed Bucket"
  display_name  = "Taxi Processed Bucket"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/buckets/${var.processed_bucket_name}"
    type = "STORAGE_BUCKET"
  }

  depends_on = [
    google_dataplex_lake.taxi-data-lake,
    google_dataplex_zone.taxi-curated-zone
  ]
}

/*
gcloud dataplex assets create "taxi-processed-datasets-${RANDOM_EXTENSION}" \
    --lake="taxi-data-lake-${RANDOM_EXTENSION}" \
    --zone="taxi-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Taxi BigQuery Dataset" \
    --display-name="Taxi BigQuery Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/${TAXI_DATASET}" \
    --discovery-enabled
*/
resource "google_dataplex_asset" "taxi-processed-dataset" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.taxi-data-lake.name
  dataplex_zone = google_dataplex_zone.taxi-curated-zone.name
  name          = "taxi-processed-dataset-${var.random_extension}"
  description   = "Taxi BigQuery Dataset"
  display_name  = "Taxi BigQuery Dataset"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/datasets/${var.taxi_dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  depends_on = [
    google_dataplex_lake.taxi-data-lake,
    google_dataplex_zone.taxi-curated-zone
  ]
}


##########################################################################################
# The Look eCommerce
##########################################################################################
/*
gcloud dataplex lakes create "ecommerce-data-lake-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="The Look eCommerce Data Lake" \
    --display-name="The Look eCommerce Data Lake"
*/
resource "google_dataplex_lake" "ecommerce-data-lake" {
  project      = var.project_id
  location     = var.dataplex_region
  name         = "ecommerce-data-lake-${var.random_extension}"
  description  = "The Look eCommerce Data Lake"
  display_name = "The Look eCommerce Data Lake"
}

/*
gcloud dataplex zones create "ecommerce-curated-zone-${RANDOM_EXTENSION}" \
    --lake="ecommerce-data-lake-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="The Look eCommerce Curated Zone" \
    --display-name="The Look eCommerce Zone"
*/
resource "google_dataplex_zone" "ecommerce-curated-zone" {
  project      = var.project_id
  location     = var.dataplex_region
  lake         = google_dataplex_lake.ecommerce-data-lake.name
  name         = "ecommerce-curated-zone-${var.random_extension}"
  type         = "CURATED"
  description  = "The Look eCommerce Curated Zone"
  display_name = "The Look eCommerce Zone"

  resource_spec {
    location_type = "MULTI_REGION"
  }

  discovery_spec {
    enabled = true
    # every 12 hours
    schedule = "0 */12 * * *" 
    csv_options {
        delimiter = ","
        header_rows = 1
    }
  }

  depends_on = [
    google_dataplex_lake.ecommerce-data-lake
  ]  
}

/*
gcloud dataplex assets create "ecommerce-dataset-${RANDOM_EXTENSION}" \
    --lake="ecommerce-data-lake-${RANDOM_EXTENSION}" \
    --zone="ecommerce-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="TheLook eCommerce BigQuery Dataset" \
    --display-name="eCommerce BigQuery Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/${THELOOK_DATASET}" \
    --discovery-enabled
*/    
resource "google_dataplex_asset" "ecommerce-dataset" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.ecommerce-data-lake.name
  dataplex_zone = google_dataplex_zone.ecommerce-curated-zone.name
  name          = "ecommerce-dataset-${var.random_extension}"
  description   = "TheLook eCommerce BigQuery Dataset" 
  display_name  = "eCommerce BigQuery Dataset"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/datasets/${var.thelook_dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  depends_on = [
    google_dataplex_lake.ecommerce-data-lake,
    google_dataplex_zone.ecommerce-curated-zone
  ]
}


##########################################################################################
# Rideshare Lakehouse
##########################################################################################
/*
gcloud dataplex lakes create "rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Rideshare Lakehouse" \
    --display-name="Rideshare Lakehouse"
*/
resource "google_dataplex_lake" "rideshare-data-lake" {
  project      = var.project_id
  location     = var.dataplex_region
  name         = "rideshare-lakehouse-${var.random_extension}"
  description  = "Rideshare Lakehouse"
  display_name = "Rideshare Lakehouse"
}


/*
# RAW
gcloud dataplex zones create "rideshare-raw-zone-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --type=RAW \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Raw Zone" \
    --display-name="Raw Zone"
*/
resource "google_dataplex_zone" "rideshare-raw-zone" {
  project      = var.project_id
  location     = var.dataplex_region
  lake         = google_dataplex_lake.rideshare-data-lake.name
  name         = "rideshare-raw-zone-${var.random_extension}"
  type         = "RAW"
  description  = "Raw Zone"
  display_name = "Raw Zone"

  resource_spec {
    location_type = "MULTI_REGION"
  }

  discovery_spec {
    enabled = true
    # every 12 hours
    schedule = "0 */12 * * *" 
    csv_options {
        delimiter = ","
        header_rows = 1
    }
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake
  ]    
}

/*
gcloud dataplex assets create "rideshare-raw-unstructured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-raw-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Raw Zone - Unstructured" \
    --display-name="Raw Zone - Unstructured" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RIDESHARE_RAW_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="|" \
    --csv-header-rows=1 
*/
resource "google_dataplex_asset" "rideshare-raw-unstructured" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.rideshare-data-lake
  dataplex_zone = google_dataplex_zone.rideshare-raw-zone
  name          = "rideshare-raw-unstructured-${var.random_extension}"
  description   = "Raw Asset - Unstructured"
  display_name  = "Raw Asset - Unstructured"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/buckets/${var.rideshare_raw_bucket}"
    type = "STORAGE_BUCKET"
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake,
    google_dataplex_zone.rideshare-raw-zone
  ]
}

/*
gcloud dataplex assets create "rideshare-raw-structured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-raw-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Raw Zone - Structured" \
    --display-name="Raw Zone - Structured" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/rideshare_lakehouse_raw" \
    --discovery-enabled
*/
resource "google_dataplex_asset" "rideshare-raw-structured" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.rideshare-data-lake
  dataplex_zone = google_dataplex_zone.rideshare-raw-zone
  name          = "rideshare-raw-structured-${var.random_extension}"
  description   = "Raw Asset - Structured"
  display_name  = "Raw Asset - Structured"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/datasets/${var.rideshare_lakehouse_raw_dataset}"
    type = "BIGQUERY_DATASET"
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake,
    google_dataplex_zone.rideshare-raw-zone
  ]
}

/*
# Enriched
gcloud dataplex zones create "rideshare-enriched-zone-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Enriched Zone" \
    --display-name="Enriched Zone"
*/
resource "google_dataplex_zone" "rideshare-enriched-zone" {
  project      = var.project_id
  location     = var.dataplex_region
  lake         = google_dataplex_lake.rideshare-data-lake.name
  name         = "rideshare-enriched-zone-${var.random_extension}"
  type         = "CURATED"
  description  = "Enriched Zone"
  display_name = "Enriched Zone"

  resource_spec {
    location_type = "MULTI_REGION"
  }

  discovery_spec {
    enabled = true
    # every 12 hours
    schedule = "0 */12 * * *" 
    csv_options {
        delimiter = ","
        header_rows = 1
    }
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake
  ]    
}

/*
gcloud dataplex assets create "rideshare-enriched-unstructured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-enriched-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Enriched Zone - Unstructured" \
    --display-name="Enriched Zone - Unstructured" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RIDESHARE_ENRICHED_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="|" \
    --csv-header-rows=1 
*/
resource "google_dataplex_asset" "rideshare-enriched-unstructured" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.rideshare-data-lake
  dataplex_zone = google_dataplex_zone.rideshare-enriched-zone
  name          = "rideshare-enriched-unstructured-${var.random_extension}"
  description   = "Enriched Asset - Unstructured"
  display_name  = "Enriched Asset - Unstructured"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/buckets/${var.rideshare_enriched_bucket}"
    type = "STORAGE_BUCKET"
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake,
    google_dataplex_zone.rideshare-enriched-zone
  ]
}


/*
gcloud dataplex assets create "rideshare-enriched-structured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-enriched-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Enriched Zone - Structured" \
    --display-name="Enriched Zone - Structured" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/rideshare_lakehouse_enriched" \
    --discovery-enabled
*/
resource "google_dataplex_asset" "rideshare-enriched-structured" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.rideshare-data-lake
  dataplex_zone = google_dataplex_zone.rideshare-enriched-zone
  name          = "rideshare-enriched-structured-${var.random_extension}"
  description   = "Enriched Asset - Structured"
  display_name  = "Enriched Asset - Structured"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/datasets/${var.rideshare_lakehouse_enriched_dataset}"
    type = "BIGQUERY_DATASET"
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake,
    google_dataplex_zone.rideshare-enriched-zone
  ]
}


/*
# Curated
gcloud dataplex zones create "rideshare-curated-zone-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --type=CURATED \
    --resource-location-type=MULTI_REGION \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Curated Zone" \
    --display-name="Curated Zone"
*/
resource "google_dataplex_zone" "rideshare-curated-zone" {
  project      = var.project_id
  location     = var.dataplex_region
  lake         = google_dataplex_lake.rideshare-data-lake.name
  name         = "rideshare-curated-zone-${var.random_extension}"
  type         = "CURATED"
  description  = "Curated Zone"
  display_name = "Curated Zone"

  resource_spec {
    location_type = "MULTI_REGION"
  }

  discovery_spec {
    enabled = true
    # every 12 hours
    schedule = "0 */12 * * *" 
    csv_options {
        delimiter = ","
        header_rows = 1
    }
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake
  ]    
}
/*
gcloud dataplex assets create "rideshare-curated-unstructured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Curated Zone - Unstructured" \
    --display-name="Curated Zone - Unstructured" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${RIDESHARE_CURATED_BUCKET}" \
    --discovery-enabled \
    --csv-delimiter="|" \
    --csv-header-rows=1 
*/
resource "google_dataplex_asset" "rideshare-curated-unstructured" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.rideshare-data-lake
  dataplex_zone = google_dataplex_zone.rideshare-curated-zone
  name          = "rideshare-curated-unstructured-${var.random_extension}"
  description   = "Curated Asset - Unstructured"
  display_name  = "Curated Asset - Unstructured"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/buckets/${var.rideshare_curated_bucket}"
    type = "STORAGE_BUCKET"
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake,
    google_dataplex_zone.rideshare-curated-zone
  ]
}

/*
gcloud dataplex assets create "rideshare-curated-structured-${RANDOM_EXTENSION}" \
    --lake="rideshare-lakehouse-${RANDOM_EXTENSION}" \
    --zone="rideshare-curated-zone-${RANDOM_EXTENSION}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --description="Curated Zone - Structured" \
    --display-name="Curated Zone - Structured" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name="projects/${PROJECT_ID}/datasets/rideshare_lakehouse_curated" \
    --discovery-enabled

*/
resource "google_dataplex_asset" "rideshare-curated-structured" {
  project       = var.project_id
  location      = var.dataplex_region
  lake          = google_dataplex_lake.rideshare-data-lake
  dataplex_zone = google_dataplex_zone.rideshare-curated-zone
  name          = "rideshare-curated-structured-${var.random_extension}"
  description   = "Curated Asset - Structured"
  display_name  = "Curated Asset - Structured"

  discovery_spec { 
    enabled = true 
  }

  resource_spec {
    name = "projects/${var.project_id}/datasets/${var.rideshare_lakehouse_curated_dataset}"
    type = "BIGQUERY_DATASET"
  }

  depends_on = [
    google_dataplex_lake.rideshare-data-lake,
    google_dataplex_zone.rideshare-curated-zone
  ]
}
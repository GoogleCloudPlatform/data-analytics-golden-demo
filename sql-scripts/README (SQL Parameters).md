## Step 1 - Add file
- Add your SQL file in this directory

## Step 2 - Change paramters
- Parameters that will be replaced in your SQL with parameters used by Terraform:
  - ${project_id} - the GCP project that is created
  - ${region} - a region has been added for each resource
  - ${bigquery_taxi_dataset} - the taxi dataset name
  - ${bigquery_thelook_ecommerce_dataset} - the looker ecommerce dataset
  - ${bucket_name} - the GCS bucket with the processed data
  - ${bigquery_region} - the BigQuery region mulitregion ["us"] or ["eu"]
  - ${gcp_account_name} - the name of the user (for row level security or such)
  - Add your others!!!

## Step 3 - Add Terraform code
- Open ./terraform-modules/sql-scripts/sql-scripts.tf
- Scroll to the bottom
- Add a block of code
  - Replace REPLACE_WITH_FILENAME your "filename" into the below
  - Replace var.bigquery_taxi_dataset with your dataset name in the second block of code
```
####################################################################################
# REPLACE_WITH_FILENAME
####################################################################################
resource "google_bigquery_routine" "sproc_REPLACE_WITH_FILENAME" {
  dataset_id      = var.bigquery_taxi_dataset
  routine_id      = "REPLACE_WITH_FILENAME"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = "${data.template_file.sproc_REPLACE_WITH_FILENAME.rendered}"
  definition_body = templatefile("../sql-scripts/DIRECTORY/REPLACE_WITH_FILENAME.sql", 
  { 
    project_id = var.project_id
    region = var.region
    bigquery_taxi_dataset = var.bigquery_taxi_dataset
    bigquery_thelook_ecommerce_dataset = var.bigquery_thelook_ecommerce_dataset
    bucket_name = var.storage_bucket
    bigquery_region = var.bigquery_region
    gcp_account_name = var.gcp_account_name
  })
}
```

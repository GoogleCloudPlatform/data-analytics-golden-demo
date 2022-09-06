
# Change Log
All notable changes to this project will be documented in this file.
 
## [Released] - Aug 2022
### Added
    - Added Dataplex (taxi and eCommerce data lakes/mesh).  There is a data quality DAG added as well.
    - Added a sample ingestion into BigQuery: sp_demo_ingest_data 
    - Taxi data for 2022 is being downloaded (up until April)
    - BigQuery Data Masking API is now enabled, you can see this on the Dataplex Policies page.  No demo has been created for this feature, yet.  
    - Added a DAG to generate Iceberg files. 
### Fixed
    - Fixed JSON stored procedure (on GitHub). 

 
## [Released] - July 2022
 
Cleaned up some code and added some Data Fusion DevOps samples.
 
### Added
- Terraform Parameters
    - omni_dataset: The full path project_id.dataset_id to the OMNI data.
    - omni_aws_connection: The connection region and name
    - omni_aws_s3_bucket_name: The full path project_id.dataset_id to the OMNI data.
- datafusion folder 
    - sample DevOps with Data Fusion (not deployed as part of Terraform)  
- new stored procdures / updates
    - sp_demo_taxi_streaming_data - shows queries against streaming table
    - sp_demo_federated_query - updated to generate data in a region that can join to BigQuery
    - sp_demo_taxi_streaming_data - demos Delta.io/Delta Lake interaction with BigQuery

### Changed
- sql-scripts
    - added the AWS omni scripts (demo_omni folder)
    - re-arranged some scripts into folders
    - fixed some clean up / truncate tables items
 
### Fixed
- NYC taxi data was put behind a CDN and the download links changed.  
    - DAG: step-01-taxi-data-download.py was updated.
- BigLake service principal now requires an org policy change. 
    - DAG: step-04-create-biglake-connection.py was updated
    - Terraform: tf-resources.tf was updated
    - Airflow will impersonate a higher level account that can make the org policy change.



## [1.0.0] - 2022-06-01
Initial deployment
### Added
### Changed   
### Fixed

--------------------------------------------------------------------------------------------------
-- STEP 1 - Delete existing exported files, in data-analytics-preview project
--------------------------------------------------------------------------------------------------
-- Delete: gs://data-analytics-preview/data-analytics-agent/Data-Export/


--------------------------------------------------------------------------------------------------
-- STEP 2 - Generate the SQL commands to do the export, in data-analytics-preview project
--------------------------------------------------------------------------------------------------
-- https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#export_data_statement
SELECT CONCAT("EXPORT DATA OPTIONS (uri = 'gs://gcs-bucket-namet/data-analytics-agent/Data-Export/" ,
              table_name, "/", table_name,
              "_*.avro', format = 'AVRO', overwrite = true, use_avro_logical_types = true) AS ",
              "(SELECT * FROM `agentic_beans_raw.",table_name,"`);") AS export_command
FROM `agentic_beans_raw.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'BASE TABLE' 
ORDER BY table_name;



-- Save Results to Google Sheets, so you can copy the rows


--------------------------------------------------------------------------------------------------
-- STEP 3 - Run the SQL commands to do the export, in data-analytics-preview project
--------------------------------------------------------------------------------------------------
-- In BigQuery paste the geneated EXPORT commands and run them


--------------------------------------------------------------------------------------------------
-- STEP 4 - Delete the existing data export in the public bucket.  Or create a new Version number.
--------------------------------------------------------------------------------------------------
-- Optional - delete existing v1 folder or create a new version (v1) number
-- Delete: data-analytics-golden-demo/data-analytics-agent/v1/Data-Export


--------------------------------------------------------------------------------------------------
-- STEP 4
--------------------------------------------------------------------------------------------------
-- Copy to public storage account
-- Must be in Google.com context
gsutil -m -q cp -r gs://data-analytics-preview/data-analytics-agent/Data-Export  gs://data-analytics-golden-demo/data-analytics-agent/v1/Data-Export


--------------------------------------------------------------------------------------------------
-- STEP 5 - Generate LOAD commands, in data-analytics-preview project
--------------------------------------------------------------------------------------------------
-- https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#load_data_statement
SELECT CONCAT("LOAD DATA OVERWRITE `${project_id}.${bigquery_agentic_beans_raw_dataset}." , table_name, 
              "` FROM FILES ( format = 'AVRO', enable_logical_types = true, uris = ['gs://data-analytics-golden-demo/data-analytics-agent/v1/Data-Export/" , table_name , "/" , table_name , "_*.avro']);") AS load_command
FROM `data_analytics_agent.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'BASE TABLE' 
ORDER BY table_name;

-- Save results to Google Sheets so you can copy


--------------------------------------------------------------------------------------------------
-- STEP 6 - Copy/Replace the generated SQL to initialize.sql
--------------------------------------------------------------------------------------------------
-- This is in the sql-scripts folder under the section header "Load all data"

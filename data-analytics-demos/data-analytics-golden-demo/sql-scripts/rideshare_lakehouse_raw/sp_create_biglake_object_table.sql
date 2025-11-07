 /*##################################################################################
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
  ###################################################################################*/
  
    
  /*
  Use Cases:
      - Be able to query your data lake files with SQL
      - Filter files by last updated and/or metadata
      - Apply row level secuirty to the files that users can view
      - You can even use these tables to determine which files on your storage is new and should be processed
  
  Description: 
      - Customers have images, PDF and other types of data in their lakes.  
      - Customers want to gain insights to this data which is typically operated on at a file level
      - Users want an easy way to navigate and find items on data lakes
  
  Show:
      - 
  
  References:
      - https://cloud.google.com/bigquery/docs/object-table-introduction
      - https://cloud.google.com/vision/docs/drag-and-drop
  
  Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images`;
  */


-- Create a table over GCS (we can now see our data lake in a table)
-- Only the connection need access to the lake, not individual users which becomes unmanageable with billions/trillions of files
-- We do not want to recreate this each time since it takes a few minutes for the images to sync
-- which can mess up the demo
IF NOT EXISTS (SELECT  1
             FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}`.INFORMATION_SCHEMA.TABLES
            WHERE table_name = 'biglake_rideshare_images' 
              AND table_type = 'EXTERNAL')
    THEN
    CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images`
    WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
    OPTIONS (
        object_metadata="DIRECTORY",
        uris = ['gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images/*.jpg',
                'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_images/*.jpeg'],
        max_staleness=INTERVAL 30 MINUTE, 
        --metadata_cache_mode="AUTOMATIC"
        -- set to Manual for demo
        metadata_cache_mode="MANUAL"
        ); 
END IF;


-- For the demo, refresh the table (so we do not need to wait)
-- Refresh can only be done for "manual" cache mode
CALL BQ.REFRESH_EXTERNAL_METADATA_CACHE('${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images');


-- Show our objects in GCS / Data Lake
-- Metadata values are recorded as to where the image was taken
SELECT * 
  FROM `${project_id}.${bigquery_rideshare_lakehouse_raw_dataset}.biglake_rideshare_images`;
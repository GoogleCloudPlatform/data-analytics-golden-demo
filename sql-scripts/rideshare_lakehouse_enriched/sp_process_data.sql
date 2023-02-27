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
      - Cleans up the tables and calls the Spark stored procedure
  
  Description: 
      - Process all data into the Iceberg format
      - Generates "fake" credit card number for the system
      
  Show:
      - 
  
  References:
      - 
  
  Clean up / Reset script:
      DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_payment_type`;
      DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_zone`;
      DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_payment_type`;

  */

-- Remove existing tables (overwrite for demo so we can run over and over again)
-- This for when we do not have Iceberg / BigSpark and cannot create an external table.  This can be removed in the future.
IF EXISTS (SELECT  1
             FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}`.INFORMATION_SCHEMA.TABLES
            WHERE table_name = 'biglake_rideshare_payment_type_iceberg' 
              AND table_type = 'EXTERNAL')
    THEN
        DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg`;
        DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg`;
        DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigsearch_bigquery_rideshare_trip`;   
    ELSE
        DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg`;
        DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg`;
        DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigsearch_bigquery_rideshare_trip`;   
END IF;

/*
Manual example w/o BigLake Metastore Service
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg_1`
OPTIONS (
         format = 'ICEBERG',
         uris = ["gs://${gcs_rideshare_lakehouse_enriched_bucket}/iceberg-warehouse/${bigquery_rideshare_lakehouse_enriched_dataset}.db/biglake_rideshare_payment_type_iceberg/metadata/00001-57ce4e42-aef6-4786-8e73-3fa713e12d7c.metadata.json"]
       );

CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg_1`
OPTIONS (
         format = 'ICEBERG',
         uris = ["gs://${gcs_rideshare_lakehouse_enriched_bucket}/iceberg-warehouse/${bigquery_rideshare_lakehouse_enriched_dataset}.db/biglake_rideshare_trip_iceberg/metadata/00000-99e91cfc-01d9-4f15-b587-17a7969cc4f3.metadata.json"]
       );

CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg_1`
OPTIONS (
         format = 'ICEBERG',
         uris = ["gs://${gcs_rideshare_lakehouse_enriched_bucket}/iceberg-warehouse/${bigquery_rideshare_lakehouse_enriched_dataset}.db/biglake_rideshare_zone_iceberg/metadata/00000-87c9cca0-a5e4-4923-b38e-66ba035b8ee0.metadata.json"]
       );
*/

-- CALL Spark job (if not calling from Airflow DAG you can comment this out)
-- CALL `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.sp_iceberg_spark_transformation`();

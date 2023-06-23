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

 Prerequisites:
    - Run the Airflow DAG: sample-dataplex-with-hms-deploy
        - This DAG can take 45 minutes to deploy.  Dataproc metastore can take a while.
        - NOTE: Your Dataplex and Dataproc Metastore will be deleted after 48 hours (to save on costs). 
        -       ** This means all your scripts / notebooks will be DELETED!  So save them inside of storage or somewhere safe. **
        -       You will need to re-run the DAG sample-dataplex-with-hms-deploy to deploy again.

    - In the console open your Taxi Data Lake:
        - https://console.cloud.google.com/dataplex/lakes/taxi-data-lake-93b2hjnp0r;location=us-central1/environments?project=data-analytics-demo-93b2hjnp0r&supportedpurview=project
        - Click "Create Default Environment"
        - Click on the Details tab
            - Make sure your metastore is ready to use (e.g.): Metastore status: Ready as of June 14, 2023 at 10:52:03 AM UTC-4

    - It can then take another 45 minutes for Dataplex to scan and initialize

    - Goto the Explore UI:
        - https://console.cloud.google.com/dataplex/explore/lakes/taxi-data-lake-93b2hjnp0r;location=us-central1/query/workbench?project=data-analytics-demo-93b2hjnp0r&supportedpurview=project
        - Make sure Taxi Data Lake is selected 
            - NOTE: If you do not see any "tables" in the left hand side, then your Metastore might still be initializing
            - NOTE: The Dataproc Metastore is ONLY mounted to the Taxi Data Lake and not the others.  Each Data Lake requires its own Metastore (at this point in time).

 Use Cases:
    -

 Description: 
    -
  
 Clean up / Reset script:
    - gsutil delete external files

*/

-- Sample query using Spark SQL
-- We can query our discovered assets

-- BigQuery tables
SELECT taxi_trips.TaxiCompany,
       CAST(taxi_trips.Pickup_DateTime AS DATE) AS Pickup_Date,
       payment_type.Payment_Type_Description,
       SUM(Total_Amount) AS Total_Amount
  FROM taxi_curated_zone_93b2hjnp0r.taxi_trips AS taxi_trips
       INNER JOIN taxi_curated_zone_93b2hjnp0r.payment_type AS payment_type
               ON taxi_trips.payment_type_id = payment_type.payment_type_id
              AND TaxiCompany = 'Green' 
              AND PartitionDate = '2022-01-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- Data Lake Tables
SELECT 'Green' AS TaxiCompany,
       CAST(taxi_trips.Pickup_DateTime AS DATE) AS Pickup_Date,
       payment_type.Payment_Type_Description,
       SUM(Total_Amount) AS Total_Amount
  FROM taxi_curated_zone_93b2hjnp0r.processed_taxi_data_green_trips_table_parquet AS taxi_trips
       INNER JOIN taxi_curated_zone_93b2hjnp0r.processed_taxi_data_payment_type_table AS payment_type
               ON taxi_trips.payment_type_id = payment_type.payment_type_id
              AND pickup_datetime BETWEEN '2022-01-01' AND '2022-02-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;


-- Join data


-- Create an external table
CREATE EXTERNAL TABLE parquet_table_name (x INT, y STRING)
LOCATION '/test-warehouse/tinytable'
STORED AS PARQUET;

INSERT INTO parquet_table_name (x,y) VALUES (1,2);

SELECT *
  FROM parquet_table_name;


-- CTAS (for lineage)

-- https://cwiki.apache.org/confluence/display/hive/languagemanual+ddl#LanguageManualDDL-CreateTableAsSelect(CTAS)
CREATE TABLE parquet_table_name_2(x INT, y STRING)
 COMMENT 'This is the page view table'
LOCATION '/test-warehouse/parquet_table_name_2'
STORED AS PARQUET;


CREATE EXTERNAL TABLE parquet_table_name_3 (x INT, y STRING)
LOCATION 'gs://processed-data-analytics-demo-93b2hjnp0r/parquet_table_name'
STORED AS PARQUET;


-- Show tables
SHOW TABLES;

-- Show in UI in the "default" folder
-- You can see that PATH too to the files: 

-- Show Hive tables in Data Catalog
-- https://console.cloud.google.com/dataplex/search?project=data-analytics-demo-93b2hjnp0r&supportedpurview=project&q=parquet_table_name

-- Lineage (source from CSV)

-- Import a notebook
-- Schedule a notebook and/or script

-- Share script / notebooks
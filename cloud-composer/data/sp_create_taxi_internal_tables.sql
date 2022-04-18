CREATE OR REPLACE PROCEDURE `{{ params.project_id }}.{{ params.dataset_id }}.sp_create_internal_taxi_tables`()
OPTIONS(strict_mode=FALSE)
BEGIN

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
    - Internal tables are table that are managed by BigQuery where you are not concerned about having data outsite of BigQuery
    - Internal tables are fully managed by BigQuery so you do not need to worry about maintenance (BQ performs this automatically) 
    - Internal tables can be Partitioned and/or Clustered in order to increase performance when accessing your data

Description: 
    - This will create ingest the external tables into BigQuery. 
    - This uses a CTAS (Create-Table-As-Select) statement.  You can also use BigQuery CLI (bq commands)
    - The majority of customers will ingest data to get the benefits of BigQuery's internal Capacitor format

Dependencies:
    - You must run sp_create_taxi_external_tables first before running this script

Show:
    - Ingestion is easy with a CTAS
    - Ingestion is free (no need to create a cluster to perform ingestion)
    - Fast ingestion of 130 million rows of data

References:
    - https://cloud.google.com/bigquery/docs/creating-partitioned-tables
    - https://cloud.google.com/bigquery/docs/clustered-tables

Clean up / Reset script:
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`;
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.vendor`;
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.rate_code`;
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.payment_type`;
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.trip_type`;
*/


-- Query: Show partitioning and clustering (by several columns)
CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` 
(
    TaxiCompany             STRING,
    Vendor_Id	            INTEGER,	
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Store_And_Forward	    STRING,
    Rate_Code_Id	        INTEGER,
    PULocationID	        INTEGER,
    DOLocationID	        INTEGER,
    Passenger_Count	        INTEGER,
    Trip_Distance	        FLOAT64,
    Fare_Amount	            FLOAT64,
    Surcharge	            FLOAT64,
    MTA_Tax	                FLOAT64,
    Tip_Amount	            FLOAT64,
    Tolls_Amount	        FLOAT64,
    Improvement_Surcharge	FLOAT64,
    Total_Amount	        FLOAT64,
    Payment_Type_Id	        INTEGER,
    Congestion_Surcharge    FLOAT64,
    Trip_Type	            INTEGER,
    Ehail_Fee	            FLOAT64,
    PartitionDate           DATE	
)
PARTITION BY PartitionDate
CLUSTER BY TaxiCompany, Pickup_DateTime
AS SELECT 
        'Green' AS TaxiCompany,
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        Store_And_Forward,
        Rate_Code_Id,
        PULocationID,
        DOLocationID,
        Passenger_Count,
        Trip_Distance,
        Fare_Amount,
        Surcharge,
        MTA_Tax,
        Tip_Amount,
        Tolls_Amount,
        Improvement_Surcharge,
        Total_Amount,
        Payment_Type_Id,
        Congestion_Surcharge,
        SAFE_CAST(Trip_Type AS INTEGER),
        Ehail_Fee,
        DATE(year, month, 1) as PartitionDate
   FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_green_trips_parquet`
UNION ALL
   SELECT
        'Yellow' AS TaxiCompany, 
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        Store_And_Forward,
        Rate_Code_Id,
        PULocationID,
        DOLocationID,
        Passenger_Count,
        Trip_Distance,
        Fare_Amount,
        Surcharge,
        MTA_Tax,
        Tip_Amount,
        Tolls_Amount,
        Improvement_Surcharge,
        Total_Amount,
        Payment_Type_Id,
        Congestion_Surcharge,
        NULL AS Trip_Type,
        NULL AS Ehail_Fee,
        DATE(year, month, 1) as PartitionDate
   FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_yellow_trips_parquet`;

CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.vendor`
(
    Vendor_Id	        INTEGER,
    Vendor_Description  STRING
) AS
SELECT Vendor_Id, Vendor_Description
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_vendor`;


CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.rate_code`
(
    Rate_Code_Id	        INTEGER,
    Rate_Code_Description   STRING
) AS
SELECT Rate_Code_Id, Rate_Code_Description
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_rate_code`;    


CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.payment_type`
(
    Payment_Type_Id	            INTEGER,
    Payment_Type_Description    STRING
) AS
SELECT Payment_Type_Id, Payment_Type_Description
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_payment_type`;


CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.trip_type`
(
    Trip_Type_Id	       INTEGER,
    Trip_Type_Description  STRING
) AS
SELECT Trip_Type_Id, Trip_Type_Description
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_trip_type`;

END
CREATE OR REPLACE PROCEDURE `{{ params.project_id }}.{{ params.dataset_id }}.sp_demo_json_datatype`()
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
    - Need to ingest, store and query JSON data.  BigQuery supports the JSON data type in addition to storing JSON as string.
    -
    
Description: 
    - Create an external table over json files in your data lake/storage
    - Ingest the data into an internal table storing the data as JSON
    - Write queries againsts the data and join to other tables
    - Insert data into the table
    - Query array elements in the JSON

Reference:
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/json-data

Clean up / Reset script:
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.ext_yellow_trips_json`;
    DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json`;
        
*/


-- Create an external table over the JSON string data
-- Import the data as strings (csv file with a field delimiter that is not in typical json)
EXECUTE IMMEDIATE """
CREATE OR REPLACE EXTERNAL TABLE `{{ params.project_id }}.{{ params.dataset_id }}.ext_taxi_trips_json`
(
    taxi_json STRING
)
WITH PARTITION COLUMNS (
    -- column order must match the external path
    year INTEGER, 
    month INTEGER
)
OPTIONS (
    format = "CSV",
    field_delimiter = '\u00fe',
    skip_leading_rows = 0,
    --uris = ['gs://{{ params.bucket_name }}/processed/taxi-data/yellow/trips_table/json/year=2020/month=6/part-00000-f5004726-b7fc-409f-82a3-d9827f2e65a8.c000.json']
    --uris = ['gs://{{ params.bucket_name }}/processed/taxi-data/yellow/trips_table/json/*/*/*.json']
    hive_partition_uri_prefix = "gs://{{ params.bucket_name }}/processed/taxi-data/yellow/trips_table/json/",
    uris = ['gs://{{ params.bucket_name }}/processed/taxi-data/yellow/trips_table/json/*.json']
    );
""";

-- Check the results
SELECT COUNT(*)
 FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_yellow_trips_json`;


-- Check the results
SELECT *
 FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_yellow_trips_json`
 LIMIT 10;


 -- Ingest data into internal table with JSON datatype (takes ~2 minutes for 124,046,938 rows)
CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json` 
(
    -- NOTE: You probably want to add a key and have a UUID as a surrogate key. 
    taxi_json JSON
)
AS
SELECT SAFE.PARSE_JSON(taxi_json)
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.ext_yellow_trips_json`;


-- Check results
SELECT COUNT(*)
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json`;


-- Check results
SELECT *
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json` 
  LIMIT 10;


-- Check results for json fields
SELECT taxi_json.Pickup_DateTime, taxi_json.Vendor_Id, taxi_json.Rate_Code_Id, taxi_json.Fare_Amount
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json` 
  LIMIT 10;


-- Typecast the values
SELECT CAST(JSON_VALUE(taxi_json.Pickup_DateTime) AS TIMESTAMP ) AS Pickup_DateTime, 
       CAST(JSON_VALUE(taxi_json.Vendor_Id) AS INTEGER)          AS Vendor_Id, 
       CAST(JSON_VALUE(taxi_json.Rate_Code_Id) AS INTEGER)       AS Rate_Code_Id, 
       CAST(JSON_VALUE(taxi_json.Fare_Amount) AS FLOAT64 )       AS Fare_Amount, 
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json` 
  LIMIT 10;


-- Complex SQL with JSON (typecast first, then treat as normal)
-- Query complete (2.8 sec elapsed, 20.1 GB processed)
WITH TaxiData AS
(
SELECT CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) AS Pickup_DateTime,
       CAST(JSON_VALUE(taxi_trips.taxi_json.Payment_Type_Id) AS INTEGER)   AS Payment_Type_Id,
       CAST(JSON_VALUE(taxi_trips.taxi_json.Passenger_Count) AS INTEGER)   AS Passenger_Count,
       CAST(JSON_VALUE(taxi_trips.taxi_json.Total_Amount)    AS FLOAT64)   AS Total_Amount,
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json` AS taxi_trips
 WHERE CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) BETWEEN '2020-01-01' AND '2020-06-01' 
   AND CAST(JSON_VALUE(taxi_trips.taxi_json.Payment_Type_Id) AS INTEGER)  IN (1,2)
)
, TaxiDataRanking AS
(
SELECT CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
       taxi_trips.Payment_Type_Id,
       taxi_trips.Passenger_Count,
       taxi_trips.Total_Amount,
       RANK() OVER (PARTITION BY CAST(Pickup_DateTime AS DATE),
                                 taxi_trips.Payment_Type_Id
                        ORDER BY taxi_trips.Passenger_Count DESC, 
                                 taxi_trips.Total_Amount DESC) AS Ranking
  FROM TaxiData AS taxi_trips
)
SELECT Pickup_Date,
       Payment_Type_Description,
       Passenger_Count,
       Total_Amount
  FROM TaxiDataRanking
       INNER JOIN `{{ params.project_id }}.{{ params.dataset_id }}.payment_type` AS payment_type
               ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE Ranking = 1
ORDER BY Pickup_Date, Payment_Type_Description;


-- Ranking done in single query
-- Query complete (2.6 sec elapsed, 20.1 GB processed)
WITH TaxiDataRanking AS
(
SELECT CAST(CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) AS DATE) AS Pickup_Date,
       CAST(JSON_VALUE(taxi_trips.taxi_json.Payment_Type_Id) AS INTEGER)   AS Payment_Type_Id,
       CAST(JSON_VALUE(taxi_trips.taxi_json.Passenger_Count) AS INTEGER)   AS Passenger_Count,
       CAST(JSON_VALUE(taxi_trips.taxi_json.Total_Amount)    AS FLOAT64)   AS Total_Amount,
       RANK() OVER (PARTITION BY CAST(CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) AS DATE),
                                 CAST(JSON_VALUE(taxi_trips.taxi_json.Payment_Type_Id) AS INTEGER)
                        ORDER BY CAST(JSON_VALUE(taxi_trips.taxi_json.Passenger_Count) AS INTEGER) DESC, 
                                 CAST(JSON_VALUE(taxi_trips.taxi_json.Total_Amount)    AS FLOAT64) DESC) AS Ranking       
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json` AS taxi_trips
 WHERE CAST(JSON_VALUE(taxi_trips.taxi_json.Pickup_DateTime) AS TIMESTAMP) BETWEEN '2020-01-01' AND '2020-06-01' 
   AND CAST(JSON_VALUE(taxi_trips.taxi_json.Payment_Type_Id) AS INTEGER)  IN (1,2)
)
SELECT Pickup_Date,
       Payment_Type_Description,
       Passenger_Count,
       Total_Amount
  FROM TaxiDataRanking
       INNER JOIN `{{ params.project_id }}.{{ params.dataset_id }}.payment_type` AS payment_type
               ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE Ranking = 1
ORDER BY Pickup_Date, Payment_Type_Description;


-- Compare against non-json table
-- Query complete (1.1 sec elapsed, 494.6 MB processed)
WITH TaxiDataRanking AS
(
SELECT CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
       taxi_trips.Payment_Type_Id,
       taxi_trips.Passenger_Count,
       taxi_trips.Total_Amount,
       RANK() OVER (PARTITION BY CAST(Pickup_DateTime AS DATE),
                                 taxi_trips.Payment_Type_Id
                        ORDER BY taxi_trips.Passenger_Count DESC, 
                                 taxi_trips.Total_Amount DESC) AS Ranking
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` AS taxi_trips
 WHERE taxi_trips.TaxiCompany = 'Yellow'
   AND taxi_trips.Pickup_DateTime BETWEEN '2020-01-01' AND '2020-06-01' 
   AND taxi_trips.Payment_Type_Id IN (1,2)
)
SELECT Pickup_Date,
       Payment_Type_Description,
       Passenger_Count,
       Total_Amount
  FROM TaxiDataRanking
       INNER JOIN `{{ params.project_id }}.{{ params.dataset_id }}.payment_type` AS payment_type
               ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE Ranking = 1
ORDER BY Pickup_Date, Payment_Type_Description;



-- Insert data (we go the passenger names)
-- Commented out due to preview feature (this can be uncommented at JSON GA)
/*
INSERT INTO {{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json (taxi_json) VALUES
(JSON """
{"Vendor_Id":456, "Passenger_Names" : ["Bugs","Daffy","Coyote"], "Pickup_DateTime":"2020-06-13T07:15:50.000Z","Dropoff_DateTime":"2020-06-13T07:17:30.000Z","Passenger_Count":1,"Trip_Distance":0.62,"Rate_Code_Id":1,"Store_And_Forward":"N","PULocationID":100,"DOLocationID":230,"Payment_Type_Id":1,"Fare_Amount":4.0,"Surcharge":0.5,"MTA_Tax":0.5,"Tip_Amount":1.56,"Tolls_Amount":0.0,"Improvement_Surcharge":0.3,"Total_Amount":9.36,"Congestion_Surcharge":2.5}
""");
*/

SELECT taxi_json.Vendor_Id, taxi_json.Passenger_Names[0] AS FirstPassenagerName
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_json`
 WHERE JSON_VALUE(taxi_json.Vendor_Id) = "456";


END
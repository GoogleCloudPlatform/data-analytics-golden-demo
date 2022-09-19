CREATE OR REPLACE PROCEDURE `azure_omni_biglake.sp_demo_azure_omni_queries`()
OPTIONS (strict_mode=false)
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
    - Query tables in Azure using BigQuery OMNI
    - Data might be FROM an acquisition or just hybrid cloud strategy

Description: 
    - Show many complex SQL statements along with Exporting data to S3 for ETL or other purposes

Dependencies:
    - You must open a new tab with the URL: https://console.cloud.google.com/bigquery?project=data-analytics-golden-v1-share

Show:
    - Just like regular external tables (see script create_azure_taxi_tables_s3.sql)
    - These are complex SQL across 100+M rows of data

References:
    - https://cloud.google.com/bigquery/docs/omni-azure-introduction

Clean up / Reset script:

*/

-- 140 million rows of data
-- SELECT COUNT(*) FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet`;

------------------------------------------------------------------------------------
-- Query 1
-- Query data that is stored in Azure ADLS Gen 2
--
-- NOTE: To run this, you must have access to OMNI.  If you deployed this via 
--       click-to-deploy then access was granted automatically.  Otherwise, you need
--       to set up and configure OMNI and Azure manually.
------------------------------------------------------------------------------------
SELECT Vendor_Id, Rate_Code_Id, SUM(Total_Amount) AS GrandTotal
FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet` 
WHERE year=2019
  AND month=1
GROUP BY Vendor_Id, Rate_Code_Id;


------------------------------------------------------------------------------------
-- Query 2
-- Sum data for a single month
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, SUM(Trips.Total_Amount) AS GrandTotal
  FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet` AS Trips
       INNER JOIN `azure_omni_biglake.taxi_azure_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `azure_omni_biglake.taxi_azure_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
WHERE year=2019
  AND month=1
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description;


------------------------------------------------------------------------------------
-- Query 3
-- Sum data for an entire year
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description,  SUM(Trips.Total_Amount) AS GrandTotal
  FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet` AS Trips
       INNER JOIN `azure_omni_biglake.taxi_azure_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `azure_omni_biglake.taxi_azure_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
WHERE year=2019
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description;


------------------------------------------------------------------------------------
-- Query 4
-- Sum data for an entire year
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description, SUM(Trips.Total_Amount) AS GrandTotal
  FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet` AS Trips
       INNER JOIN `azure_omni_biglake.taxi_azure_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `azure_omni_biglake.taxi_azure_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
       INNER JOIN `azure_omni_biglake.taxi_azure_payment_type` AS PaymentType
       ON Trips.Payment_Type_Id = PaymentType.Payment_Type_Id       
WHERE year=2019
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description;


------------------------------------------------------------------------------------
-- Query 5
-- Sum data for 3+ years
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description, SUM(Trips.Total_Amount) AS GrandTotal
  FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet` AS Trips
       INNER JOIN `azure_omni_biglake.taxi_azure_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `azure_omni_biglake.taxi_azure_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
       INNER JOIN `azure_omni_biglake.taxi_azure_payment_type` AS PaymentType
       ON Trips.Payment_Type_Id = PaymentType.Payment_Type_Id       
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description;


------------------------------------------------------------------------------------
-- Query 5
-- Rank and Partition data (3+ years) to find the highest total amount per vendor, rate code and payment type
------------------------------------------------------------------------------------
WITH HighestPayment AS
(
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description, Total_Amount,
       RANK() OVER (PARTITION BY Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description ORDER BY Total_Amount DESC) AS Ranking
  FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet` AS Trips
       INNER JOIN `azure_omni_biglake.taxi_azure_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `azure_omni_biglake.taxi_azure_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
       INNER JOIN `azure_omni_biglake.taxi_azure_payment_type` AS PaymentType
       ON Trips.Payment_Type_Id = PaymentType.Payment_Type_Id       
)
SELECT *
  FROM HighestPayment
WHERE Ranking = 1;


------------------------------------------------------------------------------------
-- Query 6
-- Compute daily averages (3+ years) by pickup/drop off locations
-- Then rank and partition the data to select the ones with the highest average totals
------------------------------------------------------------------------------------
WITH DailyAverages AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, PULocationID, DOLocationID, avg(Tip_Amount) AvgTip, avg(Total_Amount) AS AvgTotal,
    FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet`
    GROUP BY TripDay, PULocationID, DOLocationID
),
RankTable AS
(
    SELECT TripDay, PULocationID, DOLocationID, AvgTip, AvgTotal,
        RANK() OVER (PARTITION BY TripDay ORDER BY AvgTotal DESC) AS Ranking
    FROM DailyAverages 
)
SELECT *
  FROM RankTable
WHERE Ranking = 1
ORDER BY TripDay;


------------------------------------------------------------------------------------
-- Query 7
-- Find the max totals by pickup location, drop off location and then rank them independently
-- Get the highest ranks per day
------------------------------------------------------------------------------------
WITH MaxPickupTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, PULocationID, Max(Total_Amount) AS MaxPickup,
      FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet`
     GROUP BY TripDay, PULocationID
),
MaxDropoffTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, DOLocationID, Max(Total_Amount) AS MaxDropOff,
      FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet`
     GROUP BY TripDay, DOLocationID
),
PickupMax AS 
(
    SELECT TripDay, PULocationID, MaxPickup, RANK() OVER (PARTITION BY TripDay ORDER BY MaxPickup DESC) AS Ranking
      FROM MaxPickupTotalAmountPerDay
),
DropOffMax AS 
(
    SELECT TripDay, DOLocationID, MaxDropOff, RANK() OVER (PARTITION BY TripDay ORDER BY MaxDropOff DESC) AS Ranking
      FROM MaxDropoffTotalAmountPerDay
)
SELECT PickupMax.TripDay            AS PickupMax_TripDay, 
       PickupMax.PULocationID       AS PickupMax_PULocationID, 
       PickupMax.MaxPickup          AS PickupMax_MaxPickup,
       DropOffMax.TripDay           AS DropOffMax_TripDay, 
       DropOffMax.DOLocationID      AS DropOffMax_DOLocationID, 
       DropOffMax.MaxDropOff        AS DropOffMax_MaxDropOff
  FROM PickupMax
       INNER JOIN DropOffMax
       ON PickupMax.TripDay = DropOffMax.TripDay
       AND PickupMax.Ranking = 1
       AND DropOffMax.Ranking = 1
ORDER BY PickupMax.TripDay;


------------------------------------------------------------------------------------
-- Query 7 (EXPORT DATA)
-- Run the same query as Query 6, but now save to storage (S3)
-- NOTE: If two people are running this at the same time change the "query-7" in the uri="azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-export/query-7/*" 
------------------------------------------------------------------------------------
EXPORT DATA WITH CONNECTION `${omni_azure_connection}`
OPTIONS(
 uri="azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-export/query-7/*",
 format="CSV"
)
AS 
WITH MaxPickupTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, PULocationID, Max(Total_Amount) AS MaxPickup,
      FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet`
     GROUP BY TripDay, PULocationID
),
MaxDropoffTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, DOLocationID, Max(Total_Amount) AS MaxDropOff,
      FROM `azure_omni_biglake.taxi_azure_yellow_trips_parquet`
     GROUP BY TripDay, DOLocationID
),
PickupMax AS 
(
    SELECT TripDay, PULocationID, MaxPickup, RANK() OVER (PARTITION BY TripDay ORDER BY MaxPickup DESC) AS Ranking
    FROM MaxPickupTotalAmountPerDay
),
DropOffMax AS 
(
    SELECT TripDay, DOLocationID, MaxDropOff, RANK() OVER (PARTITION BY TripDay ORDER BY MaxDropOff DESC) AS Ranking
      FROM MaxDropoffTotalAmountPerDay
)
SELECT PickupMax.TripDay            AS PickupMax_TripDay, 
       PickupMax.PULocationID       AS PickupMax_PULocationID, 
       PickupMax.MaxPickup          AS PickupMax_MaxPickup,
       DropOffMax.TripDay           AS DropOffMax_TripDay, 
       DropOffMax.DOLocationID      AS DropOffMax_DOLocationID, 
       DropOffMax.MaxDropOff        AS DropOffMax_MaxDropOff
  FROM PickupMax
       INNER JOIN DropOffMax
       ON PickupMax.TripDay = DropOffMax.TripDay
       AND PickupMax.Ranking = 1
       AND DropOffMax.Ranking = 1
ORDER BY PickupMax.TripDay;


/* 
-- Load the data back into BigQuery from S3 into a BigQuery table in Google Cloud
-- You can now do cross cloud data analysis
-- You want to do as much processing of data in AWS/Azure as possible in order to keep your transfered data sizes reasonable

-- You can load data from Azure directly into a BigQuery table
-- Reference: https://cloud.google.com/bigquery/docs/omni-azure-cross-cloud-transfer
*/

-- Load the parquet files into the BigQuery US dataset: omni_cross_cloud_data_load
LOAD DATA INTO `omni_cross_cloud_data_load.azure_results_parquet` 
FROM FILES (uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-export/taxi-export-parquet/*'], format = 'PARQUET')
WITH CONNECTION `${omni_azure_connection}`;


-- Load the CSV files into the BigQuery US dataset: omni_cross_cloud_data_load
LOAD DATA INTO `omni_cross_cloud_data_load.azure_results_csv` (
  PickupMax_TripDay TIMESTAMP,
  PickupMax_PULocationID INTEGER,
  PickupMax_MaxPickup NUMERIC,
  DropOffMax_TripDay TIMESTAMP,
  DropOffMax_DOLocationID INTEGER,
  DropOffMax_MaxDropOff NUMERIC)
FROM FILES (uris = ['azure://${omni_azure_adls_name}.blob.core.windows.net/datalake/taxi-export/taxi-export-csv/*'], format = 'CSV')
WITH CONNECTION `${omni_azure_connection}`;


-- Show the tables loaded with data from Azure
SELECT * FROM `omni_cross_cloud_data_load.azure_results_csv`;
SELECT * FROM `omni_cross_cloud_data_load.azure_results_parquet`;

END;
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
    - Query tables in AWS using BigQuery OMNI
    - Data might be FROM an acquisition or just hybrid cloud strategy

Description: 
    - Show many complex SQL statements along with Exporting data to S3 for ETL or other purposes

Dependencies:
    - You must open a new tab with the URL: https://console.cloud.google.com/bigquery?project=${omni_project}
    - This is since there is a shared OMNI project setup for use

Show:
    - Just like regular external tables (see script create_aws_taxi_tables_s3.sql)
    - These are complex SQL across 100+M rows of data

References:
    - https://cloud.google.com/bigquery/docs/omni-aws-introduction

Clean up / Reset script:

*/

-- 140 million rows of data
-- SELECT COUNT(*) FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet`;

------------------------------------------------------------------------------------
-- Query 1
-- Query data that is stored in AWS S3
--
-- NOTE: To run this, you must have access to OMNI.  If you deployed this via 
--       click-to-deploy then access was granted automatically.  Otherwise, you need
--       to set up and configure OMNI and AWS manually.
------------------------------------------------------------------------------------
SELECT Vendor_Id, Rate_Code_Id, SUM(Total_Amount) AS GrandTotal
FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet` 
WHERE year=2019
  AND month=1
GROUP BY Vendor_Id, Rate_Code_Id;


------------------------------------------------------------------------------------
-- Query 2
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, SUM(Trips.Total_Amount) AS GrandTotal
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet` AS Trips
       INNER JOIN `${omni_dataset}.taxi_s3_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `${omni_dataset}.taxi_s3_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
WHERE year=2019
  AND month=1
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description;


------------------------------------------------------------------------------------
-- Query 3
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description,  SUM(Trips.Total_Amount) AS GrandTotal
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet` AS Trips
       INNER JOIN `${omni_dataset}.taxi_s3_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `${omni_dataset}.taxi_s3_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
WHERE year=2019
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description;


------------------------------------------------------------------------------------
-- Query 4
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description, SUM(Trips.Total_Amount) AS GrandTotal
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet` AS Trips
       INNER JOIN `${omni_dataset}.taxi_s3_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `${omni_dataset}.taxi_s3_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
       INNER JOIN `${omni_dataset}.taxi_s3_payment_type` AS PaymentType
       ON Trips.Payment_Type_Id = PaymentType.Payment_Type_Id       
WHERE year=2019
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description;

------------------------------------------------------------------------------------
-- Query 5
------------------------------------------------------------------------------------
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description, SUM(Trips.Total_Amount) AS GrandTotal
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet` AS Trips
       INNER JOIN `${omni_dataset}.taxi_s3_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `${omni_dataset}.taxi_s3_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
       INNER JOIN `${omni_dataset}.taxi_s3_payment_type` AS PaymentType
       ON Trips.Payment_Type_Id = PaymentType.Payment_Type_Id       
GROUP BY Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description;

------------------------------------------------------------------------------------
-- Query 5
------------------------------------------------------------------------------------

WITH HighestPayment AS
(
SELECT Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description, Total_Amount,
       RANK() OVER (PARTITION BY Vendor.Vendor_Description, RateCode.Rate_Code_Description, PaymentType.Payment_Type_Description ORDER BY Total_Amount DESC) AS Ranking
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet` AS Trips
       INNER JOIN `${omni_dataset}.taxi_s3_vendor` AS Vendor
       ON Trips.Vendor_Id = Vendor.Vendor_Id  
       INNER JOIN `${omni_dataset}.taxi_s3_rate_code` AS RateCode
       ON Trips.Rate_Code_Id = RateCode.Rate_Code_Id
       INNER JOIN `${omni_dataset}.taxi_s3_payment_type` AS PaymentType
       ON Trips.Payment_Type_Id = PaymentType.Payment_Type_Id       
)
SELECT *
  FROM HighestPayment
WHERE Ranking = 1;


------------------------------------------------------------------------------------
-- Query 6
------------------------------------------------------------------------------------
WITH DailyAverages AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, PULocationID, DOLocationID, avg(Tip_Amount) AvgTip, avg(Total_Amount) AS AvgTotal,
    FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet`
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
------------------------------------------------------------------------------------
WITH MaxPickupTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, PULocationID, Max(Total_Amount) AS MaxPickup,
      FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet`
     GROUP BY TripDay, PULocationID
),
MaxDropoffTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, DOLocationID, Max(Total_Amount) AS MaxDropOff,
      FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet`
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
SELECT PickupMax.TripDay, PickupMax.PULocationID, PickupMax.MaxPickup,
       DropOffMax.TripDay, DropOffMax.DOLocationID, DropOffMax.MaxDropOff 
  FROM PickupMax
       INNER JOIN DropOffMax
       ON PickupMax.TripDay = DropOffMax.TripDay
       AND PickupMax.Ranking = 1
       AND DropOffMax.Ranking = 1
ORDER BY PickupMax.TripDay;


------------------------------------------------------------------------------------
-- Query 7 (EXPORT DATA)
------------------------------------------------------------------------------------
EXPORT DATA WITH CONNECTION `${omni_aws_connection}`
OPTIONS(
 uri="s3://${omni_aws_s3_bucket_name}/taxi-export/query-7/*",
 format="CSV"
)
AS 
WITH MaxPickupTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, PULocationID, Max(Total_Amount) AS MaxPickup,
      FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet`
     GROUP BY TripDay, PULocationID
),
MaxDropoffTotalAmountPerDay AS
(
    SELECT TIMESTAMP_TRUNC(Pickup_DateTime, DAY) AS TripDay, DOLocationID, Max(Total_Amount) AS MaxDropOff,
      FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet`
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

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
Author: Adam Paternostro 
  
Use Cases:
    - Join data between AWS and GCP and/or Azure and/or GCP.

YouTube:
    - https://youtu.be/tHjG8tmDoWk
  
Description: 
    - Query the data in the remote cloud and then join to data directly in GCP
  
Show:
    - That it works!
    - The Explaination Plan.
  
References:
    - 

Clean up / Reset script:
*/
    

/* COMMENTED OUT DUE TO PREVIEW

-- Query raw data AWS data and join location tables in GCP
-- Show EXECUTION GRAPH when done.  You will see 1000 rows from AWS.
WITH aws_data AS
(
   SELECT Vendor_Id,
          PULocationID,
          Pickup_DateTime,
          DOLocationID,
          Dropoff_DateTime,
          Passenger_Count,
          Total_Amount
     FROM `${project_id}.${aws_omni_biglake_dataset_name}.taxi_s3_yellow_trips_parquet` 
     LIMIT 1000
)
, gcp_and_aws_data AS
(
  SELECT aws_data.Vendor_Id,
         gcp_location_pickup.borough,
         aws_data.Pickup_DateTime,
         gcp_location_dropoff.borough,
         aws_data.Dropoff_DateTime,
         aws_data.Passenger_Count,
         aws_data.Total_Amount
    FROM aws_data
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_pickup
                 ON aws_data.PULocationID = gcp_location_pickup.location_id
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_dropoff
                 ON aws_data.DOLocationID = gcp_location_dropoff.location_id
)
SELECT *
  FROM gcp_and_aws_data;
 

-- Summarize data in AWS and then join in GCP for lookup tables
-- Show EXECUTION GRAPH when done.  We query 84 million rows and return ~3650 rows from AWS.
WITH aws_data AS
(
  SELECT Vendor_Id, 
         Rate_Code_Id, 
         Payment_Type_Id, 
         SUM(Total_Amount) AS Total_Amount
    FROM `${project_id}.${aws_omni_biglake_dataset_name}.taxi_s3_yellow_trips_parquet` AS Trips
   WHERE Trips.year = 2019
   GROUP BY 1, 2, 3   
)
, gcp_and_aws_data AS
(
  SELECT Vendor.Vendor_Description,
         RateCode.Rate_Code_Description,
         PaymentType.Payment_Type_Description,
         aws_data.Total_Amount
    FROM aws_data
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS Vendor
                 ON aws_data.Vendor_Id = Vendor.Vendor_Id
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.rate_code` AS RateCode
                 ON aws_data.Rate_Code_Id = RateCode.Rate_Code_Id
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.payment_type` AS PaymentType
                 ON aws_data.Payment_Type_Id = PaymentType.Payment_Type_Id 
)
SELECT *
  FROM gcp_and_aws_data;


-- IMPORTANT: You must have the Azure tables created: CALL `${project_id}.${azure_omni_biglake_dataset_name}.sp_demo_azure_omni_create_tables`();
-- We have data in all 3 clouds and we want to know our Taxi Sales for each cloud
-- Join data in GCP with data from AWS and Azure
-- Get the January data from AWS (total sales)
-- Get the January data from Azure (total sales)
-- Get the January data from GCP (total sales)
-- Join to lookup tables (in GCP so we can see the location)
-- Pivot the data 
-- NOTE: The AWS and Azure data will match since we have the same files in each cloud.  GCP receives fresh data.
-- Show EXECUTION GRAPH when done.  We query 7.7 million rows and return 1.58 million rows from Azure and from AWS.
WITH aws_data AS
(
   SELECT 'AWS' AS cloud,
          PULocationID,
          CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
          DOLocationID,
          CAST(Dropoff_DateTime AS DATE) AS Dropoff_Date,
          SUM(Total_Amount) AS sum_total_amount
     FROM `${project_id}.${aws_omni_biglake_dataset_name}.taxi_s3_yellow_trips_parquet` 
    WHERE year = 2019
      AND month = 1
    GROUP BY 1, 2, 3, 4, 5
)
, azure_data AS
(
   SELECT 'Azure' AS cloud,
          PULocationID,
          CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
          DOLocationID,
          CAST(Dropoff_DateTime AS DATE) AS Dropoff_Date,
          SUM(Total_Amount) AS sum_total_amount
     FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet` 
    WHERE year = 2019
      AND month = 1
    GROUP BY 1, 2, 3, 4, 5
)
, gcp_data AS
(
   SELECT 'GCP' AS cloud,
          PULocationID,
          CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
          DOLocationID,
          CAST(Dropoff_DateTime AS DATE) AS Dropoff_Date,
          SUM(Total_Amount) AS sum_total_amount
     FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` 
    WHERE PartitionDate = '2019-01-01'
    GROUP BY 1, 2, 3, 4, 5
)
, union_data AS
(
  SELECT aws_data.cloud,
         gcp_location_pickup.borough AS pickup_location,
         aws_data.Pickup_Date,
         gcp_location_dropoff.borough AS dropoff_location,
         aws_data.Dropoff_Date,
         aws_data.sum_total_amount
    FROM aws_data
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_pickup
                 ON aws_data.PULocationID = gcp_location_pickup.location_id
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_dropoff
                 ON aws_data.DOLocationID = gcp_location_dropoff.location_id
  UNION ALL
  SELECT azure_data.cloud,
         gcp_location_pickup.borough AS pickup_location,
         azure_data.Pickup_Date,
         gcp_location_dropoff.borough AS dropoff_location,
         azure_data.Dropoff_Date,
         azure_data.sum_total_amount
    FROM azure_data
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_pickup
                 ON azure_data.PULocationID = gcp_location_pickup.location_id
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_dropoff
                 ON azure_data.DOLocationID = gcp_location_dropoff.location_id
  UNION ALL
  SELECT gcp_data.cloud,
         gcp_location_pickup.borough AS pickup_location,
         gcp_data.Pickup_Date,
         gcp_location_dropoff.borough AS dropoff_location,
         gcp_data.Dropoff_Date,
         gcp_data.sum_total_amount
    FROM gcp_data
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_pickup
                 ON gcp_data.PULocationID = gcp_location_pickup.location_id
         INNER JOIN `${project_id}.${bigquery_taxi_dataset}.location` AS gcp_location_dropoff
                 ON gcp_data.DOLocationID = gcp_location_dropoff.location_id
)
--SELECT * FROM union_data;  -- You can comment this out to see the data unpivoted
SELECT pickup_location,
       Pickup_Date,
       dropoff_location,
       Dropoff_Date,
       FORMAT("%'d", CAST(AWS   AS INTEGER)) AS AWS,
       FORMAT("%'d", CAST(Azure   AS INTEGER)) AS Azure,
       FORMAT("%'d", CAST(GCP   AS INTEGER)) AS GCP
  FROM union_data
  PIVOT(SUM(sum_total_amount) FOR cloud IN ('AWS', 'Azure', 'GCP'))
ORDER BY pickup_location,
         Pickup_Date,
         dropoff_location,
         Dropoff_Date;
*/

-- So Terraform does not break
SELECT 1;
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
    - Do you have data on your data lake and inside of BigQuery.  You can join this data and just like the data all 
      resides in the same location.

Description: 
    - Show that internal and external tables can be joined
    - External storage is fast and can be used for uses where a data lake holds tables for your warehousing strategy

Reference:
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax

Clean up / Reset script:
    n/a
*/

-- Query 1: Join to the External Parquet files
-- Query complete (1.6 sec elapsed, 4.6 GB processed)
SELECT ext_vendor.Vendor_Description, 
        ext_rate_code.Rate_Code_Description,
        ext_payment_type.Payment_Type_Description,
        CAST(taxi_trips.Pickup_DateTime AS DATE)   AS Pickup_Date,
        taxi_trips.Total_Amount
FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.ext_vendor` AS ext_vendor
                ON taxi_trips.Vendor_Id = ext_vendor.Vendor_Id
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.ext_rate_code` AS ext_rate_code
                ON taxi_trips.Rate_Code_Id = ext_rate_code.Rate_Code_Id
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.ext_payment_type` AS ext_payment_type
                ON taxi_trips.Payment_Type_Id = ext_payment_type.Payment_Type_Id
WHERE taxi_trips.Pickup_DateTime BETWEEN '2019-05-01' AND '2019-05-02';


-- Query 2: Join to the Interal tables
-- Query complete (1.3 sec elapsed, 4.6 GB processed)
SELECT vendor.Vendor_Description, 
        rate_code.Rate_Code_Description,
        payment_type.Payment_Type_Description,
        CAST(taxi_trips.Pickup_DateTime AS DATE)   AS Pickup_Date,
        taxi_trips.Total_Amount
FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS taxi_trips
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.vendor` AS vendor
                ON taxi_trips.Vendor_Id = vendor.Vendor_Id
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.rate_code` AS rate_code
                ON taxi_trips.Rate_Code_Id = rate_code.Rate_Code_Id
        INNER JOIN `${project_id}.${bigquery_taxi_dataset}.payment_type` AS payment_type
                ON taxi_trips.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE taxi_trips.Pickup_DateTime BETWEEN '2019-05-01' AND '2019-05-02';



CREATE OR REPLACE PROCEDURE `{{ params.project_id }}.{{ params.dataset_id }}.sp_demo_security`()
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
    - Need to secure your datasets, tables, views, columns and rows, BigQuery allows you to have full security
      of you data.  
    - Row level security allows you to have a multitenant warehouse without creating seperate tables for each tenant.

Description: 
    - Show Dataset, Table and Row Level security
    - Show an authorized view that uses a table join for security
    - Show row level access that filters a table based upon secuirty with cascading permissions

Reference:
    - https://cloud.google.com/bigquery/docs/dataset-access-controls
    - https://cloud.google.com/bigquery/docs/authorized-views
    - https://cloud.google.com/bigquery/docs/row-level-security-intro
    - https://cloud.google.com/bigquery/docs/column-level-security

Clean up / Reset script:
    DROP VIEW  IF EXISTS `{{ params.project_id }}.{{ params.dataset_id }}.v_taxi_trips_passenger_amounts`;
    DROP TABLE IF EXISTS  `{{ params.project_id }}.{{ params.dataset_id }}.user_vendor_security`;
    DROP ALL ROW ACCESS POLICIES ON `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`;
*/

-- Query 1: BigQuery allows security to be placed at a Dataset level
-- Permissions can be set for users, groups, and service accounts on datasets
GRANT `roles/bigquery.dataViewer`
   ON SCHEMA `{{ params.project_id }}.{{ params.dataset_id }}`
   TO "user:{{ params.gcp_account_name }}";

-- To View in the BigQuery UI
-- 1. Open dataset
-- 2. Click on Sharing
-- 3. Select Permissions
-- 4. Unselect "Show inherited permissions"
-- 5. Expand "BigQuery Data Viewer"
-- 6. You will see the user has access

-- Query 2: Remove the previously granted permissions (note since you are an admin it does not do much in the demo)
REVOKE `roles/bigquery.dataViewer`
    ON SCHEMA `{{ params.project_id }}.{{ params.dataset_id }}`
    FROM "user:{{ params.gcp_account_name }}";

-- Query 3: Table permissions
-- Tables can have access as well as Views
GRANT `roles/bigquery.dataViewer`
    ON TABLE `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
    TO "user:{{ params.gcp_account_name }}";

-- Query 4: Revoke table
REVOKE `roles/bigquery.dataViewer`
    ON TABLE `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
    FROM "user:{{ params.gcp_account_name }}";


-- Query 5: Create a table to be used in an authorized view. This table holds for each user their 
--          allow access to certain "Vendor Ids"
CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_id }}.user_vendor_security`
(
    user_id   STRING,
    Vendor_Id INTEGER
); 

-- Query 6:  Insert "you" as a test
INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.user_vendor_security` (user_id, Vendor_Id)
VALUES ('{{ params.gcp_account_name }}', 1);

-- Query 5:  Create the view that joins to the new table and filters based upon SESSION_USER()
CREATE OR REPLACE VIEW `{{ params.project_id }}.{{ params.dataset_id }}.v_taxi_trips_passenger_amounts` AS
SELECT vendor.Vendor_Id,
        Vendor_Description, 
        CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
        Passenger_Count, 
        Total_Amount
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` AS taxi_trips
        INNER JOIN `{{ params.project_id }}.{{ params.dataset_id }}.user_vendor_security` AS user_vendor_security
                ON user_vendor_security.user_id = SESSION_USER()
               AND taxi_trips.Vendor_Id = user_vendor_security.Vendor_Id
        INNER JOIN `{{ params.project_id }}.{{ params.dataset_id }}.vendor` AS vendor
                ON taxi_trips.Vendor_Id = vendor.Vendor_Id;

-- Query 6:  Run a SELECT against the view.  You will only see Vendors Id of 1
--           Get the max total per day and show the number of passengers
WITH RankingData AS
(
    SELECT Vendor_Id,
           Vendor_Description,
           Pickup_Date,
           Passenger_Count,
           Total_Amount,
           ROW_NUMBER() OVER (PARTITION BY Vendor_Id, Pickup_Date ORDER BY Total_Amount DESC) AS ranking
      FROM `{{ params.project_id }}.{{ params.dataset_id }}.v_taxi_trips_passenger_amounts`
     WHERE Pickup_Date BETWEEN '2021-01-01' AND '2021-02-01'
)
SELECT * EXCEPT (ranking) -- hide the ranking column
  FROM RankingData
 WHERE ranking = 1
 ORDER BY Vendor_Description, Pickup_Date;


-- Query 6:  Use Row Level Access Policy to do table row filtering
--           These policies can be stacked, are used by materialize views and other security pass through
CREATE OR REPLACE ROW ACCESS POLICY rap_taxi_trips_admin_mta_tax
    ON `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
    GRANT TO ("user:{{ params.gcp_account_name }}") -- This also works for groups: "group:tax-collectors@altostrat.com"
FILTER USING (MTA_Tax > 0);

-- Query 6: This will only show Vendor ID of 1
SELECT * 
   FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` 
 LIMIT 50;

-- Query 7: Apply another filter 
-- Filter again (filters will cascade, in a non-demo, you would be setting this for different groups of users)
CREATE OR REPLACE ROW ACCESS POLICY rap_taxi_trips_admin_mta_tax_vendor_2
    ON `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
    GRANT TO ("user:{{ params.gcp_account_name }}")
FILTER USING (Vendor_Id = 2 OR PULocationID = 182); 

-- Query 8: Show the results
SELECT * 
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` 
 LIMIT 50;

-- Query 9: Remove this so the rest of the demo works
DROP ROW ACCESS POLICY rap_taxi_trips_admin_mta_tax_vendor_2 ON `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`;
DROP ALL ROW ACCESS POLICIES ON `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`;


-- Column Level Security
-- Populate the taxi Trips w/Column Level security
-- Since some fields are protected just the ones with access are populated
INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_with_col_sec` 
(
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
        Tolls_Amount,
        Improvement_Surcharge,
        Payment_Type_Id,
        Congestion_Surcharge
)
SELECT 
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
        Tolls_Amount,
        Improvement_Surcharge,
        Payment_Type_Id,
        Congestion_Surcharge
   FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`;



-- Error: Selecting columns w/o access
-- Access Denied: BigQuery BigQuery: User does not have permission to access policy tag "Business Critical : High security" on columns {{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_with_col_sec.Tip_Amount, {{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_with_col_sec.Total_Amount.
SELECT * FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_with_col_sec` LIMIT 1000;

-- Valid
SELECT * EXCEPT(Tip_Amount, Total_Amount) FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips_with_col_sec` LIMIT 1000;

END
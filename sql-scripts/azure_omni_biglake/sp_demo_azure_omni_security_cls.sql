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
    - Show column level security on an OMNI table

Description: 
    - Filter rows by a Pickup Location

Show:
    - Data is protected (columns) even though the data is a CSV format.
    - Security can be done per user, group or domain

References:
    - https://cloud.google.com/bigquery/docs/omni-azure-introduction
    - https://cloud.google.com/bigquery/docs/column-level-security

Clean up / Reset script:

*/

-- NOTE: MANUAL STEPS
-- Perform the below during the demo to show how to setup column level security (or data masking)

-- Open the table and view the schema
-- Click the "EDIT SCHEMA" button at the bottom
-- Go to Page 2 of the Fields (bottom right little arrow)
-- Check off the fields: Fare_Amount and Total_Amount
-- Click the "ADD POLICY TAG" button at the top
-- Select the Policy tag Business-Critical-Azure-${random_extension}
-- Select the "High Security" option (you will not be able to access this data)
-- Click the "SELECT" buttom
-- Check off the fields: Surcharge, MTA_Tax, Tip_Amount, Tolls_Amount, Improvement_Surcharge
-- Click the "ADD POLICY TAG" button at the top
-- Select the Policy tag Business-Critical-Azure-${random_extension}
-- Select the "Low Security" option (you will have access to see this data)
-- Click the "SELECT" buttom
-- On the "Edit Schema" screen press "SAVE"

-- You may also add data masking to a field or two.  
-- The data masking rule is a Nullable rule which will show all NULLs

-- NOTE: The tables are named with a suffix of "_cls", this is so we do not affect the demo.  
--       In the real application of CLS you do not need a seperate table.

--- CSV FORMAT
-- This will error since we try to select the Fare_Amount and Total_Amount
SELECT *
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- This will work since we do not select the column's we do not have access
SELECT * EXCEPT (Fare_Amount,Total_Amount)
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- JSON FORMAT
-- This will error since we try to select the Fare_Amount and Total_Amount
SELECT *
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- This will work since we do not select the column's we do not have access
SELECT * EXCEPT (Fare_Amount,Total_Amount)
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- PARQUET FORMAT
-- This will error since we try to select the Fare_Amount and Total_Amount
SELECT *
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_cls`
LIMIT 1000;


-- This will work since we do not select the column's we do not have access
SELECT * EXCEPT (Fare_Amount,Total_Amount)
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_cls`
LIMIT 1000;

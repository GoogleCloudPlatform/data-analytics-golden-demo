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
    - Show row level security on OMNI tables (CSV, JSON and Parquet formats)
    
Description: 
    - Filter rows by a Pickup Location

Show:
    - Tables are filter by rows even though it is a parquet file
    
References:
    - https://cloud.google.com/bigquery/docs/omni-azure-introduction
    - https://cloud.google.com/bigquery/docs/managing-row-level-security

Clean up / Reset script:
    - DROP ALL ROW ACCESS POLICIES ON `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_rls`;
    - DROP ALL ROW ACCESS POLICIES ON `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_rls`;
    - DROP ALL ROW ACCESS POLICIES ON `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_rls`;

*/

-- NOTE: The tables are named with a suffix of "_rls", this is so we do not affect the demo.  
--       In the real application of RLS you do not need a seperate table.

-- Create row level security policies on the Parquet, CSV and JSON files
-- NOTE: This has already been done (you do not have acces to run)
CREATE OR REPLACE ROW ACCESS POLICY rls_yellow_trips_parquet_pu_244
    ON `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_rls`
    GRANT TO ("user:${gcp_account_name}") -- This also works for groups: "group:my-group@altostrat.com"
FILTER USING (PULocationID = 244);

CREATE OR REPLACE ROW ACCESS POLICY rls_yellow_trips_csv_pu_245
    ON `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_rls`
    GRANT TO ("user:${gcp_account_name}") -- This also works for groups: "group:my-group@altostrat.com"
FILTER USING (PULocationID = 245 AND Total_Amount < 100);

CREATE OR REPLACE ROW ACCESS POLICY rls_yellow_trips_json_pu_246
    ON `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_rls`
    GRANT TO ("user:${gcp_account_name}") -- This also works for groups: "group:my-group@altostrat.com"
FILTER USING (Vendor_Id = 1 AND PULocationID = 246 AND Trip_Distance < 5 AND Total_Amount < 50);


-- See just the data you are allowed to see
SELECT *
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_parquet_rls`
LIMIT 1000;

SELECT *
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_csv_rls`
 WHERE year = 2021
   AND month = 1
LIMIT 1000;

SELECT *
  FROM `${project_id}.${azure_omni_biglake_dataset_name}.taxi_azure_yellow_trips_json_rls`
 WHERE year = 2021
   AND month = 1
LIMIT 1000;

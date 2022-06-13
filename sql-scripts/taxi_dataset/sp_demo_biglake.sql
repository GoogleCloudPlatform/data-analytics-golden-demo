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
PREVIEW FEATURE:
    - You need to run the below "CLI Commands" from your Cloud Shell

Use Cases:
    - Secure your data on your datalake with row level security
    - Replace Apache Ranger with a simipler easy to use solution

Description: 
    - Create an external table
    - Create a row level access policy on the table.  Security can be preformed on: Parquet, ORC, Avro, CSV and JSON

Reference:
    - n/a

Clean up / Reset script:
    DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`;
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`;
    
*/

-- Query: Create an external table (this is some of the Green Taxi Trips data in Parquet format)
-- Preview features, plus the connection might not have been created.
EXECUTE IMMEDIATE """
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`
WITH CONNECTION `${project_id}.${bigquery_region}.biglake-connection`
OPTIONS(uris=['gs://${bucket_name}/processed/taxi-data/green/trips_table/parquet/year=2019/month=1/*.parquet'], format="PARQUET")
""";

-- See ALL the data
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`;


-- Query: Create an access policy so the admin (you) can only see pick up locations of 244
CREATE OR REPLACE ROW ACCESS POLICY rap_green_trips_pu_244
    ON `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`
    GRANT TO ("user:${gcp_account_name}") -- This also works for groups: "group:my-group@altostrat.com"
FILTER USING (PULocationID = 244);


-- See just the data you are allowed to see
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`;


-- Drop the policy
DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`;


-- See all the data
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.biglake_green_trips`;


CREATE OR REPLACE PROCEDURE `${omni_dataset}.sp_demo_aws_omni_security_cls`()
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
    - Show column level security on an OMNI table

Description: 
    - Filter rows by a Pickup Location

Dependencies:
    - You must open a new tab with the URL: https://console.cloud.google.com/bigquery?project=${omni_project}

Show:
    - Data is protected (columns) even though the data is a CSV format.
    - Security can be done per user, group or domain

References:
    - https://cloud.google.com/bigquery/docs/omni-aws-introduction
    - https://cloud.google.com/bigquery/docs/column-level-security

Clean up / Reset script:

*/

-- Open the table and view the schema
-- You will see columns with security applied
-- There is High Security on the Fare_Amount and Total_Amount (we do not have access to these fields)
-- There is Low Security on the "other" amount fields (we have access to these)

-- NOTE: The tables are named with a suffix of "_cls", this is so we do not affect the demo.  
--       In the real application of CLS you do not need a seperate table.

--- CSV FORMAT
-- This will error since we try to select the Fare_Amount and Total_Amount
SELECT *
  FROM `${omni_dataset}.taxi_s3_yellow_trips_csv_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- This will work since we do not select the column's we do not have access
SELECT * EXCEPT (Fare_Amount,Total_Amount)
  FROM `${omni_dataset}.taxi_s3_yellow_trips_csv_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- JSON FORMAT
-- This will error since we try to select the Fare_Amount and Total_Amount
SELECT *
  FROM `${omni_dataset}.taxi_s3_yellow_trips_json_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- This will work since we do not select the column's we do not have access
SELECT * EXCEPT (Fare_Amount,Total_Amount)
  FROM `${omni_dataset}.taxi_s3_yellow_trips_json_cls`
 WHERE year = 2021
   AND month = 1  
LIMIT 1000;


-- PARQUET FORMAT
-- This will error since we try to select the Fare_Amount and Total_Amount
SELECT *
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet_cls`
LIMIT 1000;


-- This will work since we do not select the column's we do not have access
SELECT * EXCEPT (Fare_Amount,Total_Amount)
  FROM `${omni_dataset}.taxi_s3_yellow_trips_parquet_cls`
LIMIT 1000;

END;
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
    Ability to read Delta.io data directly from BigQuery for BQML or analytics purposes.

Description: 
    Create a BigLake table over a Hive partitioned Delta.io table

Reference:
    - https://cloud.google.com/bigquery/docs/create-delta-lake-table

Clean up / Reset script:
    DROP EXTERNAL TABLE IF EXISTS `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_delta_lake`;

*/

-- Automatically detects partitions (Rideshare_Vendor_Id, Pickup_Date)
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_delta_lake`
WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`
OPTIONS (
    format = "DELTA_LAKE",
    uris = ['s3://${aws_omni_biglake_s3_bucket}/delta_io/rideshare_trips']
);

SELECT *
  FROM `${project_id}.${aws_omni_biglake_dataset_name}.rideshare_trips_delta_lake`;


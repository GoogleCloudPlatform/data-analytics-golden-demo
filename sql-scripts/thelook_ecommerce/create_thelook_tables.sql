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
    - Copies data locally to your dataset

Description: 
    - This brings the data local from the public dataset
    - You can then also partition or cluster based upon your use cases

Show:
    - New tables will be created

References:
    - https://cloud.google.com/bigquery/docs/tables

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.distribution_centers` ;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.events` ;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.inventory_items` ;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.order_items` ;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.orders` ;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.products` ;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.users` ;
*/

-- Copy the rest of "the look" tables (did not use dataset copy since this is small and did clustering)
-- This only works for when BigQuery is region "us"; otherwise, you need to do a dataset copy
IF UPPER(bigquery_region) = 'US' THEN 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.distribution_centers` 
    CLUSTER BY id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.distribution_centers`; 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.events` 
    CLUSTER BY user_id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.events`; 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.inventory_items` 
    CLUSTER BY product_id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.inventory_items`; 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.order_items` 
    CLUSTER BY order_id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.order_items`; 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.orders` 
    CLUSTER BY order_id, user_id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.orders`; 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.products` 
    CLUSTER BY id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.products`; 

    CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.users` 
    CLUSTER BY id
    AS
    SELECT * FROM `bigquery-public-data.thelook_ecommerce.users`; 

    CALL `${project_id}.${bigquery_thelook_ecommerce_dataset}.create_product_deliveries_streaming` ();

    CALL `${project_id}.${bigquery_thelook_ecommerce_dataset}.churn_demo_step_0_create_artifacts`();

    -- Need a better SQL (we should update it based upon today - find the current date and the max date and do an update)
    -- We want 30 days in the future for the demo.
    UPDATE `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries` 
       SET delivery_time =  TIMESTAMP_ADD(delivery_time, INTERVAL 60 DAY)
     WHERE TRUE;    

END IF;
/*##################################################################################
# Copyright 2024 Google LLC
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
    - Initializes the system (you can re-run this)

Description: 
    - Loads all tables from the public storage account
    - Uses AVRO so we can bring in JSON and GEO types

References:
    - 

Clean up / Reset script:
    -  n/a

*/


------------------------------------------------------------------------------------------------------------
-- Create GenAI / Vertex AI connections
------------------------------------------------------------------------------------------------------------
CREATE MODEL IF NOT EXISTS `${project_id}.${bigquery_governed_data_raw_dataset}.gemini_pro`
  REMOTE WITH CONNECTION `${project_id}.${multi_region}.vertex-ai`
  OPTIONS (endpoint = 'gemini-pro');

CREATE MODEL IF NOT EXISTS `${project_id}.${bigquery_governed_data_raw_dataset}.gemini_pro_1_5`
  REMOTE WITH CONNECTION `${project_id}.${multi_region}.vertex-ai`
  OPTIONS (endpoint = 'gemini-1.5-pro-001');

CREATE MODEL IF NOT EXISTS `${project_id}.${bigquery_governed_data_raw_dataset}.google-textembedding`
  REMOTE WITH CONNECTION `${project_id}.${multi_region}.vertex-ai`
  OPTIONS (endpoint = 'text-embedding-004');


------------------------------------------------------------------------------------------------------------
-- Load all data
------------------------------------------------------------------------------------------------------------
LOAD DATA OVERWRITE `${project_id}.${bigquery_governed_data_raw_dataset}.customer` 
FROM FILES (format = 'AVRO', enable_logical_types = true, uris = ['gs://${governed_data_raw_bucket}/customer/customer.avro']);

LOAD DATA OVERWRITE `${project_id}.${bigquery_governed_data_raw_dataset}.customer_transaction` 
FROM FILES (format = 'PARQUET',  uris = ['gs://${governed_data_raw_bucket}/customer_transaction/customer_transaction.parquet']);

LOAD DATA OVERWRITE `${project_id}.${bigquery_governed_data_raw_dataset}.product` 
FROM FILES (format = 'JSON', uris = ['gs://${governed_data_raw_bucket}/product/product.json']);

LOAD DATA OVERWRITE `${project_id}.${bigquery_governed_data_raw_dataset}.product_category` 
(
  product_category STRING,
  description STRING
)
FROM FILES (format = 'CSV', skip_leading_rows = 0, uris = ['gs://${governed_data_raw_bucket}/product_category/product_category.csv']);


------------------------------------------------------------------------------------------------------------
-- Set the table descriptions for each table:
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.customer`
  SET OPTIONS (
      description = 'Table containing customer raw information.'
    );

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.customer`
  ALTER COLUMN customer_id SET OPTIONS (description='Unique identifier for the customer.'),
  ALTER COLUMN first_name SET OPTIONS (description='The first name of the customer.'),
  ALTER COLUMN last_name SET OPTIONS (description='The last name of the customer.'),
  ALTER COLUMN email SET OPTIONS (description='The email address of the customer.'),
  ALTER COLUMN phone SET OPTIONS (description='The phone number of the customer.'),
  ALTER COLUMN gender SET OPTIONS (description='The gender of the customer.'),
  ALTER COLUMN ip_address SET OPTIONS (description='The IP address of the customer.'),
  ALTER COLUMN ssn SET OPTIONS (description='The Social Security Number of the customer.'),
  ALTER COLUMN address SET OPTIONS (description='The street address of the customer.'),
  ALTER COLUMN city SET OPTIONS (description='The city of the customer.'),
  ALTER COLUMN state SET OPTIONS (description='The state of the customer.'),
  ALTER COLUMN zip SET OPTIONS (description='The zip code of the customer.');

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.customer_transaction`
  SET OPTIONS (
      description = 'Table containing raw customer transaction details, with multiple rows per order. This table will be used to create order header and detail tables during an ETL process.'
    );

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.customer_transaction`
  ALTER COLUMN transaction_id SET OPTIONS (description='Unique identifier for the transaction.'),
  ALTER COLUMN customer_id SET OPTIONS (description='The ID of the customer who made the transaction.'),
  ALTER COLUMN order_date SET OPTIONS (description='The date the order was placed.'),
  ALTER COLUMN order_time SET OPTIONS (description='The time the order was placed.'),
  ALTER COLUMN transaction_type SET OPTIONS (description='The type of transaction (e.g., purchase, return).'),
  ALTER COLUMN region SET OPTIONS (description='The region where the transaction occurred.'),
  ALTER COLUMN quantity SET OPTIONS (description='The quantity of the product purchased.'),
  ALTER COLUMN product SET OPTIONS (description='The name or identifier of the product purchased.'),
  ALTER COLUMN product_category SET OPTIONS (description='The category of the product purchased.'),
  ALTER COLUMN price SET OPTIONS (description='The price of the product.');

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.product`
  SET OPTIONS (
      description = 'Table containing raw product information.'
    );

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.product`
  ALTER COLUMN description SET OPTIONS (description='Description of the product.'),
  ALTER COLUMN product SET OPTIONS (description='The name or identifier of the product.');  

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.product_category`
  SET OPTIONS (
      description = 'Table containing raw product category information.'
    );

ALTER TABLE `${project_id}.${bigquery_governed_data_raw_dataset}.product_category`
  ALTER COLUMN product_category SET OPTIONS (description='The name or identifier of the product category.'),
  ALTER COLUMN description SET OPTIONS (description='Description of the product category.');


------------------------------------------------------------------------------------------------------------
-- Run ELT processes in the enriched dataset
------------------------------------------------------------------------------------------------------------
CALL `${project_id}.${bigquery_governed_data_enriched_dataset}.initialize`();


------------------------------------------------------------------------------------------------------------
-- Run ELT processes in the curated dataset
------------------------------------------------------------------------------------------------------------
CALL `${project_id}.${bigquery_governed_data_curated_dataset}.initialize`();
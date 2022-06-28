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
    - Sharing data via Analytic Hub

Description: 
    - This is the dataset that is shared via Analytic Hub
    -  A nightly process will refresh the data 

Show:
    - New schema and table will be created

References:
    - https://cloud.google.com/bigquery/docs/analytics-hub-introduction

Clean up / Reset script:
    DROP SCHEMA `wholesale_integrators` ;
    DROP TABLE IF EXISTS wholesale_integrators.wholesale_orders;
*/


CREATE SCHEMA wholesale_integrators
OPTIONS(
 location="us"
 );

CREATE OR REPLACE TABLE wholesale_integrators.wholesale_orders
(
   order_number           INT64,   -- wholeseller's order number
   order_date             DATE,    -- date ordered
   expected_delivery_date DATE,    -- date wholeseller expects to deliver
   distribution_center_id INT64,   -- theLook distribution_centers.id reference
   product_id             INT64,   -- theLook inventor_items.product_id reference
   quantity               INT64    -- quantity ordered
)
CLUSTER BY distribution_center_id, product_id;

TRUNCATE TABLE wholesale_integrators.wholesale_orders;

/* 
-- Did not generate enough data.  Want a deliver per distibution center, per product per day.

INSERT INTO wholesale_integrators.wholesale_orders (order_number, order_date, expected_delivery_date, distribution_center_id, product_id, quantity)
SELECT element AS order_number,
      DATE_SUB(CURRENT_DATE, INTERVAL CAST(ROUND(1 + RAND() * (90 - 1)) AS INT64) DAY) AS order_date,
      DATE_ADD(DATE_SUB(CURRENT_DATE, INTERVAL 5 DAY), INTERVAL CAST(ROUND(1 + RAND() * (90 - 7)) AS INT64) DAY) AS expected_delivery_date,
      CAST(ROUND(1 + RAND() * (10 - 1)) AS INT64) AS distribution_center_id,
      CAST(ROUND(1 + RAND() * (29120 - 1)) AS INT64) AS product_id,
      CAST(ROUND(10 + RAND() * (200 - 10)) AS INT64) AS quantity
FROM UNNEST(GENERATE_ARRAY(1, 2000000)) AS element
ORDER BY element;
*/

INSERT INTO wholesale_integrators.wholesale_orders (order_number, order_date, expected_delivery_date, distribution_center_id, product_id, quantity)
WITH DeliveryDays AS
(
  SELECT DATE_ADD(DATE_SUB(CURRENT_DATE, INTERVAL 5 DAY), INTERVAL element DAY) AS delivery_date,
    FROM UNNEST(GENERATE_ARRAY(1, 90)) AS element
)
, FullDataset AS
(
  SELECT DeliveryDays.delivery_date AS expected_delivery_date,
         distribution_centers.id    AS distribution_center_id,
         products.id                AS product_id
    FROM DeliveryDays
         CROSS JOIN `bigquery-public-data.thelook_ecommerce.distribution_centers` AS distribution_centers
         CROSS JOIN `bigquery-public-data.thelook_ecommerce.products`             AS products
)
, NewData AS
(
  SELECT ROW_NUMBER() OVER (PARTITION BY 1) AS order_number,
         DATE_SUB(CURRENT_DATE, INTERVAL CAST(ROUND(1 + RAND() * (90 - 1)) AS INT64) DAY) AS order_date,
         expected_delivery_date,
         distribution_center_id,
         product_id,
         CAST(ROUND(10 + RAND() * (100 - 10)) AS INT64) AS quantity
    FROM FullDataset
)
--SELECT * FROM DeliveryDays ORDER BY 1;
--SELECT * FROM FullDataset ORDER BY 1, 2, 3;
SELECT * FROM NewData;


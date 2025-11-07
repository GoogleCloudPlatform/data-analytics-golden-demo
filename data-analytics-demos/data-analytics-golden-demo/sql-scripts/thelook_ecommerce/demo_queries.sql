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


------------------------------------------------------------------------------------
-- Query 1
-- Determine if we have enough incoming stock of items to satisfy the next 30 days of deliveries
-- This query will use data shared via Analytic Hub
--
-- NOTE: You first need to add the Analytic Hub shared data
--       1 - Click on Analytic Hub on the left side of the console after (after opening BigQuery)
--       2 - Click on Search Listings
--       3 - Click "Private" under Filters
--       4 - Click "Wholesale Integrator Order Data" in the search results
--       5 - Click "ADD DATASET TO PROJECT"
--       6 - Click "SAVE"
--       7 - Head back over to BigQuery SQL Workspace
------------------------------------------------------------------------------------

WITH Next30DayDelivery AS
(
  -- Determine how many items we are delivering in the next 30 days  
  -- This creates a running sum of delivery quantities so we can compare against the running sum of incoming inventory
  SELECT CAST(delivery_time AS DATE) AS delivery_date,
         distribution_center_id,
         product_id,
         quantity_to_delivery,
         SUM(quantity_to_delivery) OVER (PARTITION BY distribution_center_id, product_id
                                         ORDER BY delivery_time, distribution_center_id, product_id) AS running_sum_quantity_to_deliver
    FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries` product_deliveries
  WHERE delivery_time BETWEEN CURRENT_TIMESTAMP() AND TIMESTAMP_ADD(CURRENT_TIMESTAMP() , INTERVAL 30 DAY)
    AND quantity_to_delivery > 0
)
, IncomingProductStock AS
(
  -- Use the shared data from our Wholesale Provider by using the Analytic's Hub table
  -- Create a running sum of items that are being delivered
  SELECT expected_delivery_date, 
         distribution_center_id, 
         product_id, 
         quantity,
         SUM(quantity) OVER (PARTITION BY distribution_center_id, product_id
                             ORDER BY expected_delivery_date, distribution_center_id, product_id) AS running_sum_incoming_quantity
    FROM `${project_id}.wholesale_integrator_order_data.wholesale_orders`
)
, DeliveryAndIncoming AS
(
  SELECT Next30DayDelivery.delivery_date                    AS delivery_date,
         distribution_centers.name                          AS distribution_center,
        CASE WHEN LENGTH(products.name) > 50
             THEN CONCAT(SUBSTR(products.name,1,50),'...') -- for display purposes
             ELSE products.name
        END                                                 AS product_name,
         Next30DayDelivery.running_sum_quantity_to_deliver  AS quantity_required,
         IncomingProductStock.running_sum_incoming_quantity AS quantity_available,
         IncomingProductStock.running_sum_incoming_quantity - Next30DayDelivery.running_sum_quantity_to_deliver AS in_stock_qty,
         CASE WHEN IncomingProductStock.running_sum_incoming_quantity - Next30DayDelivery.running_sum_quantity_to_deliver <= 0  THEN 'Out of Stock'
              WHEN IncomingProductStock.running_sum_incoming_quantity - Next30DayDelivery.running_sum_quantity_to_deliver <= 10 THEN 'Low'
              WHEN IncomingProductStock.running_sum_incoming_quantity - Next30DayDelivery.running_sum_quantity_to_deliver <= 20 THEN 'Medium'
              ELSE 'Ok'
          END AS stock_status
    FROM Next30DayDelivery
         -- inner join since the shared data always has a delivery per day, distribution center and product
         INNER JOIN IncomingProductStock
                 ON Next30DayDelivery.delivery_date          = IncomingProductStock.expected_delivery_date
                AND Next30DayDelivery.distribution_center_id = IncomingProductStock.distribution_center_id
                AND Next30DayDelivery.product_id             = IncomingProductStock.product_id
                AND IncomingProductStock.running_sum_incoming_quantity - Next30DayDelivery.running_sum_quantity_to_deliver <= 20
         INNER JOIN `${project_id}.${bigquery_thelook_ecommerce_dataset}.distribution_centers` distribution_centers
                 ON Next30DayDelivery.distribution_center_id = distribution_centers.id
         INNER JOIN `${project_id}.${bigquery_thelook_ecommerce_dataset}.products` products
                 ON Next30DayDelivery.product_id = products.id
)
-- SELECT * FROM Next30DayDelivery ORDER BY 2, 3;       -- 2,789,763 rows
-- SELECT * FROM IncomingProductStock ORDER BY 2, 3;    -- 26,208,000 rows
SELECT *  FROM DeliveryAndIncoming ORDER BY 1, 2, 3 ;


------------------------------------------------------------------------------------
-- Query 2
-- Show data that is being streamed in real time via Dataflow from a public Pub/Sub
-- Data is immediately available for reading by BigQuery
-- Determine if our delivers are slowing down or speeding up
--
-- NOTE: You need to start the Composer Airflow DAG "sample-dataflow-start-streaming-job"
--       several minutes before running this query in order to start the streaming job.
-- NOTE: You first need to start the Streaming job
--       1 - Open Composer in the Google Cloud Console
--       2 - Click "Airflow link" which will open a new tab
--       3 - Click the "Play" button next to the DAG: sample-dataflow-start-streaming-job
--       4 - The "Play" button will drop down and select "Trigger DAG" 
--       5 - You will need to wait several minutes in order for the Dataflow to start and send data
--           You can start this before your meeting.  The streaming job will be stopped after 4 hours.
--       6 - Head back over to BigQuery SQL Workspace
------------------------------------------------------------------------------------

WITH MaxStreamingDate AS
(
   -- Use the max date (versus current time in case the streaming job is not started)
   SELECT MAX(delivery_time) AS max_delivery_time
     FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries_streaming`
)
-- SELECT max_delivery_time FROM MaxStreamingDate;
, AverageDeliveryTime AS 
(
  SELECT CASE WHEN delivery_time > TIMESTAMP_SUB(max_delivery_time, INTERVAL 60 MINUTE) 
              THEN 'CurrentWindow'
              ELSE 'PriorWindow'
          END AS TimeWindow,
          distribution_center_id,
          delivery_minutes,
          distance
    FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.product_deliveries_streaming`
          CROSS JOIN MaxStreamingDate
   WHERE delivery_time > TIMESTAMP_SUB(max_delivery_time, INTERVAL 5 DAY)
     AND delivery_minutes > 0
     AND distance > 0
)
--SELECT * FROM AverageDeliveryTime ORDER BY distribution_center_id, TimeWindow;
, PivotData AS
(
  SELECT *
    FROM AverageDeliveryTime
  PIVOT (AVG(delivery_minutes) avg_delivery_minutes, AVG(distance) avg_distance, COUNT(*) nbr_of_deliveries FOR TimeWindow IN ('CurrentWindow', 'PriorWindow'))
)
-- SELECT * FROM PivotData;
SELECT distribution_centers.name AS distribution_center,

       nbr_of_deliveries_CurrentWindow AS deliveries_current,
       nbr_of_deliveries_PriorWindow AS deliveries_prior,

       ROUND(avg_distance_CurrentWindow,1) AS distance_current,
       ROUND(avg_distance_PriorWindow,1) AS distance_prior,

       CASE WHEN avg_distance_CurrentWindow > avg_distance_PriorWindow + (avg_distance_PriorWindow * .15) THEN 'High'
            WHEN avg_distance_CurrentWindow > avg_distance_PriorWindow + (avg_distance_PriorWindow * .10) THEN 'Med'
            WHEN avg_distance_CurrentWindow > avg_distance_PriorWindow + (avg_distance_PriorWindow * .05) THEN 'Low'
            ELSE 'Normal'
        END AS distance_trend,

       ROUND(avg_delivery_minutes_CurrentWindow,1) AS minutes_current,
       ROUND(avg_delivery_minutes_PriorWindow,1) AS minutes_prior,

       CASE WHEN avg_delivery_minutes_CurrentWindow > avg_delivery_minutes_PriorWindow + (avg_delivery_minutes_PriorWindow * .15) THEN 'High'
            WHEN avg_delivery_minutes_CurrentWindow > avg_delivery_minutes_PriorWindow + (avg_delivery_minutes_PriorWindow * .10) THEN 'Med'
            WHEN avg_delivery_minutes_CurrentWindow > avg_delivery_minutes_PriorWindow + (avg_delivery_minutes_PriorWindow * .05) THEN 'Low'
            ELSE 'Normal'
        END AS minutes_trend

  FROM PivotData
       INNER JOIN `${project_id}.${bigquery_thelook_ecommerce_dataset}.distribution_centers` AS distribution_centers
               ON PivotData.distribution_center_id = distribution_centers.id
ORDER BY distribution_center_id;


------------------------------------------------------------------------------------
-- Query 3
-- Query data that is stored in AWS S3
--
-- NOTE: To run this, you must have access to OMNI.  If you deployed this via 
--       click-to-deploy then access was granted automatically.  Otherwise, you need
--       to set up and configure OMNI and AWS manually.
------------------------------------------------------------------------------------

-- Create a table on data in AWS (S3)
CREATE OR REPLACE EXTERNAL TABLE `${project_id}.${aws_omni_biglake_dataset_name}.distribution_centers`
WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`
    OPTIONS (
    format = "PARQUET",
    uris = ['s3://${aws_omni_biglake_s3_bucket}/distribution-center/distribution_centers.parquet']
);

-- Query the data in AWS
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.distribution_centers` LIMIT 1000;

-- Export the data to S3 from the table
-- We would typically grab a subset of data so we just transfer the results of the query
EXPORT DATA WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`
  OPTIONS(
  uri="s3://${aws_omni_biglake_s3_bucket}/taxi-export/distribution_centers/*",
  format="PARQUET"
  )
AS
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.distribution_centers`;

-- Load into BigQuery
-- We can now join the data to the rest of data in BigQuery as well as do machine learning
-- This will appear in your dataset: ${bigquery_thelook_ecommerce_dataset}
LOAD DATA INTO `${project_id}.${bigquery_thelook_ecommerce_dataset}.aws_distribution_centers`
  FROM FILES (uris = ['s3://${aws_omni_biglake_s3_bucket}/taxi-export/distribution_centers/*'], format = 'PARQUET')
  WITH CONNECTION `${shared_demo_project_id}.${aws_omni_biglake_dataset_region}.${aws_omni_biglake_connection}`;

-- View the data just loaded
SELECT * FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.aws_distribution_centers`;


-- Use CTAS to query and directy load into BigQuery
-- Load query results directly into a local BigQuery table
CREATE OR REPLACE TABLE `${project_id}.${bigquery_thelook_ecommerce_dataset}.omni_aws_query_results` AS
SELECT * FROM `${project_id}.${aws_omni_biglake_dataset_name}.distribution_centers`;

SELECT * FROM `${project_id}.${bigquery_thelook_ecommerce_dataset}.omni_aws_query_results`;
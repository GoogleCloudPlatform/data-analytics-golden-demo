CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.product` 
CLUSTER BY product_id
AS
WITH data AS
(
  SELECT DISTINCT product, product_category
    FROM `${project_id}.${bigquery_governed_data_raw_dataset}.customer_transaction`
)
SELECT ROW_NUMBER() OVER (ORDER BY product.product) AS product_id,
       product.product     AS product_name, 
       product.description AS product_description,
       product_category.product_category_id
  FROM `${project_id}.${bigquery_governed_data_raw_dataset}.product` AS product
       INNER JOIN data
               ON product.product = data.product
       INNER JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.product_category` AS product_category
               ON data.product_category = product_category.product_category_name;

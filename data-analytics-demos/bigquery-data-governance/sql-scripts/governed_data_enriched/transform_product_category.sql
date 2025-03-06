CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.product_category` 
CLUSTER BY product_category_id
AS
SELECT ROW_NUMBER() OVER (ORDER BY product_category) AS product_category_id,
       product_category AS product_category_name, 
       description      AS product_category_description
 FROM `${project_id}.${bigquery_governed_data_raw_dataset}.product_category` ;

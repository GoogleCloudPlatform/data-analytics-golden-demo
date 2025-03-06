------------------------------------------------------------------------------------------------------------
-- Run ELT processes in the enriched dataset
------------------------------------------------------------------------------------------------------------
CALL `${project_id}.${bigquery_governed_data_enriched_dataset}.transform_customer`();
CALL `${project_id}.${bigquery_governed_data_enriched_dataset}.transform_product_category`();
CALL `${project_id}.${bigquery_governed_data_enriched_dataset}.transform_product`();
CALL `${project_id}.${bigquery_governed_data_enriched_dataset}.transform_order_pyspark`();

------------------------------------------------------------------------------------------------------------
-- Set the table descriptions for each table:
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.customer`
  SET OPTIONS (
      description = 'Cleaned and enriched table containing customer information.'
    );

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.customer`
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
  ALTER COLUMN zip SET OPTIONS (description='The zip code of the customer.'),
  ALTER COLUMN credit_card_number SET OPTIONS (description='The credit card number of the customer.');

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.order_header`
SET OPTIONS (
    description = 'Table containing header information for customer orders.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.order_header`
  ALTER COLUMN customer_id SET OPTIONS (description='Unique identifier for the customer who placed the order.'),
  ALTER COLUMN order_id SET OPTIONS (description='Unique identifier for the order.'),
  ALTER COLUMN region SET OPTIONS (description='The region where the order was placed.'),
  ALTER COLUMN order_datetime SET OPTIONS (description='The date and time when the order was placed.');

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.order_detail`
SET OPTIONS (
    description = 'Table containing detailed information for each item in a customer order.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.order_detail`
  ALTER COLUMN order_id SET OPTIONS (description='Unique identifier for the order this item belongs to.'),
  ALTER COLUMN product_id SET OPTIONS (description='Unique identifier for the product in this order item.'),
  ALTER COLUMN quantity SET OPTIONS (description='The quantity of the product in this order item.'),
  ALTER COLUMN price SET OPTIONS (description='The price of the product in this order item.');

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.product`
SET OPTIONS (
    description = 'Cleaned table containing product information with a primary key.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.product`
  ALTER COLUMN product_id SET OPTIONS (description='Unique identifier for the product.'),
  ALTER COLUMN product_name SET OPTIONS (description='The name of the product.'),
  ALTER COLUMN product_description SET OPTIONS (description='Description of the product.'),
  ALTER COLUMN product_category_id SET OPTIONS (description='Identifier for the category the product belongs to.');


ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.product_category`
SET OPTIONS (
    description = 'Cleaned table containing product category information.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.product_category`
  ALTER COLUMN product_category_id SET OPTIONS (description='Unique identifier for the product category.'),
  ALTER COLUMN product_category_name SET OPTIONS (description='The name of the product category.'),
  ALTER COLUMN product_category_description SET OPTIONS (description='Description of the product category.');
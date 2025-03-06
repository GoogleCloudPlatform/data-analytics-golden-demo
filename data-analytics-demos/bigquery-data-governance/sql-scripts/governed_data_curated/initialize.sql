------------------------------------------------------------------------------------------------------------
-- Create a customer table with a ML model of Predicted Credit Amount
------------------------------------------------------------------------------------------------------------

-- Step 1: Create training data with the selected features
CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data` AS
SELECT c.customer_id,
       SUM(d.quantity * d.price) as total_spent,
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.customer` AS c
       INNER JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.order_header` AS oh
               ON c.customer_id = oh.customer_id
       INNER JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.order_detail` AS d
               ON oh.order_id = d.order_id
 GROUP BY c.customer_id;


-- Step 2: Create your BQML Model (Regression Example)
CREATE OR REPLACE MODEL `${project_id}.${bigquery_governed_data_curated_dataset}.customer_credit_model`
OPTIONS(
  model_type='linear_reg',
  input_label_cols=['total_spent'],
  MODEL_REGISTRY = "vertex_ai"
  ) AS
SELECT total_spent,
       customer_id
 FROM `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data`;


-- Step 3: Predict Customer Credit
EXECUTE IMMEDIATE """
CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer` 
CLUSTER BY customer_id
AS
SELECT c.*,
       ml.predicted_total_spent as predicted_credit_amount
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.customer` as c
       LEFT JOIN ML.PREDICT(MODEL `${project_id}.${bigquery_governed_data_curated_dataset}.customer_credit_model`,
                                  (SELECT customer_id, total_spent from `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data`)) as ml
              ON c.customer_id = ml.customer_id;""";


CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_header` 
CLUSTER BY order_id
AS
SELECT *
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.order_header`;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail` 
CLUSTER BY order_id
AS
SELECT *
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.order_detail` ;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product` 
CLUSTER BY product_id
AS
SELECT *
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.product` ;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product_category` 
CLUSTER BY product_category_id
AS
SELECT *
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.product_category` ;


-- This table will have its descriptions and column descriptions created by Data Insights
CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.sales` AS
SELECT p.product_name,
       p.product_description,
       pd.product_category_name,
       pd.product_category_description,
       oh.region,
       oh.order_datetime,
       od.price,
       od.quantity,
       c.*
  FROM `${project_id}.${bigquery_governed_data_enriched_dataset}.order_header` oh
      LEFT JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.order_detail` od
             ON oh.order_id=od.order_id
      INNER JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.product` AS p
              ON od.product_id=p.product_id
      INNER JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.product_category` AS pd
              ON pd.product_category_id=p.product_category_id
      INNER JOIN `${project_id}.${bigquery_governed_data_enriched_dataset}.customer` as c 
              ON c.customer_id=oh.customer_id;

------------------------------------------------------------------------------------------------------------
-- Set the PK/FK for each table:
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer`               ADD PRIMARY KEY (customer_id) NOT ENFORCED; 
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data` ADD PRIMARY KEY (customer_id) NOT ENFORCED; 
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_header`           ADD PRIMARY KEY (order_id) NOT ENFORCED; 
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail`           ADD PRIMARY KEY (order_id, product_id) NOT ENFORCED; 
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product`                ADD PRIMARY KEY (product_id) NOT ENFORCED; 
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product_category`       ADD PRIMARY KEY (product_category_id) NOT ENFORCED; 

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data`
  ADD CONSTRAINT fk_customer_customer_training_data FOREIGN KEY (customer_id) 
  REFERENCES `${project_id}.${bigquery_governed_data_curated_dataset}.customer`(customer_id) NOT ENFORCED;

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_header`
  ADD CONSTRAINT fk_customer_order_header FOREIGN KEY (customer_id) 
  REFERENCES `${project_id}.${bigquery_governed_data_curated_dataset}.customer`(customer_id) NOT ENFORCED;

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail`
  ADD CONSTRAINT fk_order_header_order_detail FOREIGN KEY (order_id) 
  REFERENCES `${project_id}.${bigquery_governed_data_curated_dataset}.order_header`(order_id) NOT ENFORCED;

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail`
  ADD CONSTRAINT fk_order_detail_product FOREIGN KEY (product_id) 
  REFERENCES `${project_id}.${bigquery_governed_data_curated_dataset}.product`(product_id) NOT ENFORCED;

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product`
  ADD CONSTRAINT fk_product_product_category FOREIGN KEY (product_category_id) 
  REFERENCES `${project_id}.${bigquery_governed_data_curated_dataset}.product_category`(product_category_id) NOT ENFORCED;


------------------------------------------------------------------------------------------------------------
-- Set the table descriptions for each table:
------------------------------------------------------------------------------------------------------------
ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer`
SET OPTIONS (
    description = 'Curated table containing customer information with predicted credit amount.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer`
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
    ALTER COLUMN credit_card_number SET OPTIONS (description='The credit card number of the customer.'),
   ALTER COLUMN predicted_credit_amount SET OPTIONS (description='The predicted credit amount for the customer.');

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data`
SET OPTIONS (
    description = 'Table containing training data for the customer credit model.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.customer_training_data`
  ALTER COLUMN customer_id SET OPTIONS (description='Unique identifier for the customer.'),
  ALTER COLUMN total_spent SET OPTIONS (description='The total amount spent by the customer.');

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail`
SET OPTIONS (
    description = 'Curated table containing detailed information for each item in a customer order, with primary and foreign key constraints.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail`
  ALTER COLUMN order_id SET OPTIONS (description='Unique identifier for the order this item belongs to (Primary Key, Foreign Key).'),
   ALTER COLUMN product_id SET OPTIONS (description='Unique identifier for the product in this order item (Primary Key, Foreign Key).'),
  ALTER COLUMN quantity SET OPTIONS (description='The quantity of the product in this order item.'),
  ALTER COLUMN price SET OPTIONS (description='The price of the product in this order item.');

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_header`
SET OPTIONS (
    description = 'Curated table containing header information for customer orders, with primary and foreign key constraints.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.order_header`
  ALTER COLUMN customer_id SET OPTIONS (description='Unique identifier for the customer who placed the order (Foreign Key).'),
  ALTER COLUMN order_id SET OPTIONS (description='Unique identifier for the order (Primary Key).'),
  ALTER COLUMN region SET OPTIONS (description='The region where the order was placed.'),
  ALTER COLUMN order_datetime SET OPTIONS (description='The date and time when the order was placed.');

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product`
SET OPTIONS (
    description = 'Curated table containing product information with a primary key.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product`
  ALTER COLUMN product_id SET OPTIONS (description='Unique identifier for the product (Primary Key).'),
  ALTER COLUMN product_name SET OPTIONS (description='The name of the product.'),
  ALTER COLUMN product_description SET OPTIONS (description='Description of the product.'),
    ALTER COLUMN product_category_id SET OPTIONS (description='Identifier for the category the product belongs to.');

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product_category`
SET OPTIONS (
    description = 'Curated table containing product category information with a primary key.'
  );

ALTER TABLE `${project_id}.${bigquery_governed_data_curated_dataset}.product_category`
  ALTER COLUMN product_category_id SET OPTIONS (description='Unique identifier for the product category (Primary Key).'),
  ALTER COLUMN product_category_name SET OPTIONS (description='The name of the product category.'),
  ALTER COLUMN product_category_description SET OPTIONS (description='Description of the product category.');


------------------------------------------------------------------------------------------------------------
-- Create the views for the analytics hub
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.customer_view`
OPTIONS(
  description="Analytics Hub View of the customer table"
)
AS
SELECT
    customer_id AS customer_id, -- Unique identifier for the customer. Primary Key.
    first_name AS first_name, -- First name of the customer.
    last_name AS last_name, -- Last name of the customer.
    email AS email, -- Email address of the customer.
    phone AS phone, -- Phone number of the customer.
    gender AS gender, -- Gender of the customer.
    ip_address AS ip_address, -- IP address associated with the customer.
    ssn AS ssn, -- Social Security Number of the customer.
    address AS address, -- Street address of the customer.
    city AS city, -- City of the customer's address.
    state AS state, -- State of the customer's address.
    zip AS zip, -- Zip code of the customer's address.
    credit_card_number AS credit_card_number, -- Credit card number of the customer.
    predicted_credit_amount AS predicted_credit_amount -- Predicted credit amount for the customer.
  FROM
   `${project_id}.${bigquery_governed_data_curated_dataset}.customer` ;


ALTER VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.customer_view`
  ALTER COLUMN customer_id SET OPTIONS(description="Unique identifier for the customer. Primary Key."),
  ALTER COLUMN first_name SET OPTIONS(description="First name of the customer."),
  ALTER COLUMN last_name SET OPTIONS(description="Last name of the customer."),
  ALTER COLUMN email SET OPTIONS(description="Email address of the customer."),
  ALTER COLUMN phone SET OPTIONS(description="Phone number of the customer."),
  ALTER COLUMN gender SET OPTIONS(description="Gender of the customer."),
  ALTER COLUMN ip_address SET OPTIONS(description="IP address associated with the customer."),
  ALTER COLUMN ssn SET OPTIONS(description="Social Security Number of the customer."),
  ALTER COLUMN address SET OPTIONS(description="Street address of the customer."),
  ALTER COLUMN city SET OPTIONS(description="City of the customer's address."),
  ALTER COLUMN state SET OPTIONS(description="State of the customer's address."),
  ALTER COLUMN zip SET OPTIONS(description="Zip code of the customer's address."),
  ALTER COLUMN credit_card_number SET OPTIONS(description="Credit card number of the customer."),
  ALTER COLUMN predicted_credit_amount SET OPTIONS(description="Predicted credit amount for the customer.");


CREATE OR REPLACE VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.order_detail_view`
OPTIONS(
  description="Analytics Hub View of the order_detail table"
)
AS
SELECT
    order_id AS order_id, -- Identifier for the order. Primary Key and Foreign Key.
    product_id AS product_id, -- Identifier for the product. Primary Key and Foreign Key.
    quantity AS quantity, -- Quantity of the product in the order.
    price AS price -- Price of the product at the time of order.
  FROM
   `${project_id}.${bigquery_governed_data_curated_dataset}.order_detail` ;

ALTER VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.order_detail_view`
  ALTER COLUMN order_id SET OPTIONS(description="Identifier for the order. Primary Key and Foreign Key."),
  ALTER COLUMN product_id SET OPTIONS(description="Identifier for the product. Primary Key and Foreign Key."),
  ALTER COLUMN quantity SET OPTIONS(description="Quantity of the product in the order."),
  ALTER COLUMN price SET OPTIONS(description="Price of the product at the time of order.");


CREATE OR REPLACE VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.order_header_view`
OPTIONS(
  description="Analytics Hub View of the order_header table"
)
AS
SELECT
    customer_id AS customer_id, -- Identifier for the customer who placed the order. Foreign Key.
    order_id AS order_id, -- Unique identifier for the order. Primary Key.
    region AS region, -- Region where the order was placed.
    order_datetime AS order_datetime -- Date and time when the order was placed.
  FROM
   `${project_id}.${bigquery_governed_data_curated_dataset}.order_header` ;


ALTER VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.order_header_view`
  ALTER COLUMN customer_id SET OPTIONS(description="Identifier for the customer who placed the order. Foreign Key."),
  ALTER COLUMN order_id SET OPTIONS(description="Unique identifier for the order. Primary Key."),
  ALTER COLUMN region SET OPTIONS(description="Region where the order was placed."),
  ALTER COLUMN order_datetime SET OPTIONS(description="Date and time when the order was placed.");


CREATE OR REPLACE VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.product_view`
OPTIONS(
  description="Analytics Hub View of the product table"
)
AS
SELECT
    product_id AS product_id, -- Unique identifier for the product. Primary Key.
    product_name AS product_name, -- Name of the product.
    product_description AS product_description, -- Detailed description of the product.
    product_category_id AS product_category_id -- Identifier for the category the product belongs to. Foreign Key.
  FROM
   `${project_id}.${bigquery_governed_data_curated_dataset}.product` ;


ALTER VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.product_view`
  ALTER COLUMN product_id SET OPTIONS(description="Unique identifier for the product. Primary Key."),
  ALTER COLUMN product_name SET OPTIONS(description="Name of the product."),
  ALTER COLUMN product_description SET OPTIONS(description="Detailed description of the product."),
  ALTER COLUMN product_category_id SET OPTIONS(description="Identifier for the category the product belongs to. Foreign Key.");


CREATE OR REPLACE VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.product_category_view`
OPTIONS(
  description="Analytics Hub View of the product_category table"
)
AS
SELECT
    product_category_id AS product_category_id, -- Unique identifier for the product category. Primary Key.
    product_category_name AS product_category_name, -- Name of the product category.
    product_category_description AS product_category_description -- Description of the product category.
  FROM
   `${project_id}.${bigquery_governed_data_curated_dataset}.product_category` ;

ALTER VIEW `${project_id}.${bigquery_analytics_hub_publisher_dataset}.product_category_view`
  ALTER COLUMN product_category_id SET OPTIONS(description="Unique identifier for the product category. Primary Key."),
  ALTER COLUMN product_category_name SET OPTIONS(description="Name of the product category."),
  ALTER COLUMN product_category_description SET OPTIONS(description="Description of the product category.");   
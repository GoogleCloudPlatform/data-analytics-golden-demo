/*##################################################################################
# Copyright 2025 Google LLC
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

--------------------------------------------------------------------------------
-- Curated
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ** camera **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.camera`
(
    camera_id               INT64         OPTIONS(description="The unique identifier for the camera."),
    camera_model            STRING                  OPTIONS(description="The model name of the camera."),
    camera_location_type    STRING                  OPTIONS(description="The mounting location/type of the camera (e.g., 'front_facing_queue', 'side_foot_traffic')."),
    resolution_pixels       STRING                  OPTIONS(description="The resolution of the camera in pixels (e.g., '1920x1080')."),
    field_of_view_degrees   NUMERIC(5, 2)           OPTIONS(description="The camera's field of view in degrees."),
    installation_date       DATE                    OPTIONS(description="The date the camera was installed."),
    status                  STRING                  OPTIONS(description="Current operational status of the camera (e.g., 'online', 'offline', 'calibrating').")
)
CLUSTER BY camera_id
OPTIONS(
    description="Dimension table containing static information about cameras used for customer queue and foot traffic analysis."
);

INSERT INTO `agentic_beans_curated.camera`
(camera_id, camera_model, camera_location_type, resolution_pixels, field_of_view_degrees, installation_date, status)
SELECT camera_id, 
       camera_model,
       camera_location_type,
       resolution_pixels,
       field_of_view_degrees,
       installation_date,
       status
  FROM `agentic_beans_enriched.camera`;


--------------------------------------------------------------------------------
-- ** customer **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.customer`
(
    customer_id             INTEGER OPTIONS(description="The unique identifier and primary key for each customer."),
    customer_name           STRING  OPTIONS(description="The full name of the customer."),
    customer_yob            INTEGER OPTIONS(description="The customer's year of birth, used for demographic analysis."),
    customer_email          STRING  OPTIONS(description="The unique email address of the customer, used for marketing and receipts."),
    customer_inception_date DATE    OPTIONS(description="The date of the customer's first transaction, marking their start date."),
    country_code            STRING  OPTIONS(description="The two-letter ISO 3166-1 alpha-2 country code of the customer (e.g., 'US', 'CA', 'GB')."),

    -- curated data
    customer_total_spend                  NUMERIC(10, 2) OPTIONS(description="The customers lifetime value."),
    customer_average_transaction_value    NUMERIC(10, 2) OPTIONS(description="The customers average order amount."),
    customer_number_of_transactions       INTEGER        OPTIONS(description="The customers number of orders."),
    customer_favorite_product_id          INTEGER        OPTIONS(description="The customers favorite product (id)."),
    customer_favorite_product_category_id INTEGER        OPTIONS(description="The customers favorite product category (id)."),
)
CLUSTER BY customer_id
OPTIONS(
    description="A table containing demographic, contact information and overall order information for individual customers."
);


INSERT INTO `agentic_beans_curated.customer`
(customer_id, customer_name, customer_yob, customer_email, customer_inception_date, country_code,
customer_total_spend, customer_average_transaction_value, customer_number_of_transactions, 
customer_favorite_product_id, customer_favorite_product_category_id)
WITH customer_order_data AS
(
  SELECT order_header.customer_id,
         ROUND(SUM(order_detail.price * order_detail.order_quantity),2) AS customer_total_spend,
         ROUND(AVG(order_detail.price * order_detail.order_quantity),2) AS customer_average_transaction_value,
         COUNT(*) AS customer_number_of_transactions
    FROM `agentic_beans_enriched.order_header` AS order_header
         INNER JOIN `agentic_beans_enriched.order_detail` AS order_detail
                 ON order_header.order_header_id = order_detail.order_header_id
   GROUP BY ALL
),
customer_product_data AS
(
  SELECT order_header.customer_id,
         order_detail.product_id,
         ROW_NUMBER() OVER (PARTITION BY order_header.customer_id ORDER BY COUNT(order_detail.product_id) DESC) AS ranking
    FROM `agentic_beans_enriched.order_header` AS order_header
         INNER JOIN `agentic_beans_enriched.order_detail` AS order_detail
                 ON order_header.order_header_id = order_detail.order_header_id
   GROUP BY ALL
),
customer_product_category_data AS
(
  SELECT order_header.customer_id,
         product.product_category_id,
         ROW_NUMBER() OVER (PARTITION BY order_header.customer_id ORDER BY COUNT(product.product_category_id) DESC) AS ranking
    FROM `agentic_beans_enriched.order_header` AS order_header
         INNER JOIN `agentic_beans_enriched.order_detail` AS order_detail
                 ON order_header.order_header_id = order_detail.order_header_id
         INNER JOIN `agentic_beans_enriched.product` AS product
                 ON order_detail.product_id = product.product_id
   GROUP BY ALL
)
SELECT customer.customer_id,
       customer.customer_name,
       customer.customer_yob,
       customer.customer_email,
       customer.customer_inception_date,
       customer.country_code,
       customer_order_data.customer_total_spend,
       customer_order_data.customer_average_transaction_value,
       customer_order_data.customer_number_of_transactions, 
       customer_product_data.product_id AS customer_favorite_product_id,
       customer_product_category_data.product_category_id AS customer_favorite_product_category_id
  FROM `agentic_beans_enriched.customer` AS customer
       LEFT JOIN customer_order_data
              ON customer.customer_id = customer_order_data.customer_id
       LEFT JOIN customer_product_data
              ON customer.customer_id = customer_product_data.customer_id
            AND customer_product_data.ranking = 1
       LEFT JOIN customer_product_category_data
              ON customer.customer_id = customer_product_category_data.customer_id
            AND customer_product_category_data.ranking = 1;


--------------------------------------------------------------------------------
-- ** event **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.event`
(
    event_id            INT64      OPTIONS(description="The unique identifier and primary key for each event."),
    event_title         STRING     OPTIONS(description="The public-facing title of the event."),
    event_location      STRING     OPTIONS(description="The specific address or location of the event."),
    event_description   STRING              OPTIONS(description="A detailed description of the event."),
    event_start_date_time TIMESTAMP OPTIONS(description="The date and time when the event begins (UTC)."),
    event_end_date_time TIMESTAMP OPTIONS(description="The date and time when the event ends (UTC)."),
    age_range           STRING              OPTIONS(description="The recommended or required age range for event attendees (e.g., 'All Ages', '18+', '21+')."),
    event_venue         STRING              OPTIONS(description="The name of the venue where the event is held, if applicable."),
    event_neighborhood  STRING              OPTIONS(description="The Manhattan neighborhood where the event takes place, based on the provided list.")
)
CLUSTER BY event_id
OPTIONS(
    description="A table containing information about events where the coffee trucks will be present."
);

INSERT INTO `agentic_beans_curated.event`
(event_id, event_title, event_location, event_description, event_start_date_time, event_end_date_time, 
age_range, event_venue, event_neighborhood)
SELECT event_id, 
       event_title,
       event_location,
       event_description,
       event_start_date_time,
       event_end_date_time,
       age_range,
       event_venue,
       event_neighborhood
  FROM `agentic_beans_enriched.event`;


--------------------------------------------------------------------------------
-- ** ingredient **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.ingredient`
(
    ingredient_id           INT64         OPTIONS(description="A unique identifier for each distinct ingredient."),
    ingredient_name         STRING         OPTIONS(description="The common name of the ingredient (e.g., 'Espresso Beans', 'Dairy Milk Whole', 'Chocolate Syrup')."),
    ingredient_category     STRING                  OPTIONS(description="The category of the ingredient (e.g., 'Coffee Beans', 'Milk', 'Syrup', 'Packaging')."),
    standard_unit_of_measure STRING                  OPTIONS(description="The primary unit of measure for this ingredient (e.g., 'grams', 'liters', 'count')."),
    is_perishable           BOOL                    OPTIONS(description="Indicates if the ingredient is perishable (TRUE/FALSE).")
)
CLUSTER BY ingredient_id
OPTIONS(
    description="Dimension table listing all trackable ingredients and consumables used on coffee trucks."
);

INSERT INTO `agentic_beans_curated.ingredient`
(ingredient_id, ingredient_name, ingredient_category, standard_unit_of_measure, is_perishable)
SELECT ingredient_id, 
       ingredient_name,
       ingredient_category,
       standard_unit_of_measure,
       is_perishable
  FROM `agentic_beans_enriched.ingredient`;


--------------------------------------------------------------------------------
-- ** machine **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.machine`
(
    machine_id              INT64         OPTIONS(description="The unique identifier for the coffee machine."),
    machine_model           STRING                  OPTIONS(description="The model name of the coffee machine (e.g., 'EspressoBot 3000', 'BrewMaster 500')."),
    manufacturer            STRING                  OPTIONS(description="The manufacturer of the coffee machine."),
    serial_number           STRING                  OPTIONS(description="The manufacturer's serial number for the machine."),
    installation_date       DATE                    OPTIONS(description="The date the machine was installed in a truck."),
    last_maintenance_date   DATE                    OPTIONS(description="The date of the last recorded maintenance activity on the machine."),
    status                  STRING                  OPTIONS(description="Current operational status of the machine (e.g., 'active', 'in_maintenance', 'retired').")
)
CLUSTER BY machine_id
OPTIONS(
    description="Dimension table containing static information about each coffee machine in the fleet."
);

INSERT INTO `agentic_beans_curated.machine`
(machine_id, machine_model, manufacturer, serial_number, installation_date, last_maintenance_date, status)
SELECT machine_id, 
       machine_model,
       manufacturer,
       serial_number,
       installation_date,
       last_maintenance_date,
       status
  FROM `agentic_beans_enriched.machine`;


--------------------------------------------------------------------------------
-- ** order_detail **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.order_detail` (
    order_detail_id INTEGER OPTIONS(description="Unique identifier for each line item in an order."),
    order_header_id INTEGER OPTIONS(description="Foreign key linking to the order_header table, indicating which order this detail belongs to."),
    truck_menu_id INTEGER OPTIONS(description="Identifier for the specific menu item ordered from the coffee truck's menu."),
    order_quantity INTEGER OPTIONS(description="Quantity of the specific menu item ordered."),
    product_id               INT64 OPTIONS(description="The foreign key referencing the 'product_id' from the 'product' table, identifying the specific coffee offering."),
    product_category_id      INT64 OPTIONS(description="The foreign key referencing the 'product_category_id' from the 'product_category' table, identifying the specific product category."),
    size                     STRING         OPTIONS(description="The size of the product offering (e.g., 'S' for Small, 'M' for Medium, 'L' for Large, 'N/A' for items without a size)."),
    price                    NUMERIC(10, 2) OPTIONS(description="The price of the product offering on this specific truck's menu."),
    order_detail_total       NUMERIC(10, 2) OPTIONS(description="The total for the line item size * price."),
)
OPTIONS(
    description="Contains detailed line items for each order, including the menu item and quantity, relevant for coffee shop and truck operations."
);


INSERT INTO `agentic_beans_curated.order_detail` 
(order_detail_id, order_header_id, truck_menu_id, order_quantity, product_id, product_category_id, size, price, order_detail_total)
SELECT order_detail.order_detail_id,
       order_detail.order_header_id,
       order_detail.truck_menu_id,
       order_detail.order_quantity,
       order_detail.product_id,
       product.product_category_id,
       order_detail.size,
       order_detail.price,
       (order_detail.order_quantity * order_detail.price) AS order_detail_total
  FROM `agentic_beans_enriched.order_detail` AS order_detail
       INNER JOIN `agentic_beans_enriched.product` AS product
               ON order_detail.product_id = product.product_id;


--------------------------------------------------------------------------------
-- ** order_header **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.order_header` (
    order_header_id INTEGER OPTIONS(description="Unique identifier for each order header."),
    order_header_timestamp TIMESTAMP OPTIONS(description="Timestamp when the order was placed."),
    truck_id INTEGER OPTIONS(description="The truck identifier the order was placed"),
    customer_id INTEGER OPTIONS(description="Identifier for the customer who placed the order."),
    order_neighborhood STRING OPTIONS(description="Neighborhood where the order was placed or delivered, relevant for coffee truck operations."),
    order_header_total NUMERIC(10, 2) OPTIONS(description="The total amount for the order."),
    payment_method STRING OPTIONS(description="The type of payment method used."),
)
OPTIONS(
    description="Contains header information for orders placed at the coffee shop, potentially through coffee trucks."
);

INSERT INTO `agentic_beans_curated.order_header`
(order_header_id, order_header_timestamp, truck_id, customer_id, order_neighborhood, order_header_total, payment_method)
WITH order_total AS
(
  SELECT order_detail.order_header_id,
         RAND() AS random_payment_method,
         SUM(order_detail.order_quantity * truck_menu.price) AS order_header_total
    FROM `agentic_beans_enriched.order_detail` AS order_detail
         INNER JOIN `agentic_beans_enriched.truck_menu` AS truck_menu
                 ON order_detail.truck_menu_id = truck_menu.truck_menu_id
   GROUP BY ALL
)
SELECT order_header.order_header_id, 
       order_header.order_header_timestamp, 
       order_header.truck_id, 
       order_header.customer_id, 
       order_header.order_neighborhood, 
       order_total.order_header_total, 
       CASE WHEN order_total.random_payment_method < .35 THEN 'Google Pay'
            WHEN order_total.random_payment_method < .40 THEN 'Apple Pay'
            WHEN order_total.random_payment_method < .50 THEN 'Samsung Pay'
            WHEN order_total.random_payment_method < .60 THEN 'Visa'
            WHEN order_total.random_payment_method < .70 THEN 'Mastercard'
            WHEN order_total.random_payment_method < .75 THEN 'American Express'
            WHEN order_total.random_payment_method < .80 THEN 'Discover Credit'
            WHEN order_total.random_payment_method < .90 THEN 'Cash'
            WHEN order_total.random_payment_method < .95 THEN 'Gift Card'
            ELSE 'Venmo'
       END AS payment_method
  FROM `agentic_beans_enriched.order_header` AS order_header
       LEFT JOIN order_total
              ON order_header.order_header_id = order_total.order_header_id;



--------------------------------------------------------------------------------
-- ** product **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.product`
(
    product_id           INT64  OPTIONS(description="The unique identifier and primary key for each product."),
    product_category_id  INT64  OPTIONS(description="A foreign key that links this product to its corresponding category in the product_category table."),
    product_name         STRING OPTIONS(description="The public-facing name of the individual product (e.g., 'Latte', 'Blueberry Muffin', 'Cold Brew')."),
    product_description  STRING OPTIONS(description="A detailed, customer-facing description of the product, suitable for a menu."),
    product_image_prompt STRING          OPTIONS(description="The specific text prompt provided to a generative AI model to create the product image."),
    product_image_uri    STRING          OPTIONS(description="The URI location of the product image stored in Google Cloud Storage (format: gs://bucket-name/image-path/image-name.png)."),
    product_image_obj_ref STRUCT<uri STRING, version STRING, authorizer STRING, details JSON> OPTIONS(description="Contains the BigLake Object Ref Data")
)
CLUSTER BY product_id
OPTIONS(
    description="A table containing all individual products available for sale on the coffee trucks' menus."
);

INSERT INTO `agentic_beans_curated.product`
(product_id, product_category_id, product_name, product_description, product_image_prompt, product_image_uri, product_image_obj_ref)
SELECT product_id, 
       product_category_id,
       product_name,
       product_description,
       product_image_prompt,
       product_image_uri,
       OBJ.FETCH_METADATA(
        OBJ.MAKE_REF(
            product_image_uri,
            'projects/${project_id}/locations/${bigquery_non_multi_region}/connections/biglake-connection')) AS product_image_obj_ref
  FROM `agentic_beans_enriched.product`;


--------------------------------------------------------------------------------
-- ** product_category **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.product_category`
(
    product_category_id           INT64  OPTIONS(description="The unique identifier and primary key for each product category."),
    product_category_name         STRING OPTIONS(description="The public-facing name of the product category (e.g., 'Espresso & Milk', 'Bakery & Pastries')."),
    product_category_description  STRING OPTIONS(description="A detailed description of the product category, suitable for providing context on a menu or for internal reference."),
    product_category_image_prompt STRING          OPTIONS(description="A GenAI prompt used to generate the product_category_image_uri."),
    product_category_image_uri    STRING          OPTIONS(description="The location of the product category image on Google Cloud Storage (format: ga://bucket-name/image-path/image-name.png)"),
    product_category_image_obj_ref STRUCT<uri STRING, version STRING, authorizer STRING, details JSON> OPTIONS(description="Contains the BigLake Object Ref Data")
    
)
CLUSTER BY product_category_id
OPTIONS(
    description="A table to classify products into distinct groups, such as beverages, food, and retail items."
);

INSERT INTO `agentic_beans_curated.product_category`
(product_category_id, product_category_name, product_category_description, product_category_image_prompt, 
product_category_image_uri, product_category_image_obj_ref)
SELECT product_category_id, 
       product_category_name,
       product_category_description,
       product_category_image_prompt,
       product_category_image_uri,
       OBJ.FETCH_METADATA(
        OBJ.MAKE_REF(
            product_category_image_uri, 'projects/${project_id}/locations/${bigquery_non_multi_region}/connections/biglake-connection')) AS product_category_image_obj_ref
  FROM `agentic_beans_enriched.product_category`;

-- Test
/*
{"errors":[{"code":403,"message":"bqcx-517693961302-6c7x@gcp-sa-bigquery-condel.iam.gserviceaccount.com does not have storage.objects.get access to the Google Cloud Storage object. Permission 'storage.objects.get' denied on resource (or it may not exist).","source":"OBJ.FETCH_METADATA"}]}

SELECT OBJ.FETCH_METADATA(product_category_image_obj_ref) FROM `agentic_beans_curated.product_category`;
*/

--------------------------------------------------------------------------------
-- ** telemetry_camera_vision **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.telemetry_camera_vision`
(
    telemetry_camera_vision_id      STRING         OPTIONS(description="A unique identifier for each queue analysis event."),
    telemetry_load_id               STRING         OPTIONS(description="A unique identifier for the batch load."),
    truck_id                        INT64          OPTIONS(description="The foreign key referencing the 'truck_id' from the 'truck' table."),
    telemetry_timestamp             TIMESTAMP      OPTIONS(description="The timestamp when the camera analysis was performed."),
    camera_id                       INT64         OPTIONS(description="The foreign key referencing the 'camera_id' from the 'camera_dim' table."),
    people_in_queue_count           INT64          OPTIONS(description="The number of people detected in the coffee truck's service queue."),
    foot_traffic_count_nearby       INT64          OPTIONS(description="The number of people detected walking by the truck in the immediate vicinity."),
    ai_detection_confidence_score   NUMERIC(3, 2)           OPTIONS(description="The AI model's confidence score for the detection accuracy (0.0 to 1.0)."),
    image_reference_url             STRING                  OPTIONS(description="Optional URL to the image or a key to the image in storage for audit/debugging."),
    detection_model_version         STRING                  OPTIONS(description="The version of the AI model used for detection.")
)
CLUSTER BY truck_id, telemetry_timestamp
OPTIONS(
    description="Curated data from AI-powered camera analysis, tracking customer queue lengths and general foot traffic around coffee trucks."
);

INSERT INTO `agentic_beans_curated.telemetry_camera_vision`
(telemetry_camera_vision_id, telemetry_load_id, truck_id, telemetry_timestamp, 
camera_id, people_in_queue_count, foot_traffic_count_nearby, ai_detection_confidence_score, image_reference_url,detection_model_version)
SELECT telemetry_camera_vision_id, 
       telemetry_load_id,
       truck_id,
       telemetry_timestamp,
       camera_id,
       people_in_queue_count,
       foot_traffic_count_nearby,
       ai_detection_confidence_score,
       image_reference_url,
       detection_model_version,
  FROM `agentic_beans_enriched.telemetry_camera_vision`;


--------------------------------------------------------------------------------
-- ** telemetry_coffee_machine **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.telemetry_coffee_machine`
(
    telemetry_coffee_machine_id     STRING         OPTIONS(description="A unique identifier for each telemetry reading."),
    telemetry_load_id               STRING         OPTIONS(description="A unique identifier for the batch load."),
    machine_id                      INT64          OPTIONS(description="The foreign key referencing the 'machine_id' from the 'machine_dim' table."),
    truck_id                        INT64          OPTIONS(description="The foreign key referencing the 'truck_id' from the 'truck' table, indicating which truck this machine belongs to."),
    telemetry_timestamp             TIMESTAMP      OPTIONS(description="The timestamp when the telemetry reading was recorded by the machine."),
    boiler_temperature_celsius      NUMERIC(5, 2)           OPTIONS(description="The current temperature of the machine's boiler in Celsius."),
    brew_pressure_bar               NUMERIC(4, 2)           OPTIONS(description="The current pressure during brewing in bars."),
    water_flow_rate_ml_per_sec      NUMERIC(5, 2)           OPTIONS(description="The water flow rate during brewing in milliliters per second."),
    grinder_motor_rpm               INT64                   OPTIONS(description="The revolutions per minute (RPM) of the coffee grinder's motor."),
    grinder_motor_torque_nm         NUMERIC(5, 2)           OPTIONS(description="The torque applied by the grinder motor in Newton-meters."),
    water_reservoir_level_percent   NUMERIC(5, 2)           OPTIONS(description="The percentage of water remaining in the machine's reservoir."),
    bean_hopper_level_grams         NUMERIC(8, 2)           OPTIONS(description="The quantity of coffee beans remaining in the hopper in grams."),
    total_brew_cycles_counter       INT64                   OPTIONS(description="Cumulative count of brew cycles completed by the machine."),
    last_error_code                 STRING                  OPTIONS(description="The most recent error code reported by the machine."),
    last_error_description          STRING                  OPTIONS(description="A description for the most recent error code."),
    power_consumption_watts         NUMERIC(8, 2)           OPTIONS(description="Current power consumption of the machine in Watts."),
    cleaning_cycle_status           STRING                  OPTIONS(description="Current status of the cleaning cycle (e.g., 'completed', 'in_progress', 'due').")
)
CLUSTER BY machine_id, telemetry_timestamp
OPTIONS(
    description="Curated telemetry data from coffee machines, used for real-time health monitoring, anomaly detection, and predictive maintenance insights."
);

INSERT INTO `agentic_beans_curated.telemetry_coffee_machine`
(telemetry_coffee_machine_id, telemetry_load_id, machine_id, truck_id, 
telemetry_timestamp, boiler_temperature_celsius, brew_pressure_bar, water_flow_rate_ml_per_sec, 
grinder_motor_rpm, grinder_motor_torque_nm, water_reservoir_level_percent, bean_hopper_level_grams,
total_brew_cycles_counter, last_error_code, last_error_description, power_consumption_watts, cleaning_cycle_status)
SELECT telemetry_coffee_machine_id, 
       telemetry_load_id,
       machine_id,
       truck_id,
       telemetry_timestamp,
       boiler_temperature_celsius,
       brew_pressure_bar,
       water_flow_rate_ml_per_sec,
       grinder_motor_rpm,
       grinder_motor_torque_nm,
       water_reservoir_level_percent,
       bean_hopper_level_grams,
       total_brew_cycles_counter,
       last_error_code,
       last_error_description,
       power_consumption_watts,
       cleaning_cycle_status
  FROM `agentic_beans_enriched.telemetry_coffee_machine`;

--------------------------------------------------------------------------------
-- ** telemetry_inventory **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.telemetry_inventory`
(
    telemetry_inventory_id           STRING         OPTIONS(description="A unique identifier for each inventory update event."),
    telemetry_load_id               STRING         OPTIONS(description="A unique identifier for the batch load."),
    truck_id                        INT64          OPTIONS(description="The foreign key referencing the 'truck_id' from the 'truck' table."),
    telemetry_timestamp             TIMESTAMP      OPTIONS(description="The timestamp when the inventory level was recorded or updated."),
    ingredient_id                   INT64         OPTIONS(description="The foreign key referencing the 'ingredient_id' from the 'ingredient_dim' table."),
    current_quantity_value          NUMERIC(10, 3) OPTIONS(description="The current measured quantity of the ingredient."),
    unit_of_measure                 STRING         OPTIONS(description="The unit of measure for the quantity (e.g., 'grams', 'liters', 'count', 'sheets')."),
    event_type                      STRING         OPTIONS(description="The type of inventory event (e.g., 'sensor_reading', 'replenished', 'consumed_by_sale', 'waste', 'manual_adjustment')."),
    associated_transaction_id       STRING                  OPTIONS(description="Optional: ID of the POS transaction that caused a consumption event."),
    source_sensor_id                STRING                  OPTIONS(description="Identifier for the specific sensor (e.g., weight sensor ID, RFID reader ID).")
)
CLUSTER BY truck_id, telemetry_timestamp
OPTIONS(
    description="Curated inventory level updates for all consumables on coffee trucks, used for real-time stock management and replenishment planning."
);

INSERT INTO `agentic_beans_curated.telemetry_inventory`
(telemetry_inventory_id, telemetry_load_id, truck_id, telemetry_timestamp, ingredient_id, 
current_quantity_value, unit_of_measure, event_type, associated_transaction_id, source_sensor_id)
SELECT telemetry_inventory_id, 
       telemetry_load_id,
       truck_id,
       telemetry_timestamp,
       ingredient_id,
       current_quantity_value,
       unit_of_measure,
       event_type,
       associated_transaction_id,
       source_sensor_id,
  FROM `agentic_beans_enriched.telemetry_inventory`;


--------------------------------------------------------------------------------
-- ** truck **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.truck`
(
    truck_id                    INT64    OPTIONS(description="The unique identifier and primary key for each truck in the fleet."),
    truck_name                  STRING   OPTIONS(description="A unique, friendly name for the truck (e.g., 'Bean Machine', 'The Daily Grind')."),
    truck_license_plate         STRING   OPTIONS(description="The official license plate number of the truck for legal identification."),
    truck_vin                   STRING   OPTIONS(description="The Vehicle Identification Number, a unique code for each vehicle."),
    truck_acquisition_timestamp TIMESTAMP   OPTIONS(description="The date and time the truck was entered into service."),
)
CLUSTER BY truck_id
OPTIONS(
    description="A table containing detailed information about each individual coffee truck in the Agentic Beans fleet."
);

INSERT INTO `agentic_beans_curated.truck`
(truck_id, truck_name, truck_license_plate, truck_vin, truck_acquisition_timestamp)
SELECT truck_id, 
       truck_name,
       truck_license_plate,
       truck_vin,
       truck_acquisition_timestamp
  FROM `agentic_beans_enriched.truck`;


--------------------------------------------------------------------------------
-- ** truck_menu **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.truck_menu`
(
    truck_menu_id     INT64 OPTIONS(description="The unique identifier and primary key for each entry on a truck's menu."),
    truck_id          INT64 OPTIONS(description="The foreign key referencing the 'truck_id' from the 'truck' table, indicating which truck this menu item belongs to."),
    product_id        INT64 OPTIONS(description="The foreign key referencing the 'product_id' from the 'product' table, identifying the specific coffee offering."),
    size              STRING OPTIONS(description="The size of the product offering (e.g., 'S' for Small, 'M' for Medium, 'L' for Large, 'N/A' for items without a size)."),
    price             NUMERIC(10, 2) OPTIONS(description="The price of the product offering on this specific truck's menu."),
)
CLUSTER BY truck_menu_id
OPTIONS(
    description="A table detailing the menu items available on each individual coffee truck, including specific pricing and availability."
);

INSERT INTO `agentic_beans_curated.truck_menu`
(truck_menu_id, truck_id, product_id, size, price)
SELECT truck_menu_id,
       truck_id, 
       product_id, 
       size, 
       price
  FROM `agentic_beans_enriched.truck_menu`;


--------------------------------------------------------------------------------
-- ** weather **
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `agentic_beans_curated.weather` (
  weather_id STRING OPTIONS(description="A unique identifier for each weather record."),
  weather_location STRING OPTIONS(description="The specific neighborhood or area in Manhattan (e.g., 'Upper East Side', 'Midtown')."),
  latitude FLOAT64 OPTIONS(description="The latitude of the weather observation's assigned neighborhood center."),
  longitude FLOAT64 OPTIONS(description="The longitude of the weather observation's assigned neighborhood center."),
  observation_datetime TIMESTAMP OPTIONS(description="The date and hour of the weather reading (in UTC)."),
  weather_description STRING OPTIONS(description="A human-readable description of the weather (e.g., 'Sunny', 'Rain', 'Snow')."),
  temperature_fahrenheit FLOAT64 OPTIONS(description="Temperature in degrees Fahrenheit."),
  temp_celsius FLOAT64 OPTIONS(description="Temperature in degrees Celsius."),
  feels_like_fahrenheit FLOAT64 OPTIONS(description="The 'feels like' temperature in Fahrenheit, accounting for wind chill or heat index."),
  feels_like_celsius FLOAT64 OPTIONS(description="The 'feels like' temperature in Celsius, accounting for wind chill or heat index."),
  humidity FLOAT64 OPTIONS(description="Relative humidity as a percentage."),
  wind_speed_mph FLOAT64 OPTIONS(description="Wind speed in miles per hour."),
  total_precipitation FLOAT64 OPTIONS(description="Total precipitation in millimeters (mm)"),
  is_day BOOL OPTIONS(description="A flag to indicate whether it is daytime or nighttime in the local timezone (America/New_York)."),
  data_source STRING OPTIONS(description="Indicates whether the data is 'historical' or 'forecasted'.")
)
CLUSTER BY observation_datetime, weather_location
OPTIONS(
  description="A table containing historical and forecasted weather data for various neighborhoods in Manhattan, designed for AI/ML demonstrations."
);

INSERT INTO `agentic_beans_curated.weather`
(weather_id, weather_location, latitude, longitude, observation_datetime, weather_description, 
temperature_fahrenheit, temp_celsius, feels_like_fahrenheit, feels_like_celsius, humidity, 
wind_speed_mph, total_precipitation, is_day, data_source)
SELECT weather_id, 
       weather_location,
       latitude,
       longitude,
       observation_datetime,
       weather_description,
       temperature_fahrenheit,
       temp_celsius,
       feels_like_fahrenheit,
       feels_like_celsius,
       humidity,
       wind_speed_mph,
       total_precipitation,
       is_day,
       data_source
  FROM `agentic_beans_enriched.weather`;

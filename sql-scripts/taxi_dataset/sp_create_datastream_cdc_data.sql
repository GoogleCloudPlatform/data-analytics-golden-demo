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
      - Generates data for datastream CDC demo
  
  Description: 
      - The will query taxi data so that we can match to the data that is created in Postgres
      - This will generate 5 million rows of reviews and payment
      - This will generate 10000 taxi driver records
  
  Clean up / Reset script:
      - Just re-run the whole thing
  */
  
  LOAD DATA OVERWRITE `${project_id}.${bigquery_taxi_dataset}.random_name`
  (
    name STRING
  )
  FROM FILES (
    format = 'CSV',
    skip_leading_rows = 0,
    field_delimiter=',',
    null_marker='',
    uris = ['gs://${raw_bucket_name}/random_names/random_names.csv']);
  
  
  -- This will hold the SQL statements executed by the Cloud SQL Postgres Database
  DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data`;
  CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data`
  (
     sql_statement   STRING,
     table_name      STRING,
     execution_order INT64
  )
  CLUSTER BY execution_order;
  
  
  -- CREATE TABLE IF NOT EXISTS driver (driver_id  SERIAL PRIMARY KEY, driver_name VARCHAR(255), license_number VARCHAR(255), license_plate VARCHAR(255) );
  INSERT INTO `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data` (sql_statement, table_name, execution_order)
  WITH driver_data AS
  (
  SELECT FORMAT("INSERT INTO driver (driver_name,license_number,license_plate) VALUES ('%s','%s','%s');",
         random_name.name,
         CONCAT(CAST(CAST(ROUND(10 + RAND() * (99 - 10)) AS INT) AS STRING),"-",
                CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),"-",
                CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),"-",
                CAST(CAST(ROUND(10 + RAND() * (999 - 10)) AS INT) AS STRING)),
         CONCAT(CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),"-",CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING))) AS sql_statement,
         'driver' AS table_name,
         ROW_NUMBER() OVER (ORDER BY random_name.name) AS execution_order
    FROM `${project_id}.${bigquery_taxi_dataset}.random_name` AS random_name
  )
  SELECT sql_statement, table_name, execution_order
    FROM driver_data;
  
  
  
  -- CREATE TABLE IF NOT EXISTS review (review_id SERIAL PRIMARY KEY, driver_id INTEGER, passenger_id INTEGER, review_date DATE, ride_date DATE, pickup_location_id INTEGER, dropoff_location_id INTEGER, total_amount MONEY, review_rating INTEGER);
  INSERT INTO `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data` (sql_statement, table_name, execution_order)
  WITH TaxiData AS
  (
    SELECT Pickup_DateTime, PULocationID, DOLocationID, Total_Amount, TIMESTAMP_ADD(Pickup_DateTime, INTERVAL CAST(ROUND(RAND() * (14 - 1))  AS INT) DAY) AS review_date,
           ROW_NUMBER() OVER (ORDER BY Pickup_DateTime DESC) AS execution_order
      FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
    ORDER BY Pickup_DateTime DESC
    LIMIT 5000000
  )
  SELECT FORMAT("INSERT INTO review (driver_id,passenger_id,review_date,ride_date,pickup_location_id,dropoff_location_id,total_amount,review_rating) VALUES (%s, %s,'%s','%s',%s, %s, %s, %s);",
         CAST(CAST(ROUND(   1 + RAND() * (10000   - 1))    AS INT) AS STRING),
         CAST(CAST(ROUND(   1 + RAND() * (500000   - 1))    AS INT) AS STRING),
         CONCAT(CAST(EXTRACT(YEAR FROM review_date) AS STRING),'-',CAST(EXTRACT(MONTH FROM review_date) AS STRING),'-',CAST(EXTRACT(DAY FROM review_date) AS STRING)),  --yyyy-mm-dd
         CONCAT(CAST(EXTRACT(YEAR FROM Pickup_DateTime) AS STRING),'-',CAST(EXTRACT(MONTH FROM Pickup_DateTime) AS STRING),'-',CAST(EXTRACT(DAY FROM Pickup_DateTime) AS STRING)),  --yyyy-mm-dd
         CAST(PULocationID AS STRING),
         CAST(DOLocationID AS STRING),
         REPLACE(CAST(Total_Amount AS STRING),',',''), -- 237,116,27.88
         CAST(CAST(ROUND(1 + RAND() * (10 - 1))  AS INT) AS STRING)),
         'review' AS table_name,
         execution_order + 10000
    FROM TaxiData;
  
  
  -- CREATE TABLE IF NOT EXISTS payment (payment_id SERIAL PRIMARY KEY, driver_id INTEGER, ride_date DATE, passenger_id INTEGER, credit_card_number VARCHAR(255), credit_card_expiration_date DATE, credit_card_security_code VARCHAR(255), pickup_location_id INTEGER, dropoff_location_id INTEGER, total_amount MONEY);
  INSERT INTO `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data` (sql_statement, table_name, execution_order)
  WITH TaxiData AS
  (
    SELECT Pickup_DateTime, PULocationID, DOLocationID, Total_Amount, TIMESTAMP_ADD(Pickup_DateTime, INTERVAL CAST(ROUND(RAND() * (14 - 1))  AS INT) DAY) AS review_date,
           CONCAT(CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',  
                  CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',  
                  CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',  
                  CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) AS credit_card_number,
  
           CAST(CONCAT(CAST(CAST(ROUND(2023 + RAND() * (2025 - 2023)) AS INT) AS STRING),'-', 
                       CAST(CAST(ROUND(   1 + RAND() * (12   - 1))    AS INT) AS STRING),'-', 
                       CAST(CAST(ROUND(   1 + RAND() * (28   - 1))    AS INT) AS STRING)) AS DATE) AS credit_card_expiration_date,
           ROW_NUMBER() OVER (ORDER BY Pickup_DateTime DESC) AS execution_order
      FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
    WHERE Payment_Type_Id = 1
    ORDER BY Pickup_DateTime DESC
    LIMIT 5000000
  )
  SELECT FORMAT("INSERT INTO payment (driver_id,ride_date,passenger_id,credit_card_number,credit_card_expiration_date,credit_card_security_code,pickup_location_id,dropoff_location_id,total_amount) VALUES (%s,'%s',%s,'%s','%s','%s', %s, %s, %s);",
         CAST(CAST(ROUND(   1 + RAND() * (10000   - 1))    AS INT) AS STRING),
         CONCAT(CAST(EXTRACT(YEAR FROM Pickup_DateTime) AS STRING),'-',CAST(EXTRACT(MONTH FROM Pickup_DateTime) AS STRING),'-',CAST(EXTRACT(DAY FROM Pickup_DateTime) AS STRING)),  --yyyy-mm-dd
         CAST(CAST(ROUND(   1 + RAND() * (500000   - 1))    AS INT) AS STRING),
         credit_card_number,
         CONCAT(CAST(EXTRACT(YEAR  FROM credit_card_expiration_date) AS STRING),'-',
                CAST(EXTRACT(MONTH FROM credit_card_expiration_date) AS STRING),'-',
                CAST(EXTRACT(DAY   FROM credit_card_expiration_date) AS STRING)),  --yyyy-mm-dd
         CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),
         CAST(PULocationID AS STRING),
         CAST(DOLocationID AS STRING),
         REPLACE(CAST(Total_Amount AS STRING),',','')),
         'payment' AS table_name,
         execution_order + 10000
    FROM TaxiData ;
  
DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.random_name`;

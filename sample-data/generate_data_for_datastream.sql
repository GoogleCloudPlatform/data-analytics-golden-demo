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

-- Used to generate random data for the datastream CDD job
-- We want data that will join to the downloaded taxi data

CREATE OR REPLACE TABLE taxi_dataset.sql
(
   sql  STRING,
   random_guid STRING
);

-- CREATE TABLE IF NOT EXISTS driver (driver_id  SERIAL PRIMARY KEY, driver_name VARCHAR(255), license_number VARCHAR(255), license_plate VARCHAR(255) );

INSERT INTO taxi_dataset.sql (sql, random_guid)
SELECT FORMAT("INSERT INTO driver (driver_name,license_number,license_plate) VALUES ('%s','%s','%s');",
       name_order.name,
       CONCAT(CAST(CAST(ROUND(10 + RAND() * (99 - 10)) AS INT) AS STRING),"-",
              CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),"-",
              CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),"-",
              CAST(CAST(ROUND(10 + RAND() * (999 - 10)) AS INT) AS STRING)),
       CONCAT(CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),"-",CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING))),
       ''
  FROM taxi_dataset.name_order 
 WHERE RowNumber <= 1000;


-- CREATE TABLE IF NOT EXISTS review (driver_id INTEGER, review_id SERIAL PRIMARY KEY, reviewer_name VARCHAR(255), review_date DATE, ride_date DATE, pickup_location_id INTEGER, dropoff_location_id INTEGER, total_amount MONEY, review_rating INTEGER);
INSERT INTO taxi_dataset.sql (sql, random_guid)
WITH TaxiData AS
(
  SELECT Pickup_DateTime, PULocationID, DOLocationID, Total_Amount, TIMESTAMP_ADD(Pickup_DateTime, INTERVAL CAST(ROUND(RAND() * (14 - 1))  AS INT) DAY) AS review_date
    FROM taxi_dataset.taxi_trips
  ORDER BY Pickup_DateTime DESC
  LIMIT 5000
)
, TaxiRowNumber AS
(
  SELECT TaxiData.*, ROW_NUMBER() OVER (ORDER BY Pickup_DateTime DESC) AS RowNumber
  FROM TaxiData
)
SELECT FORMAT("INSERT INTO review (driver_id,reviewer_name,review_date,ride_date,pickup_location_id,dropoff_location_id,total_amount,review_rating) VALUES (%s, '%s','%s','%s',%s, %s, %s, %s);",
       CAST(CAST(ROUND(   1 + RAND() * (1000   - 1))    AS INT) AS STRING),
       name_order.name,
       CONCAT(CAST(EXTRACT(YEAR FROM review_date) AS STRING),'-',CAST(EXTRACT(MONTH FROM review_date) AS STRING),'-',CAST(EXTRACT(DAY FROM review_date) AS STRING)),  --yyyy-mm-dd
       CONCAT(CAST(EXTRACT(YEAR FROM Pickup_DateTime) AS STRING),'-',CAST(EXTRACT(MONTH FROM Pickup_DateTime) AS STRING),'-',CAST(EXTRACT(DAY FROM Pickup_DateTime) AS STRING)),  --yyyy-mm-dd
       CAST(PULocationID AS STRING),
       CAST(DOLocationID AS STRING),
       REPLACE(CAST(Total_Amount AS STRING),',',''), -- 237,116,27.88
       CAST(CAST(ROUND(1 + RAND() * (10 - 1))  AS INT) AS STRING)),
       GENERATE_UUID()
  FROM TaxiRowNumber 
       INNER JOIN taxi_dataset.name_order AS name_order
               ON TaxiRowNumber.RowNumber = name_order.RowNumber;


-- CREATE TABLE IF NOT EXISTS payment (payment_id SERIAL PRIMARY KEY, credit_card_name VARCHAR(255), credit_card_number VARCHAR(255), credit_card_expiration_date DATE, credit_card_security_code VARCHAR(255), pickup_location_id INTEGER, dropoff_location_id INTEGER, total_amount MONEY);
INSERT INTO taxi_dataset.sql (sql, random_guid)
WITH TaxiData AS
(
  SELECT Pickup_DateTime, PULocationID, DOLocationID, Total_Amount, TIMESTAMP_ADD(Pickup_DateTime, INTERVAL CAST(ROUND(RAND() * (14 - 1))  AS INT) DAY) AS review_date
    FROM taxi_dataset.taxi_trips
  WHERE Payment_Type_Id = 1
  ORDER BY Pickup_DateTime DESC
  LIMIT 5000
)
, TaxiRowNumber AS
(
  SELECT TaxiData.*, ROW_NUMBER() OVER (ORDER BY Pickup_DateTime DESC) AS RowNumber, 
    CONCAT(CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',  
           CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',  
           CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',  
           CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) AS credit_card_number,

    CAST(CONCAT(CAST(CAST(ROUND(2023 + RAND() * (2025 - 2023)) AS INT) AS STRING),'-', 
                CAST(CAST(ROUND(   1 + RAND() * (12   - 1))    AS INT) AS STRING),'-', 
                CAST(CAST(ROUND(   1 + RAND() * (28   - 1))    AS INT) AS STRING)) AS DATE) AS credit_card_expiration_date
  FROM TaxiData
)
SELECT FORMAT("INSERT INTO payment (driver_id,credit_card_name,credit_card_number,credit_card_expiration_date,credit_card_security_code,pickup_location_id,dropoff_location_id,total_amount) VALUES (%s,'%s','%s','%s','%s', %s, %s, %s);",
       CAST(CAST(ROUND(   1 + RAND() * (1000   - 1))    AS INT) AS STRING),
       name_order.name,
       credit_card_number,
       CONCAT(CAST(EXTRACT(YEAR  FROM credit_card_expiration_date) AS STRING),'-',
              CAST(EXTRACT(MONTH FROM credit_card_expiration_date) AS STRING),'-',
              CAST(EXTRACT(DAY   FROM credit_card_expiration_date) AS STRING)),  --yyyy-mm-dd
       CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),
       CAST(PULocationID AS STRING),
       CAST(DOLocationID AS STRING),
       REPLACE(CAST(Total_Amount AS STRING),',','')),
       GENERATE_UUID()
  FROM TaxiRowNumber 
       INNER JOIN taxi_dataset.name_order AS name_order
               ON TaxiRowNumber.RowNumber + 200001 = name_order.RowNumber;



EXPORT DATA
  OPTIONS (
    uri = 'gs://raw-data-analytics-demo-hynex4r2xj/generate-data/*.csv',
    format = 'CSV',
    overwrite = true,
    header = false,
    field_delimiter = '|')
AS (
SELECT sql.SQL
  FROM taxi_dataset.sql 
 ORDER BY random_guid
);




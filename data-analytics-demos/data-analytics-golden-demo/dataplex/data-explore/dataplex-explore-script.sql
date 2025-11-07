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

 Prerequisites:
    - Run the Airflow DAG: sample-dataplex-with-hms-deploy
        - This DAG can take 45 minutes to deploy.  Dataproc metastore can take a while.
        - NOTE: Your Dataplex and Dataproc Metastore will be deleted after 48 hours (to save on costs). 
        -       ** This means all your scripts / notebooks will be DELETED!  So save them inside of storage or somewhere safe. **
        -       You will need to re-run the DAG sample-dataplex-with-hms-deploy to deploy again.

    - In the console open your Taxi Data Lake:
        - https://console.cloud.google.com/dataplex/lakes/taxi-data-lake-93b2hjnp0r;location=us-central1/environments?project=data-analytics-demo-93b2hjnp0r&supportedpurview=project
        - Click on the Details tab
            - Make sure your metastore is ready to use (e.g.): Metastore status: Ready as of June 14, 2023 at 10:52:03 AM UTC-4

    - It can then take another 30 minutes for Dataplex to scan and initialize

    - Goto the Explore UI:
        - https://console.cloud.google.com/dataplex/explore/lakes/taxi-data-lake-93b2hjnp0r;location=us-central1/query/workbench?project=data-analytics-demo-93b2hjnp0r&supportedpurview=project
        - Make sure Taxi Data Lake is selected 
            - NOTE: If you do not see any "tables" in the left hand side, then your Metastore might still be initializing
            - NOTE: The Dataproc Metastore is ONLY mounted to the Taxi Data Lake and not the other data lakes.  
                    Each Data Lake requires its own Metastore (at this point in time).

 Use Cases:
    - You can run Spark SQL that can query BigQuery, your Data Lake and create/work with Hive tables

 Description: 
    - This will query the above resources (BigQuery, Data Lake and Hive)
    - You can see the Hive tables in your Data Catalog
    - You can join BigQuery to Data Lake and to Hive!
  
 Clean up / Reset script:
    DROP TABLE taxi_driver;
    DROP TABLE taxi_review;

*/


-- Query BigQuery tables directly
SELECT taxi_trips.TaxiCompany,
       CAST(taxi_trips.Pickup_DateTime AS DATE) AS Pickup_Date,
       payment_type.Payment_Type_Description,
       SUM(Total_Amount) AS Total_Amount
  FROM taxi_curated_zone_${random_extension}.taxi_trips AS taxi_trips
       INNER JOIN taxi_curated_zone_${random_extension}.payment_type AS payment_type
               ON taxi_trips.payment_type_id = payment_type.payment_type_id
              AND TaxiCompany = 'Green' 
              AND PartitionDate = '2022-01-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;


-- Query Data Lake Tables 
-- NOTE: This is a small cluster (1 node) so do not run large Spark SQL unless you create an additional environment.
--       If you create an additional environment, you must MANUALLY delete since the Destroy DAG will not be able to delete Dataplex.
SELECT 'Green' AS TaxiCompany,
       CAST(taxi_trips.Pickup_DateTime AS DATE) AS Pickup_Date,
       payment_type.Payment_Type_Description,
       SUM(Total_Amount) AS Total_Amount
  FROM taxi_curated_zone_${random_extension}.processed_taxi_data_green_trips_table_parquet AS taxi_trips
       INNER JOIN taxi_curated_zone_${random_extension}.processed_taxi_data_payment_type_table AS payment_type
               ON taxi_trips.payment_type_id = payment_type.payment_type_id
              AND pickup_datetime BETWEEN '2022-01-01' AND '2022-02-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;


-- Create a Hive External table
-- You can place the LOCATION on any GCS bucket you like by using the full URI
CREATE EXTERNAL TABLE taxi_driver (taxi_driver_id INT, driver_name STRING, license_number STRING, license_plate STRING)
LOCATION '/hive-warehouse/taxi_driver'
STORED AS PARQUET;

INSERT INTO taxi_driver (taxi_driver_id,driver_name,license_number,license_plate)
VALUES 
  (1, 'Agostino Combi',        '76-662-3795-233','919-528')
, (2, 'Alex Hoareau',          '70-954-6424-635','936-158')
, (3, 'Alexis Chavez',         '79-305-2973-350','417-543')
, (4, 'Allegra Toscanini',     '25-910-1913-490','218-923')
, (5, 'Alphonse Guillou-Hamel','70-101-1542-408','433-526')
, (6, 'Amber Chavez',          '63-430-4210-300','882-730')
, (7, 'Amy Floyd',             '19-133-5461-640','266-833')
, (8, 'Andrew Carey',          '45-654-6851-906','490-496')
, (9, 'André de Pasquier',     '98-881-5026-333','746-621')
, (10,'Annedore Scholl-Klemt', '61-367-1954-677','395-449');

-- Query the table
SELECT *
  FROM taxi_driver;


-- Create a second table to hold reviews (so we can join to BigQuery)
CREATE EXTERNAL TABLE taxi_review (taxi_review_id INT, taxi_driver_id INT, review_date STRING, ride_date STRING, pickup_location_id INT, dropoff_location_id INT ,
                                   total_amount FLOAT, review_rating INT)
LOCATION '/hive-warehouse/taxi_review'
STORED AS PARQUET;

INSERT INTO taxi_review (taxi_review_id,taxi_driver_id,review_date,ride_date,pickup_location_id,dropoff_location_id,total_amount,review_rating) 
VALUES 
  (1,  1,  '2022-11-07','2022-10-31',249, 244, 40.33, 8)
, (2,  2,  '2022-11-11','2022-10-31',162, 230, 8.8,   7)
, (3,  3,  '2022-11-10','2022-10-31',138, 179, 18.55, 2)
, (4,  4,  '2022-11-01','2022-10-31',186, 107, 13.3,  1)
, (5,  5,  '2022-11-09','2022-10-31',70,  17,  37.55, 9)
, (6,  6,  '2022-11-04','2022-10-31',138, 112, 22.05, 2)
, (7,  7,  '2022-11-02','2022-10-31',142, 263, 17.6,  9)
, (8,  8,  '2022-11-10','2022-10-31',264, 264, 14.76, 2)	
, (9,  9,  '2022-11-04','2022-10-31',249, 227, 42.3,  9)
, (10, 10, '2022-11-05','2022-10-31',68,  228, 41.35, 7);

-- Query the table
SELECT *
  FROM taxi_review;


-- Show tables
SHOW TABLES;


-- Open a new page to see Hive tables under Default
-- Show in UI in the "default" folder
-- You can see that PATH too to the files: 
-- Show Hive tables in Data Catalog
-- https://console.cloud.google.com/dataplex/search?project=data-analytics-demo-${random_extension}&supportedpurview=project&q=taxi_review



-- Join BigQuery to Data Lake to Hive
-- Try to fuzzy match some data based upon various fields in the data
WITH Data AS
(
SELECT taxi_driver.driver_name                     AS driver, 
       taxi_review.review_rating                   AS rating,
       payment_type_table.Payment_Type_Description AS payment_type,
       trips.Passenger_Count                       AS passenger_count,
       trips.Tip_Amount                            AS tip,
       trips.Total_Amount                          AS total,
       trips.Pickup_DateTime                       AS pickup_date
  FROM -- BigQuery Table
       taxi_curated_zone_${random_extension}.taxi_trips AS trips
       INNER JOIN taxi_review AS taxi_review      
               ON CAST(taxi_review.ride_date AS DATE)      = CAST(trips.Pickup_DateTime AS DATE)
              AND taxi_review.pickup_location_id           = trips.PULocationID
              AND taxi_review.dropoff_location_id          = trips.DOLocationID
              AND CAST(taxi_review.total_amount AS STRING) = CAST(trips.Total_Amount AS STRING)
              AND trips.PartitionDate = '2022-10-01'
       -- Hive Table
       INNER JOIN taxi_driver AS taxi_driver
               ON taxi_review.taxi_driver_id = taxi_driver.taxi_driver_id
       -- Taxi Data Lake
       INNER JOIN taxi_curated_zone_${random_extension}.processed_taxi_data_payment_type_table AS payment_type_table
               ON payment_type_table.payment_type_id = trips.payment_type_id
)
, RankData AS
(
  SELECT *,
         RANK() OVER (PARTITION BY driver ORDER BY pickup_date) AS Ranking
    FROM Data
)
SELECT driver, rating, payment_type, passenger_count, tip, total
  FROM RankData
 WHERE Ranking = 1;

-- Share script

-- Import the notebook and show the notebook
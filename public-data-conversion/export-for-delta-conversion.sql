-- https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#export_data_statement

EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/location/location_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
SELECT *
  FROM taxi_dataset.location;


EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/payment_type/payment_type_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
SELECT Payment_Type_Id AS payment_type_id, 
       Payment_Type_Description AS payment_type_description
  FROM taxi_dataset.payment_type;


EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/rate_code/rate_code_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
SELECT rate_code_Id AS rate_code_id, 
       rate_code_Description AS rate_code_description
  FROM taxi_dataset.rate_code;


EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/trip_type/trip_type_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
SELECT trip_type_Id AS trip_type_id, 
       trip_type_Description AS trip_type_description
  FROM taxi_dataset.trip_type;


EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/vendor/vendor_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
SELECT vendor_Id AS vendor_id, 
       vendor_Description AS vendor_description
  FROM taxi_dataset.vendor;


EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/driver/driver_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
with data as (
SELECT  
       CAST(name AS STRING) AS driver_name,
       CAST(CONCAT(CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),'-',
              CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),'-',
              CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) AS STRING) AS driver_mobile_number,
       CAST(CONCAT(CAST(CAST(ROUND(10 + RAND() * (99 - 10)) AS INT) AS STRING),'-',
              CAST(CAST(ROUND(100 + RAND() * (999 - 100)) AS INT) AS STRING),'-',
              CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING),'-',
              CAST(CAST(ROUND(1000 + RAND() * (9999 - 1000)) AS INT) AS STRING)) AS STRING) AS driver_license_number,
      CAST(CONCAT(LOWER(REPLACE(name,' ','.')),'@gmail.com') AS STRING) AS driver_email_address,
      CAST(DATE_SUB(CURRENT_DATE(), INTERVAL CAST(ROUND(6570 + RAND() * (24820 - 6570)) AS INT) DAY) AS DATE) AS driver_dob,
      CAST(CAST(ROUND(100000000 + RAND() * (999999999 - 100000000)) AS INT) AS STRING) as driver_ach_routing_number,
      CAST(CAST(ROUND(100000000 + RAND() * (999999999 - 100000000)) AS INT) AS STRING) as driver_ach_account_number
   FROM `taxi_dataset.biglake_random_name`
)
select row_number() over(order by driver_name) as driver_id,
       *
       from data;


EXPORT DATA
  OPTIONS 
  (uri = 'gs://raw-data-analytics-demo-xuyjwabhbk/delta-io-raw/taxi_trips/taxi_trips_*.snappy.parquet', 
  compression = 'snappy',
  format = 'parquet', 
  overwrite = true) 
AS 
with data as (
SELECT CAST(ROUND(1 + RAND() * (10000 - 1)) AS INT) as driver_id,
       PULocationID as pickup_location_id,
       Pickup_DateTime as pickup_datetime,
       DOLocationID as dropoff_location_id,
       Dropoff_DateTime as dropoff_datetime,
       IFNULL(Passenger_Count,0) as passenger_count,
       Trip_Distance as trip_distance,
       Fare_Amount as fare_amount,
       Surcharge as surcharge,
       MTA_Tax as mta_tax,
       Tip_Amount as tip_amount,
       Tolls_Amount as tolls_amount,
       Improvement_Surcharge as improvement_surcharge,
       Total_Amount as total_amount,
  FROM `taxi_dataset.taxi_trips`
  where PartitionDate >= '2022-01-01' -- in (2022,2023,2024)
  )
select row_number() over(order by Pickup_DateTime) as trip_id,
       *
       from data;  




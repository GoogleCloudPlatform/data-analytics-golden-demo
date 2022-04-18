
CREATE OR REPLACE PROCEDURE `{{ params.project_id }}.{{ params.dataset_id }}.sp_demo_data_transfer_service`()
OPTIONS(strict_mode=FALSE)
BEGIN

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
To run this:
  1. Run the Airflow DAG: sample-bigquery-data-transfer-service to create the dest dataset and data transfer service
  2. In the Cloud Console, click on the Data Transfer "Copy Public NYC Taxi Data" and view the transfer (wait until done)
  3. Run the below SQL statements
  4. Optional: When done you can save on storage costs by running: bq rm -r --dataset "{{ params.project_id }}:{{ params.dataset_id }}_public_copy"

Use Cases:
    - Add more rows to the Yellow Taxi data to show scale
    - Use Data Transfer Service to ingest/transfer data to BigQuery
    - Transfer from: Cloud Storage,Google Ad Manager,Google Ads,Google Merchant Center (beta),Google Play,Search Ads 360 (beta), YouTube Channel reports,, YouTube Content Owner reports,Amazon S3, Teradata,Amazon Redshift

Description: 
    - Show Data Transfer Service
    - Ingest hundreds of millions of more records

Reference:
    - https://cloud.google.com/bigquery-transfer/docs/introduction

Clean up / Reset script:
    n/a
*/

-- https://developers.google.com/codelabs/maps-platform/bigquery-maps-api#0

-- 2016 does not have the same fields (no pickup/dropoff ids, just lat/long)
-- 2018 and below does not have the same fields 
ALTER TABLE `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
  ADD COLUMN IF NOT EXISTS PULocationGeo GEOGRAPHY,
  ADD COLUMN IF NOT EXISTS DOLocationGeo GEOGRAPHY,
  ADD COLUMN IF NOT EXISTS distance_between_service FLOAT64,
  ADD COLUMN IF NOT EXISTS time_between_service INTEGER;

----------------------------------------------------------------------
-- GREEN
----------------------------------------------------------------------
INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    Ehail_Fee,
    trip_type,
    PartitionDate
)
SELECT 'Green' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                      AS Store_And_Forward,
       SAFE_CAST(pickup_location_id   AS INTEGER)   AS PULocationID,
       SAFE_CAST(dropoff_location_id  AS INTEGER)   AS DOLocationID,
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       ehail_fee                                    AS Ehail_Fee,
       SAFE_CAST(trip_type            AS INTEGER)   AS Trip_Type,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate
  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_green_trips_2018`;


INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    Ehail_Fee,
    trip_type,
    PartitionDate
)
SELECT 'Green' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                      AS Store_And_Forward,
       SAFE_CAST(pickup_location_id   AS INTEGER)   AS PULocationID,
       SAFE_CAST(dropoff_location_id  AS INTEGER)   AS DOLocationID,
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       ehail_fee                                    AS Ehail_Fee,
       SAFE_CAST(trip_type            AS INTEGER)   AS Trip_Type,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate
  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_green_trips_2017`;


INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    Ehail_Fee,
    trip_type,
    PartitionDate,

    PULocationGeo,
    DOLocationGeo    
)
SELECT 'Green' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                           AS Store_And_Forward,
       NULL                                         AS PULocationID,       -- not in this years data
       NULL                                         AS DOLocationID,       -- not in this years data
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       ehail_fee                                    AS Ehail_Fee,
       SAFE_CAST(trip_type AS INTEGER)              AS Trip_Type,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate,

       -- Latitudes must be in the range [-90, 90]. Latitudes outside this range will result in an error.
       -- Longitudes outside the range [-180, 180] are allowed; ST_GEOGPOINT uses the input longitude modulo 360 to obtain a longitude within [-180, 180].

       CASE WHEN pickup_longitude BETWEEN -180 AND 180
             AND pickup_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(pickup_longitude,pickup_latitude)
             ELSE NULL
        END AS PULocationGeo,

        CASE WHEN dropoff_longitude BETWEEN -180 AND 180
              AND dropoff_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(dropoff_longitude,dropoff_latitude)
             ELSE NULL
        END AS DOLocationGeo

  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_green_trips_2016`;


INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    Ehail_Fee,
    trip_type,
    PartitionDate,

    PULocationGeo,
    DOLocationGeo    
)
SELECT 'Green' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                           AS Store_And_Forward,
       NULL                                         AS PULocationID,       -- not in this years data
       NULL                                         AS DOLocationID,       -- not in this years data
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       ehail_fee                                    AS Ehail_Fee,
       SAFE_CAST(trip_type AS INTEGER)              AS Trip_Type,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate,

       -- Latitudes must be in the range [-90, 90]. Latitudes outside this range will result in an error.
       -- Longitudes outside the range [-180, 180] are allowed; ST_GEOGPOINT uses the input longitude modulo 360 to obtain a longitude within [-180, 180].

       CASE WHEN pickup_longitude BETWEEN -180 AND 180
             AND pickup_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(pickup_longitude,pickup_latitude)
             ELSE NULL
        END AS PULocationGeo,

        CASE WHEN dropoff_longitude BETWEEN -180 AND 180
              AND dropoff_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(dropoff_longitude,dropoff_latitude)
             ELSE NULL
        END AS DOLocationGeo

  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_green_trips_2015`;


INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    Ehail_Fee,
    trip_type,
    PartitionDate,

    PULocationGeo,
    DOLocationGeo    
)
SELECT 'Green' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                           AS Store_And_Forward,
       NULL                                         AS PULocationID,       -- not in this years data
       NULL                                         AS DOLocationID,       -- not in this years data
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       ehail_fee                                    AS Ehail_Fee,
       SAFE_CAST(trip_type AS INTEGER)              AS Trip_Type,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate,

       -- Latitudes must be in the range [-90, 90]. Latitudes outside this range will result in an error.
       -- Longitudes outside the range [-180, 180] are allowed; ST_GEOGPOINT uses the input longitude modulo 360 to obtain a longitude within [-180, 180].

       CASE WHEN pickup_longitude BETWEEN -180 AND 180
             AND pickup_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(pickup_longitude,pickup_latitude)
             ELSE NULL
        END AS PULocationGeo,

        CASE WHEN dropoff_longitude BETWEEN -180 AND 180
              AND dropoff_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(dropoff_longitude,dropoff_latitude)
             ELSE NULL
        END AS DOLocationGeo

  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_green_trips_2014`;



----------------------------------------------------------------------
-- YELLOW
----------------------------------------------------------------------
INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    PartitionDate
)
SELECT 'Yellow' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                      AS Store_And_Forward,
       SAFE_CAST(pickup_location_id   AS INTEGER)   AS PULocationID,
       SAFE_CAST(dropoff_location_id  AS INTEGER)   AS DOLocationID,
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate
  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_yellow_trips_2018`;


INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    PartitionDate
)
SELECT 'Yellow' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                           AS Store_And_Forward,
       SAFE_CAST(pickup_location_id   AS INTEGER)   AS PULocationID,
       SAFE_CAST(dropoff_location_id  AS INTEGER)   AS DOLocationID,
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate
  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_yellow_trips_2017`;



INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    PartitionDate,

    PULocationGeo,
    DOLocationGeo
)
SELECT 'Yellow' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                           AS Store_And_Forward,
       NULL                                         AS PULocationID,       -- not in this years data
       NULL                                         AS DOLocationID,       -- not in this years data
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate,

       -- Latitudes must be in the range [-90, 90]. Latitudes outside this range will result in an error.
       -- Longitudes outside the range [-180, 180] are allowed; ST_GEOGPOINT uses the input longitude modulo 360 to obtain a longitude within [-180, 180].

       CASE WHEN pickup_longitude BETWEEN -180 AND 180
             AND pickup_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(pickup_longitude,pickup_latitude)
             ELSE NULL
        END AS PULocationGeo,

        CASE WHEN dropoff_longitude BETWEEN -180 AND 180
              AND dropoff_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(dropoff_longitude,dropoff_latitude)
             ELSE NULL
        END AS DOLocationGeo
  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_yellow_trips_2016`;


INSERT INTO `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips`
(
    TaxiCompany,
    Vendor_Id,
    Pickup_DateTime,
    Dropoff_DateTime,
    Passenger_Count,
    Trip_Distance,
    Rate_Code_Id,
    Store_And_Forward,
    PULocationID,
    DOLocationID,
    Payment_Type_Id,
    Fare_Amount,
    Surcharge,
    MTA_Tax,
    Tip_Amount,
    Tolls_Amount,
    Improvement_Surcharge,
    Total_Amount,
    Congestion_Surcharge,
    PartitionDate,

    PULocationGeo,
    DOLocationGeo
)
SELECT 'Yellow' AS TaxiCompany,
       SAFE_CAST(vendor_id            AS INTEGER)   AS Vendor_Id,
       SAFE_CAST(pickup_datetime      AS TIMESTAMP) AS Pickup_DateTime,
       SAFE_CAST(dropoff_datetime     AS TIMESTAMP) AS Dropoff_DateTime,
       passenger_count                              AS Passenger_Count,
       trip_distance                                AS Trip_Distance,
       SAFE_CAST(rate_code            AS INTEGER)   AS Rate_Code_Id,
       store_and_fwd_flag                           AS Store_And_Forward,
       NULL                                         AS PULocationID,       -- not in this years data
       NULL                                         AS DOLocationID,       -- not in this years data
       SAFE_CAST(payment_type         AS INTEGER)   AS Payment_Type_Id,
       fare_amount                                  AS Fare_Amount,
       extra                                        AS Surcharge,
       mta_tax                                      AS MTA_Tax,
       tip_amount                                   AS Tip_Amount,
       tolls_amount                                 AS Tolls_Amount,
       imp_surcharge                                AS Improvement_Surcharge,
       total_amount                                 AS Total_Amount,
       NULL                                         AS Congestion_Surcharge,
       DATE(EXTRACT(YEAR FROM pickup_datetime), EXTRACT(MONTH FROM pickup_datetime), 1)  AS PartitionDate,

       -- Latitudes must be in the range [-90, 90]. Latitudes outside this range will result in an error.
       -- Longitudes outside the range [-180, 180] are allowed; ST_GEOGPOINT uses the input longitude modulo 360 to obtain a longitude within [-180, 180].

       CASE WHEN pickup_longitude BETWEEN -180 AND 180
             AND pickup_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(pickup_longitude,pickup_latitude)
             ELSE NULL
        END AS PULocationGeo,

        CASE WHEN dropoff_longitude BETWEEN -180 AND 180
              AND dropoff_latitude  BETWEEN -90  AND 90 
             THEN ST_GeogPoint(dropoff_longitude,dropoff_latitude)
             ELSE NULL
        END AS DOLocationGeo
  FROM `{{ params.project_id }}.{{ params.dataset_id }}_public_copy.tlc_yellow_trips_2015`;


-- Show scale over 627,xxx,xxx records
-- Query: Count the number of records
SELECT COUNT(*) AS Cnt
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` AS taxi_trips;


-- Show the total amount per day of week (pivot) over 2015 to 2021 data
WITH WeekdayData AS
(
SELECT FORMAT_DATE("%B", Pickup_DateTime) AS MonthName,
       FORMAT_DATE("%m", Pickup_DateTime) AS MonthNumber,
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       SUM(taxi_trips.Total_Amount) AS Total_Amount
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` AS taxi_trips
 WHERE taxi_trips.Pickup_DateTime BETWEEN '2015-01-01' AND '2021-12-31'   
   AND Payment_Type_Id IN (1,2,3,4)
 GROUP BY 1, 2, 3
)
SELECT MonthName,
       FORMAT("%'d", SAFE_CAST(Sunday    AS INTEGER)) AS Sunday,
       FORMAT("%'d", SAFE_CAST(Monday    AS INTEGER)) AS Monday,
       FORMAT("%'d", SAFE_CAST(Tuesday   AS INTEGER)) AS Tuesday,
       FORMAT("%'d", SAFE_CAST(Wednesday AS INTEGER)) AS Wednesday,
       FORMAT("%'d", SAFE_CAST(Thursday  AS INTEGER)) AS Thursday,
       FORMAT("%'d", SAFE_CAST(Friday    AS INTEGER)) AS Friday,
       FORMAT("%'d", SAFE_CAST(Saturday  AS INTEGER)) AS Saturday,
  FROM WeekdayData
 PIVOT(SUM(Total_Amount) FOR WeekdayName IN ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'))
ORDER BY MonthNumber;



-- Show the total amount per day of week (pivot) over 2015 to 2021 data By YEAR
WITH WeekdayData AS
(
SELECT CONCAT(FORMAT_DATE("%B", Pickup_DateTime),'-',EXTRACT(YEAR FROM Pickup_DateTime)) AS MonthName,
       FORMAT_DATE("%m", Pickup_DateTime) AS MonthNumber,
       EXTRACT(YEAR FROM Pickup_DateTime) AS YearNbr,
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       SUM(taxi_trips.Total_Amount) AS Total_Amount
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` AS taxi_trips
 WHERE taxi_trips.Pickup_DateTime BETWEEN '2015-01-01' AND '2021-12-31'
   AND Payment_Type_Id IN (1,2,3,4)
 GROUP BY 1, 2, 3, 4
)
SELECT MonthName,
       FORMAT("%'d", SAFE_CAST(Sunday    AS INTEGER)) AS Sunday,
       FORMAT("%'d", SAFE_CAST(Monday    AS INTEGER)) AS Monday,
       FORMAT("%'d", SAFE_CAST(Tuesday   AS INTEGER)) AS Tuesday,
       FORMAT("%'d", SAFE_CAST(Wednesday AS INTEGER)) AS Wednesday,
       FORMAT("%'d", SAFE_CAST(Thursday  AS INTEGER)) AS Thursday,
       FORMAT("%'d", SAFE_CAST(Friday    AS INTEGER)) AS Friday,
       FORMAT("%'d", SAFE_CAST(Saturday  AS INTEGER)) AS Saturday,
  FROM WeekdayData
 PIVOT(SUM(Total_Amount) FOR WeekdayName IN ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'))
ORDER BY YearNbr DESC, MonthNumber;


END
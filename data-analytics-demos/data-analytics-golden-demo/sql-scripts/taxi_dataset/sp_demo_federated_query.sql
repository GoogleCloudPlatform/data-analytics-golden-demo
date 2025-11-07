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
    - Need to query data in CloudSQL (Postgres, SQL Server, MySQL) or Spanner, you can from BigQuery
    -
    
Description: 
    - 

Reference:
    - 

Clean up / Reset script:
    n/a       
*/

-- Query data directly in Spanner
-- Station Id USW00094728 = NEW YORK CNTRL PK TWR   (SELECT * FROM `bigquery-public-data.ghcn_d.ghcnd_stations` WHERE id = 'USW00094728';)
-- NOTE: You need to run the Airflow DAG "sample-bigquery-start-spanner" before running this SQL
--       You also need to wait for the Dataflow job "importspannerweatherdata" to complete (or else you will not see any data)
--       Spanner will automatically be DELETED after 4 hours.  Create a calendar reminder to run this DAG before your demo.
EXECUTE IMMEDIATE """
SELECT *
  FROM EXTERNAL_QUERY(
      'projects/${project_id}/locations/${spanner_region}/connections/bq_spanner_connection',
      "SELECT *  FROM weather WHERE station_id='USW00094728'");
""";


-- Federated Queries that join data to BigQuery require resources to be in the same region
-- Create a dataset and sample data in the same region in which Spanner is deployed
CREATE SCHEMA ${bigquery_taxi_dataset}_spanner
OPTIONS(
  location="${spanner_region}"
  );


-- Seed a BigQuery table with data
CREATE OR REPLACE TABLE `${project_id}`.${bigquery_taxi_dataset}_spanner.taxi_averages AS
    SELECT CAST('2020-01-05' AS DATE) AS PickupDate, 'Sunday'    AS WeekdayName, 0 AS WeekdayNumber, 177136 AS NumberOfTrips, 3.345020493 AS AvgDistance, 13.44308379 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-04' AS DATE) AS PickupDate, 'Saturday'  AS WeekdayName, 6 AS WeekdayNumber, 197060 AS NumberOfTrips, 3.001948239 AS AvgDistance, 12.57408292 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-06' AS DATE) AS PickupDate, 'Monday'    AS WeekdayName, 1 AS WeekdayNumber, 195843 AS NumberOfTrips, 3.150297790 AS AvgDistance, 13.42400520 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-02' AS DATE) AS PickupDate, 'Thursday'  AS WeekdayName, 4 AS WeekdayNumber, 177191 AS NumberOfTrips, 3.347735946 AS AvgDistance, 13.85145685 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-01' AS DATE) AS PickupDate, 'Wednesday' AS WeekdayName, 3 AS WeekdayNumber, 180439 AS NumberOfTrips, 3.517630446 AS AvgDistance, 14.04735933 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-03' AS DATE) AS PickupDate, 'Friday'    AS WeekdayName, 5 AS WeekdayNumber, 199545 AS NumberOfTrips, 3.042911925 AS AvgDistance, 12.95975163 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-07' AS DATE) AS PickupDate, 'Tuesday'   AS WeekdayName, 2 AS WeekdayNumber, 218548 AS NumberOfTrips, 2.955926799 AS AvgDistance, 12.88856677 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-11' AS DATE) AS PickupDate, 'Saturday'  AS WeekdayName, 6 AS WeekdayNumber, 232678 AS NumberOfTrips, 2.871209483 AS AvgDistance, 12.57551036 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-23' AS DATE) AS PickupDate, 'Thursday'  AS WeekdayName, 4 AS WeekdayNumber, 246865 AS NumberOfTrips, 2.863291394 AS AvgDistance, 12.90945193 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-22' AS DATE) AS PickupDate, 'Wednesday' AS WeekdayName, 3 AS WeekdayNumber, 236450 AS NumberOfTrips, 2.784504208 AS AvgDistance, 12.68837720 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-09' AS DATE) AS PickupDate, 'Thursday'  AS WeekdayName, 4 AS WeekdayNumber, 250181 AS NumberOfTrips, 2.888248308 AS AvgDistance, 13.01847938 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-17' AS DATE) AS PickupDate, 'Friday'    AS WeekdayName, 5 AS WeekdayNumber, 259705 AS NumberOfTrips, 2.832833908 AS AvgDistance, 12.76231355 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-14' AS DATE) AS PickupDate, 'Tuesday'   AS WeekdayName, 2 AS WeekdayNumber, 317130 AS NumberOfTrips, 2.830828439 AS AvgDistance, 12.81617005 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-16' AS DATE) AS PickupDate, 'Thursday'  AS WeekdayName, 4 AS WeekdayNumber, 254881 AS NumberOfTrips, 2.824201490 AS AvgDistance, 12.82655835 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-29' AS DATE) AS PickupDate, 'Wednesday' AS WeekdayName, 3 AS WeekdayNumber, 241997 AS NumberOfTrips, 2.772662884 AS AvgDistance, 12.71310925 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-24' AS DATE) AS PickupDate, 'Friday'    AS WeekdayName, 5 AS WeekdayNumber, 248452 AS NumberOfTrips, 2.837416845 AS AvgDistance, 12.82717004 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-19' AS DATE) AS PickupDate, 'Sunday'    AS WeekdayName, 0 AS WeekdayNumber, 187029 AS NumberOfTrips, 3.027041635 AS AvgDistance, 12.55000011 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-27' AS DATE) AS PickupDate, 'Monday'    AS WeekdayName, 1 AS WeekdayNumber, 203245 AS NumberOfTrips, 3.000888681 AS AvgDistance, 13.00633393 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-12' AS DATE) AS PickupDate, 'Sunday'    AS WeekdayName, 0 AS WeekdayNumber, 200190 AS NumberOfTrips, 3.231275089 AS AvgDistance, 13.34709351 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-26' AS DATE) AS PickupDate, 'Sunday'    AS WeekdayName, 0 AS WeekdayNumber, 199961 AS NumberOfTrips, 3.121571156 AS AvgDistance, 13.02878826 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-10' AS DATE) AS PickupDate, 'Friday'    AS WeekdayName, 5 AS WeekdayNumber, 246516 AS NumberOfTrips, 2.949418821 AS AvgDistance, 13.20513281 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-13' AS DATE) AS PickupDate, 'Monday'    AS WeekdayName, 1 AS WeekdayNumber, 223498 AS NumberOfTrips, 2.976766190 AS AvgDistance, 13.20867829 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-30' AS DATE) AS PickupDate, 'Thursday'  AS WeekdayName, 4 AS WeekdayNumber, 257929 AS NumberOfTrips, 2.839820920 AS AvgDistance, 12.93011922 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-28' AS DATE) AS PickupDate, 'Tuesday'   AS WeekdayName, 2 AS WeekdayNumber, 230215 AS NumberOfTrips, 3.691287970 AS AvgDistance, 12.50978646 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-20' AS DATE) AS PickupDate, 'Monday'    AS WeekdayName, 1 AS WeekdayNumber, 171643 AS NumberOfTrips, 3.236503091 AS AvgDistance, 13.16145208 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-15' AS DATE) AS PickupDate, 'Wednesday' AS WeekdayName, 3 AS WeekdayNumber, 231658 AS NumberOfTrips, 2.872086697 AS AvgDistance, 12.92222772 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-18' AS DATE) AS PickupDate, 'Saturday'  AS WeekdayName, 6 AS WeekdayNumber, 201245 AS NumberOfTrips, 2.708089940 AS AvgDistance, 11.95403324 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-08' AS DATE) AS PickupDate, 'Wednesday' AS WeekdayName, 3 AS WeekdayNumber, 234692 AS NumberOfTrips, 2.885778126 AS AvgDistance, 12.74203607 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-25' AS DATE) AS PickupDate, 'Saturday'  AS WeekdayName, 6 AS WeekdayNumber, 236541 AS NumberOfTrips, 2.605902613 AS AvgDistance, 11.75244702 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-21' AS DATE) AS PickupDate, 'Tuesday'   AS WeekdayName, 2 AS WeekdayNumber, 228019 AS NumberOfTrips, 2.859358387 AS AvgDistance, 12.88700257 AS AvgFareAmount
    UNION ALL
    SELECT CAST('2020-01-31' AS DATE) AS PickupDate, 'Friday'    AS WeekdayName, 5 AS WeekdayNumber, 251978 AS NumberOfTrips, 2.849273786 AS AvgDistance, 13.00445670 AS AvgFareAmount
;


-- Run the Federated query between Spanner and BigQuery
EXECUTE IMMEDIATE """
WITH WeatherData AS
(SELECT station_id,
        station_date,
        snow_mm_amt,
        precipitation_tenth_mm_amt,
        min_celsius_temp,
        max_celsius_temp
  FROM EXTERNAL_QUERY(
      'projects/${project_id}/locations/${spanner_region}/connections/bq_spanner_connection',
      "SELECT *  FROM weather WHERE station_id='USW00094728' AND station_date BETWEEN '2020-01-01' AND '2020-01-31'")
)
, TaxiData AS
(
SELECT PickupDate,
       WeekdayName,
       WeekdayNumber,
       NumberOfTrips,
       AvgDistance,
       AvgFareAmount
  FROM `${project_id}.${bigquery_taxi_dataset}_spanner.taxi_averages` AS taxi_averages
 )
 SELECT TaxiData.*,
        WeatherData.*
   FROM TaxiData 
        INNER JOIN WeatherData 
                ON TaxiData.PickupDate = WeatherData.station_date
ORDER BY TaxiData.WeekdayNumber;
""";
CREATE OR REPLACE PROCEDURE `{{ params.project_id }}.{{ params.dataset_id }}.sp_demo_federated_query`()
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
-- NOTE: You need to run the Airflow DAG "sample-bigquery-export-spanner-import" before running this SQL
--       You also need to wait for the Dataflow job "importspannerweatherdata" to complete (or else you will not see any data)
EXECUTE IMMEDIATE """
SELECT *
  FROM EXTERNAL_QUERY(
      'projects/{{ params.project_id }}/locations/{{ params.region }}/connections/bq_spanner_connection',
      "SELECT *  FROM weather WHERE station_id='USW00094728'");
""";

-- Query data in Spanner and JOIN to BigQuery Data
-- Does weather affect taxi cab rides and fares?
EXECUTE IMMEDIATE """
WITH WeatherData AS
(SELECT station_id,
        station_date,
        snow_mm_amt,
        precipitation_tenth_mm_amt,
        min_celsius_temp,
        max_celsius_temp
  FROM EXTERNAL_QUERY(
      'projects/{{ params.project_id }}/locations/{{ params.region }}/connections/bq_spanner_connection',
      "SELECT *  FROM weather WHERE station_id='USW00094728' AND station_date BETWEEN '2020-01-01' AND '2020-01-31'")
)
, TaxiData AS
(
SELECT CAST(Pickup_DateTime AS DATE) AS PickupDate,
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       FORMAT_DATE("%w", Pickup_DateTime) AS WeekdayNumber,
       COUNT(1)           AS NumberOfTrips,
       AVG(Trip_Distance) AS AvgDistance,
       AVG(Fare_Amount)   AS AvgFareAmount
  FROM `{{ params.project_id }}.{{ params.dataset_id }}.taxi_trips` AS taxi_trips
  WHERE PartitionDate BETWEEN '2020-01-01' AND '2020-01-31'
  GROUP BY 1,2,3
 )
 SELECT TaxiData.*,
        WeatherData.*
   FROM TaxiData 
        INNER JOIN WeatherData 
                ON TaxiData.PickupDate = WeatherData.station_date
ORDER BY TaxiData.WeekdayNumber;
""";   


END
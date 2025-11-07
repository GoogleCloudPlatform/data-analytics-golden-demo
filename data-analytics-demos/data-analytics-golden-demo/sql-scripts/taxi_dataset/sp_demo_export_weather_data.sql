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
NOTE: This does NOT work as a Stored Procedure.  You can copy the queries to a window and run by setting your Query to run in region US.

Use Cases:
    - Shows how to export data from BigQuery to Google Cloud Storage
    - Exports can be used to send data to other systems
    - Exports can be used for customer downloads
    
Description: 
    - Weather data from a public dataset will be exports to a CSV file
    - The data will then be ingested into Spanner database

Reference:
    - https://cloud.google.com/bigquery/docs/exporting-data
    - https://cloud.google.com/blog/products/gcp/global-historical-daily-weather-data-now-available-in-bigquery

Clean up / Reset script:
    n/a
*/

/*
https://docs.opendata.aws/noaa-ghcn-pds/readme.html
PRCP = Precipitation (tenths of mm)
SNOW = Snowfall (mm)
SNWD = Snow depth (mm)
TMAX = Maximum temperature (tenths of degrees C)
TMIN = Minimum temperature (tenths of degrees C)

SELECT * FROM `bigquery-public-data.ghcn_d.ghcnd_stations`  WHERE state = 'NY' and name like '%NEW YORK%';
SELECT * FROM `bigquery-public-data.ghcn_d.ghcnd_stations`  WHERE id = 'USW00094728';
*/
EXPORT DATA
OPTIONS(
  uri='gs://${bucket_name}/spanner/weather/*.csv',
  format='CSV',
  overwrite=true,
  header=true,
  field_delimiter=',')
AS 
WITH JustRainSnowMinMaxTempData AS
(
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2022`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2021`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2020`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2019`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2018`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2017`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2016`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
 UNION ALL
   SELECT id, date, element, MAX(value) AS value
      FROM `bigquery-public-data.ghcn_d.ghcnd_2015`
     WHERE id = 'USW00094728' -- NEW YORK CNTRL PK TWR
       AND element IN ('SNOW','PRCP','TMIN','TMAX') 
  GROUP BY id, date, element
)
SELECT id   AS station_id,
       date AS station_date,
       SNOW AS snow_mm_amt,
       PRCP AS precipitation_tenth_mm_amt,
       TMIN AS min_celsius_temp,
       TMAX AS max_celsius_temp,
  FROM JustRainSnowMinMaxTempData
PIVOT(MAX(value) FOR element IN ('SNOW','PRCP','TMIN','TMAX'))
ORDER BY date;


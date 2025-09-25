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


EXPORT DATA
OPTIONS (
    uri = 'gs://${data_analytics_agent_bucket}/data-export/weather/weather_*.avro' ,
    format = 'AVRO',
    overwrite = true,
    use_avro_logical_types = true
    ) AS
WITH
-- Step 1: Get the polygon boundaries and center point for all Manhattan neighborhoods
ManhattanNeighborhoods AS (
SELECT
    zone_name,
    zone_geom,
    ST_CENTROID(zone_geom) AS neighborhood_centroid
FROM
    `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom`
WHERE
    borough = 'Manhattan' ),
-- Step 2: Get all hourly GFS forecast data in a wide box around Manhattan
RawForecastData AS (
SELECT
    gfs.geography AS grid_geography,
    f.*
FROM
    `bigquery-public-data.noaa_global_forecast_system.NOAA_GFS0P25` AS gfs,
    UNNEST(gfs.forecast) AS f
WHERE
    gfs.creation_time >= '2020-01-01'   
    AND ST_DWITHIN(gfs.geography, ST_GEOGFROMTEXT('POINT(-73.935242 40.730610)'), 100000) -- 100km box around NYC
    AND f.time > CAST('2020-01-01' AS DATE)
    AND f.hours BETWEEN 0 AND 23 
    AND f.time < CURRENT_DATETIME() -- UTC (there is future data in the table)
    ),
-- Step 3: For each neighborhood and each hour, find the SINGLE closest weather grid point
NearestWeatherData AS (
SELECT
    n.zone_name,
    n.neighborhood_centroid,
    r.*
FROM
    ManhattanNeighborhoods AS n
CROSS JOIN
    RawForecastData AS r
    -- This QUALIFY statement is the key: it keeps only the single closest point for each neighborhood at each time.
QUALIFY
    RANK() OVER(PARTITION BY n.zone_name, r.time ORDER BY ST_DISTANCE(n.zone_geom, r.grid_geography)) = 1 ),
AllHours AS (
SELECT
    zone_name,
    neighborhood_centroid,
    time,
    temperature_2m_above_ground,
    relative_humidity_2m_above_ground,
    total_precipitation_surface,
    u_component_of_wind_10m_above_ground,
    total_cloud_cover_entire_atmosphere,
    v_component_of_wind_10m_above_ground,
    ROW_NUMBER() OVER (PARTITION BY zone_name, time ORDER BY hours) AS ranking
FROM
    NearestWeatherData ),
-- Step 4: Perform conversions to make the final select statement cleaner
ConvertedData AS (
SELECT
    w.zone_name,
    w.neighborhood_centroid,
    w.time AS observation_datetime,
    w.temperature_2m_above_ground AS temp_celsius,
    w.temperature_2m_above_ground * 9/5 + 32 AS temperature_fahrenheit,
    w.relative_humidity_2m_above_ground AS humidity_pct,
    w.total_precipitation_surface AS precip_kg_m2,
    SQRT(POW(w.u_component_of_wind_10m_above_ground, 2) + POW(w.v_component_of_wind_10m_above_ground, 2)) * 2.23694 AS wind_speed_mph,
    w.total_cloud_cover_entire_atmosphere AS cloud_cover_pct,
    w.total_precipitation_surface
FROM
    AllHours w
WHERE
    w.Ranking = 1 )
-- Step 5: Final selection and calculation
SELECT
GENERATE_UUID() AS weather_id,
c.zone_name AS weather_location,
ST_Y(c.neighborhood_centroid) AS latitude,
ST_X(c.neighborhood_centroid) AS longitude,
CAST(c.observation_datetime AS TIMESTAMP) AS observation_datetime,
CASE
    WHEN COALESCE(c.precip_kg_m2, 0) > 0 AND c.temp_celsius <= 0 THEN 'Snow'
    WHEN COALESCE(c.precip_kg_m2, 0) > 0.5 THEN 'Heavy Rain'
    WHEN COALESCE(c.precip_kg_m2, 0) > 0 THEN 'Rain'
    WHEN c.cloud_cover_pct > 80 THEN 'Overcast'
    WHEN c.cloud_cover_pct > 50 THEN 'Cloudy'
    WHEN c.wind_speed_mph > 25 THEN 'Windy'
    ELSE 'Clear'
END
AS weather_description,
c.temperature_fahrenheit,
c.temp_celsius,
CASE
    WHEN c.temperature_fahrenheit < 50 AND c.wind_speed_mph > 3 
    THEN 35.74 + (0.6215 * c.temperature_fahrenheit) - (35.75 * POW(c.wind_speed_mph, 0.16)) + (0.4275 * c.temperature_fahrenheit * POW(c.wind_speed_mph, 0.16))
    WHEN c.temperature_fahrenheit > 80
    AND c.humidity_pct > 40 THEN -42.379 + 2.04901523*c.temperature_fahrenheit + 10.14333127*c.humidity_pct - .22475541*c.temperature_fahrenheit*c.humidity_pct - 
        .00683783*POW(c.temperature_fahrenheit,2) - .05481717*POW(c.humidity_pct,2) + .00122874*POW(c.temperature_fahrenheit,2)*c.humidity_pct + 
        .00085282*c.temperature_fahrenheit*POW(c.humidity_pct,2) - .00000199*POW(c.temperature_fahrenheit,2)*POW(c.humidity_pct,2)
    ELSE c.temperature_fahrenheit
END
AS feels_like_fahrenheit,
((CASE
        WHEN c.temperature_fahrenheit < 50 AND c.wind_speed_mph > 3 THEN 35.74 + (0.6215 * c.temperature_fahrenheit) - 
            (35.75 * POW(c.wind_speed_mph, 0.16)) + (0.4275 * c.temperature_fahrenheit * POW(c.wind_speed_mph, 0.16))
        WHEN c.temperature_fahrenheit > 80
        AND c.humidity_pct > 40 THEN -42.379 + 2.04901523*c.temperature_fahrenheit + 10.14333127*c.humidity_pct - .22475541*c.temperature_fahrenheit*c.humidity_pct - 
            .00683783*POW(c.temperature_fahrenheit,2) - .05481717*POW(c.humidity_pct,2) + .00122874*POW(c.temperature_fahrenheit,2)*c.humidity_pct + 
            .00085282*c.temperature_fahrenheit*POW(c.humidity_pct,2) - .00000199*POW(c.temperature_fahrenheit,2)*POW(c.humidity_pct,2)
        ELSE c.temperature_fahrenheit
    END) - 32) * 5/9 AS feels_like_celsius,
c.humidity_pct AS humidity,
IFNULL(c.total_precipitation_surface,0) AS total_precipitation,
c.wind_speed_mph,
EXTRACT(HOUR FROM c.observation_datetime) BETWEEN 7 AND 19 AS is_day,
'historical_gfs' AS data_source
FROM
ConvertedData c;
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

-- NOTE: You need to run the populate weather in the raw "us" dataset first so that the storage account get populated.

-- LOAD the new data
LOAD DATA OVERWRITE `${bigquery_agentic_beans_raw_dataset}.weather_load`
FROM FILES ( format = 'AVRO', enable_logical_types = true, uris = ['gs://${data_analytics_agent_bucket}/data-export/weather/weather_*.avro']);

-- We have new weather_id UUIDs and we do not want to change these
INSERT INTO `${bigquery_agentic_beans_raw_dataset}.weather`
(weather_id, weather_location, latitude, longitude, observation_datetime, weather_description, 
temperature_fahrenheit, temp_celsius, feels_like_fahrenheit, feels_like_celsius, humidity, 
wind_speed_mph, total_precipitation, is_day, data_source)
SELECT weather_id, weather_location, latitude, longitude, observation_datetime, weather_description, 
       temperature_fahrenheit, temp_celsius, feels_like_fahrenheit, feels_like_celsius, humidity, 
       wind_speed_mph, total_precipitation, is_day, data_source
  FROM `${bigquery_agentic_beans_raw_dataset}.weather_load`
 WHERE observation_datetime > (SELECT MAX(observation_datetime)
                                 FROM `${bigquery_agentic_beans_raw_dataset}.weather`);

-- Drop the load table
DROP TABLE `${bigquery_agentic_beans_raw_dataset}.weather_load`;
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

/*
Author: Adam Paternostro 

Use Cases:
    - Initializes the system (you can re-run this)

Description: 
    - Loads all tables from the public storage account
    - Uses AVRO so we can bring in JSON and GEO types

References:
    - 

Clean up / Reset script:
    -  n/a

*/



------------------------------------------------------------------------------
-- Table: location
------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `nyc_taxi_curated.location` (
    location_id INT64 OPTIONS(description='The unique identifier for the location.'),
    borough STRING OPTIONS(description='The borough in New York City where the location is situated.'),
    zone STRING OPTIONS(description='The specific zone within the borough.'),
    service_zone STRING OPTIONS(description='Categorization of the zone based on the service provided.'),
    latitude FLOAT64 OPTIONS(description='The latitude coordinate of the location.'),
    longitude FLOAT64 OPTIONS(description='The longitude coordinate of the location.')
)
OPTIONS (
    description = 'This table contains location information for taxi zones in New York City, including borough, zone, service zone, and coordinates. This data can be used to map and analyze taxi activity within different areas of the city.'
    -- Example for other attributes (labels):
    -- , labels = [('environment', 'production'), ('data_domain', 'transportation')]
);

-- Load data into location table (to be executed later)
LOAD DATA INTO `nyc_taxi_curated.location`
(
    location_id INT64,
    borough STRING,
    zone STRING,
    service_zone STRING,
    latitude FLOAT64,
    longitude FLOAT64
)
FROM FILES (format = 'PARQUET', uris = ['gs://data-analytics-golden-demo/processed-bucket-v2/processed/taxi-data/location_table/*.parquet']);


------------------------------------------------------------------------------
-- Table: payment_type
------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `nyc_taxi_curated.payment_type` (
    Payment_Type_Id INT64 OPTIONS(description='Unique identifier for the payment type used for a taxi ride.'),
    Payment_Type_Description STRING OPTIONS(description='Description of the payment type used (e.g., credit card, cash).')
)
OPTIONS (
    description = 'This table contains descriptions of payment types used for taxi rides within New York City.'
    -- Example for other attributes (labels):
    -- , labels = [('environment', 'production'), ('data_domain', 'payments')]
);

-- Load data into payment_type table (to be executed later)
LOAD DATA INTO `nyc_taxi_curated.payment_type`
(
    Payment_Type_Id INT64,
    Payment_Type_Description STRING
)
FROM FILES (format = 'PARQUET', uris = ['gs://data-analytics-golden-demo/processed-bucket-v2/processed/taxi-data/payment_type_table/*.parquet']);


------------------------------------------------------------------------------
-- Table: rate_code
------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `nyc_taxi_curated.rate_code` (
    Rate_Code_Id INT64 OPTIONS(description='The Rate Code ID associated with a taxi ride. This is an integer identifying the rate under which the ride was charged.'),
    Rate_Code_Description STRING OPTIONS(description='A textual description of the Rate Code ID. Provides more context to the ID itself.')
)
OPTIONS (
    description = 'This table contains descriptions of Rate Code IDs used in taxi rides within the New York City Taxi and Limousine Commission (TLC) trip record dataset.'
    -- Example for other attributes (labels):
    -- , labels = [('environment', 'production'), ('data_domain', 'taxi_rates')]
);

-- Load data into rate_code table (to be executed later)
LOAD DATA INTO `nyc_taxi_curated.rate_code`
(
    Rate_Code_Id INT64,
    Rate_Code_Description STRING
)
FROM FILES (format = 'PARQUET', uris = ['gs://data-analytics-golden-demo/processed-bucket-v2/processed/taxi-data/rate_code_table/*.parquet']);


------------------------------------------------------------------------------
-- Table: taxi_trips
------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `nyc_taxi_curated.taxi_trips` (
    Vendor_Id INT64 OPTIONS(description='A unique identifier for the taxi vendor.'),
    Pickup_DateTime TIMESTAMP OPTIONS(description='The date and time when the taxi ride began.'),
    Dropoff_DateTime TIMESTAMP OPTIONS(description='The date and time when the taxi ride ended.'),
    Passenger_Count INT64 OPTIONS(description='The number of passengers in the taxi during the trip.'),
    Trip_Distance FLOAT64 OPTIONS(description='The distance traveled during the taxi ride in miles.'),
    Rate_Code_Id INT64 OPTIONS(description='The rate code ID applicable to the taxi ride.'),
    Store_And_Forward STRING OPTIONS(description='A flag indicating whether the trip record was stored and forwarded to the vendor.'),
    PULocationID INT64 OPTIONS(description='The ID of the location where the passenger was picked up.'),
    DOLocationID INT64 OPTIONS(description='The ID of the location where the passenger was dropped off.'),
    Payment_Type_Id INT64 OPTIONS(description='The ID representing the payment type used for the taxi ride.'),
    Fare_Amount FLOAT64 OPTIONS(description='The amount of the fare for the taxi ride.'),
    Surcharge FLOAT64 OPTIONS(description='Any additional surcharge applied to the fare.'),
    MTA_Tax FLOAT64 OPTIONS(description='The Metropolitan Transportation Authority tax amount.'),
    Tip_Amount FLOAT64 OPTIONS(description='The amount of tip given by the passenger.'),
    Tolls_Amount FLOAT64 OPTIONS(description='The amount of tolls paid during the taxi ride.'),
    Improvement_Surcharge FLOAT64 OPTIONS(description='The improvement surcharge amount.'),
    Total_Amount FLOAT64 OPTIONS(description='The total amount charged for the taxi ride.'),
    Congestion_Surcharge FLOAT64 OPTIONS(description='The congestion surcharge amount.')
)
OPTIONS (
    description = 'This table contains data about taxi rides in New York City, including trip details, fares, and payment information.'
    -- Example for other attributes (labels):
    -- , labels = [('environment', 'production'), ('data_domain', 'taxi_trips')]
);

-- Load data into taxi_trips table (to be executed later)
LOAD DATA INTO `nyc_taxi_curated.taxi_trips`
(
    Vendor_Id INT64,
    Pickup_DateTime TIMESTAMP,
    Dropoff_DateTime TIMESTAMP,
    Passenger_Count INT64,
    Trip_Distance FLOAT64,
    Rate_Code_Id INT64,
    Store_And_Forward STRING,
    PULocationID INT64,
    DOLocationID INT64,
    Payment_Type_Id INT64,
    Fare_Amount FLOAT64,
    Surcharge FLOAT64,
    MTA_Tax FLOAT64,
    Tip_Amount FLOAT64,
    Tolls_Amount FLOAT64,
    Improvement_Surcharge FLOAT64,
    Total_Amount FLOAT64,
    Congestion_Surcharge FLOAT64
)
FROM FILES (format = 'PARQUET', uris = ['gs://data-analytics-golden-demo/processed-bucket-v2/processed/taxi-data/yellow/trips_table/parquet/*.parquet']);


------------------------------------------------------------------------------
-- Table: trip_type
------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `nyc_taxi_curated.trip_type` (
    Trip_Type_Id INT64 OPTIONS(description='A unique identifier for the trip type.'),
    Trip_Type_Description STRING OPTIONS(description='A textual description of the trip type.')
)
OPTIONS (
    description = 'This table contains descriptions of the different trip types recorded within the taxi trip data.'
    -- Example for other attributes (labels):
    -- , labels = [('environment', 'production'), ('data_domain', 'trip_details')]
);

-- Load data into trip_type table (to be executed later)
LOAD DATA INTO `nyc_taxi_curated.trip_type`
(
    Trip_Type_Id INT64,
    Trip_Type_Description STRING
)
FROM FILES (format = 'PARQUET', uris = ['gs://data-analytics-golden-demo/processed-bucket-v2/processed/taxi-data/trip_type_table/*.parquet']);


------------------------------------------------------------------------------
-- Table: vendor
------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `nyc_taxi_curated.vendor` (
    Vendor_Id INT64 OPTIONS(description='The ID of the taxi vendor.'),
    Vendor_Description STRING OPTIONS(description='A description of the taxi vendor.')
)
OPTIONS (
    description = 'This table contains information about taxi vendors operating in New York City.'
    -- Example for other attributes (labels):
    -- , labels = [('environment', 'production'), ('data_domain', 'vendor_info')]
);

-- Load data into vendor table (to be executed later)
LOAD DATA INTO `nyc_taxi_curated.vendor`
(
    Vendor_Id INT64,
    Vendor_Description STRING
)
FROM FILES (format = 'PARQUET', uris = ['gs://data-analytics-golden-demo/processed-bucket-v2/processed/taxi-data/vendor_table/*.parquet']);

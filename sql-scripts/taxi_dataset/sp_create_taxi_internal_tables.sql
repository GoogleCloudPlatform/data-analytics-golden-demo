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
    - Internal tables are table that are managed by BigQuery where you are not concerned about having data outsite of BigQuery
    - Internal tables are fully managed by BigQuery so you do not need to worry about maintenance (BQ performs this automatically) 
    - Internal tables can be Partitioned and/or Clustered in order to increase performance when accessing your data

Description: 
    - This will create ingest the external tables into BigQuery. 
    - This uses a CTAS (Create-Table-As-Select) statement.  You can also use BigQuery CLI (bq commands)
    - The majority of customers will ingest data to get the benefits of BigQuery's internal Capacitor format

Dependencies:
    - You must run sp_create_taxi_external_tables first before running this script

Show:
    - Ingestion is easy with a CTAS
    - Ingestion is free (no need to create a cluster to perform ingestion)
    - Fast ingestion of 130 million rows of data

References:
    - https://cloud.google.com/bigquery/docs/creating-partitioned-tables
    - https://cloud.google.com/bigquery/docs/clustered-tables

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.taxi_trips`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.vendor`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.rate_code`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.payment_type`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.trip_type`;
*/


-- Query: Show partitioning and clustering (by several columns)
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips` 
(
    TaxiCompany             STRING,
    Vendor_Id	            INTEGER,	
    Pickup_DateTime	        TIMESTAMP,
    Dropoff_DateTime	    TIMESTAMP,
    Store_And_Forward	    STRING,
    Rate_Code_Id	        INTEGER,
    PULocationID	        INTEGER,
    DOLocationID	        INTEGER,
    Passenger_Count	        INTEGER,
    Trip_Distance	        FLOAT64,
    Fare_Amount	            FLOAT64,
    Surcharge	            FLOAT64,
    MTA_Tax	                FLOAT64,
    Tip_Amount	            FLOAT64,
    Tolls_Amount	        FLOAT64,
    Improvement_Surcharge	FLOAT64,
    Total_Amount	        FLOAT64,
    Payment_Type_Id	        INTEGER,
    Congestion_Surcharge    FLOAT64,
    Trip_Type	            INTEGER,
    Ehail_Fee	            FLOAT64,
    PartitionDate           DATE	
)
PARTITION BY PartitionDate
CLUSTER BY TaxiCompany, Pickup_DateTime
AS SELECT 
        'Green' AS TaxiCompany,
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        Store_And_Forward,
        Rate_Code_Id,
        PULocationID,
        DOLocationID,
        Passenger_Count,
        Trip_Distance,
        Fare_Amount,
        Surcharge,
        MTA_Tax,
        Tip_Amount,
        Tolls_Amount,
        Improvement_Surcharge,
        Total_Amount,
        Payment_Type_Id,
        Congestion_Surcharge,
        SAFE_CAST(Trip_Type AS INTEGER),
        Ehail_Fee,
        DATE(year, month, 1) as PartitionDate
   FROM `${project_id}.${bigquery_taxi_dataset}.ext_green_trips_parquet`
UNION ALL
   SELECT
        'Yellow' AS TaxiCompany, 
        Vendor_Id,
        Pickup_DateTime,
        Dropoff_DateTime,
        Store_And_Forward,
        Rate_Code_Id,
        PULocationID,
        DOLocationID,
        Passenger_Count,
        Trip_Distance,
        Fare_Amount,
        Surcharge,
        MTA_Tax,
        Tip_Amount,
        Tolls_Amount,
        Improvement_Surcharge,
        Total_Amount,
        Payment_Type_Id,
        Congestion_Surcharge,
        NULL AS Trip_Type,
        NULL AS Ehail_Fee,
        DATE(year, month, 1) as PartitionDate
   FROM `${project_id}.${bigquery_taxi_dataset}.ext_yellow_trips_parquet`;

CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.vendor`
(
    Vendor_Id	        INTEGER,
    Vendor_Description  STRING
) AS
SELECT Vendor_Id, Vendor_Description
  FROM `${project_id}.${bigquery_taxi_dataset}.ext_vendor`;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.rate_code`
(
    Rate_Code_Id	        INTEGER,
    Rate_Code_Description   STRING
) AS
SELECT Rate_Code_Id, Rate_Code_Description
  FROM `${project_id}.${bigquery_taxi_dataset}.ext_rate_code`;    


CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.payment_type`
(
    Payment_Type_Id	            INTEGER,
    Payment_Type_Description    STRING
) AS
SELECT Payment_Type_Id, Payment_Type_Description
  FROM `${project_id}.${bigquery_taxi_dataset}.ext_payment_type`;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.trip_type`
(
    Trip_Type_Id	       INTEGER,
    Trip_Type_Description  STRING
) AS
SELECT Trip_Type_Id, Trip_Type_Description
  FROM `${project_id}.${bigquery_taxi_dataset}.ext_trip_type`;


CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.location`
(
    location_id	 INTEGER,
    borough	     STRING,
    zone	     STRING,
    service_zone STRING,
    latitude	 FLOAT64,
    longitude	 FLOAT64
)
CLUSTER BY location_id
AS
SELECT location_id, borough, zone, service_zone, latitude, longitude
  FROM `${project_id}.${bigquery_taxi_dataset}.ext_location`;



----------------------------------------------------------------------------------------
-- Set the table and column descriptions
----------------------------------------------------------------------------------------
/*
ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data`
SET OPTIONS (description = 'This table stores metadata about the change data capture process. It includes the SQL statements executed, the tables affected, and the order of execution. This information can be used to track the changes made to the source data and to replay those changes in a different environment.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.datastream_cdc_data`
ALTER COLUMN sql_statement SET OPTIONS (description='The SQL statement executed to query or manipulate data.'),
ALTER COLUMN table_name SET OPTIONS (description='The name of the table the SQL statement is executed on.'),
ALTER COLUMN execution_order SET OPTIONS (description='The order in which the SQL statements were executed.');
*/

ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.location`
SET OPTIONS (description = 'This table contains information about taxi zones in New York City, including their location, borough, and service zone.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.location`
ALTER COLUMN location_id SET OPTIONS (description='Unique identifier for the taxi zone.'),
ALTER COLUMN borough SET OPTIONS (description='Borough of the taxi zone.'),
ALTER COLUMN zone SET OPTIONS (description='Taxi zone designation.'),
ALTER COLUMN service_zone SET OPTIONS (description='Service zone of the taxi zone.'),
ALTER COLUMN latitude SET OPTIONS (description='Latitude of the taxi zone centroid.'),
ALTER COLUMN longitude SET OPTIONS (description='Longitude of the taxi zone centroid.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.payment_type`
SET OPTIONS (description = 'This table maps payment type codes to their corresponding descriptions. This provides context to the payment methods used for taxi rides.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.payment_type`
ALTER COLUMN Payment_Type_Id SET OPTIONS (description='A code representing the payment method used for a taxi ride.'),
ALTER COLUMN Payment_Type_Description SET OPTIONS (description='A human-readable description of the payment method used for a taxi ride.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.rate_code`
SET OPTIONS (description = 'This table contains the mapping of rate codes used in the New York City taxi trip data. Each rate code corresponds to a specific fare calculation method.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.rate_code`
ALTER COLUMN Rate_Code_Id SET OPTIONS (description='Taxi rate code ID, as defined in the TLC Trip Record Data Dictionary'),
ALTER COLUMN Rate_Code_Description SET OPTIONS (description='Description of the taxi rate code');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
SET OPTIONS (description = 'This table contains data on taxi trips in New York City. It includes information about the pickup and drop off times and locations, the fare, and other trip details.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
ALTER COLUMN TaxiCompany SET OPTIONS (description='The Taxi Company for which the trip was undertaken.'),
ALTER COLUMN Vendor_Id SET OPTIONS (description='A unique identifier for the vendor.'),
ALTER COLUMN Pickup_DateTime SET OPTIONS (description='Date and time when the passenger was picked up.'),
ALTER COLUMN Dropoff_DateTime SET OPTIONS (description='Date and time when the passenger was dropped off.'),
ALTER COLUMN Store_And_Forward SET OPTIONS (description='Indicates whether the trip data was held in vehicle memory before sending to the vendor.'),
ALTER COLUMN Rate_Code_Id SET OPTIONS (description='The code signifying the rate type of the trip.'),
ALTER COLUMN PULocationID SET OPTIONS (description='TLC Taxi Zone in which the trip started.'),
ALTER COLUMN DOLocationID SET OPTIONS (description='TLC Taxi Zone in which the trip ended.'),
ALTER COLUMN Passenger_Count SET OPTIONS (description='Number of passengers in the vehicle.'),
ALTER COLUMN Trip_Distance SET OPTIONS (description='Distance of the trip in miles.'),
ALTER COLUMN Fare_Amount SET OPTIONS (description='The time-and-distance fare calculated by the meter.'),
ALTER COLUMN Surcharge SET OPTIONS (description='Additional charges added to the fare, such as peak hour surcharges or night surcharges.'),
ALTER COLUMN MTA_Tax SET OPTIONS (description='0.50 dollar MTA tax.'),
ALTER COLUMN Tip_Amount SET OPTIONS (description='Amount of tip paid by the passenger.'),
ALTER COLUMN Tolls_Amount SET OPTIONS (description='Amount of tolls paid during the trip.'),
ALTER COLUMN Improvement_Surcharge SET OPTIONS (description='0.30 dollar improvement surcharge assessed on hailed trips.'),
ALTER COLUMN Total_Amount SET OPTIONS (description='The total amount charged to the passenger, calculated as the sum of all other fare components.'),
ALTER COLUMN Payment_Type_Id SET OPTIONS (description='A numeric code signifying how the trip was paid for.'),
ALTER COLUMN Congestion_Surcharge SET OPTIONS (description='Amount of congestion surcharge for driving in designated areas.'),
ALTER COLUMN Trip_Type SET OPTIONS (description='A code indicating whether the trip was a street-hail or a dispatch.'),
ALTER COLUMN Ehail_Fee SET OPTIONS (description='Electronic Filing Fee.'),
ALTER COLUMN PartitionDate SET OPTIONS (description='The date the trip data was ingested into the system.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming`
SET OPTIONS (description = 'This table contains data on taxi rides in New York City. Each row represents a GPS point during a ride, with details such as location, time, meter readings, and ride status.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_streaming`
ALTER COLUMN ride_id SET OPTIONS (description='Unique identifier for the ride.'),
ALTER COLUMN point_idx SET OPTIONS (description='Ordinal number of the GPS point within the ride.'),
ALTER COLUMN latitude SET OPTIONS (description='Latitude of the GPS point.'),
ALTER COLUMN longitude SET OPTIONS (description='Longitude of the GPS point.'),
ALTER COLUMN timestamp SET OPTIONS (description='Timestamp of the GPS point.'),
ALTER COLUMN meter_reading SET OPTIONS (description='Meter reading at the GPS point.'),
ALTER COLUMN meter_increment SET OPTIONS (description='Change in meter reading from the previous GPS point.'),
ALTER COLUMN ride_status SET OPTIONS (description='Status of the ride at the GPS point - en route or not.'),
ALTER COLUMN passenger_count SET OPTIONS (description='Number of passengers in the taxi.'),
ALTER COLUMN product_id SET OPTIONS (description='Product ID associated with the ride - could indicate taxi type.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_with_col_sec`
SET OPTIONS (description = 'This table contains data on taxi trips in New York City. It includes information about the pickup and drop off times and locations, the fare, and other trip details.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_with_col_sec`
ALTER COLUMN Vendor_Id SET OPTIONS (description='A code indicating the TPEP provider that provided the record. 1= Creative Mobile Technologies, 2= VeriFone Inc.'),
ALTER COLUMN Pickup_DateTime SET OPTIONS (description='The date and time when the meter was engaged.'),
ALTER COLUMN Dropoff_DateTime SET OPTIONS (description='The date and time when the meter was disengaged.'),
ALTER COLUMN Passenger_Count SET OPTIONS (description='The number of passengers in the vehicle. This is a driver-entered value.'),
ALTER COLUMN Trip_Distance SET OPTIONS (description='The elapsed trip distance in miles reported by the taximeter.'),
ALTER COLUMN Rate_Code_Id SET OPTIONS (description='The final rate code in effect at the end of the trip. 1= Standard Rate, 2= JFK Flat Rate, 3= Newark Flat Rate, 4= Nassau or Westchester Flat Rate, 5= Negotiated Fare, 6= Group Ride'),
ALTER COLUMN Store_And_Forward SET OPTIONS (description='This flag indicates whether the trip record was held in vehicle memory before sending to the vendor because the vehicle did not have a connection to the server. Y= store and forward trip, N= not a store and forward trip'),
ALTER COLUMN PULocationID SET OPTIONS (description='TLC Taxi Zone in which the taximeter was engaged.'),
ALTER COLUMN DOLocationID SET OPTIONS (description='TLC Taxi Zone in which the taximeter was disengaged.'),
ALTER COLUMN Payment_Type_Id SET OPTIONS (description='A numeric code signifying how the passenger paid for the trip. 1= Credit card, 2= Cash, 3= No charge, 4= Dispute, 5= Unknown, 6= Voided trip'),
ALTER COLUMN Fare_Amount SET OPTIONS (description='The time-and-distance fare calculated by the meter.'),
ALTER COLUMN Surcharge SET OPTIONS (description='Miscellaneous extras and surcharges. Currently, this only includes the $0.50 rush hour surcharge.'),
ALTER COLUMN MTA_Tax SET OPTIONS (description='0.50 MTA tax that is automatically triggered based on the metered rate in use.'),
ALTER COLUMN Tip_Amount SET OPTIONS (description='This field is automatically populated for credit card tips. Cash tips are not included.'),
ALTER COLUMN Tolls_Amount SET OPTIONS (description='Total amount of all tolls charged to the passenger.'),
ALTER COLUMN Improvement_Surcharge SET OPTIONS (description='0.30 improvement surcharge assessed trips at the flag drop. The improvement surcharge began being levied in January 2015.'),
ALTER COLUMN Total_Amount SET OPTIONS (description='The total amount charged to passengers. Does not include cash tips.'),
ALTER COLUMN Congestion_Surcharge SET OPTIONS (description='Dollar amount of the congestion surcharge for trips that start, end or pass through the Manhattan congestion zone where the surcharge is in effect.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.trip_type`
SET OPTIONS (description = 'This table contains the mapping for the different trip types in the NYC taxi dataset. It provides a unique code for each type of taxi trip and its corresponding description.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.trip_type`
ALTER COLUMN Trip_Type_Id SET OPTIONS (description='A code indicating the type of taxi trip.'),
ALTER COLUMN Trip_Type_Description SET OPTIONS (description='Description of the trip type code.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.vendor`
SET OPTIONS (description = 'This table contains information about the technology providers that provide data for taxi trips in New York City. Each row represents a unique vendor.');


ALTER TABLE `${project_id}.${bigquery_taxi_dataset}.vendor`
ALTER COLUMN Vendor_Id SET OPTIONS (description='A code indicating the Technology Provider that provided the record.'),
ALTER COLUMN Vendor_Description SET OPTIONS (description='The name of the Technology Provider that provided the record.');
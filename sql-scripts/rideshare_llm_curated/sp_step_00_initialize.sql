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
      - 

  Description: 
      - Initialize the Curated zone of the AI Lakehouse

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/


------------------------------------------------------------------------------------------------------------
-- Create link to the LLM
------------------------------------------------------------------------------------------------------------
/*
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_curated_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_LARGE_LANGUAGE_MODEL_V1');
*/

-- New Syntax for specifying a model version text-bison@001 or text-bison@002 for latest or text-bison-32k@latest
CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_curated_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
  OPTIONS (endpoint = 'text-bison@002');

------------------------------------------------------------------------------------------------------------
-- Create link to the LLM (embeddings)
------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE MODEL `${project_id}.${bigquery_rideshare_llm_curated_dataset}.llm_embedding_model`
REMOTE WITH CONNECTION `${project_id}.us.vertex-ai`
OPTIONS(remote_service_type = 'CLOUD_AI_TEXT_EMBEDDING_MODEL_V1');

------------------------------------------------------------------------------------------------------------
-- Location Table
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.location`
CLUSTER BY location_id
OPTIONS (description='This is the zone table that contains information about each pickup location or dropoff location.')
AS 
SELECT *     
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.location`;


-- 5 Operations per 10 seconds rate limit: https://cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language#alter_schema_set_options_statement
ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.location`
  ALTER COLUMN location_id  SET OPTIONS (description='Pickup Location Id or Dropoff Location Id - Primary Key'),
  ALTER COLUMN borough      SET OPTIONS (description='Borough'),
  ALTER COLUMN zone         SET OPTIONS (description='Taxi Zone or Neighborhood'),
  ALTER COLUMN service_zone SET OPTIONS (description='Service Zone or Service Area'),
  ALTER COLUMN latitude     SET OPTIONS (description='Latitude Geolocation'),
  ALTER COLUMN longitude    SET OPTIONS (description='Longitude Geolocation');


------------------------------------------------------------------------------------------------------------
-- Payment Type
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.payment_type`
CLUSTER BY payment_type_id
OPTIONS (description='This is the payment type table that contains the different payment type decriptions.')
AS 
SELECT *     
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.payment_type`;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.payment_type`
  ALTER COLUMN payment_type_id          SET OPTIONS (description='Payment Type Id - Primary Key'),
  ALTER COLUMN payment_type_description SET OPTIONS (description='Payment Type Description - How the customer paid for the rideshare trip.');


------------------------------------------------------------------------------------------------------------
-- Trip table
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`
CLUSTER BY trip_id, driver_id, customer_id
OPTIONS (description='This is the trip table that hold every rideshare trip.  It contains the trip, driver and customer intersection of data.')
AS 
SELECT *     
  FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.trip`;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip`
  ALTER COLUMN trip_id SET OPTIONS (description='Trip Id - Primary Key'),
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - Foreign Key to Driver Table'),
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Foreign Key to Customer Table'),
  ALTER COLUMN pickup_time SET OPTIONS (description='Pickup Time - The time the customer was picked up by the driver.'),
  ALTER COLUMN dropoff_time SET OPTIONS (description='Dropoff Time - The time the customer was dropped off by the driver.'),
  ALTER COLUMN pickup_location_id SET OPTIONS (description='Pickup Location Id - Foreign Key to the Location table.  The name of the place where the customer was picked up by the driver for their trip.'),
  ALTER COLUMN dropoff_location_id SET OPTIONS (description='Dropoff Location Id - Foreign Key to the Location table.  The name of the place where the customer was dropped off by the driver for their trip..'),
  ALTER COLUMN payment_type_id SET OPTIONS (description='Payment Type Id - Foreign Key to the Payment Type Table.'),
  ALTER COLUMN passenger_count SET OPTIONS (description='Passenger Count - The number of passengers in the car during the trip.'),
  ALTER COLUMN trip_distance SET OPTIONS (description='Trip Distance - The distance of the trip in miles.'),
  ALTER COLUMN fare_amount SET OPTIONS (description='Fare Amount - The amount charged for the trip excluding tip amount.'),
  ALTER COLUMN tip_amount SET OPTIONS (description='Tip Amount - The amount the customer tipped the driver.'),
  ALTER COLUMN total_amount SET OPTIONS (description='Total Amount - The total cost of the trip which is the fare amount added with the tip amount.');


------------------------------------------------------------------------------------------------------------
-- Customer
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` 
CLUSTER BY customer_id
OPTIONS (description='This is the customer table that holds each customers name, their LLM review summaries and their quantitative data.')
AS 
SELECT customer.customer_id,
       customer.customer_name,
       customer.customer_since_date,
       customer.include_in_llm_processing,
       customer.llm_summary_customer_attribute AS customer_attribute_summary,
       customer.llm_summary_customer_review_summary AS customer_review_summary,
       customer.llm_customer_quantitative_analysis AS customer_quantitative_analysis,
       COUNT(*)             AS total_trip_count,
       AVG(passenger_count) AS avg_passenger_count,
       AVG(trip_distance)   AS avg_trip_distance,
       AVG(fare_amount)     AS avg_fare_amount,
       AVG(tip_amount)      AS avg_tip_amount,
       AVG(total_amount)    AS avg_total_amount,
       SUM(total_amount)    AS sum_total_amount
 FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer` AS customer
      INNER JOIN  `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS trip
             ON customer.customer_id = trip.customer_id
GROUP BY 1,2,3,4,5,6,7;


ALTER TABLE  `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer`
--Quantitive analysys embeddings
ADD COLUMN IF NOT EXISTS llm_customer_quantitative_analysis_embedding ARRAY<FLOAT64>,
--List of prefered drivers based on semantic matching
ADD COLUMN IF NOT EXISTS prefered_drivers ARRAY<INT64>;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Primary Key'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer.'),
  ALTER COLUMN customer_since_date SET OPTIONS (description='Customer Since Date - The first time the customer used the rideshare service.  Their inception date.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN customer_attribute_summary SET OPTIONS (description='Customer Attribute Summary - The LLM summary of the customer preferences.'),
  ALTER COLUMN customer_review_summary SET OPTIONS (description='Customer Review Summary - The LLM summary of all the customer reviews.  This summary spans drivers.'),
  ALTER COLUMN customer_quantitative_analysis SET OPTIONS (description='Customer Quantitative Analysis - The LLM summary of the quantitative data analysis.'),
  ALTER COLUMN total_trip_count SET OPTIONS (description='Total Trip Count - The number of trips taken by this customer.'),
  ALTER COLUMN avg_passenger_count SET OPTIONS (description='Avg Passenger Count - The average number of passengers for all the customer trips.'),
  ALTER COLUMN avg_trip_distance SET OPTIONS (description='Avg Trip Distance Count - The average trip distance for all the customer trips.'),
  ALTER COLUMN avg_fare_amount SET OPTIONS (description='Avg Fare Amount - The average fare amount for all the customer trips.'),
  ALTER COLUMN avg_tip_amount SET OPTIONS (description='Avg Tip Amount - The average tip amount for all the customer trips.'),
  ALTER COLUMN avg_total_amount SET OPTIONS (description='Avg Total Amount - The average total amount for all the customer trips.'),
  ALTER COLUMN sum_total_amount SET OPTIONS (description='Sum Total Amount - The total amount the customer has spent using our service.'),
  ALTER COLUMN llm_customer_quantitative_analysis_embedding SET OPTIONS (description='Embeddings of the customer quantitative analysis.'),
  ALTER COLUMN prefered_drivers SET OPTIONS (description='List of prefered drivers based on semantic matching.');


------------------------------------------------------------------------------------------------------------
-- Driver.');
------------------------------------------------------------------------------------------------------------
-- Customer Reviews
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review` 
CLUSTER BY customer_id
OPTIONS (description='This is the customer review table that holds each customer review they have provided for their trips.')
AS
SELECT customer.customer_id,
       customer.customer_name,
       customer.include_in_llm_processing AS customer_include_in_llm_processing,
       customer_review.trip_id,
       customer_review.review_date,
       driver.driver_id,
       driver.driver_name,
       driver.include_in_llm_processing AS driver_include_in_llm_processing,
       customer_review.customer_review_text,
       customer_review.review_sentiment,
       customer_review.extracted_driver_theme,
       customer_review.extracted_customer_theme       
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_review` AS customer_review
              ON customer.customer_id = customer_review.customer_id   
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver` AS driver
              ON customer_review.driver_id = driver.driver_id;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Composite Primary Key (along with Trip Id).  Foreign Key to the Customer table.'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer.'),
  ALTER COLUMN customer_include_in_llm_processing SET OPTIONS (description='Customer Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN trip_id SET OPTIONS (description='Trip Id - Composite Primary Key (along with Customer Id).  Foreign Key to the Trip table.'),
  ALTER COLUMN review_date SET OPTIONS (description='Review Data - The date the customer wrote their review of the trip.'),
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - The Foreign Key to the driver table.  This is the driver the review is being created by the customer.'),
  ALTER COLUMN driver_name SET OPTIONS (description='Driver Name - The name of the driver.'),
  ALTER COLUMN driver_include_in_llm_processing SET OPTIONS (description='Driver Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN customer_review_text SET OPTIONS (description='Customer Review Text - The review text written by the customer for the trip/driver.'),
  ALTER COLUMN review_sentiment SET OPTIONS (description='Review Sentiment - The sentiment of the review text which is: Positive, Neutral or Negative.'),
  ALTER COLUMN extracted_driver_theme SET OPTIONS (description='Extract Driver Theme - The attributes the LLM extraced about the driver per the customer review text.'),
  ALTER COLUMN extracted_customer_theme SET OPTIONS (description='Extract Customer Theme - The attributes the LLM extraced about the customer per the customer review text.');


------------------------------------------------------------------------------------------------------------
-- Customer Reviews (Summary)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE MATERIALIZED VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review_summary`
CLUSTER BY customer_id
OPTIONS (enable_refresh = true, refresh_interval_minutes = 30, description='This is the customer review summary that counts the sentiment for each customer review.')
AS
SELECT customer.customer_id,
       customer.customer_name, 
       customer.include_in_llm_processing,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%neutral%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%') AS total_review_count_postive,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%neutral%')  AS total_review_count_neutral,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count_negative,
       
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review` AS customer_review
              ON customer.customer_id = customer_review.customer_id   
GROUP BY 1, 2, 3;


/* - Not available for Materialized Views
ALTER MATERIALIZED VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review_summary`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Primary Key'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN total_review_count SET OPTIONS (description='Total Review Count - The total number of reviews created by this customer'),
  ALTER COLUMN total_review_count_postive SET OPTIONS (description='Total Review Count Positive - The number of reviews with a positive sentiment analysis.'),
  ALTER COLUMN total_review_count_neutral SET OPTIONS (description='Total Review Count Neutral - The number of reviews with a neutral sentiment analysis.'),
  ALTER COLUMN total_review_count_negative SET OPTIONS (description='Total Review Count Negative - The number of reviews with a negative sentiment analysis.');
*/

------------------------------------------------------------------------------------------------------------
-- Customer Table (Preferences)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_preference` 
CLUSTER BY customer_id
OPTIONS (description='This is the customer preference table that holds the distinct list of customer preferences extracted by the LLM.')
AS 
SELECT DISTINCT 
       customer.customer_id,
       customer.customer_name,
       customer.include_in_llm_processing,
       CASE WHEN TRIM(LOWER(extracted_customer_attribute)) = 'speaks spanish'                      THEN 'Bilingual'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'prefers english'                     THEN 'Speaks English'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes a clean car'                   THEN 'Likes a clean car'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'prefers the radio on'                THEN 'Likes the radio on'  
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'prefers the radio off'               THEN 'Likes the radio off'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'travels with large luggage'          THEN 'Likes a large amount of trunck space'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'travels with small luggage'          THEN 'Typically travels without luggage'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes a warm vehicle inside'         THEN 'Likes the car to be warm inside'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes a cooler vehicle inside'       THEN 'Likes the car to be cool inside'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes their driver to drive fast'    THEN 'Likes a driver that drives quickly'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes their driver to drive slow'    THEN 'Likes a driver that drives slowly'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'likes to have a conversation'        THEN 'Likes a driver who likes conversation'
            WHEN TRIM(LOWER(extracted_customer_attribute)) = 'perfers a driver that does not talk' THEN 'Likes a quiet driver'
            ELSE 'Other'
       END AS preference

   FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.customer_attribute` AS customer_attribute
        INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
                ON customer_attribute.customer_id = customer.customer_id
               AND customer_attribute.rank_order = 1;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_preference`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Foreign key to the customer table.'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN preference SET OPTIONS (description='Preference - The preference detected by the LLM for the customer.');


------------------------------------------------------------------------------------------------------------
-- Looker "Customer" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer`
OPTIONS (description='This is the reporting table used by looker for customer information.')
AS
SELECT customer.customer_id,
       customer.customer_name,
       customer.customer_since_date,
       customer.include_in_llm_processing,
       customer.customer_attribute_summary,
       customer.customer_review_summary,
       customer.customer_quantitative_analysis,
       customer.total_trip_count,
       customer.avg_passenger_count,
       customer.avg_trip_distance,
       customer.avg_fare_amount,
       customer.avg_tip_amount,
       customer.avg_total_amount,
       customer.sum_total_amount,

       customer_review_summary.total_review_count,
       customer_review_summary.total_review_count_postive,
       customer_review_summary.total_review_count_neutral,
       customer_review_summary.total_review_count_negative,

  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer` AS customer
        LEFT JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review_summary` AS customer_review_summary
              ON customer.customer_id = customer_review_summary.customer_id;


ALTER VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Primary Key'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer.'),
  ALTER COLUMN customer_since_date SET OPTIONS (description='Customer Since Date - The first time the customer used the rideshare service.  Their inception date.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN customer_attribute_summary SET OPTIONS (description='Customer Attribute Summary - The LLM summary of the customer preferences.'),
  ALTER COLUMN customer_review_summary SET OPTIONS (description='Customer Review Summary - The LLM summary of all the customer reviews.  This summary spans drivers.'),
  ALTER COLUMN customer_quantitative_analysis SET OPTIONS (description='Customer Quantitative Analysis - The LLM summary of the quantitative data analysis.'),
  ALTER COLUMN total_trip_count SET OPTIONS (description='Total Trip Count - The number of trips taken by this customer.'),
  ALTER COLUMN avg_passenger_count SET OPTIONS (description='Avg Passenger Count - The average number of passengers for all the customer trips.'),
  ALTER COLUMN avg_trip_distance SET OPTIONS (description='Avg Trip Distance Count - The average trip distance for all the customer trips.'),
  ALTER COLUMN avg_fare_amount SET OPTIONS (description='Avg Fare Amount - The average fare amount for all the customer trips.'),
  ALTER COLUMN avg_tip_amount SET OPTIONS (description='Avg Tip Amount - The average tip amount for all the customer trips.'),
  ALTER COLUMN avg_total_amount SET OPTIONS (description='Avg Total Amount - The average total amount for all the customer trips.'),
  ALTER COLUMN sum_total_amount SET OPTIONS (description='Sum Total Amount - The total amount the customer has spent using our service.'),
  ALTER COLUMN total_review_count SET OPTIONS (description='Total Review Count - The total number of reviews created by this customer'),
  ALTER COLUMN total_review_count_postive SET OPTIONS (description='Total Review Count Positive - The number of reviews with a positive sentiment analysis.'),
  ALTER COLUMN total_review_count_neutral SET OPTIONS (description='Total Review Count Neutral - The number of reviews with a neutral sentiment analysis.'),
  ALTER COLUMN total_review_count_negative SET OPTIONS (description='Total Review Count Negative - The number of reviews with a negative sentiment analysis.');


------------------------------------------------------------------------------------------------------------
-- Looker "Customer Preferences" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer_preference`
OPTIONS (description='This is the reporting table used by looker for customer preferences.')
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_preference`;


ALTER VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer_preference`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Foreign key to the customer table.'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN preference SET OPTIONS (description='Preference - The preference detected by the LLM for the customer.');



------------------------------------------------------------------------------------------------------------
-- Looker "Customer Reviews" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer_review`
OPTIONS (description='This is the reporting table used by looker for customer reviews.')
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review`;


ALTER VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_customer_review`
  ALTER COLUMN customer_id SET OPTIONS (description='Customer Id - Composite Primary Key (along with Trip Id).  Foreign Key to the Customer table.'),
  ALTER COLUMN customer_name SET OPTIONS (description='Customer Name - The name of the customer.'),
  ALTER COLUMN customer_include_in_llm_processing SET OPTIONS (description='Customer Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN trip_id SET OPTIONS (description='Trip Id - Composite Primary Key (along with Customer Id).  Foreign Key to the Trip table.'),
  ALTER COLUMN review_date SET OPTIONS (description='Review Data - The date the customer wrote their review of the trip.'),
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - The Foreign Key to the driver table.  This is the driver the review is being created by the customer.'),
  ALTER COLUMN driver_name SET OPTIONS (description='Driver Name - The name of the driver.'),
  ALTER COLUMN driver_include_in_llm_processing SET OPTIONS (description='Driver Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN customer_review_text SET OPTIONS (description='Customer Review Text - The review text written by the customer for the trip/driver.'),
  ALTER COLUMN review_sentiment SET OPTIONS (description='Review Sentiment - The sentiment of the review text which is: Positive, Neutral or Negative.'),
  ALTER COLUMN extracted_driver_theme SET OPTIONS (description='Extract Driver Theme - The attributes the LLM extraced about the driver per the customer review text.'),
  ALTER COLUMN extracted_customer_theme SET OPTIONS (description='Extract Customer Theme - The attributes the LLM extraced about the customer per the customer review text.');


------------------------------------------------------------------------------------------------------------
-- Driver Table w/Averages
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` 
CLUSTER BY driver_id
OPTIONS (description='This is driver table that holds information about each driver.  It constains the LLM summaries and the quanitative analysis.')
AS 
SELECT driver.driver_id,
       driver.driver_name,
       driver.driver_since_date,
       driver.include_in_llm_processing,
       driver.llm_summary_driver_attribute AS driver_attribute_summary,
       driver.llm_summary_driver_review_summary AS driver_review_summary,
       driver.llm_driver_quantitative_analysis AS driver_quantitative_analysis,       
       COUNT(*)             AS total_trip_count,
       AVG(passenger_count) AS avg_passenger_count,
       AVG(trip_distance)   AS avg_trip_distance,
       AVG(fare_amount)     AS avg_fare_amount,
       AVG(tip_amount)      AS avg_tip_amount,
       AVG(total_amount)    AS avg_total_amount,    
       SUM(total_amount)    AS sum_total_amount   
 FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver` AS driver
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.trip` AS trip
              ON driver.driver_id = trip.driver_id
GROUP BY 1,2,3,4,5,6,7;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver`
ADD COLUMN IF NOT EXISTS llm_driver_quantitative_analysis_embedding ARRAY<FLOAT64>;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver`
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - Primary Key'),
  ALTER COLUMN driver_name SET OPTIONS (description='Driver Name - The name of the driver.'),
  ALTER COLUMN driver_since_date SET OPTIONS (description='Driver Since Date - The first time the driver made a trip.  The inception date.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN driver_attribute_summary SET OPTIONS (description='Driver Attribute Summary - The LLM summary of the driver preferences.'),
  ALTER COLUMN driver_review_summary SET OPTIONS (description='Driver Review Summary - The LLM summary of all the customer reviews.  This summary spans customers.'),
  ALTER COLUMN driver_quantitative_analysis SET OPTIONS (description='Driver Quantitative Analysis - The LLM summary of the quantitative data analysis.'),
  ALTER COLUMN total_trip_count SET OPTIONS (description='Total Trip Count - The number of trips taken by this customer.'),
  ALTER COLUMN avg_passenger_count SET OPTIONS (description='Avg Passenger Count - The average number of passengers for all the customer trips.'),
  ALTER COLUMN avg_trip_distance SET OPTIONS (description='Avg Trip Distance Count - The average trip distance for all the customer trips.'),
  ALTER COLUMN avg_fare_amount SET OPTIONS (description='Avg Fare Amount - The average fare amount for all the customer trips.'),
  ALTER COLUMN avg_tip_amount SET OPTIONS (description='Avg Tip Amount - The average tip amount for all the customer trips.'),
  ALTER COLUMN avg_total_amount SET OPTIONS (description='Avg Total Amount - The average total amount for all the customer trips.'),
  ALTER COLUMN sum_total_amount SET OPTIONS (description='Sum Total Amount - The total amount the customer has spent using our service.'),
  ALTER COLUMN llm_driver_quantitative_analysis_embedding SET OPTIONS (description='Embeddings of the driver quantitative analysis.');


------------------------------------------------------------------------------------------------------------
-- Driver Attributes (some data cleaning from LLM)'),


------------------------------------------------------------------------------------------------------------
-- Driver Reviews (some data cleaning from LLM)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE MATERIALIZED VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_review_summary`
CLUSTER BY driver_id
OPTIONS (enable_refresh = true, refresh_interval_minutes = 30, description='This is the driver review summary table that holds the counts of driver sentiments based on the customer reviews of the driver.')
AS 
SELECT driver.driver_id,
       driver.driver_name,
       driver.include_in_llm_processing,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%neutral%'
               OR
               LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%positive%') AS total_review_count_postive,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%neutral%')  AS total_review_count_neutral,
       COUNTIF(LOWER(customer_review.review_sentiment) LIKE '%negative%') AS total_review_count_negative,
       
 FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
      INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.customer_review` AS customer_review
             ON driver.driver_id = customer_review.driver_id
GROUP BY 1, 2, 3;


/* - Not available for Materialized Views
ALTER MATERIALIZED VIEW  `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_review_summary`
  ALTER COLUMN TTT SET OPTIONS (description='TTT'),
  ALTER COLUMN TTT SET OPTIONS (description='TTT');
*/

------------------------------------------------------------------------------------------------------------
-- Driver Table (Preferences)
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_preference` 
CLUSTER BY driver_id
OPTIONS (description='This is the driver preference table which holds the preferences of each driver extracted by the LLM.')
AS 
SELECT DISTINCT 
       driver.driver_id,
       driver.driver_name,
       driver.include_in_llm_processing,
       CASE WHEN TRIM(LOWER(extracted_driver_attribute)) = 'safe driver'                   THEN 'Safe Driver'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes music'            THEN 'Radio On'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes no music'         THEN 'Radio Off'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'trunk space large'             THEN 'Large amount of truck space'  
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'trunk space small'             THEN 'Limited amount of truck space'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes conversation'     THEN 'Likes conversation with customer(s)'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver likes no conversation'  THEN 'Likes prefers not talking with customer(s)'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driving too fast'              THEN 'Drives fast'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driving too slow'              THEN 'Drives slow'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'clean car'                     THEN 'Keeps a clean car'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'dirty car'                     THEN 'Keeps a ditry car'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'car too hot'                   THEN 'Keeps car temperature warm'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'car too cold'                  THEN 'Keeps car temperature cool'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver speaks spanish'         THEN 'Bilingual'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'driver does not speak spanish' THEN 'Speaks English'
            WHEN TRIM(LOWER(extracted_driver_attribute)) = 'distracted driver'             THEN 'Unsafe Distracted Driver'
            ELSE 'Other'
       END AS preference

   FROM `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.driver_attribute` AS driver_attribute
        INNER JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
                ON driver_attribute.driver_id = driver.driver_id
               AND driver_attribute.rank_order = 1;


ALTER TABLE `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_preference`
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - Foreign key to the driver table.'),
  ALTER COLUMN driver_name SET OPTIONS (description='Driver Name - The name of the driver.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN preference SET OPTIONS (description='Preference - The preference detected by the LLM for the driver.');



------------------------------------------------------------------------------------------------------------
-- Looker "Driver" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_driver`
OPTIONS (description='This is the reporting table used by looker for drivers.')
AS
SELECT driver.driver_id,
       driver.driver_name,
       driver.driver_since_date,
       driver.include_in_llm_processing,
       driver.driver_attribute_summary,
       driver.driver_review_summary,
       driver.driver_quantitative_analysis,
       driver.total_trip_count,
       driver.avg_passenger_count,
       driver.avg_trip_distance,
       driver.avg_fare_amount,
       driver.avg_tip_amount,
       driver.avg_total_amount,
       driver.sum_total_amount,

       driver_review_summary.total_review_count,
       driver_review_summary.total_review_count_postive,
       driver_review_summary.total_review_count_neutral,
       driver_review_summary.total_review_count_negative,

  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver` AS driver
       LEFT JOIN `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_review_summary` AS driver_review_summary
              ON driver.driver_id = driver_review_summary.driver_id;


ALTER VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_driver`
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - Primary Key'),
  ALTER COLUMN driver_name SET OPTIONS (description='Driver Name - The name of the driver.'),
  ALTER COLUMN driver_since_date SET OPTIONS (description='Driver Since Date - The first time the driver made a trip.  The inception date.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN driver_attribute_summary SET OPTIONS (description='Driver Attribute Summary - The LLM summary of the driver preferences.'),
  ALTER COLUMN driver_review_summary SET OPTIONS (description='Driver Review Summary - The LLM summary of all the customer reviews.  This summary spans customers.'),
  ALTER COLUMN driver_quantitative_analysis SET OPTIONS (description='Driver Quantitative Analysis - The LLM summary of the quantitative data analysis.'),
  ALTER COLUMN total_trip_count SET OPTIONS (description='Total Trip Count - The number of trips taken by this customer.'),
  ALTER COLUMN avg_passenger_count SET OPTIONS (description='Avg Passenger Count - The average number of passengers for all the customer trips.'),
  ALTER COLUMN avg_trip_distance SET OPTIONS (description='Avg Trip Distance Count - The average trip distance for all the customer trips.'),
  ALTER COLUMN avg_fare_amount SET OPTIONS (description='Avg Fare Amount - The average fare amount for all the customer trips.'),
  ALTER COLUMN avg_tip_amount SET OPTIONS (description='Avg Tip Amount - The average tip amount for all the customer trips.'),
  ALTER COLUMN avg_total_amount SET OPTIONS (description='Avg Total Amount - The average total amount for all the customer trips.'),
  ALTER COLUMN sum_total_amount SET OPTIONS (description='Sum Total Amount - The total amount the customer has spent using our service.'),
  ALTER COLUMN total_review_count SET OPTIONS (description='Total Review Count - The total number of reviews for this driver'),
  ALTER COLUMN total_review_count_postive SET OPTIONS (description='Total Review Count Positive - The number of reviews, for this driver, with a positive sentiment analysis.'),
  ALTER COLUMN total_review_count_neutral SET OPTIONS (description='Total Review Count Neutral - The number of reviews, for this driver, with a neutral sentiment analysis.'),
  ALTER COLUMN total_review_count_negative SET OPTIONS (description='Total Review Count Negative - The number of reviews, for this driver, with a negative sentiment analysis.');



------------------------------------------------------------------------------------------------------------
-- Looker "Driver Preferences" View to keep Looker Simple
------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_driver_preference`
OPTIONS (description='This is the reporting table used by looker for driver preferences.')
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_llm_curated_dataset}.driver_preference`;


ALTER VIEW `${project_id}.${bigquery_rideshare_llm_curated_dataset}.looker_driver_preference`
  ALTER COLUMN driver_id SET OPTIONS (description='Driver Id - Foreign key to the driver table.'),
  ALTER COLUMN driver_name SET OPTIONS (description='Driver Name - The name of the driver.'),
  ALTER COLUMN include_in_llm_processing SET OPTIONS (description='Include in LLM Processing - For the demo we only process a subset of all the data.'),
  ALTER COLUMN preference SET OPTIONS (description='Preference - The preference detected by the LLM for the driver.');


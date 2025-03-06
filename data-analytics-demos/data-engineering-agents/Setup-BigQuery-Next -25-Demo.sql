-- Run this on BigQuery
-------------------------------------------------------------------------------------------------------------------
-- Load data
-------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS raw_data OPTIONS(location = 'us-central1');
CREATE SCHEMA IF NOT EXISTS cleaned_data OPTIONS(location = 'us-central1');

-- https://console.cloud.google.com/storage/browser/data-engineering-agent/pricing-data
LOAD DATA OVERWRITE `raw_data.competitor_pricing` 
(
  date STRING, 
  hotel_name STRING, 
  phone_number STRING, 
  room_type STRING, 
  bed_type STRING, 
  room_features STRING, 
  room_size_sqft STRING, 
  price STRING
)
FROM FILES (
  format = 'CSV', 
  skip_leading_rows = 1, 
  uris = ['gs://data-analytics-golden-demo/data-engineering-agents/pricing-data_competitor-pricing.csv']
  );

-------------------------------------------------------------------------------------------------------------------
-- Create Models
-- You will need to create an external connection and grant the service principal Vertex AI User role
-------------------------------------------------------------------------------------------------------------------
-- Create our GenAI and Vector Embeddings models
CREATE MODEL IF NOT EXISTS `cleaned_data.gemini_2_0_flash`
  REMOTE WITH CONNECTION `us-central1.vertex-ai`
  OPTIONS (endpoint = 'gemini-2.0-flash');

CREATE MODEL IF NOT EXISTS `cleaned_data.text_embedding_005`
  REMOTE WITH CONNECTION `us-central1.vertex-ai`
  OPTIONS (endpoint = 'text-embedding-005');

-------------------------------------------------------------------------------------------------------------------
-- Create embeddings on each room feature
-------------------------------------------------------------------------------------------------------------------
-- This will be our working table for the demo and we now have a primary key
CREATE TABLE IF NOT EXISTS `cleaned_data.pricing` AS 
SELECT ROW_NUMBER() OVER (PARTITION BY 1) AS pricing_id,
       *
  FROM `cleaned_data.pricing_1`;
  
-- Split the pipes (|), unest the array, and then create the embeddings
-- drop table `cleaned_data.pricing_embeddings`
CREATE TABLE IF NOT EXISTS `cleaned_data.pricing_embeddings` AS
WITH split_room_features AS
(
  SELECT pricing_id, SPLIT(LOWER(room_features), '|') AS room_features_array
    FROM `cleaned_data.pricing`
),
room_features AS
(
  SELECT pricing_id, room_feature
    FROM split_room_features
         JOIN UNNEST(room_features_array) AS room_feature
)
SELECT pricing_id,
       room_feature,
       ml_generate_embedding_result AS vector_embedding
  FROM ML.GENERATE_EMBEDDING(MODEL `cleaned_data.text_embedding_005`,
                            (SELECT pricing_id, room_feature, room_feature AS content FROM room_features),
                             STRUCT(TRUE AS flatten_json_output,
                                    'SEMANTIC_SIMILARITY' as task_type,
                                    768 AS output_dimensionality));



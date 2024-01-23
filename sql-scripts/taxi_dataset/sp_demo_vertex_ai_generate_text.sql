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
    - Generates reviews of taxi trips by assigning random taxi driver names and passenger names.
    - If you have your own reviews or text data, you can use that instead of the generated data.

References:
    - https://cloud.google.com/bigquery/docs/generate-text
    - https://cloud.google.com/vertex-ai/pricing#generative_ai_models
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-generate-text
    - https://cloud.google.com/vertex-ai/docs/generative-ai/text/text-overview

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`;
    DROP MODEL IF EXISTS `${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`;

- Create the connection
- Add Vertex AI User to role of connection
*/
  

CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm` 
CLUSTER BY (RowNumber)
AS
WITH Names AS
(
  -- Order the names
  SELECT name,
         ROW_NUMBER() OVER (ORDER BY name) AS row_number
    FROM `${project_id}.${bigquery_taxi_dataset}.biglake_random_name`
)
-- SELECT * FROM Names;
, TaxiTrips AS
(
  -- Get 1000 rows of data
  SELECT PULocationID,
         DOLocationID,
         Passenger_Count,
         Trip_Distance,
         Fare_Amount,
         Tip_Amount,
         Total_Amount,
         ROW_NUMBER() OVER (ORDER BY Pickup_DateTime) AS row_number
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
  WHERE PartitionDate = '2022-01-01'
  ORDER BY Pickup_DateTime
  LIMIT 1000
)
-- SELECT * FROM TaxiTrips;
, AssignNames AS 
(
  SELECT TaxiTrips.row_number AS RowNumber,
         TaxiTrips.PULocationID,
         TaxiTrips.DOLocationID,
         TaxiTrips.Passenger_Count,
         TaxiTrips.Trip_Distance,
         TaxiTrips.Fare_Amount,
         TaxiTrips.Tip_Amount,
         TaxiTrips.Total_Amount,
         DriverName.Name AS DriverName,
         PassengerName.Name AS PassengerName,
         CAST(NULL AS STRING) AS PassengerReview,
         CAST(NULL AS STRING) AS ReviewSentiment
    FROM TaxiTrips
         INNER JOIN Names AS DriverName
                 ON MOD(TaxiTrips.row_number, 25) = DriverName.row_number
         INNER JOIN Names AS PassengerName
                 ON CAST(ROUND(25 + RAND() * (1000 - 25)) AS INT) = PassengerName.row_number
)
SELECT *
  FROM AssignNames;


  -- Create the model that references Vertex AI PaLM APIs (text-bison)
/*
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.vertex-ai`
  OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_LARGE_LANGUAGE_MODEL_V1');
*/

-- New Syntax for specifying a model version text-bison@001 or text-bison@002 for latest or text-bison-32k@latest
CREATE OR REPLACE MODEL `${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`
  REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.vertex-ai`
  OPTIONS (endpoint = 'text-bison@002');

  
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
(
  key STRING,
  ml_generate_text_result JSON,
  ml_generate_text_status STRING,
  prompt STRING,
  json_results JSON
);

-- TRUNCATE TABLE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`;

EXECUTE IMMEDIATE """
INSERT INTO `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
(
  key,
  ml_generate_text_result,
  ml_generate_text_status,
  prompt
)
SELECT 'GENERATED-REVIEWS', ml_generate_text_result, ml_generate_text_status, prompt
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT 'Generate 10 to 25 reviews of taxi drivers which consist of both positive and negative reviews in a JSON format. Valid fields are review_text. JSON:' AS prompt),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";

/* Sample Result:
{"predictions":[{"citationMetadata":{"citations":[]},"content":"\n[\n  {\n    \"review_text\": \"The driver was very friendly and helpful. He made sure I got to my destination safely and on time. I would definitely recommend him to anyone looking for a taxi driver in the area.\"\n  },\n  {\n    \"review_text\": \"The driver was very professional and courteous. He made sure I was comfortable and safe during the ride. I would definitely use him again.\"\n  },\n  {\n    \"review_text\": \"The driver was very knowledgeable about the area and gave me some great recommendations for places to visit. He was also very friendly and made the ride enjoyable.\"\n  },\n  {\n    \"review_text\": \"The driver was very prompt and arrived on time. He was also very friendly and helpful. I would definitely recommend him to anyone looking for a taxi driver.\"\n  },\n  {\n    \"review_text\": \"The driver was very safe and careful. He made sure I got to my destination safely and on time. I would definitely use him again.\"\n  },\n  {\n    \"review_text\": \"The driver was very affordable and gave me a great price for the ride. He was also very friendly and made the ride enjoyable.\"\n  },\n  {\n    \"review_text\": \"The driver was very accommodating and went out of his way to make sure I was comfortable. He was also very knowledgeable about the area and gave me some great recommendations for places to visit.\"\n  },\n  {\n    \"review_text\": \"The driver was very professional and courteous. He made sure I was comfortable and safe during the ride. I would definitely use him again.\"\n  },\n  {\n    \"review_text\": \"The driver was very friendly and helpful. He made sure I got to my destination safely and on time. I would definitely recommend him to anyone looking for a taxi driver.\"\n  }\n]","safetyAttributes":{"blocked":false,"categories":[],"scores":[]}}]}
*/

SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
 WHERE key = 'GENERATED-REVIEWS';


-- Parse the generated JSON
-- Remove the \n
-- Parse back into JSON (we have JSON in JSON)
UPDATE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
  SET json_results = (
                      SELECT PARSE_JSON(REPLACE(STRING(ml_generate_text_result.predictions[0].content),"\n",""))
                        FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
                      WHERE key = 'GENERATED-REVIEWS'
 )
 WHERE key = 'GENERATED-REVIEWS';


-- Json results now parsed from LLM JSON
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
 WHERE key = 'GENERATED-REVIEWS';


-- Get each review as a row as a string (not a json datatype which had double quotes)
SELECT JSON_VALUE(reviews, '$.review_text') AS review
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
       CROSS JOIN UNNEST(JSON_QUERY_ARRAY(json_results)) AS reviews
 WHERE key = 'GENERATED-REVIEWS';


-- Update our main table with the reviews
UPDATE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
   SET PassengerReview = ReviewData.review
  FROM (
        SELECT JSON_VALUE(reviews, '$.review_text') AS review,
              ROW_NUMBER() OVER (ORDER BY CAST(ROUND(1 + RAND() * (1000 - 1)) AS INT)) AS RowNumber
          FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm_result`
              CROSS JOIN UNNEST(JSON_QUERY_ARRAY(json_results)) AS reviews
        WHERE key = 'GENERATED-REVIEWS'        
       ) AS ReviewData
WHERE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`.RowNumber = ReviewData.RowNumber;


-- See the updated data
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
ORDER BY RowNumber;


-- Run a query to understand the passenger reviews
EXECUTE IMMEDIATE """
SELECT *, JSON_VALUE(ml_generate_text_result.predictions[0].content,'$') AS Sentiment
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT CONCAT('Classify the sentiment of the following text as positive or negative. Text: ', PassengerReview, ' Sentiment:') AS prompt,
            RowNumber,
            DriverName,
            PassengerName,
            PassengerReview
      FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
    WHERE RowNumber IN (1,2)),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";

/* Sample Score:
{"predictions":[{"citationMetadata":{"citations":[]},"content":"positive","safetyAttributes":{"blocked":false,"categories":[],"scores":[]}}]}
*/

-- Update our main table with the review sentiment
EXECUTE IMMEDIATE """
UPDATE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
   SET ReviewSentiment = ReviewData.Sentiment
  FROM (
        SELECT *, JSON_VALUE(ml_generate_text_result.predictions[0].content,'$') AS Sentiment
        FROM
          ML.GENERATE_TEXT(
            MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
            (SELECT CONCAT('Classify the sentiment of the following text as positive or negative. Text: ', PassengerReview, ' Sentiment:') AS prompt,
                    RowNumber,
                    DriverName,
                    PassengerName,
                    PassengerReview
              FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
            WHERE PassengerReview IS NOT NULL),
            STRUCT(
              0.8 AS temperature,
              1024 AS max_output_tokens,
              0.95 AS top_p,
              40 AS top_k))  
       ) AS ReviewData
WHERE `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`.RowNumber = ReviewData.RowNumber;
""";


-- See our scoring results
SELECT *
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
 WHERE PassengerReview IS NOT NULL
 ORDER BY RowNumber;


-- Review the driver's reviews
SELECT DriverName,
        SUM(CASE WHEN ReviewSentiment = 'positive' THEN 1 ELSE 0 END) AS PositiveReviews,
        SUM(CASE WHEN ReviewSentiment = 'negative' THEN 1 ELSE 0 END) AS NegativeReviews
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips_cloud_ai_llm`
WHERE ReviewSentiment IS NOT NULL
GROUP BY DriverName;


-- Trip Reason





-- Other Samples
EXECUTE IMMEDIATE """
SELECT *
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT 'What is the answer to the equation: 10 + x + 34 = 100' AS prompt),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";


-- Sample from Docs
EXECUTE IMMEDIATE """
SELECT * 
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT 'Extract the technical specifications from the text below in a JSON format. Valid fields are name, network, ram, processor, storage, and color. Text: Google Pixel 7, 5G network, 8GB RAM, Tensor G2 processor, 128GB of storage, Lemongrass JSON:' AS prompt),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";

/*
{"predictions":[{"citationMetadata":{"citations":[]},"content":"{\n  \"name\": \"Google Pixel 7\",\n  \"network\": \"5G\",\n  \"ram\": \"8GB\",\n  \"processor\": \"Tensor G2\",\n  \"storage\": \"128GB\",\n  \"color\": \"Lemongrass\"\n}","safetyAttributes":{"blocked":false,"categories":[],"scores":[]}}]}
*/


EXECUTE IMMEDIATE """
SELECT *
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT 'Extract the items from the following text in a JSON format. Valid fields are name and sentiment. Text: I saw spiderman into the universe at my local movie theater.  I had popcorn and a soda.  I was on the edge of my seat the entire time.  I would rate it 9 out of 10 stars. JSON:' AS prompt),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";


EXECUTE IMMEDIATE """
SELECT *
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT 'Extract the items from the following text in a JSON format. Valid fields are name and sentiment. Text: I saw the new spiderman movie this weekend and had a great time with my family.  My kids could not stop talking about the movie in the car. JSON:' AS prompt),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";

 /*
{"predictions":[{"citationMetadata":{"citations":[]},"content":"{\n  \"name\": \"Spiderman\",\n  \"sentiment\": \"positive\"\n}","safetyAttributes":{"blocked":false,"categories":[],"scores":[]}}]}
 */      


EXECUTE IMMEDIATE """
SELECT *
FROM
  ML.GENERATE_TEXT(
    MODEL`${project_id}.${bigquery_taxi_dataset}.cloud_ai_llm_v1`,
    (SELECT 'Extract the nouns from the following sentenance.  My cat likes to fish.' AS prompt),
    STRUCT(
      0.8 AS temperature,
      1024 AS max_output_tokens,
      0.95 AS top_p,
      40 AS top_k));
""";

/*
{"predictions":[{"citationMetadata":{"citations":[]},"content":"cat, fish\n\nA noun is a word that names a person, place, thing, animal, action, or idea. In this sentence, \"cat\" and \"fish\" are the nouns.","safetyAttributes":{"blocked":false,"categories":[],"scores":[]}}]}
*/

/* Banking Ideas (Call Center):
- How many calls about checking accounts
- How many calls about loans
- What are the common themes in the calls
- How many calls are postive
- How many were complaining
- What operator has the most complaints
*/

-- So Terraform does not end with a comment
SELECT 1;
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
      - Ingests the data from Iceberg into BigQuery internal tables.  This lets us create
        items like BigSearch indexes and cluster more efficiently.
  
  Description: 
      - 
      
  Show:
      - 
  
  References:
      - 
  
  Clean up / Reset script:
      DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_payment_type`;
      DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone`;
      DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_payment_type`;
      DROP TABLE IF EXISTS `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`;

  */


-- Ingest the data to BigQuery
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_payment_type`
CLUSTER BY payment_type_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_payment_type_iceberg`;


-- Ingest the data to BigQuery
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone`
CLUSTER BY location_id
AS
SELECT *
  FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_zone_iceberg`;


-- Ingest the data to BigQuery
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip`
CLUSTER BY pickup_datetime, pickup_location_id
AS
SELECT  
    rideshare_trip_id,
    pickup_location_id,
    pickup_datetime,
    dropoff_location_id,
    dropoff_datetime,
    ROUND(CAST (ride_distance AS NUMERIC), 5, "ROUND_HALF_EVEN") AS ride_distance,
    is_airport,
    payment_type_id,
    ROUND(CAST (fare_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") AS fare_amount,
    ROUND(CAST (tip_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") AS tip_amount,
    ROUND(CAST (taxes_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") AS taxes_amount,
    ROUND(CAST (fare_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") + 
      ROUND(CAST (tip_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") + 
      ROUND(CAST (taxes_amount AS NUMERIC), 2, "ROUND_HALF_EVEN") AS total_amount,
    credit_card_number,
    credit_card_expire_date,
    credit_card_cvv_code,
    partition_date
  FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.biglake_rideshare_trip_iceberg`;
  

-- Holds the website scored data
CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`
  (location_id INTEGER,
  borough STRING,
  zone STRING,
  latitude FLOAT64,
  longitude FLOAT64,
  geo_point GEOGRAPHY,
  pickup_year STRING,
  pickup_month STRING,
  pickup_day STRING,
  pickup_day_of_week STRING,
  pickup_hour STRING,
  ride_distance STRING,
  is_raining BOOLEAN,
  is_snowing BOOLEAN,
  people_traveling_cnt INTEGER,
  people_cnt INTEGER,
  is_high_value_ride BOOLEAN,  
  predicted_is_high_value_ride FLOAT64,
  execution_date DATETIME)
 OPTIONS (description = 'Holds the ML scoring results');


-- Create an index (if not exists) for exact matching
IF NOT EXISTS (SELECT  1
                  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.INFORMATION_SCHEMA.SEARCH_INDEXES`
                WHERE index_name = '${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigsearch_bigquery_rideshare_trip')
  THEN
    CREATE SEARCH INDEX `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigsearch_bigquery_rideshare_trip` 
        ON `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_trip` (ALL COLUMNS)
        OPTIONS (analyzer = 'NO_OP_ANALYZER');
END IF;

-- Check our index (index_status = "Active", "total storage bytes" = 117 GB)
-- See the unindexed_row_count (rows not indexed)
-- Make sure your coverage_percent = 100 (so we know we are done indexing)
SELECT * -- table_name, index_name, ddl, coverage_percentage
  FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.INFORMATION_SCHEMA.SEARCH_INDEXES`
 WHERE index_status = 'ACTIVE';


CREATE OR REPLACE TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_images_ml_detection`
CLUSTER BY location_id,image_date
AS
 
 WITH ScoreAI AS
(
    SELECT uri,
           location_id,
           image_date,
           vision_ai_localize_objects,
           vision_ai_detect_labels,
           vision_ai_detect_landmarks,
           vision_ai_detect_logos
      FROM `${project_id}.${bigquery_rideshare_lakehouse_enriched_dataset}.bigquery_rideshare_images_ml_score`
)
SELECT uri,
       'Object' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.name),'"','') AS name,
       CAST(REPLACE(JSON_VALUE(item.score),'"','') AS FLOAT64) AS score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_localize_objects.localized_object_annotations)) AS item
UNION ALL
SELECT uri,
       'Label' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.description),'"','') AS name,
       CAST(REPLACE(JSON_VALUE(item.score),'"','') AS FLOAT64) AS score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_detect_labels.label_annotations)) AS item
UNION ALL
SELECT uri,
       'Landmark' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.description),'"','') AS name,
       CAST(REPLACE(JSON_VALUE(item.score),'"','') AS FLOAT64) AS score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_detect_landmarks.landmark_annotations)) AS item
UNION ALL
SELECT uri,
       'Logo' AS detection_type,
       location_id,
       image_date,
       REPLACE(JSON_VALUE(item.description),'"','') AS name,
       CAST(REPLACE(JSON_VALUE(item.score),'"','') AS FLOAT64) AS score
 FROM  ScoreAI, UNNEST(JSON_QUERY_ARRAY(ScoreAI.vision_ai_detect_logos.logo_annotations)) AS item;


ALTER TABLE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone`
  ADD COLUMN IF NOT EXISTS latitude  FLOAT64,
  ADD COLUMN IF NOT EXISTS longitude FLOAT64,
  ADD COLUMN IF NOT EXISTS geo_point GEOGRAPHY;

  
-- Add in GPS data
UPDATE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone` AS parent
   SET latitude = child.latitude,
       longitude = child.longitude
  FROM (SELECT 1 AS location_id, 40.689529 AS latitude, -74.174461 AS longitude UNION ALL
        SELECT 2 AS location_id, 40.70255925 AS latitude, -73.81335454 AS longitude UNION ALL
        SELECT 3 AS location_id, 40.8627648 AS latitude, -73.843439 AS longitude UNION ALL
        SELECT 4 AS location_id, 40.7261843 AS latitude, -73.97888636 AS longitude UNION ALL
        SELECT 5 AS location_id, 40.55459848 AS latitude, -74.18520474 AS longitude UNION ALL
        SELECT 6 AS location_id, 40.62706857 AS latitude, -74.11112868 AS longitude UNION ALL
        SELECT 7 AS location_id, 40.76877183 AS latitude, -73.92405867 AS longitude UNION ALL
        SELECT 8 AS location_id, 40.77794596 AS latitude, -73.92382049 AS longitude UNION ALL
        SELECT 9 AS location_id, 40.76424655 AS latitude, -73.78326043 AS longitude UNION ALL
        SELECT 10 AS location_id, 40.67392968 AS latitude, -73.78604646 AS longitude UNION ALL
        SELECT 11 AS location_id, 40.60451689 AS latitude, -74.0099318 AS longitude UNION ALL
        SELECT 12 AS location_id, 40.7027147 AS latitude, -74.0158059 AS longitude UNION ALL
        SELECT 13 AS location_id, 40.7100665 AS latitude, -74.0163668 AS longitude UNION ALL
        SELECT 14 AS location_id, 40.63262586 AS latitude, -74.03044346 AS longitude UNION ALL
        SELECT 15 AS location_id, 40.79459134 AS latitude, -73.78098737 AS longitude UNION ALL
        SELECT 16 AS location_id, 40.77186783 AS latitude, -73.77659453 AS longitude UNION ALL
        SELECT 17 AS location_id, 40.69050511 AS latitude, -73.93839425 AS longitude UNION ALL
        SELECT 18 AS location_id, 40.8721339 AS latitude, -73.8878636 AS longitude UNION ALL
        SELECT 19 AS location_id, 40.74095521 AS latitude, -73.71584278 AS longitude UNION ALL
        SELECT 20 AS location_id, 40.8588558 AS latitude, -73.8859493 AS longitude UNION ALL
        SELECT 21 AS location_id, 40.61391129 AS latitude, -73.99291731 AS longitude UNION ALL
        SELECT 22 AS location_id, 40.61413933 AS latitude, -73.99283148 AS longitude UNION ALL
        SELECT 23 AS location_id, 40.6078324 AS latitude, -74.1791761 AS longitude UNION ALL
        SELECT 24 AS location_id, 40.79882246 AS latitude, -73.97324356 AS longitude UNION ALL
        SELECT 25 AS location_id, 40.68650641 AS latitude, -73.98735704 AS longitude UNION ALL
        SELECT 26 AS location_id, 40.63515555 AS latitude, -73.9918568 AS longitude UNION ALL
        SELECT 27 AS location_id, 40.56762687 AS latitude, -73.86567155 AS longitude UNION ALL
        SELECT 28 AS location_id, 40.71401772 AS latitude, -73.79751533 AS longitude UNION ALL
        SELECT 29 AS location_id, 40.57474243 AS latitude, -73.96003611 AS longitude UNION ALL
        SELECT 30 AS location_id, 40.62450328 AS latitude, -73.82600446 AS longitude UNION ALL
        SELECT 31 AS location_id, 40.85712333 AS latitude, -73.87644768 AS longitude UNION ALL
        SELECT 32 AS location_id, 40.8631879 AS latitude, -73.8654924 AS longitude UNION ALL
        SELECT 33 AS location_id, 40.69645501 AS latitude, -73.99829935 AS longitude UNION ALL
        SELECT 34 AS location_id, 40.70578592 AS latitude, -73.97303837 AS longitude UNION ALL
        SELECT 35 AS location_id, 40.66490534 AS latitude, -73.91373099 AS longitude UNION ALL
        SELECT 36 AS location_id, 40.69997997 AS latitude, -73.92537004 AS longitude UNION ALL
        SELECT 37 AS location_id, 40.69229245 AS latitude, -73.92309264 AS longitude UNION ALL
        SELECT 38 AS location_id, 40.7082743 AS latitude, -73.738517 AS longitude UNION ALL
        SELECT 39 AS location_id, 40.64195989 AS latitude, -73.8997856 AS longitude UNION ALL
        SELECT 40 AS location_id, 40.6810663 AS latitude, -73.99580481 AS longitude UNION ALL
        SELECT 41 AS location_id, 40.81492678 AS latitude, -73.95287643 AS longitude UNION ALL
        SELECT 42 AS location_id, 40.81453702 AS latitude, -73.95613799 AS longitude UNION ALL
        SELECT 43 AS location_id, 40.7943199 AS latitude, -73.9548079 AS longitude UNION ALL
        SELECT 44 AS location_id, 40.54183504 AS latitude, -74.20614413 AS longitude UNION ALL
        SELECT 45 AS location_id, 40.7162475 AS latitude, -73.9961608 AS longitude UNION ALL
        SELECT 46 AS location_id, 40.8472653 AS latitude, -73.7864806 AS longitude UNION ALL
        SELECT 47 AS location_id, 40.8496395 AS latitude, -73.8966048 AS longitude UNION ALL
        SELECT 48 AS location_id, 40.73548 AS latitude, -73.990616 AS longitude UNION ALL
        SELECT 49 AS location_id, 40.69030707 AS latitude, -73.96645097 AS longitude UNION ALL
        SELECT 50 AS location_id, 40.76379479 AS latitude, -73.99531094 AS longitude UNION ALL
        SELECT 51 AS location_id, 40.8704192 AS latitude, -73.8285808 AS longitude UNION ALL
        SELECT 52 AS location_id, 40.68988887 AS latitude, -73.99768504 AS longitude UNION ALL
        SELECT 53 AS location_id, 40.78556044 AS latitude, -73.84007467 AS longitude UNION ALL
        SELECT 54 AS location_id, 40.68748634 AS latitude, -74.00604416 AS longitude UNION ALL
        SELECT 55 AS location_id, 40.57467769 AS latitude, -73.98075101 AS longitude UNION ALL
        SELECT 56 AS location_id, 40.74168255 AS latitude, -73.86001672 AS longitude UNION ALL
        SELECT 57 AS location_id, 40.74236642 AS latitude, -73.85778492 AS longitude UNION ALL
        SELECT 58 AS location_id, 40.8408525 AS latitude, -73.8200885 AS longitude UNION ALL
        SELECT 59 AS location_id, 40.8364979 AS latitude, -73.8977667 AS longitude UNION ALL
        SELECT 60 AS location_id, 40.8326817 AS latitude, -73.8916726 AS longitude UNION ALL
        SELECT 61 AS location_id, 40.67411807 AS latitude, -73.95469131 AS longitude UNION ALL
        SELECT 62 AS location_id, 40.67594597 AS latitude, -73.94529197 AS longitude UNION ALL
        SELECT 63 AS location_id, 40.68489029 AS latitude, -73.88585879 AS longitude UNION ALL
        SELECT 64 AS location_id, 40.76773833 AS latitude, -73.74717441 AS longitude UNION ALL
        SELECT 65 AS location_id, 40.69309054 AS latitude, -73.98567413 AS longitude UNION ALL
        SELECT 66 AS location_id, 40.70347766 AS latitude, -73.9846363 AS longitude UNION ALL
        SELECT 67 AS location_id, 40.62028797 AS latitude, -74.01337622 AS longitude UNION ALL
        SELECT 68 AS location_id, 40.7424184 AS latitude, -74.00553705 AS longitude UNION ALL
        SELECT 69 AS location_id, 40.8305395 AS latitude, -73.9157021 AS longitude UNION ALL
        SELECT 70 AS location_id, 40.77726893 AS latitude, -73.87969751 AS longitude UNION ALL
        SELECT 71 AS location_id, 40.63717133 AS latitude, -73.92813335 AS longitude UNION ALL
        SELECT 72 AS location_id, 40.65758563 AS latitude, -73.921935 AS longitude UNION ALL
        SELECT 73 AS location_id, 40.75651045 AS latitude, -73.81034858 AS longitude UNION ALL
        SELECT 74 AS location_id, 40.80199351 AS latitude, -73.94945849 AS longitude UNION ALL
        SELECT 75 AS location_id, 40.80452735 AS latitude, -73.94851436 AS longitude UNION ALL
        SELECT 76 AS location_id, 40.66305774 AS latitude, -73.88430124 AS longitude UNION ALL
        SELECT 77 AS location_id, 40.65671919 AS latitude, -73.88913842 AS longitude UNION ALL
        SELECT 78 AS location_id, 40.8468091 AS latitude, -73.889962 AS longitude UNION ALL
        SELECT 79 AS location_id, 40.727587 AS latitude, -73.9852824 AS longitude UNION ALL
        SELECT 80 AS location_id, 40.71973608 AS latitude, -73.93414856 AS longitude UNION ALL
        SELECT 81 AS location_id, 40.889208 AS latitude, -73.8312672 AS longitude UNION ALL
        SELECT 82 AS location_id, 40.74539039 AS latitude, -73.88109166 AS longitude UNION ALL
        SELECT 83 AS location_id, 40.73083694 AS latitude, -73.88702725 AS longitude UNION ALL
        SELECT 84 AS location_id, 40.5433066 AS latitude, -74.1642437 AS longitude UNION ALL
        SELECT 85 AS location_id, 40.65033295 AS latitude, -73.95432886 AS longitude UNION ALL
        SELECT 86 AS location_id, 40.59919178 AS latitude, -73.75064398 AS longitude UNION ALL
        SELECT 87 AS location_id, 40.71245812 AS latitude, -74.0082775 AS longitude UNION ALL
        SELECT 88 AS location_id, 40.7031938 AS latitude, -74.0118056 AS longitude UNION ALL
        SELECT 89 AS location_id, 40.64227636 AS latitude, -73.96029782 AS longitude UNION ALL
        SELECT 90 AS location_id, 40.7396684 AS latitude, -73.9909469 AS longitude UNION ALL
        SELECT 91 AS location_id, 40.62346015 AS latitude, -73.93279563 AS longitude UNION ALL
        SELECT 92 AS location_id, 40.77020385 AS latitude, -73.83050103 AS longitude UNION ALL
        SELECT 93 AS location_id, 40.74723429 AS latitude, -73.84953549 AS longitude UNION ALL
        SELECT 94 AS location_id, 40.856632 AS latitude, -73.8800028 AS longitude UNION ALL
        SELECT 95 AS location_id, 40.72557507 AS latitude, -73.84438939 AS longitude UNION ALL
        SELECT 96 AS location_id, 40.69680164 AS latitude, -73.86382814 AS longitude UNION ALL
        SELECT 97 AS location_id, 40.6949818 AS latitude, -73.97529812 AS longitude UNION ALL
        SELECT 98 AS location_id, 40.7360855 AS latitude, -73.7735591 AS longitude UNION ALL
        SELECT 99 AS location_id, 40.56446613 AS latitude, -74.18646961 AS longitude UNION ALL
        SELECT 100 AS location_id, 40.75436849 AS latitude, -73.99177334 AS longitude UNION ALL
        SELECT 101 AS location_id, 40.74742146 AS latitude, -73.70820798 AS longitude UNION ALL
        SELECT 102 AS location_id, 40.70196121 AS latitude, -73.87889709 AS longitude UNION ALL
        SELECT 103 AS location_id, 40.68863784 AS latitude, -74.01865504 AS longitude UNION ALL
        SELECT 104 AS location_id, 40.68863784 AS latitude, -74.01865504 AS longitude UNION ALL
        SELECT 105 AS location_id, 40.68863784 AS latitude, -74.01865504 AS longitude UNION ALL
        SELECT 106 AS location_id, 40.67556801 AS latitude, -73.98937951 AS longitude UNION ALL
        SELECT 107 AS location_id, 40.7386 AS latitude, -73.98647 AS longitude UNION ALL
        SELECT 108 AS location_id, 40.59684784 AS latitude, -73.97416048 AS longitude UNION ALL
        SELECT 109 AS location_id, 40.55467127 AS latitude, -74.15609452 AS longitude UNION ALL
        SELECT 110 AS location_id, 40.54938342 AS latitude, -74.12383787 AS longitude UNION ALL
        SELECT 111 AS location_id, 40.6580021 AS latitude, -73.99390247 AS longitude UNION ALL
        SELECT 112 AS location_id, 40.73171098 AS latitude, -73.95242504 AS longitude UNION ALL
        SELECT 113 AS location_id, 40.73359218 AS latitude, -74.00165722 AS longitude UNION ALL
        SELECT 114 AS location_id, 40.73436355 AS latitude, -74.00246172 AS longitude UNION ALL
        SELECT 115 AS location_id, 40.61871421 AS latitude, -74.0799138 AS longitude UNION ALL
        SELECT 116 AS location_id, 40.82623333 AS latitude, -73.95489866 AS longitude UNION ALL
        SELECT 117 AS location_id, 40.59537986 AS latitude, -73.79539506 AS longitude UNION ALL
        SELECT 118 AS location_id, 40.58700223 AS latitude, -74.16477545 AS longitude UNION ALL
        SELECT 119 AS location_id, 40.8385211 AS latitude, -73.9261998 AS longitude UNION ALL
        SELECT 120 AS location_id, 40.85388161 AS latitude, -73.92569556 AS longitude UNION ALL
        SELECT 121 AS location_id, 40.73527367 AS latitude, -73.80782567 AS longitude UNION ALL
        SELECT 122 AS location_id, 40.71411456 AS latitude, -73.75798821 AS longitude UNION ALL
        SELECT 123 AS location_id, 40.60108624 AS latitude, -73.95810463 AS longitude UNION ALL
        SELECT 124 AS location_id, 40.65701215 AS latitude, -73.84594769 AS longitude UNION ALL
        SELECT 125 AS location_id, 40.7271568 AS latitude, -74.0055594 AS longitude UNION ALL
        SELECT 126 AS location_id, 40.8166956 AS latitude, -73.8879584 AS longitude UNION ALL
        SELECT 127 AS location_id, 40.86515387 AS latitude, -73.92591538 AS longitude UNION ALL
        SELECT 128 AS location_id, 40.87252362 AS latitude, -73.92500131 AS longitude UNION ALL
        SELECT 129 AS location_id, 40.76000546 AS latitude, -73.88400314 AS longitude UNION ALL
        SELECT 130 AS location_id, 40.69866485 AS latitude, -73.78505094 AS longitude UNION ALL
        SELECT 131 AS location_id, 40.72334157 AS latitude, -73.78270221 AS longitude UNION ALL
        SELECT 132 AS location_id, 40.64357519 AS latitude, -73.78203392 AS longitude UNION ALL
        SELECT 133 AS location_id, 40.64083632 AS latitude, -73.97585797 AS longitude UNION ALL
        SELECT 134 AS location_id, 40.70692829 AS latitude, -73.82895566 AS longitude UNION ALL
        SELECT 135 AS location_id, 40.73144644 AS latitude, -73.82541773 AS longitude UNION ALL
        SELECT 136 AS location_id, 40.8653108 AS latitude, -73.9033336 AS longitude UNION ALL
        SELECT 137 AS location_id, 40.7422858 AS latitude, -73.977727 AS longitude UNION ALL
        SELECT 138 AS location_id, 40.77452936 AS latitude, -73.87185574 AS longitude UNION ALL
        SELECT 139 AS location_id, 40.67959577 AS latitude, -73.74333877 AS longitude UNION ALL
        SELECT 140 AS location_id, 40.7671182 AS latitude, -73.9564799 AS longitude UNION ALL
        SELECT 141 AS location_id, 40.7671182 AS latitude, -73.9564799 AS longitude UNION ALL
        SELECT 142 AS location_id, 40.7727507 AS latitude, -73.9822314 AS longitude UNION ALL
        SELECT 143 AS location_id, 40.7727507 AS latitude, -73.9822314 AS longitude UNION ALL
        SELECT 144 AS location_id, 40.71896041 AS latitude, -73.99751111 AS longitude UNION ALL
        SELECT 145 AS location_id, 40.74958515 AS latitude, -73.94812151 AS longitude UNION ALL
        SELECT 146 AS location_id, 40.75230392 AS latitude, -73.91626243 AS longitude UNION ALL
        SELECT 147 AS location_id, 40.8172685 AS latitude, -73.8977585 AS longitude UNION ALL
        SELECT 148 AS location_id, 40.68926635 AS latitude, -74.04452453 AS longitude UNION ALL
        SELECT 149 AS location_id, 40.60694765 AS latitude, -73.94866475 AS longitude UNION ALL
        SELECT 150 AS location_id, 40.57616787 AS latitude, -73.94517659 AS longitude UNION ALL
        SELECT 151 AS location_id, 40.7979238 AS latitude, -73.9638538 AS longitude UNION ALL
        SELECT 152 AS location_id, 40.81749555 AS latitude, -73.95613374 AS longitude UNION ALL
        SELECT 153 AS location_id, 40.87518582 AS latitude, -73.91249976 AS longitude UNION ALL
        SELECT 154 AS location_id, 40.59116403 AS latitude, -73.8906091 AS longitude UNION ALL
        SELECT 155 AS location_id, 40.61087096 AS latitude, -73.90813376 AS longitude UNION ALL
        SELECT 156 AS location_id, 40.63696462 AS latitude, -74.15871181 AS longitude UNION ALL
        SELECT 157 AS location_id, 40.7249024 AS latitude, -73.90829251 AS longitude UNION ALL
        SELECT 158 AS location_id, 40.7407558 AS latitude, -74.0084796 AS longitude UNION ALL
        SELECT 159 AS location_id, 40.7915135 AS latitude, -73.883338 AS longitude UNION ALL
        SELECT 160 AS location_id, 40.7201614 AS latitude, -73.8753083 AS longitude UNION ALL
        SELECT 161 AS location_id, 40.7584759 AS latitude, -73.975136 AS longitude UNION ALL
        SELECT 162 AS location_id, 40.7476358 AS latitude, -73.9767197 AS longitude UNION ALL
        SELECT 163 AS location_id, 40.7100665 AS latitude, -74.0163668 AS longitude UNION ALL
        SELECT 164 AS location_id, 40.7513343 AS latitude, -73.9868145 AS longitude UNION ALL
        SELECT 165 AS location_id, 40.62059119 AS latitude, -73.9618515 AS longitude UNION ALL
        SELECT 166 AS location_id, 40.80945321 AS latitude, -73.9675711 AS longitude UNION ALL
        SELECT 167 AS location_id, 40.8291532 AS latitude, -73.9004419 AS longitude UNION ALL
        SELECT 168 AS location_id, 40.8142658 AS latitude, -73.9129861 AS longitude UNION ALL
        SELECT 169 AS location_id, 40.8494305 AS latitude, -73.9060434 AS longitude UNION ALL
        SELECT 170 AS location_id, 40.7476293 AS latitude, -73.9767741 AS longitude UNION ALL
        SELECT 171 AS location_id, 40.766044 AS latitude, -73.8108024 AS longitude UNION ALL
        SELECT 172 AS location_id, 40.5793371 AS latitude, -74.10766666 AS longitude UNION ALL
        SELECT 173 AS location_id, 40.74400349 AS latitude, -73.84990792 AS longitude UNION ALL
        SELECT 174 AS location_id, 40.8749573 AS latitude, -73.8794619 AS longitude UNION ALL
        SELECT 175 AS location_id, 40.74504588 AS latitude, -73.75577654 AS longitude UNION ALL
        SELECT 176 AS location_id, 40.75511744 AS latitude, -73.97848793 AS longitude UNION ALL
        SELECT 177 AS location_id, 40.67916914 AS latitude, -73.91456199 AS longitude UNION ALL
        SELECT 178 AS location_id, 40.6131386 AS latitude, -73.9692767 AS longitude UNION ALL
        SELECT 179 AS location_id, 40.76591965 AS latitude, -73.91532291 AS longitude UNION ALL
        SELECT 180 AS location_id, 40.68421191 AS latitude, -73.84717744 AS longitude UNION ALL
        SELECT 181 AS location_id, 40.67025072 AS latitude, -73.98179425 AS longitude UNION ALL
        SELECT 182 AS location_id, 40.8356908 AS latitude, -73.8556916 AS longitude UNION ALL
        SELECT 183 AS location_id, 40.8494879 AS latitude, -73.8330986 AS longitude UNION ALL
        SELECT 184 AS location_id, 40.86566 AS latitude, -73.80791 AS longitude UNION ALL
        SELECT 185 AS location_id, 40.8542235 AS latitude, -73.8544131 AS longitude UNION ALL
        SELECT 186 AS location_id, 40.74817946 AS latitude, -73.99241786 AS longitude UNION ALL
        SELECT 187 AS location_id, 40.6360051 AS latitude, -74.1347652 AS longitude UNION ALL
        SELECT 188 AS location_id, 40.65877111 AS latitude, -73.95493795 AS longitude UNION ALL
        SELECT 189 AS location_id, 40.67990629 AS latitude, -73.97148363 AS longitude UNION ALL
        SELECT 190 AS location_id, 40.660285 AS latitude, -73.968988 AS longitude UNION ALL
        SELECT 191 AS location_id, 40.72121891 AS latitude, -73.73781077 AS longitude UNION ALL
        SELECT 192 AS location_id, 40.74391504 AS latitude, -73.82567902 AS longitude UNION ALL
        SELECT 193 AS location_id, 40.76175743 AS latitude, -73.93538157 AS longitude UNION ALL
        SELECT 194 AS location_id, 40.7987989 AS latitude, -73.921249 AS longitude UNION ALL
        SELECT 195 AS location_id, 40.67804805 AS latitude, -74.01414179 AS longitude UNION ALL
        SELECT 196 AS location_id, 40.72684136 AS latitude, -73.86018494 AS longitude UNION ALL
        SELECT 197 AS location_id, 40.69765644 AS latitude, -73.83207262 AS longitude UNION ALL
        SELECT 198 AS location_id, 40.70715764 AS latitude, -73.91026104 AS longitude UNION ALL
        SELECT 199 AS location_id, 40.7915135 AS latitude, -73.883338 AS longitude UNION ALL
        SELECT 200 AS location_id, 40.897481 AS latitude, -73.9047869 AS longitude UNION ALL
        SELECT 201 AS location_id, 40.58006625 AS latitude, -73.84390419 AS longitude UNION ALL
        SELECT 202 AS location_id, 40.76227683 AS latitude, -73.95120633 AS longitude UNION ALL
        SELECT 203 AS location_id, 40.65969386 AS latitude, -73.73545917 AS longitude UNION ALL
        SELECT 204 AS location_id, 40.54199846 AS latitude, -74.20502831 AS longitude UNION ALL
        SELECT 205 AS location_id, 40.69751547 AS latitude, -73.76056243 AS longitude UNION ALL
        SELECT 206 AS location_id, 40.64243774 AS latitude, -74.08486808 AS longitude UNION ALL
        SELECT 207 AS location_id, 40.75904714 AS latitude, -73.90542355 AS longitude UNION ALL
        SELECT 208 AS location_id, 40.8226007 AS latitude, -73.8095781 AS longitude UNION ALL
        SELECT 209 AS location_id, 40.7077824 AS latitude, -74.0016961 AS longitude UNION ALL
        SELECT 210 AS location_id, 40.60000577 AS latitude, -73.94708175 AS longitude UNION ALL
        SELECT 211 AS location_id, 40.7217583 AS latitude, -73.9998576 AS longitude UNION ALL
        SELECT 212 AS location_id, 40.8081547 AS latitude, -73.9308769 AS longitude UNION ALL
        SELECT 213 AS location_id, 40.8203 AS latitude, -73.84832 AS longitude UNION ALL
        SELECT 214 AS location_id, 40.5857646 AS latitude, -74.08265298 AS longitude UNION ALL
        SELECT 215 AS location_id, 40.68272465 AS latitude, -73.79118088 AS longitude UNION ALL
        SELECT 216 AS location_id, 40.68171935 AS latitude, -73.81560755 AS longitude UNION ALL
        SELECT 217 AS location_id, 40.70837968 AS latitude, -73.95811968 AS longitude UNION ALL
        SELECT 218 AS location_id, 40.67422302 AS latitude, -73.77917019 AS longitude UNION ALL
        SELECT 219 AS location_id, 40.70712515 AS latitude, -73.73905047 AS longitude UNION ALL
        SELECT 220 AS location_id, 40.8823853 AS latitude, -73.9040899 AS longitude UNION ALL
        SELECT 221 AS location_id, 40.62704573 AS latitude, -74.07794184 AS longitude UNION ALL
        SELECT 222 AS location_id, 40.64770117 AS latitude, -73.88373269 AS longitude UNION ALL
        SELECT 223 AS location_id, 40.77483751 AS latitude, -73.90379064 AS longitude UNION ALL
        SELECT 224 AS location_id, 40.7341135 AS latitude, -73.9777159 AS longitude UNION ALL
        SELECT 225 AS location_id, 40.68263057 AS latitude, -73.93678058 AS longitude UNION ALL
        SELECT 226 AS location_id, 40.74480293 AS latitude, -73.91663703 AS longitude UNION ALL
        SELECT 227 AS location_id, 40.65465381 AS latitude, -74.01419849 AS longitude UNION ALL
        SELECT 228 AS location_id, 40.65198402 AS latitude, -74.01231022 AS longitude UNION ALL
        SELECT 229 AS location_id, 40.7555029 AS latitude, -73.9680851 AS longitude UNION ALL
        SELECT 230 AS location_id, 40.7574046 AS latitude, -73.9859194 AS longitude UNION ALL
        SELECT 231 AS location_id, 40.7182569 AS latitude, -74.0070461 AS longitude UNION ALL
        SELECT 232 AS location_id, 40.71265 AS latitude, -73.9899961 AS longitude UNION ALL
        SELECT 233 AS location_id, 40.7131332 AS latitude, -74.0040434 AS longitude UNION ALL
        SELECT 234 AS location_id, 40.7027147 AS latitude, -74.0158059 AS longitude UNION ALL
        SELECT 235 AS location_id, 40.8596011 AS latitude, -73.9077775 AS longitude UNION ALL
        SELECT 236 AS location_id, 40.7733764 AS latitude, -73.9645352 AS longitude UNION ALL
        SELECT 237 AS location_id, 40.7742661 AS latitude, -73.9572831 AS longitude UNION ALL
        SELECT 238 AS location_id, 40.7946135 AS latitude, -73.97274548 AS longitude UNION ALL
        SELECT 239 AS location_id, 40.7946135 AS latitude, -73.9716832 AS longitude UNION ALL
        SELECT 240 AS location_id, 40.8910726 AS latitude, -73.9003616 AS longitude UNION ALL
        SELECT 241 AS location_id, 40.8842713 AS latitude, -73.8874432 AS longitude UNION ALL
        SELECT 242 AS location_id, 40.8478817 AS latitude, -73.8528384 AS longitude UNION ALL
        SELECT 243 AS location_id, 40.85241917 AS latitude, -73.93838802 AS longitude UNION ALL
        SELECT 244 AS location_id, 40.84671521 AS latitude, -73.94423523 AS longitude UNION ALL
        SELECT 245 AS location_id, 40.62733476 AS latitude, -74.1140894 AS longitude UNION ALL
        SELECT 246 AS location_id, 40.75343405 AS latitude, -74.00085926 AS longitude UNION ALL
        SELECT 247 AS location_id, 40.8316343 AS latitude, -73.9225191 AS longitude UNION ALL
        SELECT 248 AS location_id, 40.8399335 AS latitude, -73.8778999 AS longitude UNION ALL
        SELECT 249 AS location_id, 40.7349698 AS latitude, -74.0047388 AS longitude UNION ALL
        SELECT 250 AS location_id, 40.8402844 AS latitude, -73.8471544 AS longitude UNION ALL
        SELECT 251 AS location_id, 40.6192352 AS latitude, -74.1279993 AS longitude UNION ALL
        SELECT 252 AS location_id, 40.79354692 AS latitude, -73.80885334 AS longitude UNION ALL
        SELECT 253 AS location_id, 40.76091029 AS latitude, -73.84087083 AS longitude UNION ALL
        SELECT 254 AS location_id, 40.871338 AS latitude, -73.8613946 AS longitude UNION ALL
        SELECT 255 AS location_id, 40.7181255 AS latitude, -73.95493106 AS longitude UNION ALL
        SELECT 256 AS location_id, 40.70739988 AS latitude, -73.95672716 AS longitude UNION ALL
        SELECT 257 AS location_id, 40.65420544 AS latitude, -73.97934261 AS longitude UNION ALL
        SELECT 258 AS location_id, 40.69383856 AS latitude, -73.858056 AS longitude UNION ALL
        SELECT 259 AS location_id, 40.8992412 AS latitude, -73.8460848 AS longitude UNION ALL
        SELECT 260 AS location_id, 40.75651157 AS latitude, -73.90473691 AS longitude UNION ALL
        SELECT 261 AS location_id, 40.71177 AS latitude, -74.01236 AS longitude UNION ALL
        SELECT 262 AS location_id, 40.7768038 AS latitude, -73.9493594 AS longitude UNION ALL
        SELECT 263 AS location_id, 40.7768038 AS latitude, -73.9493594 AS longitude UNION ALL
        SELECT 264 AS location_id, 40.689529 AS latitude, -74.174461 AS longitude UNION ALL
        SELECT 265 AS location_id, 40.689529 AS latitude, -74.174461 AS longitude) AS child
WHERE parent.location_id = child.location_id;

-- Update Geograph data
UPDATE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone`
  SET geo_point = ST_GEOGPOINT(longitude, latitude)
  WHERE latitude IS NOT NULL;

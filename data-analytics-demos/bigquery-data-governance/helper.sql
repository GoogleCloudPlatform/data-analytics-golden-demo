/*##################################################################################
# Copyright 2024 Google LLC
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

-- To quickly copy all tables (need to exclude object table)
SELECT 'CREATE OR REPLACE TABLE `PROJECT-ID.governed_data_raw.' || table_name || '` COPY `PROJECT-ID.governed_data_raw.' || table_name || '` ;'
  FROM governed_data_raw.INFORMATION_SCHEMA.TABLES
 WHERE table_type = 'BASE TABLE'  
 ORDER BY table_name;

-- Sample Vector Search query
-- Get the top 100 customers that match biking which will match "cycling"
SELECT query.content AS search_string,
       base.customer_profile_data AS customer_profile_data,
       distance
  FROM VECTOR_SEARCH( ( -- table to search
                       SELECT customer_profile_data, customer_profile_data_embedding 
                         FROM `PROJECT-ID.governed_data_raw.customer_marketing_profile` 
                        WHERE ARRAY_LENGTH(customer_profile_data_embedding) = 768
                      ),
                      'customer_profile_data_embedding', -- the column name that contains our embedding (from query above)
                      (
                       SELECT text_embedding, content  -- encode our data to search
                         FROM ML.GENERATE_TEXT_EMBEDDING(MODEL `${project_id}.${bigquery_governed_data_raw_dataset}.google-textembedding`,
                                                         (SELECT 'biking'AS content),                                                             
                                                         STRUCT(TRUE AS flatten_json_output, 
                                                                'SEMANTIC_SIMILARITY' as task_type,
                                                                 768 AS output_dimensionality)
                                                          )
                      ),
                      'text_embedding', -- the column name of our newly embedded data (from query above)
                      top_k => 100
                      )
ORDER BY distance;
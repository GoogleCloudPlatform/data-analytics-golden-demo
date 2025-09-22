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

CREATE MODEL IF NOT EXISTS `${project_id}.${bigquery_data_analytics_agent_metadata_dataset}.textembedding_model`
  REMOTE WITH CONNECTION `${project_id}.${bigquery_non_multi_region}.vertex-ai`
  OPTIONS (endpoint = 'text-embedding-005');


CREATE OR REPLACE TABLE `${bigquery_data_analytics_agent_metadata_dataset}.vector_embedding_metadata` (
    project_id     STRING       OPTIONS(description="The BigQuery project for which the vector embedding is generated."),
    dataset_name   STRING       OPTIONS(description="The dataset for which the vector embedding is generated."),
    table_name     STRING       OPTIONS(description="The table for which the vector embedding is generated."),
    column_name    STRING       OPTIONS(description="The column for which the vector embedding is generated."),
    text_content   STRING       OPTIONS(description="The value or content which was embedded."),       
    text_embedding ARRAY<FLOAT64> OPTIONS(description="The vector embedding generated with text-embedding-005.")
)
OPTIONS(
    description="Contains the distinct values of every string column for every dataset and table in the current BigQuery project.  This is used for NL2SQL to lookup the actual value of fields that a human might want to use in the queries."
);

-- You can also review the code the performs this in the notebook
LOAD DATA INTO `${bigquery_data_analytics_agent_metadata_dataset}.vector_embedding_metadata`
FROM FILES ( format = 'AVRO', enable_logical_types = true, 
uris = ['gs://data-analytics-golden-demo/data-analytics-agent/v1/Data-Export/vector_embedding_metadata/vector_embedding_metadata_*.avro']);

UPDATE `${bigquery_data_analytics_agent_metadata_dataset}.vector_embedding_metadata`
   SET project_id = '${project_id}'
 WHERE TRUE;

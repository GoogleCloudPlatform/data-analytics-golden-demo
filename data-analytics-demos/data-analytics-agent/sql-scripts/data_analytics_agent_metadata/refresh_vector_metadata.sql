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
    - Creates vector embeddings for every string field in the database

Description: 
    - Loops though all datasets (a few are excluded) and gets distinct values from each table

References:
    - 

Clean up / Reset script:
    -  n/a

*/

TRUNCATE TABLE `data_analytics_agent_metadata.vector_embedding_metadata`;

FOR record IN (
  SELECT
    table_catalog AS project_id,
    table_schema AS dataset_name,
    table_name,
    column_name
  FROM
    `region-${bigquery_non_multi_region}`.INFORMATION_SCHEMA.COLUMNS
  WHERE
    data_type = 'STRING'
    AND ENDS_WITH(column_name, '_id') = FALSE
    -- Exclude the staging load and the metadata itself (it does not need to index itself)
    AND table_schema NOT IN ('agentic_beans_raw_staging_load','data_analytics_agent_metadata')
)
DO
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `data_analytics_agent_metadata.vector_embedding_metadata`
    (project_id, dataset_name, table_name, column_name, text_content, text_embedding)
    SELECT
      '%s' AS project_id,
      '%s' AS dataset_name,
      '%s' AS table_name,
      '%s' AS column_name,
      content AS text_content,
      text_embedding
    FROM
      ML.GENERATE_TEXT_EMBEDDING(
        MODEL `data_analytics_agent_metadata.textembedding_model`,
        (SELECT DISTINCT %s AS content FROM `%s.%s.%s`),
        STRUCT(TRUE AS flatten_json_output, 'SEMANTIC_SIMILARITY' as task_type, 768 AS output_dimensionality)
      );
  """,
  record.project_id,
  record.dataset_name,
  record.table_name,
  record.column_name,
  record.column_name,
  record.project_id,
  record.dataset_name,
  record.table_name
  );
END FOR;

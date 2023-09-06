/*##################################################################################
  # Copyright 2023 Google LLC
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
      - Deploy Cloud function for Speech To Text Analysis
  
  Description: 
      - Customers have audios on their Data Lake.  
      - Customers want to gain insights to this data which is typically operated on at a file level
      - Users want an easy way to navigate and find items on data lakes
  
  
  Clean up / Reset script:
    DROP FUNCTION IF EXISTS `${project_id}.${bigquery_rideshare_llm_raw_dataset}.ext_udf_ai_extract_text`;
    
  */

-- Create the Function Link between BQ and the Cloud Function
CREATE OR REPLACE FUNCTION `${project_id}.${bigquery_rideshare_llm_raw_dataset}.ext_udf_ai_extract_text` (uri STRING) RETURNS STRING 
    REMOTE WITH CONNECTION `${project_id}.${bigquery_region}.cloud-function` 
    OPTIONS 
    (endpoint = 'https://${cloud_function_region}-${project_id}.cloudfunctions.net/bigquery_external_function', 
    user_defined_context = [("mode","extract_text_uri")],
    max_batching_rows = 10
    );
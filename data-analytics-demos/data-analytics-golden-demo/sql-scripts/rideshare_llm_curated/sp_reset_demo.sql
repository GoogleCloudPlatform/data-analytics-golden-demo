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
      - 

  Description: 
      - Full reset of demo (everything back to a clean beginning state)

  Reference:
      -

  Clean up / Reset script:
      -  n/a      
*/

-- RAW
CALL `${project_id}.${bigquery_rideshare_llm_raw_dataset}.sp_step_00_initialize`();
CALL `${project_id}.${bigquery_rideshare_llm_raw_dataset}.sp_step_01_deploy_udf`();

-- ENRICHED
CALL `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sp_step_00_initialize`();
CALL `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sp_step_01_quantitative_analysis`();
CALL `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sp_step_02_extract_driver_attributes`();
CALL `${project_id}.${bigquery_rideshare_llm_enriched_dataset}.sp_step_03_extract_customer_attributes`();

-- CURATED
CALL `${project_id}.${bigquery_rideshare_llm_curated_dataset}.sp_step_00_initialize`();

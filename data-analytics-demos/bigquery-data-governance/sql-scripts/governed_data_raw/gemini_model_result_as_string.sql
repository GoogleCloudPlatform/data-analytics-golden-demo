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

/*
Author: Adam Paternostro 

Use Cases:
    - Used when calling ML.GENERATE_TEXT

Description: 
    - Retrieves the JSON result from a prediction

References:
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-generate-text

Clean up / Reset script:

*/

REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(JSON_VALUE(input.candidates[0].content.parts[0].text),'\n',' '),'\"','"'),'``` JSON',''),'```json',''),'```','')

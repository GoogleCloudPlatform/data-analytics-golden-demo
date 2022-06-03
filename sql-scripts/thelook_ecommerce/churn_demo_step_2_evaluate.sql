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
Author: Polong Lin

Use Cases:
    - Show in code or show in UI

Description: 
    - Evaluate the model using code. Default threshold is 0.5, which is modifiable.

Show:
    - the resulting evaluation metrics (e.g. ROC_AUC score, accuracy score)

References:
    - https://cloud.google.com/bigquery-ml/docs/reference/standard-sql/bigqueryml-syntax-evaluate

Clean up / Reset script:
    - n/a
*/


EXECUTE IMMEDIATE format("""
  SELECT *
    FROM ML.EVALUATE(MODEL `${project_id}`.${bigquery_thelook_ecommerce_dataset}.model_churn,
                     (SELECT * FROM `${project_id}`.${bigquery_thelook_ecommerce_dataset}.training_data),
                     STRUCT(0.5 as threshold));
""");
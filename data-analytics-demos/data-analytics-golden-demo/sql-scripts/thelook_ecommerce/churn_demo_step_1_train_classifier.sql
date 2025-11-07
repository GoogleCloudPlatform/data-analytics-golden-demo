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
    - Use logistic regression machine learning in BigQuery to predict churn
    - model is automatically registered to Vertex AI Model Registry so all models, including Vertex AI custom models can be seen in one place
    - can deploy the model to a Vertex endpoint directly from Model Registry thereafter

Description: 
    -  Train the classification model (logistic regression) by calling this stored procedure:
    -  CALL ${project_id}.step0_train_classifier();
    -  Creating the model should take less than 1 min to run.

Show:
    - Click on the new model and explore the "EVALUATION" tab

References:
    - https://cloud.google.com/bigquery-ml/docs/reference/standard-sql/bigqueryml-syntax-create-glm

Clean up / Reset script:
    DROP MODEL IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.model_churn`;
*/


EXECUTE IMMEDIATE format("""
CREATE OR REPLACE MODEL `${project_id}`.${bigquery_thelook_ecommerce_dataset}.model_churn
   OPTIONS(
   MODEL_TYPE="LOGISTIC_REG", -- or BOOSTED_TREE_CLASSIFIER, DNN_CLASSIFIER, AUTOML_CLASSIFIER
   INPUT_LABEL_COLS=["churned"],
   MODEL_REGISTRY = "vertex_ai"
) AS
SELECT * EXCEPT(user_first_engagement, user_pseudo_id)
  FROM `${project_id}`.${bigquery_thelook_ecommerce_dataset}.training_data;
""");
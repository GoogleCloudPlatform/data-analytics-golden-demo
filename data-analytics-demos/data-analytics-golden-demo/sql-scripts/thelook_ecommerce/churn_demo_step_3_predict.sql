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
    - Make predictions based on the model to see the likelihood of each user to churn
    - focus on "probs" as the probability to churn (1: churn, 2: return someafter after 24 h)
    

Description: 
    - ML.EXPLAIN_PREDICT shows the:
      - predictions of likelihood (1 or 0)
      - probability (between 0 and 1.0) of churn
      - explainable AI with the top k features that contributed to the probability score
      - the test data columns used in the prediction

Show:
    - if probability is ~0.8+, then we can perhaps say they will return on their own away
    - if probability, is ~0.3 to ~0.8, then they may be on the fence about returning. This is a great group to target with incentives like coupons or marketing campaigns.
    - if probability is ~<0.3, then they may be unlikely to return anyway, so no need to waste resources sending out incentives
    - these probabilities of 0.3 and 0.8 are arbitrary -- a business can decide what they want as thresholds

References:
    - https://cloud.google.com/bigquery-ml/docs/reference/standard-sql/bigqueryml-syntax-predict

Clean up / Reset script:
    - n/a
*/


-- Predictions
EXECUTE IMMEDIATE format("""
SELECT *
  FROM ML.PREDICT(MODEL `${project_id}`.${bigquery_thelook_ecommerce_dataset}.model_churn,
       (SELECT * FROM `${project_id}`.${bigquery_thelook_ecommerce_dataset}.training_data))
""");

-- Explainable AI
EXECUTE IMMEDIATE format("""
SELECT *
  FROM ML.EXPLAIN_PREDICT(MODEL `${project_id}`.${bigquery_thelook_ecommerce_dataset}.model_churn,
       (SELECT * FROM `${project_id}`.${bigquery_thelook_ecommerce_dataset}.training_data))
""");
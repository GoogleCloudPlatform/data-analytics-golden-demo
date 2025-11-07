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
    - An e-commerce store collects Google Analytics 4 data. With their GA4 data in BigQuery, want to predict which users who have spend 24 hours on the website are most likely
    - to churn.  We can then provide coupons on incentives to entice the customer to come back to the store. 

Description: 
    - This will create the tables necessary to train the model

Show:
    - New tables will be created, based on the raw public data: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    - training_data: contains the final cleaned data used to train a classifier to predict churn, comprised of the three other tables joined togehter
    - returningusers: table to check if each user will return or churn
    - user_demographics: data on each user's demographic information
    - user_aggregate_behavior: data aggregated based on behavior of each user in their first 24h on the website

References:
    - https://cloud.google.com/bigquery-ml/docs/linear-regression-tutorial

Clean up / Reset script:
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.returningusers`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.user_demographics`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.user_aggregate_behavior`;
    DROP TABLE IF EXISTS `${project_id}.${bigquery_thelook_ecommerce_dataset}.training_data`;
*/



-- Exploring the dataset
SELECT *
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
TABLESAMPLE SYSTEM (1 PERCENT);


-- Identify users and churn label
CREATE OR REPLACE TABLE ${bigquery_thelook_ecommerce_dataset}.returningusers AS (
    WITH firstlasttouch AS (
      SELECT
        user_pseudo_id,
        MIN(event_timestamp) AS user_first_engagement,
        MAX(event_timestamp) AS user_last_engagement
      FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
      WHERE event_name='user_engagement'
      GROUP BY
        user_pseudo_id

      ), data AS (
      SELECT
        user_pseudo_id,
        user_first_engagement,
        user_last_engagement,
        EXTRACT(MONTH from TIMESTAMP_MICROS(user_first_engagement)) as month,
        EXTRACT(DAYOFYEAR from TIMESTAMP_MICROS(user_first_engagement)) as julianday,
        EXTRACT(DAYOFWEEK from TIMESTAMP_MICROS(user_first_engagement)) as dayofweek,
        -- add 24 hr to user's first visit
        (user_first_engagement + 86400000000) AS ts_24hr_after_first_engagement,

      -- churned = 1 if last_touch within 24 hr of first visit, else 0
      IF (user_last_engagement < (user_first_engagement + 86400000000),
          1,
          0 ) AS churned,

      -- bounced = 1 if last_touch within 10 min, else 0
      IF (user_last_engagement <= (user_first_engagement + 600000000),
          1,
          0 ) AS bounced,
        FROM
          firstlasttouch
        GROUP BY
          1,2,3
          )
    SELECT
      user_pseudo_id,
      TIMESTAMP_MICROS(user_first_engagement) user_first_engagement,
      TIMESTAMP_MICROS(user_last_engagement) user_last_engagement,
      month,
      julianday,
      dayofweek,
      TIMESTAMP_MICROS(ts_24hr_after_first_engagement) ts_24hr_after_first_engagement,
      churned,
      bounced
    FROM
      data);

-- Finding bounced and returning users
SELECT
    bounced,
    churned, 
    COUNT(churned) as count_users
FROM
    ${bigquery_thelook_ecommerce_dataset}.returningusers
GROUP BY 1,2
ORDER BY bounced;


-- Finding Churn rate
SELECT
   COUNTIF(churned=1)/COUNT(churned) as churn_rate
FROM
   ${bigquery_thelook_ecommerce_dataset}.returningusers
WHERE bounced = 0;


-- Extracting demographic data for Users
CREATE OR REPLACE TABLE ${bigquery_thelook_ecommerce_dataset}.user_demographics AS (
  WITH first_values AS (
      SELECT
          user_pseudo_id,
          geo.country as country,
          device.operating_system as operating_system,
          device.language as language,
          ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp DESC) AS row_num
      FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
      WHERE event_name="user_engagement"
      )
  SELECT * EXCEPT (row_num)
  FROM first_values
  WHERE row_num = 1
  );


-- Extracting Behavioral Data for Users
SELECT
   event_name,
   COUNT(event_name) as event_count
FROM
   `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY 1
ORDER BY
  event_count DESC;


-- Creating User Aggregate Behavior View 
CREATE OR REPLACE TABLE ${bigquery_thelook_ecommerce_dataset}.user_aggregate_behavior AS (
    WITH
  events_first24hr AS (
    -- select user data only from first 24 hr of using the website
    SELECT
      e.*
    FROM
      `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
    JOIN
      ${bigquery_thelook_ecommerce_dataset}.returningusers r
    ON
      e.user_pseudo_id = r.user_pseudo_id
    WHERE
      TIMESTAMP_MICROS(e.event_timestamp) <= r.ts_24hr_after_first_engagement
    )
    SELECT
        user_pseudo_id,
        SUM(IF(event_name = 'user_engagement', 1, 0)) AS cnt_user_engagement,
        SUM(IF(event_name = 'page_view', 1, 0)) AS cnt_page_view,
        SUM(IF(event_name = 'view_item', 1, 0)) AS cnt_view_item,
        SUM(IF(event_name = 'view_promotion', 1, 0)) AS cnt_view_promotion,
        SUM(IF(event_name = 'select_promotion', 1, 0)) AS cnt_select_promotion,
        SUM(IF(event_name = 'add_to_cart', 1, 0)) AS cnt_add_to_cart,
        SUM(IF(event_name = 'begin_checkout', 1, 0)) AS cnt_begin_checkout,
        SUM(IF(event_name = 'add_shipping_info', 1, 0)) AS cnt_add_shipping_info,
        SUM(IF(event_name = 'add_payment_info', 1, 0)) AS cnt_add_payment_info,
        SUM(IF(event_name = 'purchase', 1, 0)) AS cnt_purchase,
    FROM
        events_first24hr
    GROUP BY
        1
    );


-- Creating training_data combining returningusers,  user_demographics and user_aggregate_behavior 
CREATE OR REPLACE TABLE ${bigquery_thelook_ecommerce_dataset}.training_data AS (
    
  SELECT
    dem.*,
    IFNULL(beh.cnt_user_engagement, 0) AS cnt_user_engagement,
    IFNULL(beh.cnt_page_view, 0) AS cnt_page_view,
    IFNULL(beh.cnt_view_item, 0) AS cnt_view_item,
    IFNULL(beh.cnt_view_promotion, 0) AS cnt_view_promotion,
    IFNULL(beh.cnt_select_promotion, 0) AS cnt_select_promotion,
    IFNULL(beh.cnt_add_to_cart, 0) AS cnt_add_to_cart,
    IFNULL(beh.cnt_begin_checkout, 0) AS cnt_begin_checkout,
    IFNULL(beh.cnt_add_shipping_info, 0) AS cnt_add_shipping_info,
    IFNULL(beh.cnt_add_payment_info, 0) AS cnt_add_payment_info,
    IFNULL(beh.cnt_purchase, 0) AS cnt_purchase,
    ret.user_first_engagement,
    ret.month,
    ret.julianday,
    ret.dayofweek,
    ret.churned
  FROM
    ${bigquery_thelook_ecommerce_dataset}.returningusers ret
  LEFT OUTER JOIN
    ${bigquery_thelook_ecommerce_dataset}.user_demographics dem
  ON 
    ret.user_pseudo_id = dem.user_pseudo_id
  LEFT OUTER JOIN 
    ${bigquery_thelook_ecommerce_dataset}.user_aggregate_behavior beh
  ON
    ret.user_pseudo_id = beh.user_pseudo_id
  WHERE ret.bounced = 0
  );
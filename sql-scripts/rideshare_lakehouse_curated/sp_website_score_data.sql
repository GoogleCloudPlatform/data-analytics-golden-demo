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
  Use Cases:
      - For each pickup location this will use the AI/ML Model to score the data.  The results are then
        placed in a table.  The top 10 results are then presented based upon the highest scoring. 
  
  Description: 
      - This is called by the Rideshare Plus website
      
  Show:
      - 
  
  References:
      - 
  
  Clean up / Reset script:

  -- CALL `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.sp_website_score_data`('short', FALSE, FALSE, 0, 0);
  */

DECLARE Max_people_cnt, Max_people_traveling_cnt INT64;

BEGIN
BEGIN TRANSACTION;
    IF people_cnt = 0 AND people_traveling_cnt = 0 THEN 
       -- random counts if both values are zero (random up to our training data)
       SET (Max_people_cnt, Max_people_traveling_cnt) = (SELECT AS STRUCT CAST(MAX(people_cnt) AS INT64), CAST(MAX(people_traveling_cnt) AS INT64)
                                                           FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_model_training_data`);
       SET people_cnt           = CAST(ROUND(1 + RAND() * (Max_people_cnt - 1)) AS INT);
       SET people_traveling_cnt = CAST(ROUND(1 + RAND() * (Max_people_traveling_cnt - 1)) AS INT);
    END IF;   

    DELETE FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides` WHERE TRUE;

    -- Score every location to determine the highest value ones
    EXECUTE IMMEDIATE format("""
    INSERT INTO `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`
    (location_id, borough, zone, latitude, longitude, geo_point, pickup_year, pickup_month, pickup_day, 
    pickup_day_of_week, pickup_hour, ride_distance, is_raining, is_snowing, people_traveling_cnt, people_cnt, 
    is_high_value_ride, predicted_is_high_value_ride, execution_date) 
    SELECT CAST(location_id AS INT) AS location_id, 
        borough,
        zone,
        latitude ,
        longitude,
        geo_point,
        pickup_year,
        pickup_month,
        pickup_day,
        pickup_day_of_week,
        pickup_hour,
        ride_distance AS ride_distance,
        is_raining,
        is_snowing,
        CAST(people_traveling_cnt AS INT),
        CAST(people_cnt AS INT),
        CASE WHEN predicted_is_high_value_ride > .5 THEN TRUE
                ELSE FALSE
            END AS is_high_value_ride,
        predicted_is_high_value_ride,
        CURRENT_DATETIME() AS execution_date
    FROM ML.PREDICT (MODEL `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.model_predict_high_value`,
        (
        SELECT CAST(location_id AS STRING) AS location_id,
                borough,
                zone,
                latitude ,
                longitude,
                geo_point,
                CAST(EXTRACT(YEAR      FROM CURRENT_DATETIME()) AS STRING) AS pickup_year,
                CAST(EXTRACT(MONTH     FROM CURRENT_DATETIME()) AS STRING) AS pickup_month,
                CAST(EXTRACT(DAY       FROM CURRENT_DATETIME()) AS STRING) AS pickup_day,
                CAST(EXTRACT(DAYOFWEEK FROM CURRENT_DATETIME()) AS STRING) AS pickup_day_of_week,
                CAST(EXTRACT(HOUR      FROM CURRENT_DATETIME()) AS STRING) AS pickup_hour,
                '%s' AS ride_distance,
                %s AS is_raining,
                %s AS is_snowing,
                CAST(%s AS STRING) AS people_traveling_cnt,
                CAST(%s AS STRING) AS people_cnt
            FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_rideshare_zone`
        ));
      """, ride_distance,
           CAST(is_raining AS STRING),
           CAST(is_snowing AS STRING),
           CAST(people_traveling_cnt AS STRING),
           CAST(people_cnt AS STRING));

    -- Just so we have some results for the demo
    UPDATE `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides` parent
         SET is_high_value_ride = TRUE
       WHERE parent.location_id IN (SELECT location_id 
                                      FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`
                                     ORDER BY predicted_is_high_value_ride DESC
                                     LIMIT 5);

    -- Only show the top 10 rides (so the map is not too cluttered)
    DELETE
      FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`
     WHERE location_id NOT IN (SELECT location_id
                                 FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`
                                WHERE is_high_value_ride = TRUE
                             ORDER BY predicted_is_high_value_ride DESC
                                LIMIT 10);
  
    -- Optional: View values
    /*
    SELECT *
    FROM `${project_id}.${bigquery_rideshare_lakehouse_curated_dataset}.bigquery_predict_high_value_rides`
    WHERE is_high_value_ride = TRUE;
    */

    COMMIT TRANSACTION;
  EXCEPTION WHEN ERROR THEN
    -- Roll back the transaction inside the exception handler.
    SELECT @@error.message;
    ROLLBACK TRANSACTION;
END; -- Transaction
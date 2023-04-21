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
Prerequisites (10 minutes):
    - Execute Airflow DAG: sample-datastream-PRIVATE-ip-deploy (this will deploy a Cloud SQL database, a reverse proxy vm and datastream)

    - Verify the tables are starting to CDC to BigQuery (there will only be 1 row in each until you start the next DAG):
    NOTE: The dataset name datastream_private_ip_public as the suffix of "public".  This means we are syncing the public schema from Postgres.
    SELECT * FROM `${project_id}.datastream_private_ip_public.driver`;
    SELECT * FROM `${project_id}.datastream_private_ip_public.review`;
    SELECT * FROM `${project_id}.datastream_private_ip_public.payment`;

    - Execute Airflow DAG: sample-datastream-PRIVATE-ip-generate-data (this will generate test data that can be joined to the taxi data)
    - NOTE: There will be duplicate data since the SQL fiels is executed 10 times.

(OPTIONAL)
SSH to the SQL Reverse Proxy (so you can run psql SQL statements against the Cloud SQL database via command line)
    - Open this: https://console.cloud.google.com/compute/instances?project=${project_id}
    - Click on SSH
    - You might see an error: "VM is missing firewall rule allowing TCP ingress traffic from 35.235.240.0/20 on port 22."
    - You probably have to change the IP address (35.235.240.0/20) in the firewall rule. 
    - Open this:
    - Edit the Firewall rule: https://console.cloud.google.com/networking/firewalls/details/cloud-shell-ssh-firewall-rule?project=${project_id}
    - Click Edit
    - Change the Source IPv4 ranges to the IP Address shown in the SSH message
    - Click Save
    - Click retry in your SSH windows

Install postgresql client (you only needed to do once on the VM)
    sudo apt-get install wget ca-certificates
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo sh -c 'deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update -y
    sudo apt-get install postgresql postgresql-contrib -y

Run psql so you can run Ad-hov SQL statements:
    Open this to find the IP Address of your Cloud SQL: https://console.cloud.google.com/sql/instances?project=${project_id}
    psql --host=<<YOUR CLOUD SQL IP ADDRESS>> --user=postgres --password" -d demodb
    Enter the password of (this is the random extension used throughout this demo): ${random_extension}
    SELECT * FROM driver;
    SELECT * FROM review;
    SELECT * FROM payment;

(OPTIONAL)
Customizing the OLTP data:
    - You can create your own schema and test data by modifying the below files in your Composer "Data" directory
    - postgres_create_schema.sql           -> Customize this to create your own tables
    - postgres_create_generated_data.sql   -> Customize this to create your own test data

Use Cases:
    - Offload your analytics from your OLTP databases to BigQuery
    - Avoid purchasing (potentially expensive) licenses for packaged software 
    - Avoid puchasing addition hardware for your OLTP database (or storage SAN) and save on licenses
    - Perform analytics accross your disparent OLTP databases by CDC to BigQuery

Description: 
    - This will CDC data from a Cloud SQL Postgres database
    - The database is using a Private IP address
    - Datastream has been configured to connect to the Private IP address via a sql-reverse-proxy VM
    - We we join from our OLTP (CDC) data for drivers, reviews and payments to match to our warehouse

Reference:
    - n/a

Clean up / Reset script:
    - Execute Airflow DAG: sample-datastream-PRIVATE-ip-destroy
    
*/


-- See the streaming data
SELECT * FROM `${project_id}.datastream_private_ip_public.driver`;
SELECT * FROM `${project_id}.datastream_private_ip_public.review`;
SELECT * FROM `${project_id}.datastream_private_ip_public.payment`; 
  

-- See the counts change (the replication has been set low, but it can take up to 15 seconds)
-- Make sure the Airflow job sample-datastream-private-ip-generate-data is running
SELECT COUNT(*) AS Cnt FROM `${project_id}.datastream_private_ip_public.driver`;
SELECT COUNT(*) AS Cnt FROM `${project_id}.datastream_private_ip_public.review`;
SELECT COUNT(*) AS Cnt FROM `${project_id}.datastream_private_ip_public.payment`; 


-- We can find determine rating of our drivers based upon the data
-- We can bring ride duration and other fields by joining the CDC data to the warehouse
WITH driver_data AS
(
    SELECT driver_id, driver_name
     FROM `${project_id}.datastream_private_ip_public.driver`
)
, overall_drive_rating AS
(
    SELECT driver_id, AVG(CAST(review_rating AS FLOAT64)) AS average_rating
      FROM `${project_id}.datastream_private_ip_public.review`
     GROUP BY 1
)
, warehouse_data AS
(
    SELECT trips.TaxiCompany, 
           trips.PULocationID,
           trips.Passenger_Count, 
           trips.Trip_Distance, 
           TIMESTAMP_DIFF(trips.Dropoff_DateTime, trips.Pickup_DateTime, MINUTE) AS ride_duration_in_minutes,
           reviews.driver_id
      FROM `${project_id}.datastream_private_ip_public.review` AS reviews
           INNER JOIN `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS trips
                   ON reviews.ride_date = CAST(trips.Pickup_DateTime AS DATE)
                  AND reviews.pickup_location_id = trips.PULocationID
                  AND reviews.dropoff_location_id = trips.DOLocationID
                  AND reviews.total_amount = trips.Total_Amount
)
SELECT warehouse_data.*, 
       driver_data.driver_name,
       overall_drive_rating.average_rating
  FROM warehouse_data
       LEFT JOIN overall_drive_rating
               ON warehouse_data.driver_id = overall_drive_rating.driver_id
       LEFT JOIN driver_data
               ON warehouse_data.driver_id = driver_data.driver_id
ORDER BY driver_data.driver_name ;


-- Optional - perform machine learning on the data or use in a dashboard to show trending data


-- See the payment data to see customers who are paying with credit cards
WITH credit_card_data AS
(
    SELECT DISTINCT driver_id, ride_date, credit_card_name,credit_card_number,  pickup_location_id, dropoff_location_id, total_amount
      FROM `${project_id}.datastream_private_ip_public.payment`
    WHERE driver_id <= 1000 -- The data generator can generate dups so we clean here
)
SELECT driver.driver_name,
       payment.credit_card_name,
       payment.credit_card_number,
       trips.*
  FROM `${project_id}.datastream_private_ip_public.driver` AS driver
       INNER JOIN credit_card_data AS payment
               ON payment.driver_id = driver.driver_id
       LEFT JOIN `${project_id}.${bigquery_taxi_dataset}.taxi_trips` AS trips
               ON payment.ride_date = CAST(trips.Pickup_DateTime AS DATE)
              AND payment.pickup_location_id = trips.PULocationID
              AND payment.dropoff_location_id = trips.DOLocationID
              AND payment.total_amount = trips.Total_Amount
              AND trips.Payment_Type_Id = 1 -- credit card
ORDER BY driver.driver_name;
              

-- Counts should be increasing
SELECT COUNT(*) AS Cnt FROM `${project_id}.datastream_private_ip_public.driver`;
SELECT COUNT(*) AS Cnt FROM `${project_id}.datastream_private_ip_public.review`;
SELECT COUNT(*) AS Cnt FROM `${project_id}.datastream_private_ip_public.payment`; 
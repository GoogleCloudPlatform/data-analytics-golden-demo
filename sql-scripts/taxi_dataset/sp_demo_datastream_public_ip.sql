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
      - Disable Org Policy: sql.restrictAuthorizedNetworks
        OPEN: https://console.cloud.google.com/iam-admin/orgpolicies/sql-restrictAuthorizedNetworks/edit?project=data-analytics-demo-itfo3j9qq5
            - Click "Customize"
            - Click "Add Rule"
            - Click "Off"
            - Save
      - Execute Airflow DAG: sample-datastream-PUBLIC-ip-deploy (this will deploy a Cloud SQL database, a reverse proxy vm and datastream)
      - Re-Enabled (after DAG is complete) Org Policy: sql.restrictAuthorizedNetworks
        OPEN: https://console.cloud.google.com/iam-admin/orgpolicies/sql-restrictAuthorizedNetworks/edit?project=data-analytics-demo-itfo3j9qq5
            - Click "Inherit parent's policy"
            - Save

      - Verify the tables are starting to CDC to BigQuery (there will only be 1 row in each until you start the next DAG):
        NOTE: The dataset name datastream_public_ip_public as the suffix of "public".  This means we are syncing the public schema from Postgres.
        SELECT * FROM `data-analytics-demo-itfo3j9qq5.datastream_public_ip_public.driver`;
        SELECT * FROM `data-analytics-demo-itfo3j9qq5.datastream_public_ip_public.review`;
        SELECT * FROM `data-analytics-demo-itfo3j9qq5.datastream_public_ip_public.payment`;

      - Execute Airflow DAG: sample-datastream-PUBLIC-ip-generate-data (this will generate test data that can be joined to the taxi data)
        - NOTE: There will be duplicate data since the SQL fiels is executed 10 times.

  (OPTIONAL)
  Install pgAdmin to connect to your database
      Open this to find the IP Address of your Cloud SQL: https://console.cloud.google.com/sql/instances?project=data-analytics-demo-itfo3j9qq5
      You will need to Edit your database and add your Public IP (Google "whats my ip")
        - Click Edit
        - Expand Connections
        - Added your public IP address to "Authorized networks"
        - Click Save (it will take a minute)
      Username: postgres
      Database password (this is the random extension used throughout this demo): ${random_extension}
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
      - The database is using a Public IP address
      - Datastream has been configured to connect to the Public IP address with allowed IP address to your database
      - We we join from our OLTP (CDC) data for drivers, reviews and payments to match to our warehouse
  
  Reference:
      - n/a
  
  Clean up / Reset script:
      - Execute Airflow DAG: sample-datastream-PUBLIC-ip-destroy
      
  */
select 1;